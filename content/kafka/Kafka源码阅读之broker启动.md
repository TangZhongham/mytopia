---
title: "Kafka源码阅读之broker启动"
date: 2020-04-17T17:44:51+08:00
draft: true
---

# Kafka 源码解析之 broker启动

> 基于 kafka 2.3.0
> C:/kafka
> created on 0327
> modified on 0410
> 学习了 scala 之后我又来了

```java
```

## Kafka 启动脚本分析

## Kafka 核心主类 kafka.Kafka

由于作者的 java 知识相对薄弱，源码注解可能做的比较细

```java
object Kafka extends Logging {
  // 读取配置文件方法
  def getPropsFromArgs(args: Array[String]): Properties = {
    // 处理命令行参数的解析工具 OptionParser
    val optionParser = new OptionParser(false)
    // 允许覆盖内容
    val overrideOpt = optionParser.accepts("override", "Optional property that should override values set in server.properties file")
      .withRequiredArg()
      .ofType(classOf[String])
    // This is just to make the parameter show up in the help output, we are not actually using this due the
    // fact that this class ignores the first parameter which is interpreted as positional and mandatory
    // but would not be mandatory if --version is specified
    // This is a bit of an ugly crutch till we get a chance to rework the entire command line parsing
    val versionOpt = optionParser.accepts("version", "Print version information and exit.")

    // 如果 命令行参数 为 0
    if (args.length == 0 || args.contains("--help")) {
      CommandLineUtils.printUsageAndDie(optionParser, "USAGE: java [options] %s server.properties [--override property=value]*".format(classOf[KafkaServer].getSimpleName()))
    }

    if (args.contains("--version")) {
      CommandLineUtils.printVersionAndDie()
    }

    val props = Utils.loadProps(args(0))

    if (args.length > 1) {
      val options = optionParser.parse(args.slice(1, args.length): _*)

      if (options.nonOptionArguments().size() > 0) {
        CommandLineUtils.printUsageAndDie(optionParser, "Found non argument parameters: " + options.nonOptionArguments().toArray.mkString(","))
      }

      props ++= CommandLineUtils.parseKeyValueArgs(options.valuesOf(overrideOpt).asScala)
    }
    props
  }
  // Kafka 实际的执行类
  def main(args: Array[String]): Unit = {
    try {
      //上述的 getPropsFromArgs 获取配置文件信息
      val serverProps = getPropsFromArgs(args)
      // 调用了KafkaServerStartable 对象 读取 props 文件，里面实际上是调用了 KafkaServer.startup()
      val kafkaServerStartable = KafkaServerStartable.fromProps(serverProps)
      // 操作系统判断
      try {
        if (!OperatingSystem.IS_WINDOWS && !Java.isIbmJdk)
          new LoggingSignalHandler().register()
      } catch {
        case e: ReflectiveOperationException =>
          warn("Failed to register optional signal handler that logs a message when the process is terminated " +
            s"by a signal. Reason for registration failure is: $e", e)
      }

      // attach shutdown handler to catch terminating signals as well as normal termination
      // Runtime 用了单实例的设计模式，所以在java程序中不同线程通过调用Runtime.getRuntime()获得的是同一个对象实例，
      // 也就是说一个java进程中只有一个Runtime实例
      //该函数的作用就是在你的程序结束前,执行一些清理工作,尤其是没有用户界面的程序.很明显,这些关闭钩子都是线程对象,
      // 因此,清理工作要写在run()里.根据JDK帮助文档,清理工作不能太耗时,要尽快结束,但仍然可以对数据库进行操作.
      //意思就是在jvm中增加一个关闭的钩子，当jvm关闭的时候，会执行系统中已经设置的所有通过方法addShutdownHook添加的钩子，
      // 当系统执行完这些钩子后，jvm才会关闭。所以这些钩子可以在jvm关闭的时候进行内存清理、对象销毁等操作。
      Runtime.getRuntime().addShutdownHook(new Thread("kafka-shutdown-hook") {
        override def run(): Unit = kafkaServerStartable.shutdown()
      })
      // 这里终于到了 kafka 启动了， 本质上就是 KafkaServer.startup()
      kafkaServerStartable.startup()
      // shutdown 之后需要做的一些事
      kafkaServerStartable.awaitShutdown()
    }
    catch {
      case e: Throwable =>
        fatal("Exiting Kafka due to fatal exception", e)
        Exit.exit(1)
    }
    Exit.exit(0)
  }
}

```

## 然后到了 kafka.server.KafkaServerStartable 和 kafka.server.KafkaServer

KafkaServerStartable 包装了一层KafkaServer。本质上 KafkaServerStartable 定义了 KafkaServer 的 几种状态，将属于这几种状态的 error 抽象了出来。

现在来看看 KafkaServer 的 startup() 启动类

```java
class KafkaServer(val config: KafkaConfig, time: Time = Time.SYSTEM, threadNamePrefix: Option[String] = None,
                  kafkaMetricsReporters: Seq[KafkaMetricsReporter] = List()) extends Logging with KafkaMetricsGroup {
  // 启动、是否关闭、是否启动标识
  // 原子方式进行读和写的布尔值
  //AtomicBoolean是Java.util.concurrent.atomic包下的原子变量，这个包里面提供了一组原子类。
  // 其基本的特性就是在多线程环境下，当有多个线程同时执行这些类的实例包含的方法时，具有排他性，
  // 即当某个线程进入方法，执行其中的指令时，不会被其他线程打断，而别的线程就像自旋锁一样，
  // 一直等到该方法执行完成，才由JVM从等待队列中选择一个另一个线程进入，这只是一种逻辑上的理解。
  // 实际上是借助硬件的相关指令来实现的，不会阻塞线程(或者说只是在硬件级别上阻塞了)。
  private val startupComplete = new AtomicBoolean(false)
  private val isShuttingDown = new AtomicBoolean(false)
  private val isStartingUp = new AtomicBoolean(false)

  // CountDownLatch是同步工具类之一，可以指定一个计数值，在并发环境下由线程进行减1操作，
  // 当计数值变为0之后，被await方法阻塞的线程将会唤醒，实现线程间的同步。
  private var shutdownLatch = new CountDownLatch(1)

  private val jmxPrefix: String = "kafka.server"

  private var logContext: LogContext = null

  var metrics: Metrics = null

  val brokerState: BrokerState = new BrokerState

  var dataPlaneRequestProcessor: KafkaApis = null
  var controlPlaneRequestProcessor: KafkaApis = null

  var authorizer: Option[Authorizer] = None
  // 监听 socket 请求
  var socketServer: SocketServer = null
  // 请求资源池
  var dataPlaneRequestHandlerPool: KafkaRequestHandlerPool = null
  var controlPlaneRequestHandlerPool: KafkaRequestHandlerPool = null

  // 日志管理
  var logDirFailureChannel: LogDirFailureChannel = null
  var logManager: LogManager = null

  // 分区副本管理
  var replicaManager: ReplicaManager = null
  var adminManager: AdminManager = null
  var tokenManager: DelegationTokenManager = null

  // 动态 config 处理
  var dynamicConfigHandlers: Map[String, ConfigHandler] = null
  var dynamicConfigManager: DynamicConfigManager = null
  var credentialProvider: CredentialProvider = null
  var tokenCache: DelegationTokenCache = null

  var groupCoordinator: GroupCoordinator = null

  var transactionCoordinator: TransactionCoordinator = null

  var kafkaController: KafkaController = null

  var kafkaScheduler: KafkaScheduler = null

  var metadataCache: MetadataCache = null
  var quotaManagers: QuotaFactory.QuotaManagers = null

  private var _zkClient: KafkaZkClient = null
  val correlationId: AtomicInteger = new AtomicInteger(0)
  val brokerMetaPropsFile = "meta.properties"
  val brokerMetadataCheckpoints = config.logDirs.map(logDir => (logDir, new BrokerMetadataCheckpoint(new File(logDir + File.separator + brokerMetaPropsFile)))).toMap

  private var _clusterId: String = null
  private var _brokerTopicStats: BrokerTopicStats = null


  def clusterId: String = _clusterId

  // Visible for testing
  private[kafka] def zkClient = _zkClient

  private[kafka] def brokerTopicStats = _brokerTopicStats

  newGauge(
    "BrokerState",
    new Gauge[Int] {
      def value = brokerState.currentState
    }
  )

  newGauge(
    "ClusterId",
    new Gauge[String] {
      def value = clusterId
    }
  )

  newGauge(
    "yammer-metrics-count",
    new Gauge[Int] {
      def value = {
        com.yammer.metrics.Metrics.defaultRegistry.allMetrics.size
      }
    }
  )

  /**
   * Start up API for bringing up a single instance of the Kafka server.
   * Instantiates the LogManager, the SocketServer and the request handlers - KafkaRequestHandlers
   */
    // Kafka 真正 broker 的启动类
  def startup() {
    try {
      info("starting")

      // 如果脚本再次在本机启动这个类，
      if (isShuttingDown.get)
        throw new IllegalStateException("Kafka server is still shutting down, cannot re-start!")

      if (startupComplete.get)
        return

      val canStartup = isStartingUp.compareAndSet(false, true)
      if (canStartup) {
        brokerState.newState(Starting)

        /* setup zookeeper */
        // 启动 broker 第一步就是 初始化 zk client
        initZkClient(time)

        /* Get or create cluster_id */
        // 确定 cluser id， 包装 n 层 直到配置文件 /cluster/id
        _clusterId = getOrGenerateClusterId(zkClient)
        info(s"Cluster ID = $clusterId")

        /* generate brokerId */
        // 获取 broker id
        val (brokerId, initialOfflineDirs) = getBrokerIdAndOfflineDirs
        config.brokerId = brokerId
        logContext = new LogContext(s"[KafkaServer id=${config.brokerId}] ")
        this.logIdent = logContext.logPrefix

        // initialize dynamic broker configs from ZooKeeper. Any updates made after this will be
        // applied after DynamicConfigManager starts.
        // Kafka 支持动态修改 config （都存 zk 上）
        config.dynamicConfig.initialize(zkClient)

        /* start scheduler */
        // 启动调度器 A scheduler based on java.util.concurrent.ScheduledThreadPoolExecutor
        // It has a pool of kafka-scheduler- threads that do the actual work.
        kafkaScheduler = new KafkaScheduler(config.backgroundThreads)
        kafkaScheduler.startup()

        /* create and configure metrics */
        val reporters = new util.ArrayList[MetricsReporter]
        reporters.add(new JmxReporter(jmxPrefix))
        val metricConfig = KafkaServer.metricConfig(config)
        metrics = new Metrics(metricConfig, reporters, time, true)

        /* register broker metrics */
        _brokerTopicStats = new BrokerTopicStats

        quotaManagers = QuotaFactory.instantiate(config, metrics, time, threadNamePrefix.getOrElse(""))
        notifyClusterListeners(kafkaMetricsReporters ++ metrics.reporters.asScala)

        logDirFailureChannel = new LogDirFailureChannel(config.logDirs.size)

        /* start log manager */
        // 启动 Log Manager
        logManager = LogManager(config, initialOfflineDirs, zkClient, brokerState, kafkaScheduler, time, brokerTopicStats, logDirFailureChannel)
        logManager.startup()

        metadataCache = new MetadataCache(config.brokerId)
        // Enable delegation token cache for all SCRAM mechanisms to simplify dynamic update.
        // This keeps the cache up-to-date if new SCRAM mechanisms are enabled dynamically.
        tokenCache = new DelegationTokenCache(ScramMechanism.mechanismNames)
        credentialProvider = new CredentialProvider(ScramMechanism.mechanismNames, tokenCache)

        // Create and start the socket server acceptor threads so that the bound port is known.
        // Delay starting processors until the end of the initialization sequence to ensure
        // that credentials have been loaded before processing authentications.
        // 启动socket server，准备对外服务了! 9092 在启动前面的内部类后 对外 服务
        socketServer = new SocketServer(config, metrics, time, credentialProvider)
        socketServer.startup(startupProcessors = false)

        /* start replica manager */
        // 复制管理
        replicaManager = createReplicaManager(isShuttingDown)
        replicaManager.startup()

        // broker 相关信息注册到 zk 上，host:port 和防止 controller 脑裂的 epoch
        // 直到这步 真正注册 到 /broker/ids 算是加入到集群中了
        val brokerInfo = createBrokerInfo
        val brokerEpoch = zkClient.registerBroker(brokerInfo)

        // Now that the broker id is successfully registered, checkpoint it
        checkpointBrokerId(config.brokerId)

        /* start token manager */
        tokenManager = new DelegationTokenManager(config, tokenCache, time , zkClient)
        tokenManager.startup()

        /* start kafka controller */
        // 启动kafka controller
        kafkaController = new KafkaController(config, zkClient, time, metrics, brokerInfo, brokerEpoch, tokenManager, threadNamePrefix)
        kafkaController.startup()

        adminManager = new AdminManager(config, metrics, metadataCache, zkClient)

        /* start group coordinator */
        // Hardcode Time.SYSTEM for now as some Streams tests fail otherwise, it would be good to fix the underlying issue
        groupCoordinator = GroupCoordinator(config, zkClient, replicaManager, Time.SYSTEM)
        groupCoordinator.startup()

        /* start transaction coordinator, with a separate background thread scheduler for transaction expiration and log loading */
        // Hardcode Time.SYSTEM for now as some Streams tests fail otherwise, it would be good to fix the underlying issue
        transactionCoordinator = TransactionCoordinator(config, replicaManager, new KafkaScheduler(threads = 1, threadNamePrefix = "transaction-log-manager-"), zkClient, metrics, metadataCache, Time.SYSTEM)
        transactionCoordinator.startup()

        /* Get the authorizer and initialize it if one is specified.*/
        authorizer = Option(config.authorizerClassName).filter(_.nonEmpty).map { authorizerClassName =>
          val authZ = CoreUtils.createObject[Authorizer](authorizerClassName)
          authZ.configure(config.originals())
          authZ
        }

        val fetchManager = new FetchManager(Time.SYSTEM,
          new FetchSessionCache(config.maxIncrementalFetchSessionCacheSlots,
            KafkaServer.MIN_INCREMENTAL_FETCH_SESSION_EVICTION_MS))

        /* start processing requests */
        // 从这里开始， 准备 完成， 开始处理外界消息。
        dataPlaneRequestProcessor = new KafkaApis(socketServer.dataPlaneRequestChannel, replicaManager, adminManager, groupCoordinator, transactionCoordinator,
          kafkaController, zkClient, config.brokerId, config, metadataCache, metrics, authorizer, quotaManagers,
          fetchManager, brokerTopicStats, clusterId, time, tokenManager)

        // 起线程池，传入 socket server 对象
        dataPlaneRequestHandlerPool = new KafkaRequestHandlerPool(config.brokerId, socketServer.dataPlaneRequestChannel, dataPlaneRequestProcessor, time,
          config.numIoThreads, s"${SocketServer.DataPlaneMetricPrefix}RequestHandlerAvgIdlePercent", SocketServer.DataPlaneThreadPrefix)

        socketServer.controlPlaneRequestChannelOpt.foreach { controlPlaneRequestChannel =>
          controlPlaneRequestProcessor = new KafkaApis(controlPlaneRequestChannel, replicaManager, adminManager, groupCoordinator, transactionCoordinator,
            kafkaController, zkClient, config.brokerId, config, metadataCache, metrics, authorizer, quotaManagers,
            fetchManager, brokerTopicStats, clusterId, time, tokenManager)

          controlPlaneRequestHandlerPool = new KafkaRequestHandlerPool(config.brokerId, socketServer.controlPlaneRequestChannelOpt.get, controlPlaneRequestProcessor, time,
            1, s"${SocketServer.ControlPlaneMetricPrefix}RequestHandlerAvgIdlePercent", SocketServer.ControlPlaneThreadPrefix)
        }

        // 监控相关
        Mx4jLoader.maybeLoad()

        /* Add all reconfigurables for config change notification before starting config handlers */
        config.dynamicConfig.addReconfigurables(this)

        /* start dynamic config manager */
        dynamicConfigHandlers = Map[String, ConfigHandler](ConfigType.Topic -> new TopicConfigHandler(logManager, config, quotaManagers, kafkaController),
                                                           ConfigType.Client -> new ClientIdConfigHandler(quotaManagers),
                                                           ConfigType.User -> new UserConfigHandler(quotaManagers, credentialProvider),
                                                           ConfigType.Broker -> new BrokerConfigHandler(config, quotaManagers))

        // Create the config manager. start listening to notifications
        dynamicConfigManager = new DynamicConfigManager(zkClient, dynamicConfigHandlers)
        dynamicConfigManager.startup()

        // socket server 开始对外服务
        socketServer.startDataPlaneProcessors()
        socketServer.startControlPlaneProcessor()
        brokerState.newState(RunningAsBroker)
        // 修改初始 new KafkaServer 类的状态，启动完成
        shutdownLatch = new CountDownLatch(1)
        startupComplete.set(true)
        isStartingUp.set(false)
        AppInfoParser.registerAppInfo(jmxPrefix, config.brokerId.toString, metrics, time.milliseconds())
        info("started")
      }
    }
    catch {
      case e: Throwable =>
        fatal("Fatal error during KafkaServer startup. Prepare to shutdown", e)
        isStartingUp.set(false)
        shutdown()
        throw e
    }
  }
```

## 核心

经过以上分析，kafka 大致的启动流程我们就知道了，接下来是看 kafka 内部 各个 startup 出来的模块，到底每个是负责什么的。

比方说: 
KafkaScheduler是一个基于java.util.concurrent.ScheduledThreadPoolExecutor的调度器，它内部是以前缀kafka-scheduler-xx（xx是线程序列号）的线程池处理真正的工作。

