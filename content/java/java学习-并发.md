---
title: "Java学习 并发"
date: 2020-06-29T18:16:04+08:00
draft: true
---

# Java 并发

> 记录在各个地方学到的小知识, 起常看常新和弥补作用

并发知识索引:

什么是线程, 线程的状态, 线程可以干嘛, 为了解决线程干嘛带来的新问题的解决方案.

## 《Java 核心技术》

Runnable 状态是因为: 此时线程可能正在运行也可能没在运行, 要由操作系统为线程提供具体的运行时间, 线程调度的细节依赖于操作系统提供的服务.

线程的状态: New、Runnable、Terminated、+ 并发所产生的三个condition: Blocked、Waiting、Timed Waiting.

在 Race Condition 竞态条件下, 同步的几种锁使用方式:

1. synchronized, 不够灵活
2. ReentrantLock, 灵活, 需要在 finally unlock
3. 使用object 自带的内部锁 锁自己(flink 常用) synchronized (lock) {}

条件对象的使用需要注意: if a > 0 , xxx , 这两步中间可能就导致不一致, 可以用 Condition 来操作

如果是实例字段的话使用 volatile 关键字.

stop 方法不会执行 finally 语句块, 导致一些锁得不到释放, 因此不再使用.

- [ ] BlockingQueue 常用的几个基本实现原理.
- [ ] 起线程开销大, 涉及到和操作系统的交互, 因此有线程池. Executors 常用方法.
- [ ] Fork Join 基本原理 (akka 使用)

## 开源世界