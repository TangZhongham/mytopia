---
title: "Kafka源码阅读之ServerSocketChannel"
date: 2020-05-08T17:02:23+08:00
draft: true
---

# kafka源码解析之 ServerSocketChannel 详解

> 由于kafka socketServer 使用到了 nio 的 serverSocketChannel, 本文详细解析了 该类的使用方法。
> <https://blog.csdn.net/kavu1/article/details/53212178>

Kafka 的 kafka.network.Acceptor 负责监听外界 Socket 连接并把请求转发给 kafka.network.Processor，完事后
Processor 负责转发 Socket 的请求和响应，并将其发送到 kafka.network.RequestChannel。

与java.net.Socket类和java.net.ServerSocket类相对应，NIO也提供了SocketChannel和ServerSocketChannel两种不同的套接字通道实现。这两种新增的通道都支持阻塞和非阻塞两种模式。
低负载、低并发的应用程序可以选择同步阻塞I/O以降低编程复杂度；对于高负载、高并发的网络应用，需要使用NIO的非阻塞模式进行开发。
链接：<https://www.jianshu.com/p/5442b04ccff8>

**注意**, 如果一个 Channel 要注册到 **Selector** 中, 那么这个 Channel 必须是**非阻塞**的, 即channel.configureBlocking(false);
因为 Channel 必须要是非阻塞的, 因此 FileChannel 是不能够使用选择器的, 因为 FileChannel 都是阻塞的.

## ServerSocketChannel 与 ServerSocket

ServerSocketChannel类似于SocketChannel,只不过ServerSocketChannel使用server端.ServerSocketChannel是ServerSocket + Selector的高层
封装.可以通过socket()方法获得与其关联的ServerSocket.

事实上**channel即为socket链接的高层封装**,每个channel都绑定在一个socket上,它们息息相关.

SocketChannel的关闭支持异步关闭(来自InterruptableChannel特性),这与Channel类中指定的异步close操作有关.如果一个线程关闭了某个Socket input,那么同时另一个线程被阻塞在该SocketChannel的read操作中,那么处于阻塞线程中的读取操作将完成,而不读取任何字节且返回-1.如果一个线程关闭了socket output,而同时另一个线程被阻塞在该socketChannel的write操作中,此时阻塞线程将收到AsynchronousClosedException.

SocketChannel是线程安全的,但是任何时刻只能有一个线程处于read或者write操作(read操作同步readLock,write操作同步writeLock,2个线程可以同时进行read和write;),不过DatagramChannel支持并发的读写.

参考:<http://shift-alt-ctrl.iteye.com/blog/1840409>

## NIO 的四种事件

| OP\_ACCEPT | OP\_CONNECT | OP\_WRITE | OP\_READ |                     |     |
|------------|-------------|-----------|----------|---------------------|-----|
|            | Y           | Y         | Y        | SocketChannel       | 客户端 |
| Y          |             |           |          | ServerSocketChannel | 服务端 |
|            |             | Y         | Y        | SocketChannel       | 服务端 |
|            |             |           |          |                     |     |

就绪条件：

OP_ACCEPT就绪条件：
当收到一个客户端的连接请求时，该操作就绪。这是ServerSocketChannel上唯一有效的操作。
OP_CONNECT就绪条件：
只有客户端SocketChannel会注册该操作，当客户端调用SocketChannel.connect()时，该操作会就绪。
OP_READ就绪条件：
该操作对客户端和服务端的SocketChannel都有效，当OS的读缓冲区中有数据可读时，该操作就绪。
OP_WRITE就绪条件：
该操作对客户端和服务端的SocketChannel都有效，当OS的写缓冲区中有空闲的空间时，该操作就绪。

## Acceptor 与 java.nio.channels.ServerSocketChannel

可以理解为 Acceptor 为了和 processor 通信， 是包装了 一层的 ServerSocketChannel。

查看 acceptor 的 class 和 run 方法， 发现主要是：

1. 通过 new ServerSocketChannel 开启 Socket 服务
2. 注册 OP_ACCEPT 事件，表示该accptor 可以被外界访问，已经开始监听
3. 通过 key.isAcceptable 确认 acceptor 正常，使用 round-robin 轮询将对应的 SocketChannel 发送到 Processor 线程。

Selector不断轮询是否有事件准备好了，如果有事件准备好了则获取事件相应的SelectionKey，进入事件处理