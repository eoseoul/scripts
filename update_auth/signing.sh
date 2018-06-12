#!/bin/bash

# Default set
edit_tool="/usr/bin/vi"
sign_key=".sign"
tmp_file="_tmp_sign_edit"

if [ $# -lt 1 ]; then 
  echo "Usage: $0 [filename] {edit}"
  echo " >> sign script is ecryption tool using rsa key"
  echo "    Unencrypt file -> Encryption / Encrypt file -> Decrypt output"
  echo " >> The edit option is used to modify the encrypted file "
  exit 1;
fi

# file extention parsing
sign_type=$(basename $1 | tr '[:upper:]' '[:lower:]' | awk -F"." '{print $NF}')

# generate a 2048-bit RSA key and store it in key.txt
if [ ! -f .sign ]; then
  openssl genrsa -out $sign_key 4096
  chmod 0600 $sign_key
fi

# file exists check
if [ ! -r $1 ]; then
  echo "We can't read file - $1"
  exit 1
fi

# option(edit) lowercase
option=$(echo $2 | tr '[:upper:]' '[:lower:]')

# is file signing?
if [ $sign_type == "sign" ] 
then
  # input with edit option? 
  if [ -z $option ]; then
    # decrypt the message and output to stdout
    openssl rsautl -inkey $sign_key -decrypt < $1
  elif [ $option == "edit" ]; then
    openssl rsautl -inkey $sign_key -decrypt -out $tmp_file < $1
    vi $tmp_file
    cat $tmp_file | openssl rsautl -inkey $sign_key -encrypt > $1
    rm -f $tmp_file
  else
    echo "Option is not correct. only support 'edit'"
    exit 1
  fi
else
  # encrypt "hello world" using the RSA key in key.txt
  echo "================================= Encode ===================================="
  cat $1
  echo "================================= Encode ===================================="
  cat $1 | openssl rsautl -inkey $sign_key -encrypt > $1.sign
  # remove original file
  rm -f $1
fi
