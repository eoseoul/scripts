#!/bin/bash

# eos source parents directory
base_dir="/neowiz/eos-mainnet"
# EOS rpc url
rpc_url="http://EOS_RPC_URL:PORT"
# EOS wallet host and port
wallet_url="http://127.0.0.1:8880"
# define cleos command line
CLE="${base_dir}/eos_src/build/programs/cleos/cleos -u $rpc_url --wallet-url $wallet_url"

# Default claim reward delay
delay=86401
# claim reward account
account_name="<< Account Name >> "

send_msg () {
    # Hangout call URL
    Hangout_URL="<< HANGOUT WEB HOOK URL >>"
    curl -X POST -H 'Content-Type: application/json' "$Hangout_URL" -d "{\"text\": \"$1\"}"
}

reward_job () {
  # Wallet start
  $base_dir/wallet/run.sh start
  CUR_BAL=$($CLE get currency balance eosio.token $account_name EOS | awk '{print $1}')

  # Wallet unlock
  _key=$(${base_dir}/signing.sh ${base_dir}/KEY/$account_name.wpk.sign | tail -n 1 | sed "s/\"//g")
  $CLE wallet unlock -n $account_name --password $_key >> /dev/null 2>&1
  CHK_WLT=$($CLE wallet list | grep $account_name | grep "\*" |wc -l)
  # Check wallet config
  if [ $CHK_WLT -eq 0 ]; then
    send_msg "We can't found your account in wallet.\nPlease check key is registered or account is created.\n - account : $account_name"
    exit 1
  fi

  # Claim Rewards
  $CLE system claimrewards $account_name >> /dev/null 2>&1
  RET=$?

  # Check Claim rewards success?
  if [ $RET -eq 0 ]; then
    _timer=$(($(date +"%s")+$delay));
      echo $_timer > ${base_dir}/.reward.timer
      NOW_BAL=$($CLE get currency balance eosio.token $account_name EOS  | awk '{print $1}')
      DIF=$(echo "scale=4;$NOW_BAL - $CUR_BAL"|bc)
      $CLE wallet lock -n $account_name  >> /dev/null 2>&1
      send_msg "[$account_name] Claim Rewards job complete - Total Rewards = $DIF EOS"
  else
    _timer=$(($(date +"%s")+30))
    echo $_timer > ${base_dir}/.reward.timer
      send_msg "[$account_name] Claim Rewards job Failed - bot will retry claim reward job at after 30 sec"
  fi
  $base_dir/wallet/run.sh stop
}


run_job_test () {
    _chk=$(($RANDOM % 2))
    if [ $_chk -eq 0 ]; then
        echo "### Refund - failed then next turn after 30 sec"
        _timer=$(($(date +"%s")+3))
       echo $_timer    > $base_dir/.reward.timer
    else
        echo "### Refund - Success then next turn after 86401 sec"
        _timer=$(($(date +"%s")+30))
       echo $_timer > $base_dir/.reward.timer
    fi
}

while true; do
    if [ ! -f $base_dir/.reward.timer ]; then
        next_reward=$(date +"%s" -d "1 day")
    else
        next_reward=$(cat $base_dir/.reward.timer)
    fi
    ntime=$(date +"%s")
    if [ $ntime -gt $next_reward ]; then
        echo "now time : $ntime [ "$(date -d "@$ntime")" ] / next time : $next_reward [ "$(date -d "@$next_reward")" ] / ASAP Run!"
        reward_job
    else
        w_time=$((next_reward - ntime))
        echo "now time : $ntime [ "$(date -d "@$ntime")" ] / next time : $next_reward [ "$(date -d "@$next_reward")" ] / wait delay : $w_time"
        sleep $w_time
        reward_job
    fi
done
