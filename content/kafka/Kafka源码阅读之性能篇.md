---
title: "Kafka源码阅读之性能篇"
date: 2020-05-08T17:01:30+08:00
draft: true
---

# kafka源码解析之性能篇

## 概念篇

### Linux 的 Page Cache 和 Buffer Cache

page cache是系统读写磁盘文件时为了提高性能而将一部分文件缓存到内存中。
这种做法虽然提高了磁盘I/O性能，但是也极大的占用了物理内存，特别当系统内存紧张时更容易出现问题。

也就是说，我们平常向硬盘写文件时，默认异步情况下，并不是直接把文件内容写入到硬盘中才返回的，而是成功拷贝到内核的page cache后就直接返回，所以大多数情况下，硬盘写操作不会是性能瓶颈。写入到内核page cache的pages成为dirty pages，稍后会由内核线程pdflush真正写入到硬盘上。

从硬盘读取文件时，同样不是直接把硬盘上文件内容读取到用户态内存，而是先拷贝到内核的page cache，然后再“拷贝”到用户态内存，这样用户就可以访问该文件。因为涉及到硬盘操作，所以第一次读取一个文件时，不会有性能提升；不过，如果一个文件已经存在page cache中，再次读取该文件时就可以直接从page cache中命中读取不涉及硬盘操作，这时性能就会有很大提高。

### Page Cache 的构成

page cache中的每个文件都是一棵基数树（radix tree，本质上是多叉搜索树），树的每个节点都是一个页。根据文件内的偏移量就可以快速定位到所在的页，如下图所示。

![page cache](./images/page.jpg)

## 原理篇

Kafka为什么不自己管理缓存，而非要用page cache？原因有如下三点：

1. JVM中一切皆对象，数据的对象存储会带来所谓object overhead，浪费空间；

2. 如果由JVM来管理缓存，会受到GC的影响，并且过大的堆也会拖累GC的效率，降低吞吐量；

3. 一旦程序崩溃，自己管理的缓存数据会全部丢失。

Kafka三大件（broker、producer、consumer）与page cache的关系可以用下面的简图来表示。

![page cache](./images/pagecache.jpg）

producer生产消息时，会使用**pwrite()**系统调用【对应到Java NIO中是**FileChannel.write()** API】按**偏移量**写入数据，并且都会**先写入page cache**里。consumer消费消息时，会使用**sendfile()**系统调用【对应**FileChannel.transferTo()** API】，**零拷贝**地将数据从page cache传输到broker的Socket buffer，再通过网络传输。

<https://zhuanlan.zhihu.com/p/105509080>

图中没有画出来的还有leader与follower之间的同步，这与consumer是同理的：只要follower处在ISR中，就也能够通过零拷贝机制将数据从leader所在的broker page cache传输到follower所在的broker。

同时，page cache中的数据会随着内核中flusher线程的调度以及对sync()/fsync()的调用写回到磁盘，就算进程崩溃，也不用担心数据丢失。另外，如果consumer要消费的消息不在page cache里，才会去磁盘读取，并且会顺便预读出一些相邻的块放入page cache，以方便下一次读取。

由此我们可以得出重要的结论：**如果Kafka producer的生产速率与consumer的消费速率相差不大，那么就能几乎只靠对broker page cache的读写完成整个生产-消费过程**，磁盘访问非常少。并且Kafka持久化消息到各个topic的partition文件时，是只追加的顺序写，充分利用了磁盘顺序访问快的特性，效率高。

### 注意事项与相关参数

对于单纯运行Kafka的集群而言，首先要注意的就是为Kafka设置合适（不那么大）的JVM堆大小。从上面的分析可知，Kafka的性能与堆内存关系并不大，而对page cache需求巨大。根据经验值，为**Kafka分配5~8GB的堆内存**就已经足足够用了，将剩下的系统内存都作为page cache空间，可以最大化I/O效率。

另一个需要特别注意的问题是**lagging consumer**，即那些消费速率慢、明显落后的consumer。它们要读取的数据有较大概率不在broker page cache中，因此会增加很多不必要的读盘操作。比这更坏的是，lagging consumer读取的“冷”数据仍然会进入page cache，污染了多数正常consumer要读取的“热”数据，连带着正常consumer的性能变差。在生产环境中，这个问题尤为重要。


前面已经说过，page cache中的数据会随着内核中flusher线程的调度写回磁盘。与它相关的有以下4个参数，必要时可以调整。

/proc/sys/vm/dirty_writeback_centisecs：flush检查的周期。单位为0.01秒，默认值500，即5秒。每次检查都会按照以下三个参数控制的逻辑来处理。

/proc/sys/vm/dirty_expire_centisecs：如果page cache中的页被标记为dirty的时间超过了这个值，就会被直接刷到磁盘。单位为0.01秒。默认值3000，即半分钟。

/proc/sys/vm/dirty_background_ratio：如果dirty page的总大小占空闲内存量的比例超过了该值，就会在后台调度flusher线程异步写磁盘，不会阻塞当前的write()操作。默认值为10%。

/proc/sys/vm/dirty_ratio：如果dirty page的总大小占总内存量的比例超过了该值，就会阻塞所有进程的write()操作，并且强制每个进程将自己的文件写入磁盘。默认值为20%。


由此可见，调整空间比较灵活的是参数2、3，而尽量不要达到参数4的阈值，代价太大了。

我们在性能上已经做了很大的努力。 我们主要的使用场景是处理WEB活动数据，这个数据量非常大，因为每个页面都有可能大量的写入。此外我们假设每个发布 message 至少被一个consumer (通常很多个consumer) 消费， 因此我们尽可能的去降低消费的代价。

我们还发现，从构建和运行许多相似系统的经验上来看，性能是多租户运营的关键。如果下游的基础设施服务很轻易被应用层冲击形成瓶颈，那么一些小的改变也会造成问题。通过非常快的(缓存)技术，我们能确保应用层冲击基础设施之前，将负载稳定下来。 当尝试去运行支持集中式集群上成百上千个应用程序的集中式服务时，这一点很重要，因为应用层使用方式几乎每天都会发生变化。

我们在上一节讨论了磁盘性能。 一旦消除了磁盘访问模式不佳的情况，该类系统性能低下的主要原因就剩下了两个：大量的小型 I/O 操作，以及过多的字节拷贝。

小型的 I/O 操作发生在客户端和服务端之间以及服务端自身的持久化操作中。

为了避免这种情况，我们的协议是建立在一个 “消息块” 的抽象基础上，合理将消息分组。 这使得网络请求将多个消息打包成一组，而不是每次发送一条消息，从而使整组消息分担网络中往返的开销。Consumer 每次获取多个大型有序的消息块，并由服务端 依次将消息块一次加载到它的日志中。

这个简单的优化对速度有着数量级的提升。批处理允许更大的网络数据包，更大的顺序读写磁盘操作，连续的内存块等等，所有这些都使 KafKa 将随机流消息顺序写入到磁盘， 再由 consumers 进行消费。

另一个低效率的操作是字节拷贝，在消息量少时，这不是什么问题。但是在高负载的情况下，影响就不容忽视。为了避免这种情况，我们使用 producer ，broker 和 consumer 都共享的标准化的二进制消息格式，这样数据块不用修改就能在他们之间传递。

broker 维护的消息日志本身就是一个文件目录，每个文件都由一系列以相同格式写入到磁盘的消息集合组成，这种写入格式被 producer 和 consumer 共用。保持这种通用格式可以对一些很重要的操作进行优化: 持久化日志块的网络传输。 现代的unix 操作系统提供了一个高度优化的编码方式，用于将数据从 pagecache 转移到 socket 网络连接中；在 Linux 中系统调用 sendfile 做到这一点。

为了理解 sendfile 的意义，了解数据从文件到套接字的常见数据传输路径就非常重要：

1. 操作系统从磁盘读取数据到内核空间的 pagecache
2. 应用程序读取内核空间的数据到用户空间的缓冲区
3. 应用程序将数据(用户空间的缓冲区)写回内核空间到套接字缓冲区(内核空间)
4. 操作系统将数据从套接字缓冲区(内核空间)复制到通过网络发送的 NIC 缓冲区
5. 这显然是低效的，有四次 copy 操作和两次系统调用。使用 sendfile 方法，可以允许操作系统将数据从 pagecache 直接发送到网络，这样避免重新复制数据。所以这种优化方式，只需要最后一步的copy操作，将数据复制到 NIC 缓冲区。

我们期望一个普遍的应用场景，一个 topic 被多消费者消费。使用上面提交的 **zero-copy（零拷贝）**优化，数据在使用时只会被复制到 pagecache 中一次，节省了每次拷贝到用户空间内存中，再从用户空间进行读取的消耗。这使得消息能够以接近网络连接速度的 上限进行消费。

pagecache 和 sendfile 的组合使用意味着，在一个kafka集群中，大多数 consumer 消费时，您将看不到磁盘上的读取活动，因为数据将完全由缓存提供。

## Ref

https://blog.csdn.net/u013411339/article/details/99514789

http://kafka.apachecn.org/documentation.html#persistence

https://zhuanlan.zhihu.com/p/105509080

https://shiyueqi.github.io/2017/04/27/Kafka-Pagecache%E5%8E%9F%E7%90%86/

https://www.jianshu.com/p/f0b294062de8

https://www.jianshu.com/p/f0b294062de8