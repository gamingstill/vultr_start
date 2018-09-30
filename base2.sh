#!/bin/bash

tabs 4
clear

ROOT_UID=0
E_NOTROOT=1
HOMEDIR=/home

#server exports
USERNAME=${USERNAME}
USERNAME_UID=${USERNAME_UID:-1979}
SSH_PUB_KEY1=${SSH_PUB_KEY1}

#Mail gun exports
MAIL_GUN_DOMAIN='kark.io'
MAIL_GUN_KEY=${MAIL_GUN_KEY}
MAIL_TO_EMAIL=${MAIL_TO_EMAIL}
MAIL_FROM_EMAIL=${MAIL_FROM_EMAIL}
# set some stuff!!!
SUDOERS_DEPLOYFILE="/etc/sudoers.d/automate-tinygame"
SSHDIR=".ssh"
USER_SSH_DIR="$HOMEDIR/$USERNAME/$SSHDIR"
USER_HOME="$HOMEDIR/$USERNAME"
RELEASE=$(lsb_release -c | cut -f 2 -d $'\t')
DISTRO=$(lsb_release -i | cut -f 2 -d $'\t')


main()
{
  checkForEnv
  okStuff
}

checkForEnv(){
# if the enviorment variable are not set properly just quit and send an email!!
for var in SSH_PUB_KEY1 USERNAME MAIL_TO_EMAIL MAIL_FROM_EMAIL MAIL_GUN_KEY MAIL_GUN_DOMAIN; do
eval 'val=$'"$var"
if [ -z "$val" ]; then
sendErrorMail "FAILED TO CREATE SERVER::VULTR" "SCRIPT FAILED EXECUTION - export variable missing" "FailServer"
exit 1
fi
done
}


sendErrorMail()
{
curl -s --user "api:${MAIL_GUN_KEY}" \
https://api.mailgun.net/v3/"${MAIL_GUN_DOMAIN}"/messages \
-F from="$3 <${MAIL_FROM_EMAIL}>" \
-F to="${MAIL_TO_EMAIL}" \
-F subject="$1" \
-F text="$2"
}


echoRed() {
  echo -e "\E[1;31m$1"
  echo -e '\e[0m'
  sendErrorMail "FAILED TO CREATE SERVER::VULTR" "Something went wrong!!" "Fail Server"
}

echoGreen() {
  echo -e "\E[1;32m$1"
  echo -e '\e[0m'
}

echoCyan() {
  echo -e "\E[1;36m$1"
  echo -e '\e[0m'
}

echoMagenta() {
  echo -e "\E[1;35m$1"
  echo -e '\e[0m'
}

check_errs()
{
  # Function. Parameter 1 is the return code
  # Para. 2 is text to display on failure.
      if [ "${1}" -ne "0" ]; then
        echoRed "ERROR # ${1} : ${2}"
        # as a bonus, make our script exit with the right error code.
        if [ "$#" -eq 3 ]; then
          echoCyan "cleaning file from failed script attempt "
          rm -f ${3}
          check_errs $? "Failed to remove file - ${3}"
        fi

        exit ${1}
      fi
}

okStuff()
{
local UPGRADE_ATTEMPT_COUNT=100
local UPGRADE_STATE=1
for i in `seq 1 $UPGRADE_ATTEMPT_COUNT`;
do
    if [ "$UPGRADE_STATE" -eq "1" ]; then
        apt-get -y update
        if [ "`echo $?`" -eq "0" ]; then
            echo "package list updated."
            UPGRADE_STATE=2;
        fi
    fi

    if [ "$UPGRADE_STATE" -eq "2" ]; then
        apt-get -y upgrade
        if [ "`echo $?`" -eq "0" ]; then
            echo "packages updated."
            UPGRADE_STATE=3;
        fi
    fi

    if [ "$UPGRADE_STATE" -eq "3" ]; then
        break
    fi

    sleep 5
done

if [ "$UPGRADE_STATE" -ne "3" ]; then
    echo "ERROR: packages failed to update after $UPGRADE_ATTEMPT_COUNT attempts."
fi
}

main "$@"
