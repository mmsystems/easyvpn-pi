easyvpn-pi
==========

easyvpn-pi is a script that allows you to create easily an OpenVPN server in your raspberry-pi with raspbian. 


INSTALL:
--------

#Update repos and install a new copy of ca-certificates (need for github)
$ sudo apt-get update
$ sudo apt-get -y install ca-certificates

#Clone the repo in your system
$ git clone https://github.com/mmsystems/easyvpn-pi
$ cd easyvpn-pi

#Make executable, and run!
$ chmod +x easyvpn-pi.sh
$ sudo ./easyvpn-pi


... follow the onscreen steps ...


Configure your client device with the new certificates created.


EXAMPLE:
--------

This is a example config running in a Linux client:



#OpenVPN Client configuration - openvpn.conf
client
dev tun
proto udp

#You should change this to your ip or dynamic dns!!
remote YourExternalIP/DynamicDNS 1194

resolv-retry infinite
nobind
user nobody
group nogroup
persist-key
persist-tun

#You should change this to your certs previously created!!
ca /root/Desktop/openvpn/certs/ca.crt
cert /root/Desktop/openvpn/certs/client1.crt
key /root/Desktop/openvpn/certs/client1.key

ns-cert-type server
comp-lzo
verb 3



Copy this openvpn configuration to a file called "openvpn.conf" and run: 
$ sudo openvpn openvpn.conf&
