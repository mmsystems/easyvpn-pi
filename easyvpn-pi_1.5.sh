#!/bin/bash
# - EASYOPENVPN.SH - Script to allow an easy installation of OpenVPN in raspberry-pi
# +-----------------------------+---------------------------------+----------------------+
# | Marcos Españadero González  |  ciberentropia.blogspot.com.es  |  mmsysmail@gmail.com |
# +-----------------------------+---------------------------------+----------------------+
# | Juan Alonso Sanz            |  blog.juanalo.com               |  juanalo@gmail.com   |
# +-----------------------------+---------------------------------+----------------------+

#Script variables
ER="/usr/share/doc/openvpn/examples/easy-rsa/2.0"
#Directory of openvpn
OVPN_DIR="/etc/openvpn"
#Directory path of easy-rsa
DER="$OVPN_DIR/easy-rsa"
#Key directory
KEY_DIR="$DER/keys"
#All clients output dir
OUT_DIR="/etc/openvpn/clients"
#Current client dir
CLIENT_DIR=""
#Current client name
CLIENT_NAME=""
#Protocol to use
PROTO="udp"
#Port to listen
PORT="1194"
#Port query to user
USER_PORT=""
#External port
EXT_PORT=""
#Ip of eth0
IP_ETH0=""
#Ip to use
IP_RPI=""
#External DNS or IP
EXT_DNS=""
#Indicates wether to reboot or not
REBOOT="0"
#Indicate wether to restart service
RESTART="0"


#Script functions declaration

#A reboot is required for all changes are updated. Asks if you want to restart.
function reboot_pi() {
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
   echo "Send mail from $GMAIL_USR to $GMAIL_DST..."
   whiptail --infobox "Send mail from $GMAIL_USR to $GMAIL_DST..." 10 80
   sendemail -f $GMAIL_USR -t $GMAIL_DST -s smtp.gmail.com:587 -u "OpenVPN Certs and key ($CLIENT_NAME)" -m "Mail sent by easyopenvpn" -a $CLIENT_DIR/$CLIENT_NAME.zip -xu $GMAIL_USR -xp $GMAIL_PWD -o tls=yes > /dev/null 2>&1
   if [ "$?" == "0" ]
     then
	   echo "Send mail from $GMAIL_USR to "$GMAIL_DST"...OK"
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
#Create openvpn.conf file in the path: /etc/openvpn
function server_conf(){
   echo "dev tun
   proto $PROTO
   port 1194
   ca $KEY_DIR/ca.crt
   cert $KEY_DIR/server.crt
   key $KEY_DIR/server.key
   dh $KEY_DIR/dh1024.pem
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
}

#Creates ovpn file for iOS client devices
function ovpn_ios(){
   local OVPN=$CLIENT_DIR/$CLIENT_NAME.ios.ovpn
   local CA="$KEY_DIR/ca.crt"
   local CERT="$KEY_DIR/$CLIENT_NAME.crt"
   local KEY="$KEY_DIR/$CLIENT_NAME.key"

   echo "# Enables connection to GUI
   management /data/data/de.blinkt.openvpn/cache/mgmtsocket unix
   management-client
   management-query-passwords
   management-hold

   setenv IV_GUI_VER "de.blinkt.openvpn 0.6.9a"
   machine-readable-output
   client
   verb 4
   connect-retry-max 5
   connect-retry 5
   resolv-retry 60
   dev tun
   remote $EXT_DNS 1194 UDP
   <ca>" > $OVPN
   awk /BEGIN/,/END/ < $CA  >> $OVPN
   echo "</ca>
   <key>" >> $ovpn
   awk /BEGIN/,/END/ < $KEY >> $OVPN
   echo "</key>
   <cert>" >> $OVPN
   awk /BEGIN/,/END/ < $CERT >> $OVPN
   echo "</cert>
   comp-lzo
   route-ipv6 ::/0
   route 0.0.0.0 0.0.0.0 vpn_gateway
   remote-cert-tls server
   # Use system proxy setting
   management-query-proxy" >> $OVPN
}
#Creates ovpn files for clients
function ovpn_files(){
   local OVPN=$CLIENT_DIR/$CLIENT_NAME.ovpn
   local CA="$KEY_DIR/ca.crt"
   local CERT="$KEY_DIR/$CLIENT_NAME.crt"
   local KEY="$KEY_DIR/$CLIENT_NAME.key"

   echo "#Client file
   client
   dev tun
   proto $PROTO
   remote $EXT_DNS 1194 UDP
   resolv-retry infinite
   nobind
   persist-key
   persist-tun
   ns-cert-type server
   comp-lzo
   verb 3
   <ca>" > $OVPN
   awk /BEGIN/,/END/ < $CA  >> $OVPN
   echo "</ca>
   <key>" >> $OVPN
   awk /BEGIN/,/END/ < $key >> $OVPN
   echo "</key>
   <cert>" >> $OVPN
   awk /BEGIN/,/END/ < $CERT >> $OVPN
   echo "</cert>" >> $OVPN
}

#Check installed packets and install necesaries
function check_packets(){
   local packets=""

   if ! type openvpn >/dev/null 2>&1
     then
       packets="openvpn"
	   echo "OpenVPN is going to install"
   fi
   if ! type openssl >/dev/null 2>&1
     then
       packets="$packets openssl"
	   echo "Openssl is going to install"
   fi
   if ! type zip >/dev/null 2>&1
     then
       packets="$packets zip"
	   echo "Zip is going to install"
   fi
   if [ "$packets" != "" ]
     then
       echo "Updating APT data base..."
       whiptail --infobox "Updating APT data base..." 10 40
       apt-get update > /dev/null 2>&1
	   echo "Installing necesary packets..."
	   whiptail --infobox "Installing necesary packets..." 10 50
       apt-get install -y $packets > /dev/null 2>&1
	   REBOOT=1
   fi
}

#Generates ca certificate
function ca_cert(){
  local gen_ca="0"
  if [ "$REBOOT" == "0" ]
    then
      whiptail --yesno "Want to generate CA certificate?" 8 42
      if [ "$?" == "0" ]
        then
		  gen_ca="1"
      fi
    else
	  gen_ca="1"
  fi
  if [ "$gen_ca" == "1" ]
    then
      echo "Creating initial CA..."
      whiptail --infobox "Creating initial CA..." 10 40
      $DER/pkitool --initca > /dev/null 2>&1
	  RESTART="1"
  fi
}

#Generates server certificates
function server_cert(){
  local gen_crt="0"
  if [ "$REBOOT" == "0" ]
    then
      whiptail --yesno "Want to generate SERVER certificate?" 8 42
      if [ "$?" == "0" ]
        then
		  gen_crt="1"
      fi
    else
	  gen_crt="1"
  fi
  if [ "$gen_crt" == "1" ]
    then
      echo "Creating SERVER certificate..."
      whiptail --infobox "Creating SERVER certificate..." 10 40
      $DER/pkitool --server server > /dev/null 2>&1
      RESTART="1"
  fi
}

#Generates client certificates
#The variable "KEY_CN" must be different in the creation of each user (including the server).
#In the variable "KEY_CN" is assigned the user name.
function client_cert(){
   #TODO: ask wether to generate this certificate
   CLIENT_NAME=$(whiptail --inputbox "Client name:" 8 40 3>&1 1>&2 2>&3)
   echo "Creating CLIENT certificate..."
   whiptail --infobox "Creating CLIENT certificate..." 10 40
   KEY_CN=$CLIENT_NAME
   $DER/pkitool $CLIENT_NAME > /dev/null 2>&1

   #Create DIFFIE-HELLMAN
   echo "Creating DIFFIE HELLMAN... (this may take a while!)"
   whiptail --infobox "Creating DIFFIE HELLMAN... (this may take a while!)" 10 60
   $DER/build-dh > /dev/null 2>&1
}

#Main script starts here

#Check if the script is running as root
if [ "$UID" != "0" ]
  then
    echo "$0 must be run as root"
    exit 1
fi

#Check wether to install packets openvpn, openssl and zip
check_packets

#Copy easy-rsa example files and scripts
if [ -d $ER ]
  then
    cp -r $ER $DER
  else
    echo -e  "\n\nERROR: Directory $ER not exist!"
    exit 1
fi

#Modify vars file of easy-rsa
sed -i 's/`pwd`/\/etc\/openvpn\/easy-rsa/g' $DER/vars

#Run the file "vars" to load the variables.
echo "Loading vars..."
whiptail --infobox "Loading vars..." 10 40
source $DER/vars > /dev/null 2>&1

#Erase any previous settings
#TODO: check wether is necesary to clean key repository
echo "Clean KEY repository..."
whiptail --infobox "Clean KEY repository..." 10 40
bash $DER/clean-all > /dev/null 2>&1

#Create symbolic link to openssl
if [ ! -f $DER/openssl.cnf ]
then
   ln -s $DER/openssl-1.0.0.cnf $DER/openssl.cnf
fi

#Keep the current IP of ETH0 in a variable.
IP_ETH0=`ifconfig eth0 | grep "inet addr:" | awk '{ print $2 }' | awk -F: '{ print $2 }'`

#Ask de user for de server IP to use
IP_RPI=$(whiptail --inputbox "Raspberry IP: (Current IP: $IP_ETH0)" 8 50 3>&1 1>&2 2>&3)
if [ "$IP_RPI" == "" ]
  then
    IP_RPI=$IP_ETH0
fi

#Ask for server port
#USER_PORT=$(whiptail --inputbox "Port to listen: (Default port: $PORT)" 8 50 3>&1 1>&2 2>&3)
#if [ "$USER_PORT" != "" ]
#  then
#    PORT=$USER_PORT
#fi

#Ask for external DNS or IP for client use
EXT_DNS=$(whiptail --inputbox "External IP or Dynamic DNS" 8 50 3>&1 1>&2 2>&3)

#Ask for external Port for client use
#EXT_PORT=$(whiptail --inputbox "External Port (Default $PORT)" 8 50 3>&1 1>&2 2>&3)
#if [ "$EXT_PORT" == "" ]
#  then
#    EXT_PORT=$PORT
#fi

#Create the CA certificate if installing packages or user wants
ca_cert

#Create the server key if installing packages or user wants
server_cert

#Create the client key
client_cert

#Activate the IP_FORWARD for packet forwarding, editing
#the file /etc/sysctl.conf
sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g' /etc/sysctl.conf

#Define the iptables rules to run on every system start
#Chek if the iptables rules are already created in rc.local
if [ "$(cat /etc/rc.local | grep "iptables -t nat -A INPUT -i eth0 -p udp -m udp --dport 1194 -j ACCEPT")" == "" ]
  then
    sed -i '$ i\iptables -t nat -A INPUT -i eth0 -p udp -m udp --dport 1194 -j ACCEPT' /etc/rc.local
fi
if [ "$(cat /etc/rc.local | grep "iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o eth0 -j SNAT --to-source $IP_RPI")" == "" ]
  then
    sed -i "$ i\iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o eth0 -j SNAT --to-source $IP_RPI" /etc/rc.local
fi

#Create a folder where the certificates are stored and copy them there credentials.
CLIENT_DIR="$OUT_DIR/$CLIENT_NAME"
mkdir -p $CLIENT_DIR

#Create ovpn client files
ovpn_ios
ovpn_files

#zip files
zip -j $CLIENT_DIR/$CLIENT_NAME.zip $KEY_DIR/ca.crt $KEY_DIR/$CLIENT_NAME.crt $KEY_DIR/$CLIENT_NAME.key $CLIENT_DIR/$CLIENT_NAME.ovpn $CLIENT_DIR/$CLIENT_NAME.ios.ovpn
whiptail --msgbox "Credentials stored in $CLIENT_DIR" 8 46

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
              echo "Installing sendemail..."
              whiptail --infobox "Installing sendemail..." 10 30
              apt-get -y install sendemail libio-socket-ssl-perl libnet-ssleay-perl > /dev/null 2>&1
              #Fix sendemail bug in SSL/TLS email
              sed -i 's/SSLv3 TLSv1/SSLv3/g' /usr/bin/sendemail
              sleep 2
              send_mail
          fi
    else
         send_mail
    fi
fi

#Asks for reboot
if [ "$REBOOT" == "1" ]
  then
    server_conf
    reboot_pi
  else
    if [ "$RESTART" == "1" ]
	  then
	    echo "Restarting openvpn..."
	    whiptail --msgbox "Restarting openvpn..." 8 46
		server_conf
	    /etc/init.d/openvpn restart
    fi
fi
