#!/usr/bin/env sh

set -e
printf "\n\n [i] Starting SimpleX ...\n\n"

confd="/etc/opt/simplex"
xftp="/etc/opt/simplex-xftp"
logd="/var/opt/simplex"

# Check if smp-server has been initialized
if [ ! -f "$confd/smp-server.ini" ]; then
  # Set a 15 digit server password. See the comments in smp-server.ini for a description of what this does
  export PASS=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 15) 

  # Init certificates and configs
  smp-server init -y -l --password $PASS

  else
    export PASS=$(grep -i "^create_password" $confd/smp-server.ini | awk -F ':' '{print $2}' | awk '{$1=$1};1')
fi

if [ -f "$xftp/file-server.ini" ]; then
   # Remove the directory if file-server.ini exists
   rm -r $xftp/*
else
   echo "Nice and clean."
fi
# # Check if xftp-server has been initialized
# if [ ! -f "$xftp/file-server.ini" ]; then
#   # Init certificates and configs
#   mkdir -p /root/xftp
#   xftp-server init -q '10gb' -p /root/xftp/

#   else
#   echo "All good! - XFTP initialized"
# fi

# Backup store log just in case
#
# Uses the UTC (universal) time zone and this
# format: YYYY-mm-dd'T'HH:MM:SS
# year, month, day, letter T, hour, minute, second
#
# This is the ISO 8601 format without the time zone at the end.
#
_file="${logd}/smp-server-store.log"
if [ -f "${_file}" ]; then
  _backup_extension="$(date -u '+%Y-%m-%dT%H:%M:%S')"
  cp -v -p "${_file}" "${_file}.${_backup_extension:-date-failed}"
  unset -v _backup_extension
fi
unset -v _file

TOR_ADDRESS=$(sed -n -e 's/^tor-address: \(.*\)/\1/p' /root/start9/config.yaml)
XFTP_ADDRESS=$(sed -n -e 's/^xftp-address: \(.*\)/\1/p' /root/start9/config.yaml)
SMP_FINGERPRINT=$(cat $confd/fingerprint)
# XFTP_FINGERPRINT=$(cat $xftp/fingerprint)

SMP_URL="smp://$SMP_FINGERPRINT:$PASS@$TOR_ADDRESS"
XFTP_URL="xftp://$XFTP_FINGERPRINT@$XFTP_ADDRESS"
mkdir -p /root/start9

cat << EOF > /root/start9/stats.yaml
---
version: 2
data:
  SimpleX SMP Server Address:
    type: string
    value: $SMP_URL
    description: Your SMP Server address, used in client applications.
    copyable: true
    qr: true
    masked: true
EOF
#   SimpleX XFTP Server Address:
#     type: string
#     value: $XFTP_URL
#     description: Your XFTP Server address, used in client applications.
#     copyable: true
#     qr: true
#     masked: true
# EOF

# Finally, run smp-sever and xftp-server. Notice that "exec" here is important:
# smp-server replaces our helper script, so that it can catch INT signal
# exec tini -s -- sh -c "smp-server start +RTS -N -RTS & xftp-server start +RTS -N -RTS; wait"
exec tini -s -- smp-server start +RTS -N -RTS
# _term() {
#   echo "Caught TERM signal!"
#   kill -INT "$smp_process" 2>/dev/null
#   kill -INT "$xftp_process" 2>/dev/null
# }

# smp-server start +RTS -N -RTS &
# smp_process=$!

# xftp-server start +RTS -N -RTS &
# xftp_process=$!

# trap _term INT

# wait $xftp_process $smp_process
