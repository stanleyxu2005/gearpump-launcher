#!/bin/sh

# Licensed under the Apache License, Version 2.0
# See accompanying LICENSE file.

if [ ! -d "$SUT_HOME/bin" ]; then
  echo "FATAL: Directory '$SUT_HOME' is incomplete. Please re-install."
  exit 1
fi

if [ -z "$JAVA_OPTS" ]; then
  echo "FATAL: Environment variable 'JAVA_OPTS' is NOT set."
  exit 1
fi
export JAVA_OPTS

function set_user_data_opts {
  LOG_DIR=/var/log/gearpump
  JARSTORE_DIR=/tmp/gearpump
  JAVA_OPTS="$JAVA_OPTS -Dgearpump.log.daemon.dir=$LOG_DIR"
  JAVA_OPTS="$JAVA_OPTS -Dgearpump.log.application.dir=$LOG_DIR"
  JAVA_OPTS="$JAVA_OPTS -Dgearpump.jarstore.rootpath=$JARSTORE_DIR"
}

COMMAND=$1
shift

case "$COMMAND" in
  master|local)
    # Launch a container with Gearpump cluster and REST interface (in foreground)
    HOSTNAME=$(hostname)
    JAVA_OPTS="$JAVA_OPTS -Dgearpump.hostname=$HOSTNAME"
    JAVA_OPTS="$JAVA_OPTS -Dgearpump.services.host=$HOSTNAME"
    set_user_data_opts
    nohup sh "$SUT_HOME"/bin/services &
    nohup sh "$SUT_HOME"/bin/"$COMMAND" "$@"
    ;;
  worker)
    # Launch a container with a Gearpump worker (in foreground)
    JAVA_OPTS="$JAVA_OPTS -Dgearpump.hostname=$(hostname -i)"
    set_user_data_opts
    nohup sh "$SUT_HOME"/bin/worker
    ;;
  gear|storm)
    # Launch a container and execute command `gear` or `storm`
    # Container will be killed, when command is executed. 
    JAVA_OPTS="$JAVA_OPTS -Dgearpump.hostname=$(hostname -i)"
    set_user_data_opts
    sh "$SUT_HOME"/bin/"$COMMAND" "$@"
    ;;
  storm-drpc)
    # Launch a container with a Storm DRPC daemon
    # Note that this command has nothing to do with Gearpump, it only uses storm related jar libs.
    LIB_HOME="$SUT_HOME"/lib
    cat > "$SUT_HOME"/storm.yaml <<- YAML
drpc.servers:
  - `ip route | awk '/default/ {print $3}'`
YAML
    java -server -Xmx768m -cp "$LIB_HOME"/*:"$LIB_HOME"/storm/* backtype.storm.daemon.drpc
    ;;
  *)
    cat <<- USAGE
Gearpump Commands:
  master -ip [HOST] -port [PORT]
  worker
  gear (app|info|kill) [ARGS]
  storm [ARGS]

Storm Commands:
  storm-drpc
USAGE
    exit 1
    ;;
esac
