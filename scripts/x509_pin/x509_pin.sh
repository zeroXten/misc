#!/bin/bash

# This is a simple bash script to download a site's X.509 public key for the purpose
# of pinning. Previous keys are stored in a local directory and can be check against
# the current key.

# Written in 2013  by @zeroXten using information from
# https://www.owasp.org/index.php/Certificate_and_Public_Key_Pinning

training_mode=0
port=443
output_dir="$HOME/.x509_pin"

while true; do
  case "$1" in
    -t|--train) training_mode=1; shift;;
    -p|--port)  port=$2; shift 2;;
    -d|--dir)   output_dir=$2; shift 2;;
    *) break;;
  esac
done

host="$1"

if [ -z "$host" ]; then
  name=$(basename $0)
  echo "Usage: $name HOST [PORT]"
  exit 1
fi

if [ ! -x "/usr/bin/openssl" ]; then
  echo "FATAL: Cannot find openssl"
  exit 2
fi

if [ ! -d "$output_dir" ]; then
  mkdir "$output_dir"
  chmod 0700 "$output_dir"
fi

if [ ! -d "${output_dir}/${host}_${port}" ]; then
  mkdir "${output_dir}/${host}_${port}"
  chmod 0700 "${output_dir}/${host}_${port}"
fi

if [ -x "/usr/bin/nc" ]; then
  echo "INFO: Testing connection"
  /usr/bin/nc -d -w 1 "$host" "$port" >/dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo "FATAL: Connection to ${host}:${port} timed out"
    exit 3
  fi
fi

echo "INFO: Getting fingerprint for $host"
fp=$(/usr/bin/openssl s_client -showcerts -connect "${host}:${port}" </dev/null 2>/dev/null | openssl x509 -noout -sha1 -fingerprint 2>/dev/null | awk -F'=' '{ print $2 }')
if [ $? -ne 0 ]; then
  echo "FATAL: Could not get fingerprint from ${host}:${port}"
  exit 4
fi

if [ $training_mode -eq 1 ]; then
  echo "================== WARNING ==================="
  echo "              In training mode"
  echo "       New fingerprints will be trusted"
  echo "=============================================="
    
  if [ -e "${output_dir}/${host}_${port}/${fp}" ]; then
    echo "INFO: Fingerprint already exists"
    exit 0
  else
    touch "${output_dir}/${host}_${port}/${fp}"
    chmod 0600 "${output_dir}/${host}_${port}/${fp}"
    echo "INFO: Adding fingerprint ${fp}"
    exit 0
  fi
else 
  if [ -e "${output_dir}/${host}_${port}/${fp}" ]; then
    echo "OK: Fingerprint has been seen before for ${host}:${port}"
    exit 0
  else
    echo "================== WARNING ==================="
    echo "              POSSIBLE ATTACK"
    echo "=============================================="
    echo "            Fingerprint is new"
    echo 
    echo " We are not in training mode so either the"
    echo " certificate has changed or we're being"
    echo " attacked."
    echo "=============================================="
    echo " SHA1 fingerprint is:"
    echo " ${fp}"
    echo "=============================================="
    exit 5
  fi
fi
