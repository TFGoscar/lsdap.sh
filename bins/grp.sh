#!/bin/bash
dc1=$(cat /etc/lsdap/data.conf | grep "fqdn" | awk -F '=' '{print $2}' | awk -F '.' '{print $2}')
dc2=$(cat /etc/lsdap/data.conf | grep "fqdn" | awk -F '=' '{print $2}' | awk -F '.' '{print $3}')

groups=$(ldapsearch -xLLL -b "dc=$dc1,dc=$dc2" objectClass=posixGroup | grep cn: | awk '{print $2}')
echo -e "[Name]                        [GID]"

for i in $groups
do
    gid=$(ldapsearch -xLLL -b "dc=midominio11,dc=local" cn=$i gidNumber | grep gidNumber: | awk '{print $2}')
    # Usamos printf para formatear la salida
    printf "%-29s %s\n" "$i" "$gid"
done
