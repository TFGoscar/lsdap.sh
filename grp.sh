#!/bin/bash


groups=$(ldapsearch -xLLL -b "dc=midominio11,dc=local" objectClass=posixGroup | grep cn: | awk '{print $2}')
echo -e "[Name]          [GID]"

for i in $groups
do
    gid=$(ldapsearch -xLLL -b "dc=midominio11,dc=local" cn=$i gidNumber | grep gidNumber: | awk '{print $2}')
    # Usamos printf para formatear la salida
    printf "%-15s %s\n" "$i" "$gid"
done
