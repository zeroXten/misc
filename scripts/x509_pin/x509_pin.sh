#!/bin/bash

# This is a simple bash script to download a site's X.509 public key for the purpose
# of pinning. Previous keys are stored in a local directory and can be check against
# the current key.

# Written in 2013  by @zeroXten using information from
# https://www.owasp.org/index.php/Certificate_and_Public_Key_Pinning

host="$1"
port="${2:-443}"
output_dir="$HOME/.x509_pin"

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

if [ -x "/usr/bin/nc" ]; then
  echo "INFO: Testing connection"
  /usr/bin/nc -d -w 1 "$host" "$port" >/dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo "FATAL: Connection to ${host}:${port} timed out"
    exit 3
  fi
fi

echo "INFO: Getting public key for $host"
new_key=$(/usr/bin/openssl s_client -showcerts -connect "${host}:${port}" </dev/null 2>/dev/null | openssl x509 -noout -pubkey 2>/dev/null)
if [ $? -ne 0 ]; then
  echo "FATAL: Could not get cert from $host"
  exit 4
fi

if [ -e "${output_dir}/${host}.pub" ]; then
  current_key=$(cat "${output_dir}/${host}.pub")
  if [ "$new_key" != "$current_key" ]; then
    echo "================== WARNING ==================="
    echo "           Public key has changed"
    echo "=============================================="
    echo "Current key:"
    echo -e "$current_key"
    echo "============================================="
    echo "New key:"
    echo -e "$new_key"
    echo "============================================="
    exit 5
  else
    echo "OK: Keys match"
    exit 0
  fi
else
    echo "INFO: First time we've seen this host. Saving key."
    touch "${output_dir}/${host}.pub"
    chmod 0600 "${output_dir}/${host}.pub"
    echo -e "$new_key" > "${output_dir}/${host}.pub"
    exit 0
fi
