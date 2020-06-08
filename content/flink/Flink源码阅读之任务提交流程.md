---
title: "Flink源码阅读之任务提交流程"
date: 2020-06-08T16:59:22+08:00
draft: true
---

# Flink 源码阅读之任务提交基本流程

org.apache.flink.runtime.blob.BlobServer#run
java.net.ServerSocket#accept

BlobServer.run

涉及的类:

org.apache.flink.client.cli.CliFrontend
org.apache.flink.client.ClientUtils
org.apache.flink.streaming.examples.wordcount.WordCount

org.apache.flink.runtime.blob.BlobServer#run

org.apache.flink.runtime.taskexecutor.TaskExecutor#submitTask

org.apache.flink.runtime.deployment.TaskDeploymentDescriptor

## 流程准备

以远程调试模式运行
org.apache.flink.client.cli.CliFrontend

org.apache.flink.runtime.entrypoint.StandaloneSessionClusterEntrypoint

org.apache.flink.runtime.taskexecutor.TaskManagerRunner

使用 ./flink 提交 WordCount.jar, 查看整个任务的流转过程

org.apache.flink.client.program.PackagedProgram#callMainMethod
java.lang.reflect.Method#invoke

org.apache.flink.streaming.api.environment.StreamContextEnvironment#execute

org.apache.flink.streaming.api.graph.StreamGraphGenerator#generate

org.apache.flink.streaming.api.graph.StreamGraphGenerator#transform

org.apache.flink.streaming.api.environment.StreamExecutionEnvironment#executeAsync(org.apache.flink.streaming.api.graph.StreamGraph)

org.apache.flink.core.execution.JobListener#onJobSubmitted

org.apache.flink.client.program.rest.RestClusterClient#submitJob

JM

org.apache.flink.runtime.dispatcher.Dispatcher#submitJob
log.info("Received JobGraph submission {} ({}).", jobGraph.getJobID(), jobGraph.getName());

org.apache.flink.runtime.dispatcher.Dispatcher#runJob

org.apache.flink.runtime.dispatcher.Dispatcher#createJobManagerRunner

flink-rest-server-netty-worker-thread
org.apache.flink.runtime.rest.handler.AbstractRestHandler#handleRequest
org.apache.flink.runtime.rest.handler.AbstractRestHandler#respondToRequest

org.apache.flink.runtime.rpc.akka.AkkaRpcActor#handleRpcMessage

JM
org.apache.flink.runtime.blob.BlobServer#run
java.net.ServerSocket#accept

org.apache.flink.streaming.api.environment.StreamContextEnvironment#execute


Job 发到 JM 后

org.apache.flink.runtime.dispatcher.Dispatcher#runJob

org.apache.flink.runtime.jobmaster.JobMaster#offerSlots

Scheduler 调度 生成 StreamGraph
org.apache.flink.runtime.executiongraph.Execution

发给 TM
RemoteRpcInvocation(submitTask(TaskDeploymentDescriptor, JobMasterId, Time))

org.apache.flink.runtime.taskexecutor.TaskExecutor#submitTask

submitTask 方法 new 一个 Task

TM 去 Blobserver 拿jar
https://juejin.im/post/5e80ae51518825736d278248

org.apache.flink.runtime.taskmanager.Task#startTaskThread


InputGateDeploymentDescriptor 是什么


## What‘s more

通过基本的执行流程我们可以衍生出很多精进的知识去了解.

- 如何生成 Job 链
- RPC 具体实现, 都是干嘛的
- Checkpoint机制
- Task 容错
- 与Kafka 的对接等等
