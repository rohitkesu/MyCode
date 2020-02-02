#!/bin/bash
#####################################################################################
#  Script : beeline-check.sh
#
#  Created at: 23-Oct-2019
#
#  Description : Script to check the Hive/Spark Sql connectivity using beeline
#                tool provided by spark
#  Parameters :  Hostname, Port, userid, password
#####################################################################################

usage() {
    echo
    echo "Usage: ./beeline-check.sh -h HOSTNAME -o PORT -u USERNAME -p PASSWORD"
    echo
    exit 1
}

SERVER_NAME=$(hostname)
PORT="10000"
USERNAME=
PASSWORD=
SEND_TO="rkeshar4@its.jnj.com"
WMUSER="fitadmin"
BEELINE_PATH="/apps/adf/spark-2.4.3-bin-hadoop2.7/bin/beeline"
SCRIPTNAME=$(basename $0 | awk -F '.' '{print $1}')
SUFFIX=$(date +%y%m%d%H%M%S)

if [[ "${#}" -eq "0" ]]
then
    usage;
fi

while getopts "h:o:u:p:" opt;
do
  case "${opt}"
  in
    h) SERVER_NAME=${OPTARG}
       ;;
    o) PORT=${OPTARG}
       ;;
    u) USERNAME=${OPTARG}
       ;;
    p) PASSWORD=${OPTARG}
       ;;
    *) usage
       ;;
  esac
done

CONNECTION_STRING="${BEELINE_PATH} -u jdbc:hive2://${SERVER_NAME}:${PORT} -n ${USERNAME} -p ${PASSWORD}"

${CONNECTION_STRING} <<EOF > "/tmp/${SCRIPTNAME}.log.${SUFFIX}" 2>&1
!quit
EOF

grep "User name or password error" "/tmp/${SCRIPTNAME}.log.${SUFFIX}" > /dev/null 2>&1
if [[ "${?}" -eq "0" ]]
then
    echo "Message from $(basename $0): Error validating the login : User name or password error.
    Hostname:${SERVER_NAME} Port:${PORT} Username:${USERNAME} Password: ${PASSWORD}" |
    mail -s "Message from $(basename $0): Error validating the login." -r "${WMUSER}@${SERVER_NAME}" "${SEND_TO}"
    exit 0
fi

grep "Connected to: Spark SQL" "/tmp/${SCRIPTNAME}.log.${SUFFIX}" > /dev/null 2>&1
if [[ "${?}" -ne "0" ]]
then
    echo "Message from $(basename $0): Hive/Spark Sql connectivity failed on
    Hostname:${SERVER_NAME} Port:${PORT} Username:${USERNAME} Password: ${PASSWORD}" |
    mail -s "Message from $(basename $0): Hive/Spark Sql connectivity failed" -r "${WMUSER}@${SERVER_NAME}" "${SEND_TO}"
    exit 0
fi

exit 0
