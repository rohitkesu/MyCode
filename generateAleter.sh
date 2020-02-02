#!/bin/bash
#####################################################################################
#  Script : generateAleter.sh
#
#  Created at: 19-Nov-2019
#
#  Description : Script to generate Aleter.json file which is send to netcool to 
#                generate an incident
#####################################################################################

SERVER_NAME=$(hostname)
SERVER_NAME_FQDN=$(tail -1 /etc/hosts | awk '{print $NF}')
DATE_EPOCH=$(date +%s)
SUMMARY="${1}"
FULLMESSAGETEXT="${2}"
FULLMESSAGETEXT_BASE64=$(echo $FULLMESSAGETEXT | base64)

cat >./Alerter.json <<EOF
{
  "genricAleter_authID": "EDG-TT-Type03",
  "genricAleter_authCode": "d95c3dae92a321ca85e36bb67248f346",

  "genricAleter_action": "toNetcool",

  "genricAleter_netcool_data": {
    "EDG_Identifier": "A || B || C || D",
    "EDG_Severity": 3,
    "EDG_IncidentTime": "${DATE_EPOCH}",
    "EDG_ConfigurationItem": "${SERVER_NAME}",
    "EDG_Node": "${SERVER_NAME_FQDN}",
    "EDG_Summary": "${SUMMARY}",
    "EDG_FullMessageText": "${FULLMESSAGETEXT}",
    "EDG_FullMessageText_base64": "${FULLMESSAGETEXT_BASE64}"
  },

  "message": "${FULLMESSAGETEXT}",
  "short_message": "${SUMMARY}",
  "version": "1.1"
}
EOF
