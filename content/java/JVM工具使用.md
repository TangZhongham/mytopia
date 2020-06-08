---
title: "JVM工具使用"
date: 2020-06-08T17:04:06+08:00
draft: true
---

# Java 基础运维工具使用

>

## jps

JVM Process Status Tool, 用于列出正在运行的虚拟机进程. 用于查看pod 内是否存在进程挂掉/验证是否手动添加JVM参数。
inceptor/slipstream 可以配合 grep 查询虚拟机启动时**显式指定的JVM参数**。显示没有jinfo全，但是够用。

```shell
[root@linux-158-15 ~]# jps -v | more
43 InceptorServer2 -agentpath:/usr/lib/inceptor/bin/libagent.so -XX:MetaspaceSiz
e=512m -XX:MaxMetaspaceSize=2g -Djava.net.preferIPv4Stack=true -Dsun.net.inetadd
r.ttl=60 -XX:+UseParNewGC -XX:NewRatio=4 -XX:+CMSClassUnloadingEnabled -XX:MinHe
apFreeRatio=100 -XX:MaxHeapFreeRatio=100 -XX:CMSMaxAbortablePrecleanTime=1000 -X
X:+ExplicitGCInvokesConcurrent -XX:MaxTenuringThreshold=4 -XX:TargetSurvivorRati
o=8 -XX:+HeapDumpOnOutOfMemoryError -XX:+UseConcMarkSweepGC -XX:CMSInitiatingOcc
upancyFraction=70 -Xms2048m -Xmx8192m -verbose:gc -XX:+PrintGCDetails -XX:+Print
GCDateStamps -XX:+PrintGCTimeStamps -Djava.library.path=/usr/lib/hadoop/lib/nati
ve -Dspark.akka.threads=8 -Dspark.akka.threads=8 -Dspark.rdd.compress=false -Dsp
ark.storage.memoryFraction=0.5 -Dspark.driver.host=linux-158-15 -Dclass.default.
serializer= -Dspark.fastdisk.dir=/vdir/mnt/ramdisk/ngmr -Dspark.storage.fastdisk
Fraction=0.5 -Dngmr.task.pipeline=false -Dngmr.task.pipeline.start.fraction=0.5
-Dngmr.task.pipeline.task.timeout.ms=-1 -Dspark.local.dir=/vdir/mnt/disk1/hadoop
/ng
```

## jstat

JVM Statistics Monitoring Tool, 用于监视虚拟机各种运行状态信息。

```shell
jstat [ option vmid [interval[s|ms] [count]] ]

每200毫秒查询一次 进程43 的垃圾收集情况，一共查询5次
jstat -gc 43 200 5
2 秒
jstat -gc 43 2s 5
```

### jstat 常用选项

https://docs.oracle.com/javase/8/docs/technotes/tools/unix/jstat.html

-gc：监视 JAVA 堆情况，常用查看 gc 容量情况的工具

-gcutil：主要关注百分比信息

-gccause：和百分比输出一样，多一个上次垃圾收集产生原因
**建议使用** -gccause 收集 GC 信息！！！

LGCC：Cause of last Garbage Collection
GCC：Cause of current Garbage Collection
YGC ：对新生代堆进行GC。频率比较高，因为大部分对象的存活寿命较短，在新生代里被回收。性能耗费较小。
FGC ：全堆范围的GC。默认堆空间使用到达80%(可调整)的时候会触发FGC。

```shell
[root@linux-158-15 ~]# jstat -gccause 43 2 5
  S0     S1     E      O      M     CCS    YGC     YGCT    FGC    FGCT     GCT    LGCC                 GCC

 20.61   0.00  56.14   3.41  98.85  98.17     32    2.696     5    7.225    9.921 Allocation Failure   No GC

 20.61   0.00  56.14   3.41  98.85  98.17     32    2.696     5    7.225    9.921 Allocation Failure   No GC

 20.61   0.00  56.14   3.41  98.85  98.17     32    2.696     5    7.225    9.921 Allocation Failure   No GC

 20.61   0.00  56.14   3.41  98.85  98.17     32    2.696     5    7.225    9.921 Allocation Failure   No GC

 20.61   0.00  56.14   3.41  98.85  98.17     32    2.696     5    7.225    9.921 Allocation Failure   No GC
```

以上表明该 inceptor server 新生代Eden区（E）使用了 56% 的空间，两个Survivor 区（Survivor0、Survivor1），老年代（O) 和 **元空间**（M），**程序运行以来**发生了 32 次 Minor GC（YGC Young GC），**总耗时** 2.6 s，发生 Full GC （FGC）5次，**总耗时** 7s，上次GC（LGCC） 是因为 Allocation Failure （Allocation Failure： 表明本次引起GC的原因是因为在年轻代中没有足够的空间能够存储新的数据了），现在没有在GC （GCC）

ps：方法区 P (或永久代)，用来存放class，Method等元数据信息，但在JDK1.8已经没有了，取而代之的是MetaSpace(元空间)，元空间不在虚拟机里面，而是直接使用本地内存。

为什么要用元空间代替永久代？
 (1) 类以及方法的信息比较难确定其大小，因此对于永久代的指定比较困难，太小容易导致永久代溢出，太大容易导致老年代溢出。
 (2) 永久代会给GC带来不需要的复杂度，并且回收效率偏低。
 (3) Oracle可能会将HotSpot和Jrockit合二为一。

### YGC FGC 触发时机

YGC的时机:

edn空间不足

FGC的时机：

1.old空间不足；

2.perm空间不足；

3.显示调用System.gc() ，包括RMI等的定时触发;

4.YGC时的悲观策略；

5.dump live的内存信息时(jmap –dump:live)。

对YGC的 触发时机，相当的显而易见，就是eden空间不足， 这时候就肯定会触发ygc

对于FGC的触发时机， old空间不足， 和perm的空间不足， 调用system.gc()这几个都比较显而易见，就是在这种情况下， 一般都会触发GC。

## jinfo

Configuration Info for Java, 实时查看虚拟机各项参数，涵盖显式和默认等等，多儿全。

```shell
jinfo pid
```

https://www.cnblogs.com/redcreen/archive/2011/05/04/2037057.html

## jmap

Memory Map for Java, 用于生成堆转储快照

jmap -heap 47

```shell
显示堆中对象统计信息，包括类、实例数量、合计容量
jmap -histo:live ${JAVA_PID}     【一般简称为jmap（统计信息）】相关效果： 触发一次常规full gc

jmap -dump:live,format=b,file=${FILE_PATH} ${JAVA_PID}   【一般简称为heapdump】
相关效果： 触发一次常规full gc，将所有live对象写入文件。
操作及注意事项： 
  a. 由于live对象总大小最大可能达到堆大小(-Xmx指定)，甚至由于存储格式问题达到更大，注意存储文件的磁盘可用空间。
  b. 一般可先使用histo分析一下活对象总大小，以此估计文件大小。
  c. 网络传输该文件强烈建议先采用常见压缩.tar.gz等，压缩率可达10倍。
```

ps: 持续 FGC 可能出现 Unable to open socket file 的错误，因为当前Java进程一直在持续的GC，而在GC期间java进程是不响应外部jmap请求，建议一顿猛打，无间隔持续地尝试jmap命令一定时间（不超过2分钟），一般在其中可以有概率成功打出jmap。

pps: 由 live 引起的 FGC 可以在GC日志看到:Heap Inspection Initiated GC 标志

## jstack

Stack Trace for Java, 生成虚拟机当前时刻的线程快照，线程快照就是当前虚拟机内每一条线程正在执行的方法堆栈的集合，生成线程快照的 目的通常是定位线程出现长时间停顿的原因，如线程间死锁、死循环、请求外部资源导致的长时间挂 起等，都是导致线程长时间停顿的常见原因。线程出现停顿时通过jstack来查看各个线程的调用堆栈， 就可以获知没有响应的线程到底在后台做些什么事情，或者等待着什么资源。

一般存在 incepto job 卡死，等情况需要用到，隔 x 秒打几个。

```shell
jstack pid
可尝试“su hive”，再打jstack信息。
sudo -u hive /usr/java/latest/bin/jstack {PID}
```

## Ref

jstat 含义：<https://docs.oracle.com/javase/7/docs/technotes/tools/share/jstat.html>

jmap 姿势：<http://172.16.1.168:8090/pages/viewpage.action?pageId=18684230>

jstack 姿势：<http://172.16.1.168:8090/pages/viewpage.action?pageId=18683344>

