#!/bin/bash
#####################################################################################
#  Script : beeline-check.sh
#
#  Created at: 23-Oct-2019
#
#  Description : Script to check the Hive/Spark Sql connectivity using beeline
#                tool provided by spark
#  Parameters :  Userid, password
#####################################################################################

usage() {
  echo
  echo "Usage: ./beeline-check.sh -u USERNAME -p PASSWORD"
  echo
  exit 1
}

#SERVER_NAME=$(hostname)
#PORT="10000"
USERNAME=
PASSWORD=
RETRIES="3"
SEND_TO="DL-NCSUS-GTSFITSERVICESGLOBALSUPPORT@ITS.JNJ.com"
WMUSER="fitadmin"
BEELINE_PATH="/apps/adf/spark-2.4.3-bin-hadoop2.7/bin/beeline"
SCRIPTNAME=$(basename $0 | awk -F '.' '{print $1}')
SUFFIX=$(date +%y%m%d%H%M%S)
CURRENT_PATH=$(dirname $0)
SERVER_LIST="${CURRENT_PATH}/SERVER_LIST.DAT"
ALETER_SCRIPT="generateAleter.sh"

if [[ "${#}" -eq "0" ]]
then
  usage;
fi

while getopts "u:p:" opt;
do
  case "${opt}"
  in
    u) USERNAME=${OPTARG}
      ;;
    p) PASSWORD=${OPTARG}
      ;;
    *) usage
      ;;
  esac
done

if [[ ! -d "/tmp/beeline" ]]
then
  mkdir "/tmp/beeline"
fi

cat $SERVER_LIST | while read SINGLELINE
do

  if [[ $(echo "${SINGLELINE}" | head -c1) = '#' ]]
  then
    continue
  else
    SERVER_NAME=$(echo "${SINGLELINE}" | awk -F ':' '{print $1}')
    PORT=$(echo "${SINGLELINE}" | awk -F ':' '{print $2}')
  fi

  CONNECTION_STRING="${BEELINE_PATH} -u jdbc:hive2://${SERVER_NAME}:${PORT} -n ${USERNAME} -p ${PASSWORD}"

n=0
while [[ "${n}" -lt "${RETRIES}" ]]
do
${CONNECTION_STRING} <<EOF > "/tmp/beeline/${SCRIPTNAME}_${SERVER_NAME}_${PORT}.log.${SUFFIX}" 2>&1
!quit
EOF
  grep "Connected to: Spark SQL" "/tmp/beeline/${SCRIPTNAME}_${SERVER_NAME}_${PORT}.log.${SUFFIX}" > /dev/null 2>&1
  if [[ "${?}" -eq "0" ]]
  then
    break
  else
    n=$[$n+1]
    sleep 5
  fi    
done

  grep "User name or password error" "/tmp/beeline/${SCRIPTNAME}_${SERVER_NAME}_${PORT}.log.${SUFFIX}" > /dev/null 2>&1
  if [[ "${?}" -eq "0" ]]
  then
    echo "Message from $(basename $0): Error validating the login : User name or password error.
    Hostname:${SERVER_NAME} Port:${PORT} Username:${USERNAME}" |
    mail -s "Message from $(basename $0): Error validating the login." -r "${WMUSER}@${SERVER_NAME}" -a "/tmp/beeline/${SCRIPTNAME}_${SERVER_NAME}_${PORT}.log.${SUFFIX}" "${SEND_TO}"
  
    ${CURRENT_PATH}/${ALETER_SCRIPT} "Error validating the login." \
    "Message from $(basename $0): Error validating the login. Hostname:${SERVER_NAME} Port:${PORT} Username:${USERNAME}"

    if [[ ! -f "${CURRENT_PATH}/Alerter.json" ]]
    then
      echo "Error generating the Alerter.json file"
      exit 1
    fi

    curl -X POST -H "Content-Type: application/json" -d @Alerter.json  'https://itsusralsp07260.jnj.com:12201/gelf' 

    if [[ "${?}" -ne "0" ]]
    then
      echo "Error posting an incident message to NetCool"
      exit 1
    fi      
  else 
    grep "Connected to: Spark SQL" "/tmp/beeline/${SCRIPTNAME}_${SERVER_NAME}_${PORT}.log.${SUFFIX}" > /dev/null 2>&1
    if [[ "${?}" -ne "0" ]]
    then
      echo "Message from $(basename $0): Hive/Spark Sql connectivity failed on
      Hostname:${SERVER_NAME} Port:${PORT} Username:${USERNAME}" |
      mail -s "Message from $(basename $0): Hive/Spark Sql connectivity failed" -r "${WMUSER}@${SERVER_NAME}" -a "/tmp/beeline/${SCRIPTNAME}_${SERVER_NAME}_${PORT}.log.${SUFFIX}" "${SEND_TO}"

      ${CURRENT_PATH}/${ALETER_SCRIPT} "Hive/Spark Sql connectivity failed" \
      "Message from $(basename $0): Hive/Spark Sql connectivity failed. Hostname:${SERVER_NAME} Port:${PORT} Username:${USERNAME}"

      if [[ ! -f "${CURRENT_PATH}/Alerter.json" ]]
      then
        echo "Error generating the Alerter.json file"
        exit 1
      fi

      curl -X POST -H "Content-Type: application/json" -d @Alerter.json  'https://itsusralsp07260.jnj.com:12201/gelf' 

      if [[ "${?}" -ne "0" ]]
      then
        echo "Error posting an incident message to NetCool"
        exit 1
      fi      
    fi
  fi
done 

exit 0
