#!/bin/bash


# Script to check syntactical/ indentation errors in the code and
# update the version in metadata.rb file for pushing the code in repository


# Below code to check the delivery local errors

REPO_DIR='/home/rkeshar4/SourceCode/cookbooks/gemfire/_scm/itx_ame_gemfire'
cd $REPO_DIR

delivery local lint
if [[ ${?} -ne 0 ]]
then
  echo "ERROR: Please fix the errors detected"
  exit 1
fi

delivery local syntax
if [[ ${?} -ne 0 ]]
then
  echo "ERROR: Please fix the errors detected"
  exit 1
fi

# Below code to update the version in metadata.rb file

echo "Update the version of metadata.rb file?"
read -p "(Y)es to Proceed OR (N)o to Quit : " ANSWER
echo $ANSWER
if [[ "${ANSWER}" != "Y" ]]
then
  echo "Exiting..."
  exit 1
fi 

METADATA='/home/rkeshar4/SourceCode/cookbooks/gemfire/_scm/itx_ame_gemfire/metadata.rb'

if [[ ! -f $METADATA ]]
then
  echo "ERROR: $METADATA file is not located" 
  exit 1
fi

VERSION=$(grep -w 'version' $METADATA | awk '{print $NF}' | awk -F "'" '{print $2}')
echo "Existing version in metadata.rb file : $VERSION"

MAJORVERSION=$(echo $VERSION | awk -F "." '{print $1}')
MINORVERSION=$(echo $VERSION | awk -F "." '{print $2}')
SUBERVERSION=$(echo $VERSION | awk -F "." '{print $3}')
if [[ "${SUBERVERSION}" -eq "99" ]]
then
  SUBERVERSION="0"
  MINORVERSION=$((MINORVERSION+1))
else
  SUBERVERSION=$((SUBERVERSION+1))
fi

NEWVERSION="$MAJORVERSION.$MINORVERSION.$SUBERVERSION"

echo "Updating version in metadata.rb file : $NEWVERSION"
sed -i s/$VERSION/$NEWVERSION/ $METADATA

grep -w $NEWVERSION $METADATA > /dev/null 2>&1
if [[ "${?}" -eq 0 ]]
then
  echo "Updated version in metadata.rb file : $NEWVERSION"
fi

# Below code is for checking in the code in Bitbucket
echo
git status
echo

echo "Proceed to Check-in the code Bitbucket?"
read -p "(Y)es to Proceed OR (N)o to Quit : " ANSWER
echo $ANSWER
if [[ "${ANSWER}" != "Y" ]]
then
  echo "Exiting..."
  exit 1
fi 

read -p "Provide a local branch name (e.g. feature/spark-install) : " LOCALBRANCH
echo $LOCALBRANCH

git branch $LOCALBRANCH
git checkout $LOCALBRANCH

git status

echo "Proceed to add all files (git add .)?"
read -p "(Y)es to Proceed OR (N)o to Quit : " ANSWER
echo $ANSWER
if [[ "${ANSWER}" != "Y" ]]
then
  echo "Exiting..."
  exit 1
fi 

git add -A .

read -p "Provide a message to commit : " COMMITMESSAGE
echo $COMMITMESSAGE

git commit -m "$COMMITMESSAGE"

echo "Proceed to push the files in Bitbucket ?"
read -p "(Y)es to Proceed OR (N)o to Quit : " ANSWER
echo $ANSWER
if [[ "${ANSWER}" != "Y" ]]
then
  echo "Exiting..."
  exit 1
fi 

git push origin $LOCALBRANCH

exit 0



