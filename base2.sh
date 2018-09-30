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

echo "$UPGRADE_ATTEMPT_COUNT"
echo "dsaldasldadasdasdasdasdasdasdasdasdasdassadsadasdadwqerwqrqwrfsfdsfsdfsfsfdssf"

    if [ "$UPGRADE_STATE" -eq "1" ]; then
        apt-get --yes --force-yes update
        if [ "`echo $?`" -eq "0" ]; then
            echo "package list updated."
            UPGRADE_STATE=2;
        fi
    fi

    if [ "$UPGRADE_STATE" -eq "2" ]; then
       apt-get --yes --force-yes upgrade
        if [ "`echo $?`" -eq "0" ]; then
            echo "packages upgraded."
            UPGRADE_STATE=3;
        fi
    fi
    
    if [ "$UPGRADE_STATE" -eq "3" ]; then
       apt-get --yes --force-yes install debconf-doc
        if [ "`echo $?`" -eq "0" ]; then
            echo "debconf-doc installed."
            UPGRADE_STATE=4;
        fi
    fi
    
    if [ "$UPGRADE_STATE" -eq "4" ]; then
       apt-get --yes --force-yes install unattended-upgrades
        if [ "`echo $?`" -eq "0" ]; then
            echo "unattended upgrades installed."
            UPGRADE_STATE=5;
        fi
    fi
    
    if [ "$UPGRADE_STATE" -eq "5" ]; then
      apt-get --yes --force-yes install fail2ban
        if [ "`echo $?`" -eq "0" ]; then
            echo "fail2ban installed."
            UPGRADE_STATE=6;
        fi
    fi
    
    if [ "$UPGRADE_STATE" -eq "6" ]; then
        break
    fi

    sleep 5
done

if [ "$UPGRADE_STATE" -ne "6" ]; then
    echo "ERROR: packages failed to update after $UPGRADE_ATTEMPT_COUNT attempts."
fi


truncate -s 0 /etc/apt/apt.conf.d/10periodic
check_errs $? "Failed to truncate 10periodic"

echo 'APT::Periodic::Update-Package-Lists "1";' >  /etc/apt/apt.conf.d/10periodic
echo 'APT::Periodic::Download-Upgradeable-Packages "1";' >>  /etc/apt/apt.conf.d/10periodic
echo 'APT::Periodic::AutocleanInterval "7";' >>  /etc/apt/apt.conf.d/10periodic
echo 'APT::Periodic::Unattended-Upgrade "1";' >>  /etc/apt/apt.conf.d/10periodic

echo '// Automatically upgrade packages from these (origin, archive) pairs' >>  /etc/apt/apt.conf.d/50unattended-upgrades
echo 'Unattended-Upgrade::Allowed-Origins {    ' >>  /etc/apt/apt.conf.d/50unattended-upgrades
echo '    // ${distro_id} and ${distro_codename} will be automatically expanded' >>  /etc/apt/apt.conf.d/50unattended-upgrades
echo '    "${distro_id} stable";' >>  /etc/apt/apt.conf.d/50unattended-upgrades
echo '    "${distro_id} ${distro_codename}-security";' >>  /etc/apt/apt.conf.d/50unattended-upgrades
echo '    "${distro_id} ${distro_codename}-updates";' >>  /etc/apt/apt.conf.d/50unattended-upgrades
echo '//  "${distro_id} ${distro_codename}-proposed-updates";' >>  /etc/apt/apt.conf.d/50unattended-upgrades
echo '};' >>  /etc/apt/apt.conf.d/50unattended-upgrades


ufw allow 22
check_errs $? "Failed to configure ufw #1"

ufw allow 80
check_errs $? "Failed to configure ufw #2"

ufw allow 443
check_errs $? "Failed to configure ufw #3"

ufw allow 4444
check_errs $? "Failed to configure ufw #4"

ufw enable
check_errs $? "Failed to configure ufw #5"

# Secure Node 
sed -i '/^PermitRootLogin/s/yes/prohibit-password/' /etc/ssh/sshd_config
check_errs $? "Failed to config sshd config #1"

sed -i "s/.*RSAAuthentication.*/RSAAuthentication yes/g" /etc/ssh/sshd_config
check_errs $? "Failed to config sshd config #2"

sed -i "s/.*PubkeyAuthentication.*/PubkeyAuthentication yes/g" /etc/ssh/sshd_config
check_errs $? "Failed to config sshd config #3"

sed -i "s/.*PasswordAuthentication.*/PasswordAuthentication no/g" /etc/ssh/sshd_config
check_errs $? "Failed to config sshd config #4"

sed -i "s/.*AuthorizedKeysFile.*/AuthorizedKeysFile\t\.ssh\/authorized_keys/g" /etc/ssh/sshd_config
check_errs $? "Failed to config sshd config #5"

sed -i "s/.*PermitRootLogin.*/PermitRootLogin no/g" /etc/ssh/sshd_config
check_errs $? "Failed to config sshd config #6"

sshd -t
check_errs $? "Failed sshd config is not valid"

service sshd restart
check_errs $? "Failed to restart sshd"
sendErrorMail "Basic Server Done::VULTR" "Success!!!" "Game Server"
}

main "$@"
