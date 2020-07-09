---
title: "Flink源码阅读之启动流程"
date: 2020-06-08T16:57:43+08:00
draft: true
---

# Flink源码阅读之启动流程

> 本文分析了 Flink standalone/yarn 的启动流程

## 先看启动脚本 start-cluster.sh

```shell
## 读取默认 config 配置文件
. "$bin"/config.sh

# Start the JobManager instance(s)
## 用来定制 shell 环境 -s 开启某个选项 nocasematch 忽略大小写
shopt -s nocasematch
## 支持高可用模式启动
if [[ $HIGH_AVAILABILITY == "zookeeper" ]]; then
    # HA Mode
    readMasters

    echo "Starting HA cluster with ${#MASTERS[@]} masters."

    for ((i=0;i<${#MASTERS[@]};++i)); do
        master=${MASTERS[i]}
        webuiport=${WEBUIPORTS[i]}

        if [ ${MASTERS_ALL_LOCALHOST} = true ] ; then
            "${FLINK_BIN_DIR}"/jobmanager.sh start "${master}" "${webuiport}"
        else
            ssh -n $FLINK_SSH_OPTS $master -- "nohup /bin/bash -l \"${FLINK_BIN_DIR}/jobmanager.sh\" start ${master} ${webuiport} &"
        fi
    done

else
    ## 正常 cluster 模式启动
    echo "Starting cluster."

    # Start single JobManager on this machine
    "$FLINK_BIN_DIR"/jobmanager.sh start
fi
shopt -u nocasematch

# Start TaskManager instance(s)
TMSlaves start
```

## 查看实际启动的 jobmanager.sh

```shell
# Start/stop a Flink JobManager.
## echo 出脚本的用法，可以学着这种写法
USAGE="Usage: jobmanager.sh ((start|start-foreground) [host] [webui-port])|stop|stop-all"

## %1 表示第一个变量
STARTSTOP=$1
## 第二个
HOST=$2 # optional when starting multiple instances
## 第三个
WEBUIPORT=$3 # optional when starting multiple instances

## 如果第一个参数 STARTSTOP 不是以下几种，则返回 USAGE; 学习
if [[ $STARTSTOP != "start" ]] && [[ $STARTSTOP != "start-foreground" ]] && [[ $STARTSTOP != "stop" ]] && [[ $STARTSTOP != "stop-all" ]]; then
  echo $USAGE
  exit 1
fi

## 这个命令很少直接在shell命令行中使用，我们一般把它用在shell脚本中，用于取得脚本文件所在目录，然后将当前目录切换过去。
bin=`dirname "$0"`
bin=`cd "$bin"; pwd`

## 读取配置文件
. "$bin"/config.sh

## 启动入口，默认 standalonesession
ENTRYPOINT=standalonesession

if [[ $STARTSTOP == "start" ]] || [[ $STARTSTOP == "start-foreground" ]]; then
    if [ ! -z "${FLINK_JM_HEAP_MB}" ] && [ "${FLINK_JM_HEAP}" == 0 ]; then
	    echo "used deprecated key \`${KEY_JOBM_MEM_MB}\`, please replace with key \`${KEY_JOBM_MEM_SIZE}\`"
    else
	    flink_jm_heap_bytes=$(parseBytes ${FLINK_JM_HEAP})
	    FLINK_JM_HEAP_MB=$(getMebiBytes ${flink_jm_heap_bytes})
    fi

    if [[ ! ${FLINK_JM_HEAP_MB} =~ $IS_NUMBER ]] || [[ "${FLINK_JM_HEAP_MB}" -lt "0" ]]; then
        echo "[ERROR] Configured JobManager memory size is not a valid value. Please set '${KEY_JOBM_MEM_SIZE}' in ${FLINK_CONF_FILE}."
        exit 1
    fi

    if [ "${FLINK_JM_HEAP_MB}" -gt "0" ]; then
        export JVM_ARGS="$JVM_ARGS -Xms"$FLINK_JM_HEAP_MB"m -Xmx"$FLINK_JM_HEAP_MB"m"
    fi

    # Add JobManager-specific JVM options
    export FLINK_ENV_JAVA_OPTS="${FLINK_ENV_JAVA_OPTS} ${FLINK_ENV_JAVA_OPTS_JM}"

    # Startup parameters
    ## 相关参数可以加到这里
    args=("--configDir" "${FLINK_CONF_DIR}" "--executionMode" "cluster")
    if [ ! -z $HOST ]; then
        args+=("--host")
        args+=("${HOST}")
    fi

    if [ ! -z $WEBUIPORT ]; then
        args+=("--webui-port")
        args+=("${WEBUIPORT}")
    fi
fi

if [[ $STARTSTOP == "start-foreground" ]]; then
    exec "${FLINK_BIN_DIR}"/flink-console.sh $ENTRYPOINT "${args[@]}"
else
    "${FLINK_BIN_DIR}"/flink-daemon.sh $STARTSTOP $ENTRYPOINT "${args[@]}"
fi
```

### flink 真正的启动类 flink-daemon.sh

```shell
# Start/stop a Flink daemon.
USAGE="Usage: flink-daemon.sh (start|stop|stop-all) (taskexecutor|zookeeper|historyserver|standalonesession|standalonejob) [args]"

STARTSTOP=$1
DAEMON=$2
ARGS=("${@:3}") # get remaining arguments as array

bin=`dirname "$0"`
bin=`cd "$bin"; pwd`

. "$bin"/config.sh

case $DAEMON in
    (taskexecutor)
    ## Task Manager 启动类
        CLASS_TO_RUN=org.apache.flink.runtime.taskexecutor.TaskManagerRunner
    ;;

    (zookeeper)
        CLASS_TO_RUN=org.apache.flink.runtime.zookeeper.FlinkZooKeeperQuorumPeer
    ;;

    (historyserver)
        CLASS_TO_RUN=org.apache.flink.runtime.webmonitor.history.HistoryServer
    ;;
    ## 默认传滴就是 standalonesession 所以是在这里啦
    (standalonesession)
        CLASS_TO_RUN=org.apache.flink.runtime.entrypoint.StandaloneSessionClusterEntrypoint
    ;;

    (standalonejob)
        CLASS_TO_RUN=org.apache.flink.container.entrypoint.StandaloneJobClusterEntryPoint
    ;;

    (*)
        echo "Unknown daemon '${DAEMON}'. $USAGE."
        exit 1
    ;;
esac

if [ "$FLINK_IDENT_STRING" = "" ]; then
    FLINK_IDENT_STRING="$USER"
fi

FLINK_TM_CLASSPATH=`constructFlinkClassPath`

pid=$FLINK_PID_DIR/flink-$FLINK_IDENT_STRING-$DAEMON.pid

mkdir -p "$FLINK_PID_DIR"

# Log files for daemons are indexed from the process ID's position in the PID
# file. The following lock prevents a race condition during daemon startup
# when multiple daemons read, index, and write to the PID file concurrently.
# The lock is created on the PID directory since a lock file cannot be safely
# removed. The daemon is started with the lock closed and the lock remains
# active in this script until the script exits.
command -v flock >/dev/null 2>&1
if [[ $? -eq 0 ]]; then
    exec 200<"$FLINK_PID_DIR"
    flock 200
fi

# Ascending ID depending on number of lines in pid file.
# This allows us to start multiple daemon of each type.
id=$([ -f "$pid" ] && echo $(wc -l < "$pid") || echo "0")

FLINK_LOG_PREFIX="${FLINK_LOG_DIR}/flink-${FLINK_IDENT_STRING}-${DAEMON}-${id}-${HOSTNAME}"
log="${FLINK_LOG_PREFIX}.log"
out="${FLINK_LOG_PREFIX}.out"

log_setting=("-Dlog.file=${log}" "-Dlog4j.configuration=file:${FLINK_CONF_DIR}/log4j.properties" "-Dlogback.configurationFile=file:${FLINK_CONF_DIR}/logback.xml")

JAVA_VERSION=$(${JAVA_RUN} -version 2>&1 | sed 's/.*version "\(.*\)\.\(.*\)\..*"/\1\2/; 1q')

# Only set JVM 8 arguments if we have correctly extracted the version
if [[ ${JAVA_VERSION} =~ ${IS_NUMBER} ]]; then
    if [ "$JAVA_VERSION" -lt 18 ]; then
        JVM_ARGS="$JVM_ARGS -XX:MaxPermSize=256m"
    fi
fi

case $STARTSTOP in

    (start)
        # Rotate log files
        rotateLogFilesWithPrefix "$FLINK_LOG_DIR" "$FLINK_LOG_PREFIX"

        # Print a warning if daemons are already running on host
        if [ -f "$pid" ]; then
          active=()
          while IFS='' read -r p || [[ -n "$p" ]]; do
            kill -0 $p >/dev/null 2>&1
            if [ $? -eq 0 ]; then
              active+=($p)
            fi
          done < "${pid}"

          count="${#active[@]}"

          if [ ${count} -gt 0 ]; then
            echo "[INFO] $count instance(s) of $DAEMON are already running on $HOSTNAME."
          fi
        fi

        # Evaluate user options for local variable expansion
        FLINK_ENV_JAVA_OPTS=$(eval echo ${FLINK_ENV_JAVA_OPTS})

        echo "Starting $DAEMON daemon on host $HOSTNAME."
        $JAVA_RUN $JVM_ARGS ${FLINK_ENV_JAVA_OPTS} "${log_setting[@]}" -classpath "`manglePathList "$FLINK_TM_CLASSPATH:$INTERNAL_HADOOP_CLASSPATHS"`" ${CLASS_TO_RUN} "${ARGS[@]}" > "$out" 200<&- 2>&1 < /dev/null &

        mypid=$!

        # Add to pid file if successful start
        if [[ ${mypid} =~ ${IS_NUMBER} ]] && kill -0 $mypid > /dev/null 2>&1 ; then
            echo $mypid >> "$pid"
        else
            echo "Error starting $DAEMON daemon."
            exit 1
        fi
    ;;

    (stop)
        if [ -f "$pid" ]; then
            # Remove last in pid file
            to_stop=$(tail -n 1 "$pid")

            if [ -z $to_stop ]; then
                rm "$pid" # If all stopped, clean up pid file
                echo "No $DAEMON daemon to stop on host $HOSTNAME."
            else
                sed \$d "$pid" > "$pid.tmp" # all but last line

                # If all stopped, clean up pid file
                [ $(wc -l < "$pid.tmp") -eq 0 ] && rm "$pid" "$pid.tmp" || mv "$pid.tmp" "$pid"

                if kill -0 $to_stop > /dev/null 2>&1; then
                    echo "Stopping $DAEMON daemon (pid: $to_stop) on host $HOSTNAME."
                    kill $to_stop
                else
                    echo "No $DAEMON daemon (pid: $to_stop) is running anymore on $HOSTNAME."
                fi
            fi
        else
            echo "No $DAEMON daemon to stop on host $HOSTNAME."
        fi
    ;;

    (stop-all)
        if [ -f "$pid" ]; then
            mv "$pid" "${pid}.tmp"

            while read to_stop; do
                if kill -0 $to_stop > /dev/null 2>&1; then
                    echo "Stopping $DAEMON daemon (pid: $to_stop) on host $HOSTNAME."
                    kill $to_stop
                else
                    echo "Skipping $DAEMON daemon (pid: $to_stop), because it is not running anymore on $HOSTNAME."
                fi
            done < "${pid}.tmp"
            rm "${pid}.tmp"
        fi
    ;;

    (*)
        echo "Unexpected argument '$STARTSTOP'. $USAGE."
        exit 1
    ;;

esac

```

## 终于找到 StandaloneSessionClusterEntrypoint 启动类 啦

通过查看 三 个启动脚本，终于找到了 standalone 的启动类 ```StandaloneSessionClusterEntrypoint```，下面看看源码是怎么实现的

```shell

```
