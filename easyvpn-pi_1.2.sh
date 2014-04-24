#!/bin/bash
# - EASYOPENVPN.SH - Script to allow an easy installation of OpenVPN in raspberry-pi
# +-----------------------------+---------------------------------+----------------------+
# | Marcos Españadero González  |  ciberentropia.blogspot.com.es  |  mmsysmail@gmail.com |
# +-----------------------------+---------------------------------+----------------------+

#Check if the script is running as root
if [ "$UID" != "0" ]
  then
    echo "$0 must be run as root"
    exit 1
fi

#Install packets openvpn, openssl and zip
whiptail --yesno "Do you want to install OpenVPN, OpenSSL and zip?" 7 60
if [ "$?" == "0" ]
  then
    whiptail --infobox "Updating APT data base..." 10 40
    apt-get update > /dev/null 2>&1
    whiptail --infobox "Installing OpenVPN, OpenSSL and zip..." 10 50
    apt-get install -y openvpn openssl zip > /dev/null 2>&1
    whiptail --infobox "Installing OpenVPN, OpenSSL and zip...OK" 10 50
    sleep 2
  else
    clear
    exit 1
fi

#Copy easy-rsa example files and scripts
ER="/usr/share/doc/openvpn/examples/easy-rsa/2.0"
if [ -d $ER ]
  then
    cp -r $ER /etc/openvpn/easy-rsa
  else
    echo "Directory $ER not exist!"
    exit 1
fi

#Modify vars file of easy-rsa
sed -i 's/`pwd`/\/etc\/openvpn\/easy-rsa/g' /etc/openvpn/easy-rsa/vars

#Variable to define the directory path of easy-rsa
DER=/etc/openvpn/easy-rsa

#Run the file "vars" to load the variables.
whiptail --infobox "Loading vars..." 10 40
source $DER/vars > /dev/null 2>&1

#Erase any previous settings
whiptail --infobox "Clean KEY repository..." 10 40
bash $DER/clean-all > /dev/null 2>&1

#Create symbolic link to openssl
ln -s $DER/openssl-1.0.0.cnf $DER/openssl.cnf

#Create the CA certificate
whiptail --infobox "Creating initial CA..." 10 40
$DER/pkitool --initca > /dev/null 2>&1

#Create the server key
whiptail --infobox "Creating SERVER certificate..." 10 40
$DER/pkitool --server server > /dev/null 2>&1

#Create the client key
CLIENT_NAME=$(whiptail --inputbox "Client name:" 8 40 3>&1 1>&2 2>&3)
#The variable "KEY_CN" must be different in the creation of each user (including the server). 
#In the variable "KEY_CN" is assigned the user name. 
whiptail --infobox "Creating CLIENT certificate..." 10 40
KEY_CN=$CLIENT_NAME
$DER/pkitool $CLIENT_NAME > /dev/null 2>&1

#Create DIFFIE-HELLMAN
whiptail --infobox "Creating DIFFIE HELLMAN... (this may take awhile!)" 10 60
$DER/build-dh > /dev/null 2>&1

#The openvpn.conf file is created in the path: /etc/openvpn
echo "dev tun
proto udp
port 1194
ca /etc/openvpn/easy-rsa/keys/ca.crt
cert /etc/openvpn/easy-rsa/keys/server.crt
key /etc/openvpn/easy-rsa/keys/server.key
dh /etc/openvpn/easy-rsa/keys/dh1024.pem
user nobody
group nogroup
server 10.8.0.0 255.255.255.0
persist-key
persist-tun
status /var/log/openvpn-status.log
verb 3
client-to-client
push \""redirect-gateway def1\""
#set the dns servers
push \""dhcp-option DNS 8.8.8.8\""
push \""dhcp-option DNS 8.8.4.4\""
log-append /var/log/openvpn
comp-lzo" > /etc/openvpn/openvpn.conf

#Activate the IP_FORWARD for packet forwarding, editing 
#the file /etc/sysctl.conf
sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g' /etc/sysctl.conf

#Keep the current IP of ETH0 in a variable.
IP_ETH0=`ifconfig eth0 | grep "inet addr:" | awk '{ print $2 }' | awk -F: '{ print $2 }'`

#Define the iptables rules to run on every system start
IP_RPI=$(whiptail --inputbox "Raspberry IP: (Current IP: $IP_ETH0)" 8 50 3>&1 1>&2 2>&3)
if [ "$IP_RPI" == "" ]
  then
    IP_RPI=$IP_ETH0
fi
sed -i '$ i\iptables -t nat -A INPUT -i eth0 -p udp -m udp --dport 1194 -j ACCEPT' /etc/rc.local
sed -i "$ i\iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o eth0 -j SNAT --to-source $IP_RPI" /etc/rc.local

#Create a folder where the certificates are stored and copy them there credentials.
mkdir -p /etc/openvpn/clients
zip -j /etc/openvpn/clients/$CLIENT_NAME.zip /etc/openvpn/easy-rsa/keys/ca.crt /etc/openvpn/easy-rsa/keys/$CLIENT_NAME.crt /etc/openvpn/easy-rsa/keys/$CLIENT_NAME.key
whiptail --msgbox "Credentials stored in /etc/openvpn/clients" 8 46

function reboot_pi() {
#A reboot is required for all changes are updated. Asks if you want to restart.
whiptail --yesno "NEED REBOOT =========== Reboot now?" 10 17
if [ "$?" == "0" ]
  then
    reboot
  else
    whiptail --msgbox "OpenVPN will not work until you restart" 8 44
    exit 1
fi
}

#Send certificates by mail
function send_mail() {
         #Get gmail credentials and destination email
         GMAIL_USR=$(whiptail --inputbox "Gmail user (user@gmail.com): " 8 46 3>&1 1>&2 2>&3)
         GMAIL_PWD=$(whiptail --passwordbox "Gmail password: " 8 46 3>&1 1>&2 2>&3)
         GMAIL_DST=$(whiptail --inputbox "Send to: " 8 46 3>&1 1>&2 2>&3)
         whiptail --infobox "Send mail from $GMAIL_USR to "$GMAIL_DST"..." 10 80
         sendemail -f $GMAIL_USR -t $GMAIL_DST -s smtp.gmail.com:587 -u "OpenVPN Certs and key ($CLIENT_NAME)" -m "Mail sent by easyopenvpn" -a /etc/openvpn/clients/$CLIENT_NAME.zip -xu $GMAIL_USR -xp $GMAIL_PWD -o tls=yes > /dev/null 2>&1
         if [ "$?" == "0" ]
           then
             whiptail --infobox "Send mail from $GMAIL_USR to "$GMAIL_DST"...OK" 10 80
             sleep 3
           else
             whiptail --yesno " Send mail from $GMAIL_USR to "$GMAIL_DST"...FAIL\n\nWant to retry sending?" 10 80
               if [ "$?" == "0" ]
                 then
                   send_mail
               fi
         fi
}

#asks if you want to send.
whiptail --yesno "Want to send the certificate by mail?" 8 42
if [ "$?" == "0" ]
  then
    #Check if sendemail is installed
    if [ "`which sendemail`" == "" ]
      then
        #Asks if you want to install 'sendemail' and its dependencies.
        whiptail --yesno "Install sendemail and its dependencies?\n\nPackets to be installed:\n\n * sendemail\n * libio-socket-ssl-perl\n * libnet-ssleay-perl" 15 46
          if [ "$?" == "0" ]
            then
              whiptail --infobox "Installing sendemail..." 10 30
              apt-get -y install sendemail libio-socket-ssl-perl libnet-ssleay-perl > /dev/null 2>&1
              #Fix sendemail bug in SSL/TLS email
              sed -i 's/SSLv3 TLSv1/SSLv3/g' /usr/bin/sendemail
              whiptail --infobox "Installing sendemail...OK" 10 30
              sleep 2
              send_mail
          fi
    else
         send_mail
    fi
  else
    exit 1
fi

#Asks for reboot
reboot_pi
