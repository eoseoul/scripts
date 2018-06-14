#!/bin/bash
CURL_BIN=$(which curl)
SECURE=0
print_no_argv (){
    echo
    echo "Usage : $0 [Options]"
    echo
    echo "  -H : Target Hostname"
    echo "  -p : EOS nodeos Http Port (Default: 8888)"
    echo "  -s : Use HTTPS Check (Optional)"
    echo "  -w : Difference between head_block and irreversible_block warning count (Default: 253)"
    echo "  -c : Difference between head_block and irreversible_block critical count (Defaut: 506)"
    echo "  -h : help"
    echo
}


while getopts "H:w:c:p:s" options
do
    case $options in
        H)
            HOST="$OPTARG";;
        p)
            PORT="$OPTARG";;
        w)
            WARN_VAL="$OPTARG";;
        c)
            CRIT_VAL="$OPTARG";;
        s)
            SECURE=1;;
        *)
            print_no_argv
            exit 0;;
    esac
done

# set default value
WARN_VAL=${WARN_VAL:-"253"}
CRIT_VAL=${CRIT_VAL:-"506"}

if [ -z $HOST ]
then
    print_no_argv
    exit 3;
elif [ -z $PORT ]
then
    print_no_argv
    exit 3;
elif [ $(echo $WARN_VAL | grep -E "[::numeric::]" | wc -l) -eq 1 ]
then
    echo
    echo "### Warning value is not numeric."
    print_no_argv
    exit 3;
elif [ $(echo $CRIT_VAL | grep -E "[::numeric::]" | wc -l) -eq 1 ]
then
    echo
    echo "### Critical Value is not numeric."
    print_no_argv
    exit 3;
elif [ $WARN_VAL -gt $CRIT_VAL ]
then
    echo
    echo "### Critical value is small then Warning Values"
    echo " - Warning  : $WARN_VAL"
    echo " - Critical : $CRIT_VAL"
    echo
fi

# Set HTTPS
if [ $SECURE -eq 1 ]; then
  CHECK_URL="https://$HOST:$PORT/v1/chain/get_info"
else
  CHECK_URL="http://$HOST:$PORT/v1/chain/get_info"
fi


read _hblk _lirblk _hblkt _sver <<<$($CURL_BIN $CHECK_URL --silent | jq '.head_block_num, .last_irreversible_block_num,  .head_block_time, .server_version' | sed "s/\"//g" )

# Server open check
if [ -z $_hblk ]
then
    echo "STATUS CRITICAL - Server is not response($HOST:$PORT)"
    exit 2;
fi

_diff_hblk=$(($_hblk-$_lirblk))
nTIME=$(date +"%s" --utc)
bTIME=$(date +"%s" --date="$(echo $_hblkt| sed "s/T/\ /g")" -u)
_diff_blkt=$(($nTIME-$bTIME))

if [ $_diff_hblk -gt $CRIT_VAL ]
then
    echo "CRITICAL - Irreversible not sync - VER:$_sver,HEAD:$_hblk,IRR_BLK:$_lirblk,DiffBLK:$_diff_hblk (Critical:$CRIT_VAL)"
    exit 2;
elif [ $_diff_blkt -gt $CRIT_VAL ]
then
    echo "CRITICAL - Block is not sync - VER:$_sver,HEAD:$_hblk,IRR_BLK:$_lirblk,LastBlockTime:$(date +"%Y-%m-%dT%H:%M:%S" --date=@${bTIME})(UTC),DiffTime:$_diff_blkt"
    exit 2;
elif [ $_diff_hblk -gt $WARN_VAL ]
then
    echo "WARNING - Irreversible not sync - VER:$_sver,HEAD:$_hblk,IRR_BLK:$_lirblk,DiffBLK:$_diff_hblk (Warning:$WARN_VAL)"
    exit 1;
elif [ $_diff_blkt -gt $WARN_VAL ]
then
    echo "WARNING - Block is not sync - VER:$_sver,HEAD:$_hblk,IRR_BLK:$_lirblk,LastBlockTime:$(date +"%Y-%m-%dT%H:%M:%S" --date=@${bTIME})(UTC),DiffTime:$_diff_blkt"
    exit 1;
else
    echo "STATUS OK - ver:$_sver,HEAD:$_hblk,IRR_BLK:$_lirblk,DiffBLK:$_diff_hblk,BLKTime:$(date +"%Y-%m-%dT%H:%M:%S" --date=@${bTIME})(UTC),DiffTime:$_diff_blkt"
    exit 0;
fi
