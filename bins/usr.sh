#!/bin/bash
dc1=$(cat /etc/lsdap/data.conf | grep "fqdn" | awk -F '=' '{print $2}' | awk -F '.' '{print $2}')
dc2=$(cat /etc/lsdap/data.conf | grep "fqdn" | awk -F '=' '{print $2}' | awk -F '.' '{print $3}')

users=$(ldapsearch -xLLL -b "dc=$dc1,dc=$dc2" objectClass=posixAccount | grep cn: | awk '{print $2}')
echo -e "[Name]                        [UID]"

for i in $users
do
    uid=$(ldapsearch -xLLL -b "dc=midominio11,dc=local" cn=$i uidNumber | grep uidNumber: | awk '{print $2}')
    # Usamos printf para formatear la salida
    printf "%-29s %s\n" "$i" "$uid"
done
