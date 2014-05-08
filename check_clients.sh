#!/bin/bash

#Function to view the connected users in openvpn-status.log
function view_usr() {
CON_CLI="`cat /var/log/openvpn-status.log | awk -F, '/10.8.0/ { print $2,"\t",$3,"\t",$1 }'`"
if [ "$CON_CLI" == "" ]
   then
      whiptail --msgbox "NO CLIENTS CONECTED" 8 24
   else
      whiptail --msgbox "$CON_CLI" 8 80
fi
}

#Function to list created users
function list_usr(){
LIST_CLI="`ls /etc/openvpn/easy-rsa/keys/* | grep ".csr" | grep -Fv "server.csr" | awk -F. '{ print $1 }' | awk -F/ '{ print $6 }'`"
#Calculate the number of client lines
NUM_LIN=`echo "$LIST_CLI" | wc -l`
let NUM_TOT=$NUM_LIN+6
if [ "$LIST_CLI" == "" ]
   then
      whiptail --msgbox "NO CLIENTS CREATED YET" 8 24
   else
      whiptail --msgbox "$LIST_CLI" $NUM_TOT 24
fi
manage_usr
}

#Function to create a new user
function crea_usr(){
#Read the client name
CLIENT_NAME=$(whiptail --inputbox "Client name:" 8 40 3>&1 1>&2 2>&3)
#The variable "KEY_CN" must be different in the creation of each user (including the server).
#In the variable "KEY_CN" is assigned the user name.
#Check if the client already exist
for i in [ `ls /etc/openvpn/easy-rsa/keys/* | grep ".csr" | grep -Fv "server.csr" | awk -F. '{ print $1 }' | awk -F/ '{ print $6 }'` ]
   do
      if [ "$i" == "$CLIENT_NAME" ]
         then
            whiptail --msgbox "ERROR - The client already exist" 8 36
            manage_usr
      fi
done
#User creation process
echo -e "Creating CLIENT certificate..."
#Run the file "vars" to load the variables.
source /etc/openvpn/easy-rsa/vars > /dev/null 2>&1
whiptail --infobox "Creating CLIENT certificate..." 10 40
KEY_CN=$CLIENT_NAME
echo "$KEY_CN"
/etc/openvpn/easy-rsa/pkitool $CLIENT_NAME > /dev/null 2>&1
list_usr
}

#Function to delete users
function del_usr(){
CLIENT_REMOVE=$(whiptail --inputbox "Client to remove:" 8 40 3>&1 1>&2 2>&3)
for i in [ `ls /etc/openvpn/easy-rsa/keys/* | grep ".csr" | grep -Fv "server.csr" | awk -F. '{ print $1 }' | awk -F/ '{ print $6 }'` ]
   do
      if [ "$i" == "$CLIENT_REMOVE" ]
         then
            rm -r /etc/openvpn/easy-rsa/keys/$CLIENT_REMOVE.crt /etc/openvpn/easy-rsa/keys/$CLIENT_REMOVE.csr /etc/openvpn/easy-rsa/keys/$CLIENT_REMOVE.key
            whiptail --msgbox "User  $CLIENT_REMOVE  deleted" 8 36
            list_usr
      fi

done
whiptail --msgbox "ERROR - The client NOT exist" 8 36
manage_usr
}

#Main manage users function
function manage_usr() {
SELECTION=$(whiptail --menu "MANAGE USERS" 14 60 4 \
    "Create" "     Create new OpenVPN user" \
    "Delete" "     Delete OpenVPN users" \
    "List" "     List all created OpenVPN users" \
    "View" "     View active OpenVPN users" \
    3>&1 1>&2 2>&3)

if [ "$?" == "0" ]
   then
      case "$SELECTION" in
         Create)
            crea_usr
            ;;
         Delete)
            del_usr
            ;;
         List)
            list_usr
            ;;
         View)
            view_usr
            ;;
         *)
            exit
            ;;
      esac
   else
      exit
fi
manage_usr
}

manage_usr
