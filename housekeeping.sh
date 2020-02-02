#!/bin/bash
######################################################################################
#  Script : housekeeping.sh
#
#  Created at: 25-Oct-2019
#
#  Description : This file deletes old files as directed by the pameters provided in 
#                FILELIST.DAT. The parameter file FILELIST.DAT must contain [F,D] -
#                for File or Directory operation, No. of days old files to be retained
#                and the rest deleted, Directory Path where to search and a search
#                pattern. 
#
#  Parameters : --dryrun [Only to display the files/directories to be deleted]
######################################################################################

usage() {

    echo 
    echo "USAGE : ./$(basename $0) [--dryrun]"
    echo
    exit 1
}

display() {

    echo
    echo "Following files/directories will be deleted :"
    echo

    cat "${RESULTFILE}"
}

find_data() {

    OPERATION=$(echo "${1}" | tr [:upper:] [:lower:])
    NOOFDAYS="+${2}"
    DELETEPATH="${3}"
    PATTERNMATCH="${4}"
    NAME=" -name "

    case "${4}" in
        '*' | "" )
            find "${DELETEPATH}" -maxdepth 1 -type "${OPERATION}" -mtime "${NOOFDAYS}" -user "${CURRENTUSER}" -print >> "${RESULTFILE}" 2>"${LOGFILE}"
            ;;
        *)
            find "${DELETEPATH}" -maxdepth 1 ${NAME} "${PATTERNMATCH}" -type "${OPERATION}" -mtime "${NOOFDAYS}" -user "${CURRENTUSER}" -print >> "${RESULTFILE}" 2>"${LOGFILE}"
            ;;
    esac

}

delete_files() {

    cat "${RESULTFILE}" | while read RESULT
    do
        rm -rfv "${RESULT}" >> "${LOGFILE}"
    done
}

CURRENTPATH=$(dirname $0)
LOGDIR=$(basename $0 | awk -F '.' '{print $1}')
#CURRENTUSER=$(id -un)
CURRENTUSER="fitadmin"
PARAMETERFILE="FILELIST.DAT"
PARAMETERFILEPATH="${CURRENTPATH}"/"${PARAMETERFILE}"
RESULTFILE="${CURRENTPATH}/resultfile.txt"
SUFFIX=$(date +%y%m%d%H%M%S)
LOGFILE="/tmp/${LOGDIR}/$(basename $0 | awk -F '.' '{print $1}').log.${SUFFIX}"

if [[ ! -r "${PARAMETERFILEPATH}" ]]
then
    echo
    echo "ERROR: FILELIST.DAT must exist in the script file directory: ${CURRENTPATH}"
    echo "Exiting.."
    echo
    exit 1
fi

if [[ "${#}" > 0 ]]
then
    if [[ "${1}" = '--dryrun' ]]
    then
        DRYRUN=1;
    else
        usage;        
    fi    
fi

if [[ -f "${RESULTFILE}" ]]
then
    rm -f "${RESULTFILE}"
    touch "${RESULTFILE}"
fi    

if [[ ! -d "/tmp/${LOGDIR}" ]]
then
    mkdir "/tmp/${LOGDIR}"
    chmod go+w "/tmp/${LOGDIR}"
fi

cat "${CURRENTPATH}"/"${PARAMETERFILE}" | while read SINGLELINE
do
    if [[ $(echo "${SINGLELINE}" | head -c1) = '#' ]]
    then
        continue
    else        
        OPERATION=$(echo "${SINGLELINE}" | awk -F ':' '{print $1}')
        NOOFDAYS=$(echo "${SINGLELINE}" | awk -F ':' '{print $2}')
        DELETEPATH=$(echo "${SINGLELINE}" | awk -F ':' '{print $3}')
        PATTERN=$(echo "${SINGLELINE}" | awk -F ':' '{print $4}')

        find_data "${OPERATION}" "${NOOFDAYS}" "${DELETEPATH}" "${PATTERN}"    
    fi        
done

if [[ "${DRYRUN}" -eq "1" ]]
then
    display
else
    delete_files    
fi       

exit 0
