#!/bin/bash
##########################################################
#                                                        #
#   This script is  performace test for transfer trx     #
#                                                        #
#                                                        #
#   Script created by EOSeoul                            #
#   visit to http://github.com/eoseoul                   #
#                                                        #
##########################################################

ulimit -n 65530

EOS_BIN="/usr/local/bin"
BASE_DIR="${HOME}"
DATA_DIR="$BASE_DIR/bmt_client"
KEY_DIR="$DATA_DIR/KEY"
JOB_DIR="$DATA_DIR/JOB"

# Wallet(keosd) config
WALLET_DIR="$DATA_DIR/wallet"
WALLET_CONFIG="$DATA_DIR/wallet"
WALLET_HOST="localhost"
WALLET_PORT="8888"
# Wallet use share : 1 is enable. 0 is disable.
WALLET_SHARE=1

ACCOUNT_CREATOR="eosio"
CREATOR_PRIV_KEY="5KQwrPbwdL6PhXujxW37FSSQZ1JiwsST4cqQzDeyXtP79zkvFD3"

conf_file=bmt.conf
[ -f $conf_file ] && . $conf_file

# Define ECHO function
echo_f ()
{
  message=${1:-"[ Failed ]"}
  printf "\033[1;31m%s\033[0m\n" "$message"
}
echo_s ()
{
  message=${1:-"[ Success ]"}
  printf "\033[1;32m%s\033[0m\n" "$message"
}
echo_k ()
{
  message=${1:-"[ Failed ]"}
  printf "\033[1;33m%s\033[0m\n" "$message"
  exit 1;
}
echo_fx ()
{
  message=${1:-"[ Failed ]"}
  printf "\033[1;31m%s\033[0m\n" "$message"
  exit 1;
}

clean_all () {
for((x=0;x<${#WLT[@]};x++));do
  eval $(awk -F"|" '{print "WALLET_NAME="$1" WALLET_HOST="$2" WALLET_PORT="$3}' <<< ${WLT[$x]})
  WALLET_DIR=$DATA_DIR/$WALLET_NAME

  if [ -f $WALLET_DIR/keosd.pid ]
  then
    echo " -- stop keosd(wallet) node"
    $WALLET_DIR/run.sh stop
  fi
  echo " -- Remove wallet data"
  # Clear node data
  rm -rf $WALLET_DIR
done
rm -rf $KEY_DIR bmt_user.txt $JOB_DIR
}


make_dir () {
  echo -ne "  -- Make dir - $1 : "
  if [ ! -d $1 ]
  then
    mkdir -p $1
    [ $? -eq 0 ] && echo_s
  else
    echo "[ Skip ]"
  fi
}

node_svc_check () {
  if [ $1 == "wallet" ]
  then
    RET=$(curl -Is http://${WALLET_HOST}:${WALLET_PORT}/v1/wallet/list_wallets | head -n 1 | grep HTTP | wc -l)
  else
    RET=$(curl -Is http://$1/v1/chain/get_info | head -n 1 | grep HTTP | wc -l)
  fi
  [ $RET == "0" ] && return 1 || return 0
}

create_wallet_node () {
  [ ! -d $KEY_DIR ] && mkdir $KEY_DIR
  make_dir $WALLET_DIR/wpk
  echo "  -- Create wallet config"
  sed -e "s/__WALLET_HOST__/${WALLET_HOST}/g" \
      -e "s/__WALLET_PORT__/${WALLET_PORT}/g" \
      -e "s+__WALLET_DIR__+${WALLET_DIR}+g" < $DATA_DIR/template/wallet.config > $WALLET_DIR/config.ini

  sed -e "s+__DATA__+${WALLET_DIR}+g" \
      -e "s/__PROG__/keosd/g" < $DATA_DIR/template/run.sh > $WALLET_DIR/run.sh
  chmod 0755 $WALLET_DIR/run.sh
  echo "  -- Start wallet Node"
  $WALLET_DIR/run.sh start
  sleep 1
  echo " --- Create default wallet"
  cleos --wallet-host ${WALLET_HOST} --wallet-port ${WALLET_PORT} wallet create -n eosio > $WALLET_DIR/wpk/eosio.wpk 2>/dev/null 
  cleos --wallet-host ${WALLET_HOST} --wallet-port ${WALLET_PORT} wallet import -n eosio ${BOOT_PRIV_KEY} 2>/dev/null 
  cleos --wallet-host ${WALLET_HOST} --wallet-port ${WALLET_PORT} wallet create -n ${ACCOUNT_CREATOR} > $WALLET_DIR/wpk/${ACCOUNT_CREATOR}.wpk 2>/dev/null 
  cleos --wallet-host ${WALLET_HOST} --wallet-port ${WALLET_PORT} wallet import -n ${ACCOUNT_CREATOR} ${CREATOR_PRIV_KEY} 2>/dev/null
}

init_wallet_node () {
  for((x=0;x<${#WLT[@]};x++));do
    eval $(awk -F"|" '{print "WALLET_NAME="$1" WALLET_HOST="$2" WALLET_PORT="$3}' <<< ${WLT[$x]})
    WALLET_DIR=$DATA_DIR/$WALLET_NAME
    echo -ne " - Check $WALLET_NAME daemon : "
    node_svc_check wallet
    if [ $? -eq 0 ]
    then
      echo "[ SKIP ]"
      echo "  -- $WALLET_NAME is already running - keosd"
      echo "  -- WALLET HOST : $WALLET_HOST / WALLET PORT : $WALLET_PORT"
      return 1
    elif [ $WALLET_SHARE -eq 1 ]
    then
      if [ -d $WALLET_DIR ]
      then
        echo "[ SKIP ]"
        echo "  -- wallet directory is already exists! "
        echo "     Starting keosd. wait 5 secs ... "
        $WALLET_DIR/run.sh start
        sleep 1
      else
        echo_s
        create_wallet_node
      fi
    else
      echo "[ SKIP ]"
      echo "  -- Skip to set wallet node"
    fi
  done
}

unlock_proc () {
  for INF in $(ls $WALLET_DIR/wpk/*.wpk);do
    _UID=$(basename $INF | sed "s/\.wpk//g")
    echo " ## Unlock Account in $WALLET_NAME - $_UID "
    cleos --wallet-port $WALLET_PORT --wallet-host $WALLET_HOST wallet unlock -n $_UID --password=$(cat $INF | tail -n 1 | sed "s/\"//g") >/dev/null
  done
}
unlock_all () {
  for((x=0;x<${#WLT[@]};x++));do
    eval $(awk -F"|" '{print "WALLET_NAME="$1" WALLET_HOST="$2" WALLET_PORT="$3}' <<< ${WLT[$x]})
    WALLET_DIR=$DATA_DIR/$WALLET_NAME
    echo -ne " - Check $WALLET_NAME daemon : "
    node_svc_check wallet
    if [ $? -eq 0 ]
    then
      unlock_proc
    elif [ $WALLET_SHARE -eq 1 ]
    then
      if [ -d $WALLET_DIR ]
      then
        echo "[ SKIP ]"
        echo "  -- wallet directory is already exists! "
        echo "     Starting keosd. wait 5 secs ... "
        $WALLET_DIR/run.sh start
        unlock_proc
      fi
    else
      echo "[ SKIP ]"
      echo "  -- Skip to set wallet node"
    fi
  done
}


get_target_host () {
  while true; do
    echo "============================================="
    read -p "- Enter EOS node hostname  : " HTTP_HOST
    read -p "- Enter EOS node http port : " HTTP_PORT
    TGT_HOST="${HTTP_HOST}:${HTTP_PORT}"
    node_svc_check $TGT_HOST
    if [ $? -eq 0 ]; then
      return 0
    else
      echo "We can't connect nodeos host - http://$HTTP_HOST:$HTTP_PORT"
    fi
  done
}

create_account () {
  D_COIN=${D_COIN:-"1000.0000 EOS"}
  if [ -z $1 ]; then
    echo "createor arguments missing"
    return 1
  elif [ -z $2 ]; then
    echo "user account argument missing"
    return 1
  fi

  [ ! -d $KEY_DIR ] && mkdir $KEY_DIR
  cleos create key > $KEY_DIR/$2.key
  PUB=$(cat $KEY_DIR/$2.key | awk '/Public/ {print $3}')
  PRIV=$(cat $KEY_DIR/$2.key | awk '/Private/ {print $3}')
  for((x=0;x<${#WLT[@]};x++));do
    eval $(awk -F"|" '{print "WALLET_NAME="$1" WALLET_HOST="$2" WALLET_PORT="$3}' <<< ${WLT[$x]})
    WALLET_DIR=$DATA_DIR/$WALLET_NAME

    node_svc_check wallet
    if [ $? -eq 1 ]
    then
      echo "Wallet(keosd) is not running!!!"
      return 1
    fi
    #[ -z $HTTP_PORT ] && get_target_host
    pd_rnd=$[$RANDOM % ${#PDINFO[@]}]
    eval $(awk -F"|" '{print "PNAME="$1" HTTP_HOST="$2" HTTP_PORT="$3}' <<< ${PDINFO[$pd_rnd]})

    CMD="cleos --wallet-host ${WALLET_HOST} --wallet-port ${WALLET_PORT} -H $HTTP_HOST -p $HTTP_PORT"

    CHK=$($CMD get account $1 | grep "key" | grep "EOS" |wc -l )
    if [ $CHK -eq 0 ]
    then
      echo "We can't found creator account - $1"
      exit 1
    fi

    CHK=$($CMD get account $2 | grep "key" | grep "EOS" | wc -l )

    if [ $CHK -ne 0 ]
    then
      echo "$2 Account already exists!!!!"
      exit 1
    fi
    echo -ne "# $2 create wallet -  $WALLET_NAME : "
    $CMD wallet create -n $2 > $WALLET_DIR/wpk/$2.wpk
    $CMD wallet import -n $2 $PRIV > /dev/null 2>&1
    [ $? -eq 0 ] && echo_s || echo_f
  done

  $CMD create account $1 $2 $PUB $PUB > /dev/null 2>&1
  $CMD push action eosio.token transfer '["'$1'","'$2'","'$CREATE_AMOUNT' '$CURRENCY'","Initial coin"]' -p $1 > /dev/null 2>&1
  echo "Account create success!!!"
  echo "Key file : $KEY_DIR/$2.key / Wallet Key : $WALLET_DIR/wpk/$2.wpk"
  echo " - $1 Account(Parents) Currency : "$($CMD get currency balance eosio.token $1 ${CURRENCY})
  echo " - $2 Account(Child) Currency : "$($CMD get currency balance eosio.token $2 ${CURRENCY})

}

gen_demo_user () {
  R_PRE=$(tr -cd 'abcdefghijklmnopqrstuvwxyz12345' < /dev/urandom | fold -w 4 | head -n1)
  _CNT=${1:-400}
  _PRE=${2:-$R_PRE}

  for _name in $(tr -cd 'abcdefghijklmnopqrstuvwxyz12345' < /dev/urandom | fold -w 6 | head -n${_CNT})
  do
    echo "### USER - ${_PRE}${_name}"
    create_account ${ACCOUNT_CREATOR} ${_PRE}${_name}
    echo ${_PRE}${_name} >> bmt_user.txt
  done
}

gen_hello_job () {
  [ ! -d $JOB_DIR ] && mkdir $JOB_DIR
  rm -f $JOB_DIR/job_list
  _CNT=${1:-10}
  if [ $_CNT -gt 50 ] || [ $_CNT -lt 10 ]
  then
     echo "Too much!!! between 10 to 50"
     exit 1
  fi
  echo " ### Run to helloworld contract"
  CNT=0
    for vic in $(cat bmt_user.txt | shuf -r -n $((_CNT*1000)) );do
      ((CNT++))
      pd_rnd=$[$RANDOM % ${#PDINFO[@]}]
      eval $(awk -F"|" '{print "PNAME="$1" HTTP_HOST="$2" HTTP_PORT="$3}' <<< ${PDINFO[$pd_rnd]})

      wlt_rnd=$[$RANDOM % ${#WLT[@]}]
      eval $(awk -F"|" '{print "WALLET_NAME="$1" WALLET_HOST="$2" WALLET_PORT="$3}' <<< ${WLT[$wlt_rnd]})

      CMD="cleos --wallet-host ${WALLET_HOST} --wallet-port ${WALLET_PORT} -H $HTTP_HOST -p $HTTP_PORT"
      echo "$CMD action hello hi '[\"$vic\"]' -p neoply -p $vic" >> $JOB_DIR/job_list
    done
echo
}


gen_job_fast () {
  [ ! -d $JOB_DIR ] && mkdir $JOB_DIR
  rm -f $JOB_DIR/job_list
  _thread=${1:-20}
  if [ $_thread -gt 50 ] || [ $_thread -lt 0 ]
  then
     echo "Too much!!! between 1 to 10"
     exit 1
  fi
  echo " ### Generated Job Script"
  CNT=0
  for((x=1;x<=${_thread};x++));do
    /bin/bash ${DATA_DIR}/gen.job 100 &
  done

  for job in `jobs -p`
  do
    echo "Generating benchmark script - $job"
    wait $job
  done
  sleep 1
  echo "Run to script with \"run_job\"!!"
}


run_job () {
  echo "### START - $(date +%Y-%m-%dT%H:%M:%S)" > $JOB_DIR/transaction_ret.log
  cd $JOB_DIR;
  shuf job_list | split -l 500
  cd -
  JOB_LIST=$(ls $JOB_DIR/x*);

  for INF in $JOB_LIST;do
    echo " #### Running Job Script - $INF"
    /bin/bash $INF >> $JOB_DIR/transaction_ret.log &
  done

  for job in `jobs -p`
  do
    echo "Running benchmark script - $job"
    wait $job
  done
  rm -f $JOB_DIR/x*
  echo "#### Wait 3 sec"
  sleep 3;
  result_job
}

result_job () {
  pd_rnd=$[$RANDOM % ${#PDINFO[@]}]
  eval $(awk -F"|" '{print "PNAME="$1" HTTP_HOST="$2" HTTP_PORT="$3}' <<< ${PDINFO[$pd_rnd]})
  T_TX=$(cat $JOB_DIR/transaction_ret.log | grep "transaction" | wc -l)
  START_TX=$(cat $JOB_DIR/transaction_ret.log | grep "transaction" | head -n 1 | awk '{print $3}';)
  END_TX=$(cat $JOB_DIR/transaction_ret.log | grep "transaction" | tail -n 1 | awk '{print $3}';)
  CMD="cleos --wallet-host ${WALLET_HOST} --wallet-port ${WALLET_PORT} -H $HTTP_HOST -p $HTTP_PORT"
  START_TIME=$($CMD get transaction $START_TX | grep "expiration" | awk -F"\"" '{print $4}';)
  END_TIME=$($CMD get transaction $END_TX | grep "expiration" | awk -F"\"" '{print $4}';)
  TPS=$(echo "$T_TX / ($(date --date=$END_TIME +%s) - $(date --date=$START_TIME +%s))" | bc)
  echo "======================================================================================"
  echo "      START TIME : $START_TIME"
  echo "        END TIME : $END_TIME"
  echo "        TOTAL TX : $T_TX"
  echo "             TPS : $TPS"
  echo "  [ Wallet Daemon ] "
  for((x=0;x<${#WLT[@]};x++));do
  echo "   - ${WLT[$x]} " | sed "s/|/,\ /g"
  done
  echo "  [  BP Node  ]"
  for((x=0;x<${#PDINFO[@]};x++));do
  echo "   - ${PDINFO[$x]} "| sed "s/|/,\ /g"
  done
  echo "======================================================================================"
}


case "$1" in
    wallet)
        init_wallet_node
        ;;
    clean)
        clean_all
        ;;
    prepare)
        init_wallet_node
        #get_target_host
        gen_demo_user $2
        #gen_hello_job
        gen_job_fast
        ;;
#    createuser)
#        create_account $2 $3
#        ;;
    gen_job)
        gen_job_fast
        ;;
    run_job)
        run_job
        ;;
    get_ret)
        result_job
        ;;
    unlock)
        unlock_all
        ;;
    *)
        echo
        echo $"Usage: $0 [ command ]"
        echo
        echo $" [ command ]"
#        echo $"  - wallet          : deploy local wallet daemon"
        echo $"  - clean           : remove all node directory and config files"
#        echo $"  - create [creator] [account] : Create Account by creator"
        echo $"  - prepare         : create benchmark prepare account"
        echo $"   > Default : Create 200 test account / Create 10000 transaction job"
        echo $"  - run_job         : run to batch job with multi thread"
        echo $"  - gen_job         : generate new bash script (Default 20000 trx)"
	echo 
        RETVAL=2
esac

exit $RETVAL

