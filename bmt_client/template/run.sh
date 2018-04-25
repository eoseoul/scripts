#!/bin/bash
DATADIR=__DATA__
PROG=__PROG__

echo_s ()
{
  printf "\033[1;32m[ Success ]\033[0m\n"
}
echo_f ()
{
  printf "\033[1;31m[ failed ]\033[0m\n"
}
echo_fx ()
{
  printf "\033[1;31m[ failed ]\033[0m\n";
  exit 1;
}

_start() {
  if [ -f ${DATADIR}/${PROG}.pid ]; then
    _pid=`cat ${DATADIR}/${PROG}.pid`
    if [ -d "/proc/${_pid}" ]; then
      echo "   --- $(basename $DATADIR) node is running now."
      return 1
    fi
  fi
  echo -ne "   --- Starting Node - $(basename $DATADIR) : "
  ${PROG} ${1} --data-dir $DATADIR --config-dir $DATADIR >> $DATADIR/stdout.txt 2>> $DATADIR/stderr.txt & echo $! > $DATADIR/${PROG}.pid
  [ $? -eq 0 ] && echo_s || echo_f
}

_stop() {
  if [ -f ${DATADIR}/${PROG}.pid ]; then
    _pid=`cat ${DATADIR}/${PROG}.pid`
    kill ${_pid}
    rm -r $DATADIR"/${PROG}.pid"
    echo -ne "   --- Stoping ${PROG} - $(basename $DATADIR) : "
    while true; do
      [ ! -d "/proc/$_pid/fd" ] && break
      echo -ne ". "
      sleep 1
    done
    echo_s 
  fi
}

case "$1" in
    start)
        _start ${2}
        ;;
    stop)
        _stop
        ;;
    restart)
        _stop
        _start
        ;;
    *)
        echo $"Usage: $0 {start|stop|restart} {extended argv}"
        RETVAL=2
esac

exit $RETVAL
