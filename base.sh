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
  basicStuff
  okStuff
}


checkforenv(){
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
apt-get --yes --force-yes update
check_errs $? "Failed to apt-get update"

apt-get --yes --force-yes upgrade
check_errs $? "Failed to apt-get upgrade"

apt-get --yes --force-yes install debconf-doc
check_errs $? "Failed to apt-get debconf-doc"

apt-get --yes --force-yes install unattended-upgrades
check_errs $? "Failed to configure unattended-upgrades"

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

apt-get --yes --force-yes install fail2ban
check_errs $? "Failed to install fail2ban"

#ufw allow from {your-ip} to any port 22
#check_errs $? "Failed to configure ufw #1"

ufw allow 22
check_errs $? "Failed to configure ufw #1"

ufw allow 80
check_errs $? "Failed to configure ufw #2"

ufw allow 443
check_errs $? "Failed to configure ufw #3"

ufw allow 9252
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

basicStuff(){
if [ $UID -ne $ROOT_UID ]
then                                                                                                       
    echoRed "﴾͡๏̯͡๏﴿ O'RLY? Sorry You must be root to run this script... Quiting";
    exit $E_NOTROOT
else
    echoGreen "(ง ͠° ͟ل͜ ͡°)ง go go get em cowboy"
fi

useradd -u $USERNAME_UID --shell '/bin/bash' $USERNAME
check_errs $? "Failed create user $USERNAME"

echoGreen "$USERNAME with UID:$USERNAME_UID was successfully created!"

usermod -aG sudo $USERNAME
check_errs $? "Failed to add user $USERNAME to group sudo"

mkdir -p $USER_SSH_DIR
check_errs $? "Failed to create directory $USER_SSH_DIR"

chown $USERNAME:$USERNAME $USER_HOME
check_errs $? "Failed change ownership of $USER_HOME"

chmod 700 $USER_SSH_DIR
check_errs $? "Failed change permission on $USER_SSH_DIR"

echo $SSH_PUB_KEY1 > "$USER_SSH_DIR/authorized_keys"
check_errs $? "Failed to add public key to account $USER_SSH_DIR/authorized_keys"

chmod 700 "$USER_SSH_DIR/authorized_keys"
check_errs $? "Failed to modifiy permissions on $USER_SSH_DIR/authorized_keys"

chown -R $USERNAME:$USERNAME $USER_SSH_DIR
check_errs $? "Failed to modifiy permissions on $USER_SSH_DIR/authorized_keys"

echoGreen "SSH PUBLIC Key has been successfully added to USER:$USERNAME"

echo "$USERNAME	ALL = NOPASSWD: ALL" > $SUDOERS_DEPLOYFILE
check_errs $? "Failed to create sudoers file"

visudo -c -f $SUDOERS_DEPLOYFILE
check_errs $? "Validate suders file $SUDOERS_DEPLOYFILE" $SUDOERS_DEPLOYFILE

echoGreen "USER:$USERNAME has been successfully added to custom suders file"
echoGreen "Basic stuff done!!!!"


}

main "$@"
