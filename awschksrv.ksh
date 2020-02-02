#!/usr/bin/ksh

chk_ulimit()
{
ulimitName=$1
ulimitParm=$2
ulimitSet=$3
ulimitReq=$4
ulimitType=$5

#print "${ulimitName}, ${ulimitParm}, ${ulimitReq}, ${ulimitSet}"

if [ "$ulimitSet" = "$ulimitReq" ]
then
   print "   ulimit ${ulimitType} ${ulimitName} ($ulimitReq) - ${PASSTXT}"
else
   chkulimiterror=1
   print "   ***************************************"
   print "   ulimit ${ulimitType} ${ulimitName} - ${FAILTXT}"
   print "   ${ulimitName} (ulimit -${ulimitType}${ulimitParm})"
   print "   current value (${ulimitSet})"
   print "   required value (${ulimitReq})"
   print "   ***************************************"
fi
}

getusrvalues()
{
unixusr=$1

#passwdentry=`grep $unixusr /etc/passwd`
#wmuseruid=`print $passwdentry | cut -d":" -f3`
#wmusergid=`print $passwdentry | cut -d":" -f4`
#wmusershell=`print $passwdentry | cut -d":" -f7`
groupentry=`grep $wmusergid /etc/group | cut -d":" -f1`
groupusersentry=`grep users /etc/group | cut -d":" -f1`
passexp=`chage -l $unixusr | grep "^Password expires" | cut -d":" -f2 | awk '{gsub(/^ +| +$/,"")} {print $0 }'`
passina=`chage -l $unixusr | grep "^Password inactive" | cut -d":" -f2 | awk '{gsub(/^ +| +$/,"")} {print $0 }'`
accountexp=`chage -l $unixusr | grep "^Account expires" | cut -d":" -f2 | awk '{gsub(/^ +| +$/,"")} {print $0 }'`
passmin=`chage -l $unixusr | grep "^Minimum number" | cut -d":" -f2 | awk '{gsub(/^ +| +$/,"")} {print $0 }'`
passmax=`chage -l $unixusr | grep "^Maximum number" | cut -d":" -f2 | awk '{gsub(/^ +| +$/,"")} {print $0 }'`
wmuseractive=`grep $unixusr /opt/ncsbin/acctutil/exclude.txt`

set -A usrCHKSET $wmuseruid $wmusergid $wmusershell $groupentry $groupusersentry $passexp $passina $accountexp $passmin $passmax $wmuseractive
}

chk_user()
{
chkuserName=$1
chkuserReq=$2
chkuserSet=$3

if [ "$chkuserSet" = "$chkuserReq" ]
then
   print "   ${chkuserName} (${chkuserReq}) - ${PASSTXT}"
else
   chkusererror=1
   print "   ***************************************"
   print "   Current value ${chkuserName} (${chkuserSet}) - ${FAILTXT}"
   print "   Required value ${chkuserName} (${chkuserReq})"
   print "   ***************************************"
fi
}

chk_dmzserver()
{
isdmzserver="false"
dmzserver=`hostname -s`
dmzserverlookup=`nslookup ${dmzserver}-ext.jnj.com`

if [ $? = 0 ]
then
  isdmzserver="true"
fi
}

chk_compliant()
{
chk_value=$1

if [ "${chk_value}" = "0" ]
then
   print "${COMPLIANTTXT}"
else
   print "${NOTCOMPLIANTTXT}"
fi
}

run_main()
{
print "SERVER ${SERVERNAME} VALIDATION REPORT\n"

#CHECKING SERVER SPECIFICATIONS"
print "CHECKING SERVER SPECIFICATIONS"
MEMSIZENO=`grep "MemTotal" /proc/meminfo | cut -f2 -d: | tr -cd [:digit:]`
MEMSIZENOGB=`print ${MEMSIZENO} | awk '{$1=$1/(1024^2); printf("%3.1f", $1)}'`
serverpass=0

if [ ${MEMSIZENO} -lt ${MEMMIN} ]
then
  print "   MEMORY (${MEMSIZENOGB} GB) - ${FAILTXT}"
  serverpass=1
else
  print "   MEMORY (${MEMSIZENOGB} GB) - ${PASSTXT}"
fi

CPUNO=`grep -c "processor" /proc/cpuinfo`
CPUMODEL=`grep "model name" /proc/cpuinfo | head -1 | cut -f2 -d: | sed -e 's/^ *//g;s/ *$//g'`

if [ ${CPUNO} -lt ${CPUMIN} ]
then
  print "   CPU (${CPUNO} - ${CPUMODEL}) - ${FAILTXT}"
  serverpass=1
else
  print "   CPU (${CPUNO} - ${CPUMODEL}) - ${PASSTXT}"
fi

OSNAME=`cat /etc/redhat-release`
print "   OS (${OSNAME})"

if [ "${serverpass}" = "0" ]
then
   print "   SERVER SPECIFICATIONS are ${COMPLIANTTXT}\n"
else
   print "   SERVER SPECIFICATIONS are ${NOTCOMPLIANTTXT}\n"
   exitcode=1
fi

#CHECK ULIMIT
print "CHECKING SERVER ULIMITS"
set -A SetName open_files max_user_processes
set -A ReqHard 1048576 1048576
set -A ReqSoft 1048576 1048576

ulimitparms="n u"
i=0
chkulimiterror=0

#read values
for parameter in $ulimitparms
do
   SysHard[$i]=`ulimit -H$parameter`
   SysSoft[$i]=`ulimit -S$parameter`
   (( i++ ))
done

#compare values
i=0
for setting in $ulimitparms
do
   chk_ulimit ${SetName[$i]} ${setting} ${SysHard[$i]} ${ReqHard[$i]} H
   chk_ulimit ${SetName[$i]} ${setting} ${SysSoft[$i]} ${ReqSoft[$i]} S
   (( i++ ))
done

if [ "$chkulimiterror" = "0" ]
then
   print "   SERVER ulimits are ${COMPLIANTTXT}"
else
   print "   SERVER ulimits are ${NOTCOMPLIANTTXT}"
   exitcode=1
fi

#CHECK UTILITIES
print "\nCHECKING SERVER UTILITIES/TOOLS"
set -A ToolName tar curl
set -A ToolLocation /bin/tar /usr/bin/curl
set -A ToolVersion 1.23 7.19.7
toolpass=0

for i in {0..1}
do
   if [ -f ${ToolLocation[$i]} ]
   then
      print "   TOOL_PATH (${ToolLocation[$i]}) - ${PASSTXT}"
      # Get tool version
      case ${ToolName[$i]} in
               tar)
                 VERSION=`eval ${ToolLocation[$i]} --version | head -1 | cut -d")" -f2 | tr -d ' '`
                 ;;
               curl)
                 VERSION=`eval ${ToolLocation[$i]} --version | head -1 | cut -d" " -f2`
                 ;;
      esac

      verchk=`echo -ne "${ToolVersion[$i]}\n${VERSION}" | sort -rV | uniq | grep -n "${VERSION}" | cut -d":" -f1`

      if [ ${verchk} -eq 1 ]
      then
         print "   TOOL_VERSION (${ToolVersion[$i]}) - ${PASSTXT}"
      else
         print "   TOOL_VERSION (${ToolVersion[$i]}) - ${FAILTXT}"
         toolpass=1
      fi
   else
      print "   TOOL_PATH (${ToolName[$i]}) - ${FAILTXT}"
      toolpass=1
   fi
done

if [ $toolpass = 0 ]
then
  print "   SERVER UTILITIES/TOOLS are \033[0m\033[32mCOMPLIANT\033[0m"
else
  print "   SERVER UTILITIES/TOOLS are \033[0m\033[31mNOT-COMPLIANT\033[0m"
fi


#CHECK FILESYSTEM
print "\nCHECKING SERVER FILE SYSTEM AND OWNERSHIP FOR $wmuser"
#fslist=`df -k | grep -P "(webMethods)|(softwareag)|(appjava)" | cut -d"%" -f2`
#fslist=`grep -P "(apps)|(depot)|(fitdata)" /proc/mounts | awk '{print $2}'`
#fslist=`grep -P "(apps)|(depot)" /proc/mounts | awk '{print $2}'`
fslist="/apps /depot /fitshare /fitdata"
set -A fslistsize 950 0 0 0

v=0
w=0
x=0
y=0
fsindex=0
for filesystem in $fslist
do
  #print "REQUIRED SIZE ${fslistsize[fsindex++]}"
  chkmount=`grep -P "${filesystem}" /proc/mounts | awk '{print $2}'`
  if [ ${chkmount} ]
  then
    fsmount[v++]=${filesystem}
    chksize=`df -Pk ${filesystem} | awk '{print $2}'`
    dirlevels=`echo $filesystem | tr -dc '/' | wc -c`
    tempdir=$filesystem
    for (( c=1; c<=$dirlevels ; c++ ))
    do
       owner=$(stat -c %U $tempdir)
       case $tempdir in
          "/opt"|"/opr") ;;  # SKIP
          *)
             if [ "$owner" != "fitadmin"  ] ;
             then
                fserror[x++]="$tempdir($owner)"
             else
                fsdirs[y++]="$tempdir"
             fi ;;
       esac
       tempdir=`dirname $tempdir`
    done
  else
    fsmounterror[w++]=${filesystem}      
    continue
  fi
done

countFSerror=`echo ${#fserror[@]}`
countFSmounterror=`echo ${#fsmounterror[@]}`

if [ "${countFSmounterror}" = "0" ]
then
   for z in "${fsmount[@]}"; do print "   $z - ${PASSTXT}"; done
else
   for z in "${fsmounterror[@]}"; do print "   $z MOUNT NOT FOUND - ${FAILTXT}"; done
fi

if [ "$countFSerror" = "0" ]
then
   set -A fsdirunique $( printf '%s\n' "${fsdirs[@]}" | sort -u )
   for z in "${fsdirunique[@]}"; do print "   $z - ${PASSTXT}"; done
else
   print "   ***************************************"
   print "   VERIFY OWNERSHIP FOR THE FOLLOWING:"
   set -A fserrorunique $( printf '%s\n' "${fserror[@]}" | sort -u )
   for z in "${fserrorunique[@]}"; do print "   $z - ${FAILTXT}"; done
   #for z in "${fserror[@]}"; do print "   $z - ${FAILTXT}"; done
   print "   ***************************************"
   exitcode=1
fi

if [[ "$countFSerror" = "0" && "$countFSmounterror" = "0" ]]
then
   print "   FILE SYSTEM is ${COMPLIANTTXT}"
else
   print "   file system is ${NOTCOMPLIANTTXT}"
fi

#CHECK USER
#print "\nCHECKING $wmuser USERNAME"
#set -A usrCHKNAME USER_ID GROUP_ID BASH_SHELL GROUP_EADV GROUP_USERS PASSWORD_EXPIRES PASSWORD_INACTIVE ACCOUNT_EXPIRES MIN_DAYS MAX_DAYS
#usrCHKNAME="USER_ID GROUP_ID BASH_SHELL GROUP_EADV GROUP_USERS PASSWORD_EXPIRES PASSWORD_INACTIVE ACCOUNT_EXPIRES MIN_DAYS MAX_DAYS USER_INACTIVE"
#case ${SERVERREGION} in
#     ITSUS) 
#       set -A usrCHKREQ 15000 12000 /bin/bash fitgrp users never never never 0 99999 fitadmin
#       ;;
#     ITSBE) 
#       set -A usrCHKREQ 21543 10657 /bin/bash fitgrp users never never never 0 99999 fitadmin
#       ;;
#     ITSGB)
#       set -A usrCHKREQ 15000 12000 /bin/bash fitgrp users never never never 0 99999 fitadmin
#       ;;
#     AWSAM)
#       set -A usrCHKREQ 15000 12000 /bin/bash fitgrp users never never never 0 99999 fitadmin
#       ;;
#     ITSSG)
#       set -A usrCHKREQ 15000 12000 /bin/bash fitgrp users never never never 0 99999 fitadmin
#       ;;
#esac     
#getusrvalues $wmuser

#compare values
j=0
chkusererror=0
for usersetting in $usrCHKNAME
do
   chk_user ${usersetting} ${usrCHKREQ[$j]} ${usrCHKSET[$j]}
   (( j++ ))
done

if [ "$chkusererror" = "0" ]
then
   print "   $wmuser USERNAME is ${COMPLIANTTXT}\n"
else
   print "   $wmuser USERNAME is ${NOTCOMPLIANTTXT}\n"
   exitcode=1
fi

print "SUMMARY"
print "   SERVER SPECIFICATIONS - \c"
chk_compliant ${serverpass}

print "   SERVER ULIMITS - \c"
chk_compliant ${chkulimiterror}

print "   SERVER UTILITIES/TOOLS - \c"
chk_compliant ${toolpass}

print "   SERVER FILE SYSTEM OWNERSHIP FOR $wmuser - \c"
chk_compliant ${countFSerror}

print "   USERNAME $wmuser - \c"
chk_compliant ${chkusererror}

print "\nREPORT SAVED\n   ${RPTFILE}"
}

# Script start
EMAILDL="fdepepp@its.jnj.com"
SERVERNAME=`hostname -f | tr [:lower:] [:upper:]`
SERVERNAMES=`hostname | tr [:lower:] [:upper:]`
SERVERREGION=`hostname | cut -c1-5 | tr [:lower:] [:upper:]`
SCRIPTNAME=`basename $0 .ksh`
wmuser="fitadmin"
exitcode=0
PID=$$
DATE_STAMP=`/bin/date "+%y%m%d%H%M"`
CURRENTDIR=`pwd`
PASSTXT="\033[0m\033[32mPASS\033[0m"
FAILTXT="\033[0m\033[31mFAIL\033[0m"
COMPLIANTTXT="\033[0m\033[32mCOMPLIANT\033[0m"
NOTCOMPLIANTTXT="\033[0m\033[31mNOT-COMPLIANT\033[0m"
#MEMMIN="32872648"   # Default Values
#MEMMIN="197914930"   # Default Values
MEMMIN="82006432"   # Default Values
CPUMIN="4"          # Default Values

while [ $# -gt 0 ]
do
    case "$1" in
        -c)  CPUMIN="$2";;
        -m)  memgb="$2";
             MEMMIN=`print $memgb | awk '{$1=$1*(1024^2); print $1}'`;
             shift;;
        -?)  print "\nusage: $0 [-c cores] [-m memory]\n";
             print "  -c minimum number of [cores] to verify"
             print "  -m minimum number of allocated [memory] in GB to verify"
             print "  -? help\n"
             exit 1;;
    esac
    shift
done

if [ -d ${CURRENTDIR}/chk_results ]
then
   RPTFILE="${CURRENTDIR}/chk_results/${SCRIPTNAME}.${SERVERNAMES}.${DATE_STAMP}${PID}"
else
   RPTFILE="${CURRENTDIR}/${SCRIPTNAME}.${SERVERNAMES}.${DATE_STAMP}${PID}"
fi
chk_dmzserver

clear
run_main | tee ${RPTFILE}
cat ${RPTFILE} | perl -pe 's/\x1b\[[0-9;]*[mG]//g' | mail -s "SERVER ${SERVERNAME} VALIDATION REPORT" -r "${wmuser}@${SERVERNAME}" ${EMAILDL}

if [ "$exitcode" = "1" ]
then
   exit 1
fi
