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
read_password() {
    local var_name="$1"
    local password=""

    while IFS= read -r -s -n 1 char; do
        # Si el carácter es Enter (o Nueva línea), salir
        if [[ $char == $'\0' ]]; then
            echo
            break
        fi

        # Comprobar si el carácter es retroceso (backspace)
        if [[ $char == $'\x7f' ]] || [[ $char == $'\b' ]]; then
            if [[ -n $password ]]; then
                password="${password%${password: -1}}"
                # Borrar un asterisco en la terminal
                echo -ne "\b \b"
            fi
        else
            password+="$char"
            # Mostrar un asterisco por cada carácter
            echo -n "*"
        fi
    done

    # Asignar la contraseña a la variable especificada
    eval "$var_name='$password'"
}
# -----------------------------------------------------------------------
# LOGO
  clear
  echo -e "\n\t ${bluecolor}
.__               .___                
|  |    ______  __| _/_____   ______  
|  |   /  ___/ / __ | \__  \  \____ \ 
|  |__ \___ \ / /_/ |  / __ \_|  |_| |
|____//____  >\____ | (____  /|   __/ 
           \/      \/      \/ |__|

${endcolor}\n"

#-------------------------------------------
# Creación de carpeta para el correcto funcionamiento del script.
    lsdapdirectory=$(ls /etc | grep "lsdap" | head -1)
    if [ "$lsdapdirectory" = "lsdap" ]; then
    echo "Tienes el programa instalado. Se esta borrando."
    rm -r /etc/lsdap
    rm -r /usr/bin/lsdget

    else
        read -p "- Do you want config this equipe like a server or just like a client?(S/C) --> " configmode
        configmode=$(echo $configmode | tr '[:upper:]' '[:lower:]')
        if [ "$configmode" = "c" ]; then
            read -p "- Hostname --> " hostname
            echo "$hostname" > /etc/hostname

            read -p "- Server FQDN (server.domain.tdp) --> " serverfqdn
            dc2=$(echo "$serverfqdn" | awk -F'.' '{print $3}')
            dc1=$(echo "$serverfqdn" | awk -F'.' '{print $2}')

            servername=$(echo "$serverfqdn" | awk -F'.' '{print $1}')

            while [ "$dc2" = "" ]; do
                dc2=$(echo "$serverfqdn" | awk -F'.' '{print $3}')
                echo ""
                echo "[!] INVALID FORMAT TRY AGAIN [!]"
                read -p "- SERVER FQDN (server.domain.topleveldomain) --> " serverfqdn
            done

            read -p "- Server IP --> " serverip
            sed -i '2d' /etc/hosts
            echo "127.0.0.1 localhost" >> /etc/hosts
            echo "127.0.1.1 $hostname" >> /etc/hosts
            echo "$serverip $serverfqdn $servername" >> /etc/hosts
            sudo apt install libpam-ldap libnss-ldap nss-updatedb libnss-db nscd ldap-utils -y 
            sed -i '72s/^#//' /etc/ldap.conf
            sed -i '72s/hard/soft/' /etc/ldap.conf
            sed -i '129s/md5/crypt/' /etc/ldap.conf
            sed -i '8s/^#//' /etc/ldap/ldap.conf
            sed -i "8s/example/$dc1/" /etc/ldap/ldap.conf
            sed -i "8s/com/$dc2/" /etc/ldap/ldap.conf
            sed -i "9s/^#//" /etc/ldap/ldap.conf
            sed -i 's|\(ldap://[^\ ]*\) \(ldap://[^\ ]*\)|\1\n# \2|' /etc/ldap/ldap.conf
            sed -i "9s/example/$dc1/" /etc/ldap/ldap.conf
            sed -i "9s/com/$dc2/" /etc/ldap/ldap.conf

            sed -i "12s/^#//" /etc/ldap/ldap.conf
            sed -i "13s/^#//" /etc/ldap/ldap.conf
            sed -i "14s/^#//" /etc/ldap/ldap.conf

            sed -i "7s/files systemd/files ldap/" /etc/nsswitch.conf
            sed -i "8s/files systemd/files ldap/" /etc/nsswitch.conf
            sed -i "9s/files/files ldap/" /etc/nsswitch.conf
            sed -i "10s/files/files ldap/" /etc/nsswitch.conf
            sed -i "12s/.*/hosts:          files dns/" /etc/nsswitch.conf
            nss_updatedb ldap
            sleep 1.5
            sed -i "26s/use_authtok//" /etc/pam.d/common-password
            sudo echo "session required	pam_mkhomedir.so skel=/etc/skel/ umask=0022" >> /etc/pam.d/common-session

            reboot now

        elif [ "$configmode" = "s" ]; then

            read -p "[+] ¿Do you want to start a LDAP Domain instalation on this host?(y/n) --> " installoption
            configmode=$(echo $installoption | tr '[:upper:]' '[:lower:]')
            if [ $installoption = "y" ]; then
                sudo apt-get install slapd ldap-utils -y
            fi
            
            servername=$(cat /etc/hostname)
            fqdn0=$(slapcat | grep "^dn: dc=" | grep -v "nodomain" | sed 's/dn: //g' | sed 's/,dc=/./g' | sed 's/dc=//g')
            fqdn="$servername.$fqdn0"
            dc1=$(echo "$fqdn" | awk -F'.' '{print $2}')
            dc2=$(echo "$fqdn" | awk -F'.' '{print $3}')
            echo -n "- LADP Password --> "
            read_password ldappassword

            ldapsearch -D "cn=admin,dc=$dc1,dc=$dc2" -w "$ldappassword" 2>/tmp/test 1>/dev/null
            comprobacionldaps=$(cat /tmp/test | awk '{print $4}')
            until [ "$comprobacionldaps" != "(49)" ] && [ "$ldappassword" != "" ]; do
                echo ""
                echo -n "Incorrect Password. Try again --> "
                read_password ldappassword
                ldapsearch -D "cn=admin,dc=$dc1,dc=$dc2" -w "$ldappassword" 2>/tmp/test 1>/dev/null
                comprobacionldaps=$(cat /tmp/test | awk '{print $4}')
            done


            mkdir -p /etc/lsdap/bins
            touch /etc/lsdap/file.ldif
            touch /etc/lsdap/data.conf
            wget "https://raw.githubusercontent.com/TFGoscar/lsdap.sh/refs/heads/main/bins/ou.sh" -O "/etc/lsdap/bins/ou.sh" 2>/dev/null
            wget "https://raw.githubusercontent.com/TFGoscar/lsdap.sh/refs/heads/main/bins/grp.sh" -O "/etc/lsdap/bins/grp.sh" 2>/dev/null
            wget "https://raw.githubusercontent.com/TFGoscar/lsdap.sh/refs/heads/main/bins/pablo.sh" -O "/etc/lsdap/bins/pablo.sh" 2>/dev/null
            wget "https://raw.githubusercontent.com/TFGoscar/lsdap.sh/refs/heads/main/bins/usr.sh" -O "/etc/lsdap/bins/usr.sh" 2>/dev/null
            wget "https://raw.githubusercontent.com/TFGoscar/lsdap.sh/refs/heads/main/bins/new-ldap.sh" -O "/etc/lsdap/bins/new-lsdap.sh" 2>/dev/null
            wget "https://raw.githubusercontent.com/TFGoscar/lsdap.sh/refs/heads/main/bins/uninstall.sh" -O "/etc/lsdap/bins/uninstall-lsdap.sh" 2>/dev/null
            ln -s /etc/lsdap/bins/pablo.sh /usr/bin/lsdget
            ln -s /etc/lsdap/bins/new-lsdap.sh /usr/bin/lsdnew
            ln -s /etc/lsdap/bins/uninstall-lsdap.sh /usr/bin/lsduninstall
            
            chmod 700 /etc/lsdap/*
            chmod 700 /etc/lsdap/bins/*

            echo "fqdn=$fqdn" >> /etc/lsdap/data.conf
            echo "lastuid=5000" >> /etc/lsdap/data.conf
            echo "lastgid=5000" >> /etc/lsdap/data.conf
            echo "lsdappassword=$ldappassword" >> /etc/lsdap/data.conf
            rm ./set-up.sh
        fi
    fi
