#!/bin/bash


# Si el usuario no es root, muestra un error y sale con 2
if [ $(id -u) -ne 0 ]; then
    echo "del-ldap: Permission denied."
    exit 2
fi
if [ $# -gt 2 ]; then
    echo "del-ldap: Number of params incorrect."
    exit 2
fi
clear

# READ PASSWORD WIT ASTHERICS
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
#--------------------------
# Variable Contraseña
ldappassword=$(cat /etc/lsdap/data.conf | grep "lsdappassword" | awk -F'=' '{print $2}')
# Función para crear una unidad organizativa (OU)
function creaOU() {
    unidad=$(slapcat | grep "ou=$1,")
    if [ "$unidad" != "" ]; then
        echo "new-ldap: OU $1 already exists."
        exit 2
    else
        lsdget -o
		echo ""
        read -p "¿Name of the OU you want to put $1 into, if theres no higher ou just press enter --> " opcion
        if [ "$opcion" = "" ]; then
            echo "dn: ou=$1,$dominio" > /etc/lsdap/file.ldif
            echo "ou: $1" >> /etc/lsdap/file.ldif
            echo "objectClass: organizationalUnit" >> /etc/lsdap/file.ldif
            ldapadd -x -D $admin -w "$ldappassword" -f /etc/lsdap/file.ldif
        else
            ruta=$(slapcat | grep "^dn: ou=$opcion," | sed 's/dn: //g')
            if [ "$ruta" != "" ]; then
                echo "dn: ou=$1,$ruta" > /etc/lsdap/file.ldif
                echo "ou: $1" >> /etc/lsdap/file.ldif
                echo "objectClass: organizationalUnit" >> /etc/lsdap/file.ldif
                ldapadd -x -D $admin -w "$ldappassword" -f /etc/lsdap/file.ldif
				echo "COMMAND --> 'ldapadd -x -D $admin -w "PASSWORD" -f /etc/lsdap/file.ldif'"
            else
                echo "new-ldap: $opcion does not exist in LDAP tree."
                exit 2
            fi
        fi
    fi
}

# Función para crear un grupo
function creaGRP() {
    grupo=$(slapcat | grep "^dn: cn=$1,")
    if [ "$grupo" != "" ]; then
        echo "new-ldap: $1 object already exists."
        exit 2
    else
        lsdget -o
		echo ""
        read -p "¿Name of the OU you want to put $1 into, if theres no higher ou just press enter --> " opcion
		echo ""
        lsdget -g
        read -p "Free GID Number you want to use? --> " gidNumber
        gidNumberLibre=$(ldapsearch -xLLL -b $dominio gidNumber=$gidNumber)
        if [ "$gidNumberLibre" = "" ]; then
            if [ "$opcion" = "" ]; then
                echo "dn: cn=$1,$dominio" > /etc/lsdap/file.ldif
                echo "cn: $1" >> /etc/lsdap/file.ldif
                echo "objectClass: posixGroup" >> /etc/lsdap/file.ldif
                echo "gidNumber: $gidNumber" >> /etc/lsdap/file.ldif
                ldapadd -x -D $admin -w "$ldappassword" -f /etc/lsdap/file.ldif
                groupadd $1 -g $gidNumber
				echo "COMMAND --> 'ldapadd -x -D $admin -w "$ldappassword" -f /etc/lsdap/file.ldif'"

            else
                ruta=$(slapcat | grep "^dn: ou=$opcion," | sed 's/dn: //g')
                if [ "$ruta" != "" ]; then
                    echo "dn: cn=$1,$ruta" > /etc/lsdap/file.ldif
                    echo "cn: $1" >> /etc/lsdap/file.ldif
                    echo "objectClass: posixGroup" >> /etc/lsdap/file.ldif
                    echo "gidNumber: $gidNumber" >> /etc/lsdap/file.ldif
                    ldapadd -x -D $admin -w "$ldappassword" -f /etc/lsdap/file.ldif
                    groupadd $1 -g $gidNumber
					echo "COMMAND --> 'ldapadd -x -D $admin -w "PASSWORD" -f /etc/lsdap/file.ldif'"
                else
                    echo "new-ldap: $opcion does not exist in LDAP tree."
                    exit 2
                fi
            fi
        else
            echo "new-ldap: gidNumber already exists."
            exit 2
        fi
    fi
}

# Función para crear un usuario
function creaUSR() {
    usu=$(slapcat | grep "^dn: cn=$1,")
    if [ "$usu" != "" ]; then
        echo "new-ldap: $1 object already exists."
        exit 2
    else
        lsdget -o
        read -p "¿Name of the OU you want to put $1 into, if theres no higher ou just press enter --> " opcion
        if [ "$opcion" = "" ]; then
            ruta=$dominio
        else
            ruta=$(slapcat | grep "^dn: ou=$opcion," | sed 's/dn: //g')
            if [ "$ruta" = "" ]; then
                echo "new-ldap: $opcion does not exist in LDAP tree."
                exit 2
            fi
        fi
        lsdget -u
        read -p "Type a FREE UID --> " uidNumber
        uidNumberLibre=$(ldapsearch -xLLL -b $dominio uidNumber=$uidNumber)
        if [ "$uidNumberLibre" != "" ]; then
            echo "new-ldap: uidNumber already exists."
            exit 2
        fi
        lsdget -g
        read -p "GID of the group you want to use --> " gidNumberUsu
        gidNumberUsuExiste=$(ldapsearch -xLLL -b $dominio objectClass=posixGroup gidNumber | grep "^gidNumber: $gidNumberUsu$")
        if [ "$gidNumberUsuExiste" = "" ]; then
            echo "new-ldap: The current gidNumber does not exist."
            exit 2
        fi
        read -p "Common name --> " nombre
        read -p "Surnames --> " apellidos
		echo -n "User password --> "
 		read_password contraUsu
        contraUsu=$(slappasswd -s $contraUsu)
        echo "dn: cn=$1,$ruta" > /etc/lsdap/file.ldif
        echo "objectClass: inetOrgPerson" >> /etc/lsdap/file.ldif
        echo "objectClass: posixAccount" >> /etc/lsdap/file.ldif
        echo "objectClass: shadowAccount" >> /etc/lsdap/file.ldif
        echo "cn: $1" >> /etc/lsdap/file.ldif
        echo "uid: $1" >> /etc/lsdap/file.ldif
        echo "uidNumber: $uidNumber" >> /etc/lsdap/file.ldif
        echo "gidNumber: $gidNumberUsu" >> /etc/lsdap/file.ldif
        echo "givenName: '$nombre'" >> /etc/lsdap/file.ldif
        echo "sn: '$apellidos'" >> /etc/lsdap/file.ldif
        echo "userPassword: $contraUsu" >> /etc/lsdap/file.ldif
        echo "homeDirectory: /perfiles/$1" >> /etc/lsdap/file.ldif
        ldapadd -x -w "$ldappassword" -D $admin -f /etc/lsdap/file.ldif
		lsdget -g > /tmp/lsdget
		nombregrupo=$(cat /tmp/lsdget | grep "$gidNumber" | awk '{print $1}'| sed 's/\[Name\]//g' | sed 's/ //g')
		rm /tmp/lsdget
		cuela=$(echo "useradd -u $uidNumber -g $nombregrupo -m -d /perfiles/$1 $1")
        $cuela
		echo "COMMAND --> ldapadd -x -w 'PASSWORD' -D $admin -f /etc/lsdap/file.ldif"

    fi
}

# Obtengo el nombre del dominio con las líneas de slapcat que empiezan por dn: dc=
dominio=$(slapcat | grep "^dn: dc=" | grep -v "nodomain" | sed 's/dn: //g')

# Formo el dn del usuario admin
admin="cn=admin,$dominio"

if [ $# -eq 2 ]; then
    if [ "$1" = "-o" ]; then
        creaOU $2
    elif [ "$1" == "-g" ]; then
        creaGRP $2
    elif [ "$1" == "-u" ]; then
        creaUSR $2
    else
        echo "new-ldap: First param must be -o, -g or -u."
        exit 2
    fi
else
    echo "new-ldap: Need two params."
    exit 2
fi
