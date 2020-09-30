#!/bin/bash
# Author: cham423

# Global Variables
runuser=$(whoami)
tempdir=$(pwd)
certpath=""

# check for root privs, before getting started 
if [ $(id -u) -ne '0' ]; then
echo
echo ' [ERROR]: This Setup Script Requires root privileges!'
echo ' Please run this setup script again with sudo or run as login as root.'
echo
exit 1
fi

# read args
while [ "$1" != "" ]; do
    case $1 in
         -c | --cert-path)           shift
                                certpath="$1"
                                ;;
    esac
    shift
done
# validate certpath
if [ "$certpath" != "" ]; then
  echo "YOU FOUND A CERT! GOOD JOB"
  echo "the cert you gave was: $certpath"
  if [[ ! -d $certpath ]]; then
    echo "  [ERROR]: provided certpath was not a directory, exiting."
    echo "  provide the path to the directory with the fullchain.pem file in it, not the file itself." 
    exit 1
  fi
  echo
fi

# check if ubuntu 18.04 or ubuntu 20 
func_check_os(){
  if [ $(lsb_release -rs) == '20.04' ]; then
    ubuntu=20
  elif [ $(lsb_release -rs) == '18.04']; then
    ubuntu=18
  else
    echo
    echo ' [WARNING]: Unsupported OS! you are not running ubuntu 18 or 20.'
    echo ' this script may behave weirdly.'
    echo
  fi
}
# install java first
func_prereqs(){
echo '[Starting] Installing Java'
apt-get update && apt-get -y install openjdk-11-jdk
}
func_read_vars(){
echo -n "Enter your DNS (A) record for domain [ENTER]: "
read domain
echo

echo -n "Enter your common password to be used [ENTER]: "
read password
echo

echo -n "Enter your CobaltStrike server location (go copy/update it over now if you didn't already) [ENTER]: "
read cobaltStrike
echo

domainPkcs="$domain.p12"
domainStore="$domain.store"
cobaltStrikeProfilePath="$cobaltStrike/httpsProfile"
}



func_check_tools(){
  # Check for keytool 
  if [ $(which keytool) ]; then
    echo '[Sweet] java keytool is installed'
  else 
    echo
    echo ' [ERROR]: keytool does not seem to be installed'
    echo
    exit 1
  fi
  if [ $(which openssl) ]; then
    echo '[Sweet] openssl keytool is installed'
  else 
    echo
    echo ' [ERROR]: openssl does not seem to be installed'
    echo
    exit 1
  fi
  if [ $(which git) ]; then
    echo '[Sweet] git keytool is installed'
  else 
    echo
    echo ' [ERROR]: git does not seem to be installed'
    echo
    exit 1
   fi
}

func_apache_check(){
  # Check Sudo Dependency going to need that!

  # if [ sudo lsof -nPi | grep ":80 (LISTEN)" ]; then
  #   echo
  #   echo ' [ERROR]: This Setup Script Requires that port!'
  #   echo '          80 not be in use.'
  #   echo
  #   exit 1
  if [ $(which java) ]; then
    echo '[Sweet] java is already installed'
    echo
  else
    apt-get update
    apt-get install default-jre -y 
    echo '[Success] java is now installed'
    echo
  fi
  if [ $(which apache2) ]; then
    echo '[Sweet] Apache2 is already installed'
    service apache2 start
    echo
  else
    apt-get update
    apt-get install apache2 -y 
    echo '[Success] Apache2 is now installed'
    echo
    service apache2 restart
    service apache2 start
  fi
  if [ $(lsof -nPi | grep -i apache | grep -c ":80 (LISTEN)") -ge 1 ]; then
    echo '[Success] Apache2 is up and running!'
  else 
    echo
    echo ' [ERROR]: Apache2 does not seem to be running on'
    echo '          port 80? Try manual start?'
    echo
    exit 1
  fi
  if [ $(which ufw) ]; then
    echo 'Looks like UFW is installed, opening ports 80 and 443'
    ufw allow 80/tcp
    ufw allow 443/tcp
    echo
  fi
}

func_install_letsencrypt(){
  echo '[Starting] cloning into letsencrypt!'
  git clone https://github.com/cham423/certbot /opt/letsencrypt
  echo '[Success] letsencrypt is built!'
  cd /opt/letsencrypt
  echo '[Starting] to build letsencrypt cert!'
  ./letsencrypt-auto --apache -d $domain -n --register-unsafely-without-email --agree-tos 
  if [ -e /etc/letsencrypt/live/$domain/fullchain.pem ]; then
    echo '[Success] letsencrypt certs are built!'
  else
    echo "[ERROR] letsencrypt certs failed to build.  Check that DNS A record is properly configured for this domain"
    exit 1
  fi
}

func_install_certbot(){
  echo '[Starting] updating snapd'
  snap install core; snap refresh core
  echo '[Success] snapd is good to go'
  echo '[Starting] installing certbot'
  snap install --classic certbot
  ln -s /snap/bin/certbot /usr/bin/certbot
  echo '[Success] certbot is good to go'
  echo '[Starting] to build letsencrypt cert!'
  certbot --apache -d $domain -n --register-unsafely-without-email --agree-tos --apache-handle-modules false --apache-handle-sites false 
  if [ -e /etc/letsencrypt/live/$domain/fullchain.pem ]; then
    echo '[Success] letsencrypt certs are built!'
  else
    echo "[ERROR] I didn't find a built certificate file."
    echo "  potential causes:Check that DNS A record is properly configured for this domain"
    echo
    echo "  you can go hunt for the certificate file in this directory:"
    echo "  /etc/letsencrypt/live/<your_domain>/fullchain.pem"
    echo
    echo "  if you find it, specify the directory in the --cert-path option when running this script and run again."
    exit 1
  fi
}

func_build_pkcs(){
  cd /etc/letsencrypt/live/$domain
  echo "[Starting] Building PKCS12 .p12 cert."
  openssl pkcs12 -export -in fullchain.pem -inkey privkey.pem -out $domainPkcs -name $domain -passout pass:$password
  echo "[Success] Built $domainPkcs PKCS12 cert."
  echo "[Starting] Building Java keystore via keytool."
  keytool -importkeystore -deststorepass $password -destkeypass $password -destkeystore $domainStore -srckeystore $domainPkcs -srcstoretype PKCS12 -srcstorepass $password -alias $domain
  echo "[Success] Java keystore $domainStore built."
  mkdir $cobaltStrikeProfilePath
  cp $domainStore $cobaltStrikeProfilePath
  echo '[Success] Moved Java keystore to CS profile Folder.'
}

func_build_path(){
  echo "[Starting] Building PKCS12 .p12 cert from specified path"
  openssl pkcs12 -export -in $certpath/fullchain.pem -inkey $certpath/privkey.pem -out $certpath/$domainPkcs -name $domain -passout pass:$password
  echo "[Success] Built $domainPkcs PKCS12 cert."
  echo "[Starting] Building Java keystore via keytool."
  keytool -importkeystore -deststorepass $password -destkeypass $password -destkeystore $certpath/$domainStore -srckeystore $certpath/$domainPkcs -srcstoretype PKCS12 -srcstorepass $password -alias $domain
  echo "[Success] Java keystore $domainStore built."
  mkdir $cobaltStrikeProfilePath
  cp $certpath/$domainStore $cobaltStrikeProfilePath
  echo "[Success] Moved Java keystore to CS profile Folder."
}

func_build_c2(){
  cd $cobaltStrikeProfilePath
  echo "todo - clone sourcepoint, automate profile creation "
  echo "keystore name (append to profile) \"$domainStore\"\""
  echo "keystore password (append to profile) \"$password\"\""
}
# Main section where all the stuff happens
func_check_os
func_prereqs
func_read_vars
func_check_tools
func_apache_check
#func_install_letsencrypt
if [ "$certpath" == "" ]; then
func_install_certbot
func_build_pkcs
else
func_build_path
fi
func_build_c2
