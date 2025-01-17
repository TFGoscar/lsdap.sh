#!/bin/bash

# ROOT CHECK
    whoami=$(whoami)
    if [ "$whoami" != "root" ]; then
        echo "[!] YOU MUST RUN THIS SCRIPT LIKE ROOT. [!]"
        echo ""
        exit
    fi
#-------------------------------------------------------

# COLORS
    greenColour="\e[0;32m\033[1m"
    endColour="\033[0m\e[0m"
    redColour="\e[0;31m\033[1m"
    blueColour="\e[0;34m\033[1m"
    yellowColour="\e[0;33m\033[1m"
    purpleColour="\e[0;35m\033[1m"
    turquoiseColour="\e[0;36m\033[1m"
    grayColour="\e[0;37m\033[1m"
#---------------------------------------

# Creación de carpeta para el correcto funcionamiento del script.
    lsdapdirectory=$(ls | grep "lsdap" | head -1)
    if [ $lsdapdirectory == "lsdap" ]; then
        echo ""
    else
        clear
        echo -n "         [#]       This is the first time you run this script,        [#]
         [#] so you must answer some questions before use the script. [#]
          "
        echo ""
        # Unicamente sirve para el usuario, crear otros bucles para cada pregunta
        until [ "$userexist" = "true" ]; do
            read -p "- Name of a non root regular sytem user --> " user
            checkuser=$(awk -F ':' '$3 > 999 ' /etc/passwd | awk -F ':' '$3 < 65534'| awk -F ':' '{print $1}' | grep $user)
            if [ "$checkuser" = "$user" ]; then
                userexist="true"

            else
                echo "El usuario introducido no existe, vuelve a introducirlo"
                echo ""
                sleep 0.5
            fi
            done
        read -p "- FQDN (server.domain.topleveldomain) --> " fqdn
        

        mkdir ./lsdap
        touch ./lsdap/file.ldif
        touch ./lsdap/data.conf
        wget "https://raw.githubusercontent.com/TFGoscar/lsdap.sh/refs/heads/main/ou.sh" -O "./lsdap/ou.sh"
        wget "https://raw.githubusercontent.com/TFGoscar/lsdap.sh/refs/heads/main/grp.sh" -O "./lsdap/grp.sh"
        wget "https://raw.githubusercontent.com/TFGoscar/lsdap.sh/refs/heads/main/pablo.sh" -O "./lsdap/pablo.sh"

        chmod 755 ./lsdap
        chmod 755 ./lsdap/*
    
        echo "user=$user" >> ./lsdap/data.conf
        echo "fqdn=$fqdn" >> ./lsdap/data.conf
        echo "lastuid=5000" >> ./lsdap/data.conf
        echo "lastgid=5000" >> ./lsdap/data.conf

        regularuser=$(cat ./lsdap/.data.conf | head -1)
        chown "$user:$user" ./lsdap
        chown "$user:$user" ./lsdap/*
        
    fi
#------------------------------------------------------------------


# Menu -----------------------------------------------------------------------------------------------------------------
until [ "$option" = "e" ]; do
    # VARIABLE CLEANER
    reconfigureoption=""
    searchoption=""
    useroption=""
    ou=""


    # VARIABLE
    dc1=$(cat ./lsdap/data.conf | grep "fqdn" | awk -F '=' '{print $2}' | awk -F '.' '{print $2}')
    dc2=$(cat ./lsdap/data.conf | grep "fqdn" | awk -F '=' '{print $2}' | awk -F '.' '{print $3}')
    clear
    # Saving Variables
    fqdn=$(cat ./lsdap/data.conf | grep "fqdn" | awk -F '=' '{print $2}')



    echo -n "[ - Choose the option you want to do (writte the letter) - ]

    (u) --> Create a new User.
    (o) --> Create a new Organizational Unit.
    (g) --> Create a new Grupe.
    (s) --> Search objects in LDAP domain.
    (r) --> Reconfigure script.
    (e) --> Exit.

    [$dc1.$dc2]
    "
    read -p "
[#] Choose your option --> " option

    if [ "$option" = "u" ];then
        read -p "[#] The User you want to create is inside into any OU? (N/1/2) --> " ins

        if [ "$ins" = "1" ]; then
            ./lsdap/ou.sh
            read -p "[#] Name of the OU you want to put the group into --> " ou1
            ou1="ou=$ou1"
        elif [ "$ins" = "2" ]; then
            ./lsdap/ou.sh
            read -p "[#] Name of the first OU you want to put the group into --> " ou1
            read -p "[#] Name of the second OU you want to put the group into --> " ou2
            ou1="ou=$ou1"
            ou2=",ou=$ou2"
        fi

    
    read -p "[#] Common Name --> " username
    read -p "[#] Surname --> " usersn
    read -p "[#] Name -->" givenname 
    echo ""
    ./lsdap/grp.sh
    echo ""
    read -p "[#] Group number you want to put the user into --> " usergroupnumber

    lastuserid=$(cat ./lsdap/data.conf | awk lastuid)
    userid=$()


dn: cn=jlopez,ou=usuarios,dc=pedroespinosa,dc=local
objectClass: inetOrgPerson
objectClass: posixAccount
objectClass: shadowAccount
uid: $userid
sn: $usersn
givenName: $givenname
cn: $username
uidNumber: $uidNumber
gidNumber: $gidNumber
userPassword: mi_password
homeDirectory: /home/jlopez


        option="e"
    elif [ "$option" = "o" ];then
        echo ""
        read -p "[#] The OU you want to create is inside another OU? (Y/N) --> " ins
        
        if [ "$ins" = "Y" ]; then
            ./lsdap/ou.sh
            read -p "[#] Name of the higher OU --> " hiow
            hiow=",ou=$hiow"
        fi
        read -p "[#] Organizational Unit name --> " newouname
        echo "dn: ou=$newouname$hiow,dc=$dc1,dc=$dc2" > ./lsdap/file.ldif
        echo "ou: $newouname" >> ./lsdap/file.ldif
        echo "objectClass: organizationalunit" >> ./lsdap/file.ldif
        sudo ldapadd -x -D cn=admin,dc=$dc1,dc=$dc2 -W -f ./lsdap/file.ldif

        sleep 5
        option="e"
    elif [ "$option" = "g" ];then
        
        read -p "[#] Name of the new Group --> " groupname
        read -p "[#] GID of the new Group --> " groupgid
        read -p "[#] The Group you want to create is inside into any OU? (N/1/2) --> " ins

        if [ "$ins" = "1" ]; then
            ./lsdap/ou.sh
            read -p "[#] Name of the OU you want to put the group into --> " ou1
            ou1="ou=$ou1"
        elif [ "$ins" = "2" ]; then
            ./lsdap/ou.sh
            read -p "[#] Name of the first OU you want to put the group into --> " ou1
            read -p "[#] Name of the second OU you want to put the group into --> " ou2
            ou1="ou=$ou1"
            ou2=",ou=$ou2"
            sleep 2

        fi

        echo "dn: cn=$groupname,$ou1$ou2,dc=midominio11,dc=local" > ./lsdap/file.ldif
        echo "objectClass: posixGroup" >> ./lsdap/file.ldif
        echo "cn: $groupname" >> ./lsdap/file.ldif
        echo "gidNumber: $groupgid" >> ./lsdap/file.ldif

        sudo ldapadd -x -D cn=admin,dc=$dc1,dc=$dc2 -W -f ./lsdap/file.ldif
        
    elif [ "$option" = "s" ];then
        until [ $searchoption = "e" ]; do 
        echo -n "[-   What are you looking foo?   -]"
        echo ""
        echo "  (1) - LDADP's tree."  
        echo "  (2) - Specific resource"
        echo "  (e) - Go Back."
        echo " "
        read -p "[#] Choose your option --> " searchoption

        if [ "$searchoption" = "1" ]; then
            ./lsdap/pablo.sh

        elif [ "$searchoption" = "2" ]; then


        fi
    
        
    elif [ "$option" = "r" ];then
        # RECONFIGURE
        until [ "$reconfigureoption" = "e" ]; do
            clear
            echo -n "[-   What do you want to reconfigure?   -]
            "
            echo ""
            echo "  (1) - Change FQDN ($fqdn)."  
            #echo "  (2) - "
            echo "  (e) - Go Back."
            echo " "
            read -p "[#] Choose your option --> " reconfigureoption
            fqdn=$(cat ./lsdap/data.conf | grep "fqdn" | awk -F '=' '{print $2}')

            if [ "$reconfigureoption" = "1" ]; then
                fqdn=$(cat ./lsdap/data.conf | grep "fqdn" | awk -F '=' '{print $2}')
                echo " "
                read -p "- FQDN ($fqdn) --> " newfqdn
                echo ""
                echo "[!] Saving new FQDN in config's file"
                sed -i "s/$fqdn/$newfqdn/g" ./lsdap/data.conf
                fqdn=$newfqdn
                sleep 1
            fi
        done
    fi
done
