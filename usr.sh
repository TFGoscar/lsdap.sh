#!/bin/bash

users=$(ldapsearch -xLLL -b "dc=midominio11,dc=local" objectClass=posixAccount | grep cn: | awk '{print $2}')
echo -e "[Name]                        [UID]"

for i in $users
do
    uid=$(ldapsearch -xLLL -b "dc=midominio11,dc=local" cn=$i uidNumber | grep uidNumber: | awk '{print $2}')
    # Usamos printf para formatear la salida
    printf "%-29s %s\n" "$i" "$uid"
done
