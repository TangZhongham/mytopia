---
title: "Kafka源码阅读之socketServer原理篇"
date: 2020-05-08T12:00:33+08:00
draft: true
---

# Kafka 源码解析之 socketServer 原理篇

> Kafka 是如何做到百万级高并发低延迟的?

## 原理

有别于传统的 thread per connection 模型, Kafka 使用基于 NIO 实现的 Reactor 模型.

Kafka 使用 nio 实现了自己的 socketServer 网络层代码, 而非常见的 netty、mina 框架, 从性能上来看这一块并不是主要的性能瓶颈.

kafka socketServer 通信采取的是 NIO 的reactor模式, 是一种事件驱动模式.

## 什么是 Reactor 模型

1. 同步的等待多个事件源到达（采用select()实现）

2. 将事件多路分解以及分配相应的事件服务进行处理，这个分派采用server集中处理（dispatch）

3. 分解的事件以及对应的事件服务应用从分派服务中分离出去（handler）

### 为何需要 Reactor 模型

1. 同步阻塞IO，读写阻塞，线程等待时间过长
2. 在制定线程策略的时候，只能根据CPU的数目来限定可用线程资源，不能根据连接并发数目来制定，也就是连接有限制。否则很难保证对客户端请求的高效和公平。
3. 多线程之间的上下文切换，造成线程使用效率并不高，并且不易扩展
4. 状态数据以及其他需要保持一致的数据，需要采用并发同步控制

## Kafka 的 socketServer 如何实现 Reactor 模型

## kafka 的架构模型

工作原理：
1）先创建ServerSocketChannel对象并在Selector上注册OP_ACCEPT事件，ServerSocketChannel负责监听指定端口上的连接请求。
2）当客户端发起服务端的网络连接时，服务端的Selector监听到此OP_ACCEPT事件，会触发Acceptor来处理OP_ACCEPT。
3）当Acceptor接收到来自客户端的Socket连接请求时会为这个连接创建响应的SocketChannel，将SocketChannel设置为非阻塞模式，并在Selector上注册其关注的I/O事件，如OP_READ,OP_WRITE。此时，客户端和服务端的Socket连接建立完成。
4）当客户端通过已经建立的SocketChannel连接向服务端发送请求时，服务端的Selector会监听到OP_READ事件，并触发执行相应的处理逻辑（上图中的Reader Handler）。当服务端可以向客户端写数据时，服务端的Selector会监听到OP_WRITE事件，并触发相应的执行逻辑（上图中的Writer Handler）。
这些事情都是在同一个线程完成的，KafkaProducer中的Sender线程以及KafkaConsumer的代码都是这种设计。这样的设计时候客户端这样的并发连接数小，数据量较小的场景，这样对于服务端来说就会有缺点。如：某个请求的处理过程比较复杂会造成线程的阻塞，造成所有的后续请求读无法处理，这就会导致大量的请求超时。为了避免这种情况，就必须要求服务端在读取请求，处理请求已经发送响应等各个环节上必须能迅速的完成，这样就提升了编程的难度，在有些情况下实现不了。而且这种模式不能利用服务器多核多处理器的并行处理能力，造成资源的浪费。
为了满足高并发的需求，服务端需要使用多线程来执行逻辑。我们可以对上述架构做调整，将网络的读写的逻辑和业务处理的逻辑进行拆分，让其由不同的线程池来处理，从而实现多线程处理。
链接：https://www.jianshu.com/p/0239a3ced855

客户端请求NIO的连接器Acceptor，同时它还具备事件的转发功能，转发到Processor处理,服务端网络事件处理器Processor 请求队列RequestChannel，存储了所有待处理的请求信息, 请求处理线程池(RequestHandlerPool)作为守护线程轮训RequestChannel的请求处理信息，并将其转发给API层对应的处理器处理API层处理器将请求处理完成之后放入到Response Queue中，并由Processor从ResponseQueue取出发送到对应的Client端.

1. 1 个 Acceptor 线程，负责监听 Socket 新的连接请求，注册了 OP_ACCEPT 事件，将新的连接按照 round robin 方式交给对应的 Processor 线程处理；**注意** kafka 一般情况下的 reactor 模型还是单线程Acceptor多线程handler, 每个 EndPoint (网卡) 只能构造一个 Acceptor.
2. N 个 Processor 线程，其中每个 Processor 都有自己的 selector，它会向 Acceptor 分配的 SocketChannel 注册相应的 OP_READ 事件，N 的大小由 num.networker.threads (3) 决定；
3. M 个 KafkaRequestHandler 线程处理请求，并将处理的结果返回给 Processor 线程对应的 response queue 中，由 Processor 将处理的结果返回给相应的请求发送者，M 的大小由 num.io.threads (8) 来决定。

整体请求流程如下:

1. Acceptor 监听到来自请求者（请求者可以是来自 client，也可以来自 server）的新的连接，Acceptor 将这个请求者按照 round robin 的方式交给对对应的 Processor 进行处理；
2. Processor 注册这个 SocketChannel 的 OP_READ 的事件，如果有请求发送过来就可以被 Processor 的 Selector 选中；
3. Processor 将请求者发送的请求放入到一个 Request Queue 中，这是所有 Processor 共有的一个队列；queued.max.requests requestChannel 的大小, 默认500
4. KafkaRequestHandler 从 Request Queue 中取出请求；
5. 调用 KafkaApis 进行相应的处理；
6. 处理的结果放入到该 Processor 对应的 Response Queue 中（每个 request 都标识它们来自哪个 Processor），Request Queue 的数量与 Processor 的数量保持一致；
7. Processor 从对应的 Response Queue 中取出 response；
8. Processor 将处理的结果返回给对应的请求者

## 源码详解

<https://www.geek-share.com/detail/2789927213.html>
<https://www.jianshu.com/p/ff1432f5a14b>

### Acceptor

Acceptor是NIO里面的一个轻量级接入服务，它主要包含如下变量：

nioSelector：Java的NIO网络选择器
serverChannel：ip和端口绑定到socket
Processors:processor的容器，存放的是processor对象

**它的主要处理流程如下：**

1. 将nioSelector注册为OP_ACCEPT

2. 轮训从nioSelector读取事件

3. 通过RR的模式选择processor (Round-Robin)

4. 接收一个新的链接设置(从serverSocketChannel获取socketChannel，并对它的属性进行设置)

5. 移交processor的accept处理

### Processor

Processor的主要职责是将来自客户端的网络链接请求封装成RequestContext并发送给RequestChannel，同时需要对handler处理完的响应回执发送给客户端。它主要包括：

newConnections：是一个线程安全的队列，存放从acceptor接收到的网络新链接
inflightResponses：已发送客户端的响应，存放了和客户端的链接id(由本地ip、port以及远端ip、port还有额外一个序列值组成)和响应对象的映射
responseQueue：是一个阻塞队列，存放handler的响应请求

**它的主要处理流程如下：**

1. proccessor线程从newConnections中轮询获取socketChannel，并将selector监听事件修改为OP_READ；

2. processNewResponses处理新的响应需求，其中类型为SendAction的就是向客户端发送响应，并将发送的响应记录在inflightResponses ,它的核心逻辑是sendResponse如下：

3. Selector调用poll从客户端获取到的请求信息，并将获取到的NetworkReceive添加到completedReceives缓存中。

4. 而processCompletedReceives负责处理completedReceives中的接收信息，最后封装为RequestChannel.Request，再调用requestChannel将请求添加到发送队列（即requestQueue）当中，源码逻辑如下所示：

### RequestChannel

requestChannel承载了kafka请求和响应的所有转发，它包含有如下两个变量：

requestQueue：是一个加锁阻塞队列，RequestChannel传输请求和响应信息的重要组件，上面讲到的RequestChannel.Request就是被放入到这个队列中

Processors：存储了processorid和processor的映射关系，主要是在response发送的时候从中选择对应的processor
它的两个核心功能是添加请求和发送响应回执，源码逻辑分别如下：

## Selector 的封装 (TODO)

https://blog.csdn.net/zhanyuanlin/article/details/76906583
https://blog.csdn.net/zhanyuanlin/article/details/76556578
https://matt33.com/2018/06/27/kafka-server-process-model/
https://www.zhenchao.org/2019/06/21/kafka/kafka-reactor/

## Ref

<https://www.geek-share.com/detail/2789927213.html>

Reactor
<https://juejin.im/post/5b4570cce51d451984695a9b>
