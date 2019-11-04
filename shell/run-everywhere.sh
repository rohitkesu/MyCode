#!/bin/bash

SERVER_FILE='/home/ec2-user/servers'

usage() {
  echo  
  echo "${0} -f [server_file] -n -s -v"
  echo "     -f to provide a file name which contains server ip address where commands to be executed"
  echo "     -n for dryrun"
  echo "     -s to run a command in sudo mode"
  echo "     -v for verbose mode"
  exit 1d
}

log () {

  MESSAGE="${1}"
  if [[ "${VERBOSE}" -eq 'true' ]]
  then
    echo "MESSAGE"
  fi
}

while getopts "f:nsv" opt
do
  case $opt in
    f) SERVER_FILE=$OPTARG ;;
    n) DRYRUN='true' ;;
    s) SUPERUSER='sudo' ;;
    v) VERBOSE='true' ;;
    ?) usage ;;
  esac
done      

if [[ ! -e $SERVER_FILE ]]
then
  echo "ERROR: Cannot read server file $SERVER_FILE"
  exit 1
else
  log ""
  log "Using server file ${SERVER_FILE}"
  log ""
fi

shift $(( $OPTIND - 1 ))

if [[ "${#}" -lt 1 ]]
then
  echo
  echo "ERROR: Provide atleast some commands to be executed against the servers"
  echo
  exit 1
else
  CMD="${@}"
  log "Command to be executed on the remote servers: ${CMD}"
fi

for SERVER in $(cat $SERVER_FILE)
do
  log "Processing on Server: $SERVER"
  if [[ ${DRYRUN} -eq 'true' ]]
  then
    log "Processing on Server: $SERVER running comand: $SUPERUSER $CMD"
    echo "ssh -o ConnectTimeout=2 $SERVER $SUPERUSER $CMD"
  else
    ssh -o ConnectTimeout=2 $SERVER $SUPERUSER $CMD
    if [[ "${?}" -ne 0 ]]
    then
      echo "Error in executing command $CMD on $SERVER"
      exit 1
    fi    
  fi
done  

exit 0