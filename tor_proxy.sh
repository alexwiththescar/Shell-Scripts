#!/bin/bash
#This script switches on/off the tranparent tor proxy

###############################
#### Function Definitions #####
###############################

#This function resets iptables to their default state
reset_iptables () {
  IPTABLES="$(which iptables)"

  # RESET DEFAULT POLICIES
  $IPTABLES -P INPUT ACCEPT
  $IPTABLES -P FORWARD ACCEPT
  $IPTABLES -P OUTPUT ACCEPT
  $IPTABLES -t nat -P PREROUTING ACCEPT
  $IPTABLES -t nat -P POSTROUTING ACCEPT
  $IPTABLES -t nat -P OUTPUT ACCEPT
  $IPTABLES -t mangle -P PREROUTING ACCEPT
  $IPTABLES -t mangle -P OUTPUT ACCEPT

  # FLUSH ALL RULES, ERASE NON-DEFAULT CHAINS
  $IPTABLES -F
  $IPTABLES -X
  $IPTABLES -t nat -F
  $IPTABLES -t nat -X
  $IPTABLES -t mangle -F
  $IPTABLES -t mangle -X
}

#This function modifies iptables so that they are compatible with the transparent tor proxy
tor_iptables () {
  ### set variables
  #destinations you don't want routed through Tor
  _non_tor="192.168.1.0/24 192.168.0.0/24"

  #the UID that Tor runs as (varies from system to system)
  _tor_uid="120"

  #Tor's TransPort
  _trans_port="9040"

  ### flush iptables
  iptables -F
  iptables -t nat -F

  ### set iptables *nat
  iptables -t nat -A OUTPUT -m owner --uid-owner $_tor_uid -j RETURN
  iptables -t nat -A OUTPUT -p udp --dport 53 -j REDIRECT --to-ports 53

  #allow clearnet access for hosts in $_non_tor
  for _clearnet in $_non_tor 127.0.0.0/9 127.128.0.0/10; do
     iptables -t nat -A OUTPUT -d $_clearnet -j RETURN
  done

  #redirect all other output to Tor's TransPort
  iptables -t nat -A OUTPUT -p tcp --syn -j REDIRECT --to-ports $_trans_port

  ### set iptables *filter
  iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

  #allow clearnet access for hosts in $_non_tor
  for _clearnet in $_non_tor 127.0.0.0/8; do
     iptables -A OUTPUT -d $_clearnet -j ACCEPT
  done

  #allow only Tor output
  iptables -A OUTPUT -m owner --uid-owner $_tor_uid -j ACCEPT
  iptables -A OUTPUT -j REJECT
}


############################
#### Main Script Starts ####
############################

if [ "$(cat /etc/resolv.conf | grep 127.0.1.1)" ]
then
  echo "Tor transparent proxy is NOT running. It will be now switched ON."
  sed -i 's/127\.0\.1\.1/127\.0\.0\.1/g' /etc/resolv.conf # Replacing 127.0.1.1 with 127.0.0.1
  tor_iptables 
else
  echo "Tor transparent proxy is ALREADY running. Let us switch it OFF."
  sed -i 's/127\.0\.0\.1/127\.0\.1\.1/g' /etc/resolv.conf # Replacing 127.0.0.1 with 127.0.1.1
  reset_iptables
fi
