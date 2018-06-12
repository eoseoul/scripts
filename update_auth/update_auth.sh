#!/bin/bash

# Set mainnet or testnet HTTP RPC URL
RPC="http://localhost:6601"
# Set keosd(wallet) URL
WALLET="http://localhost:58080"
# Set EOS source direcotry. need to build.
EOS_SOURCE="/home/eos/testnet/eos_src"
# Set Signing script
SIGNING="$(pwd)/signing.sh"

if [ $# -lt 2 ]; then
  echo
  echo "Usage: $0 {active|owner} [Account]"
  echo " > To run update auth, account must be unlocked."
  echo 
  exit 1
fi

_type=$( echo $1 | tr '[:upper:]' '[:lower:]' )

if [ $(curl -Is $RPC | head -n 1 | grep HTTP | wc -l) -eq 0 ]; then
  echo " $RPC is not open. Check to RPC config"
  exit 1
fi

if [ $(curl -Is $WALLET | head -n 1 | grep HTTP | wc -l ) -eq 0 ]; then
  echo " $WALLET is not open. Check to wallet daemon"
  exit 1
fi

if [ ! -x $EOS_SOURCE/build/programs/cleos/cleos ]; then
  echo "$EOS_SOURCE directory is not correct. check to EOS_SOURCE config in this script"
  echo "if you want to DOWNLOAD and install EOS then check below commands"
  echo " > git clone https://github.com/eosio/eos --recursive"
  echo " > git checkout v1.0.3"
  echo " > cd eos; ./eosio_build.sh"
  exit 1
fi

CLE="$EOS_SOURCE/build/programs/cleos/cleos -u $RPC --wallet-url $WALLET "

if [ $($CLE wallet list | grep "$2\ \*" | wc -l) -eq 0 ];
then
  echo " $2 account is not registerd in wallet OR account is unlocked."
  exit 1
fi
echo "================================================================================"
echo "The updateauth action changes the public key registered in the user account."
echo "This is very dangerous, and you are responsible for all problems that occur"
echo "during the operation. Be sure to remember this point."
echo "================================================================================"
read -p "Do you really want to run it? (y/N)" _confirm
_confirm=${_confirm:-"N"}
_confirm=$(echo $_confirm | tr '[:lower:]' '[:upper:]')

if [ $_confirm == "Y" ]; then
  echo "=========================== New Generation Key =============================="
  echo "### Generate $_type Key ###"
  echo 
  if [ -f new_${2}_${_type}.key ]; then
    echo " !!! new_${1}_${_type}.key is exists. you already auth updated"
    exit 1
  fi

  read -p "Do you want to encrypt new key file?? (y/N)" _enc
  _enc=${_confirm:-"N"}
  _enc=$(echo $_confirm | tr '[:lower:]' '[:upper:]')
  
  $CLE create key > new_${2}_${_type}.key
  PUB_KEY=$(cat new_${2}_${_type}.key | grep Public | awk '{print $3}');
  PRIV_KEY=$(cat new_${2}_${_type}.key | grep Private | awk '{print $3}');
  if [ $_enc == "Y" ]; then
    echo 
    echo "============================== Information =================================="
    echo " The newly created key has been encrypted and saved."
    echo " The encrypted key file can be checked with the './signing.sh {filename}' command,"
    echo " and can be released only when the .sign key file is present."
    echo "============================================================================="
    echo
    $SIGNING new_${2}_${_type}.key
    echo

  else
    cat new_${2}_${_type}.key
  fi
  echo
  echo "============================== ! Caution ! =================================="
  echo " The updateauth command invalidates an existing public key."
  echo " Therefore, you must keep the key below in a different repository."
  echo " When the Updateauth command completes, be sure to delete the _new.key file."
  
  if [ $_type == "active" ]; then
  echo "================================= RUN ======================================="
    $CLE push action eosio updateauth '{"account": "'$2'", "permission": "active", "parent": "owner", "auth":{"threshold": 1, "keys": [{"key":"'$PUB_KEY'","weight":1}], "waits": [], "accounts": [{"weight": 1, "permission": {"actor": "'$2'", "permission": active}}]}}' -p $2@active
  echo "============================================================================="
    if [ $? -eq 0 ]; then
      echo "Auth Update success. Import private key in wallet"
      $CLE wallet import -n $2 $PRIV_KEY
    else
      echo "Auth Update failed. remove new key file"
      rm -f new_${2}_${_type}.key
    fi
  elif [ $_type == "owner" ]; then
  echo "================================= RUN ======================================="
    $CLE push action eosio updateauth '{"account": "'$2'", "permission": "owner", "parent": "", "auth":{"threshold": 1, "keys": [{"key":"'$PUB_KEY'","weight":1}], "waits": [], "accounts": [{"weight": 1, "permission": {"actor": "'$2'", "permission": owner}}]}}' -p $2@owner
  echo "============================================================================="
    if [ $? -eq 0 ]; then
      echo " >> Auth Update success. Import private key in wallet"
      $CLE wallet import -n $2 $PRIV_KEY
    else
      echo " >> Auth Update failed. remove new key file"
      rm -f new_${2}_${_type}.key
    fi
  else
    echo " updateauth type is not correct."
    exit 1
  fi
else
  echo "Cancel to update auth script"
  exit 2
fi
