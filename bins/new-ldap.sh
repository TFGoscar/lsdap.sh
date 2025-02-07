#/bin/bash
clear
#si el usuario no es root, muestra un error y sale con 2
if [ $(id -u) -ne 0 ]
then
	echo "del-ldap: Permission denied."
	exit 2
fi

if [ $# -gt 2 ]
then
	echo "del-ldap: Numbers of params incorrect."
	exit 2
fi

function creaOU()
{
	unidad=$(slapcat | grep "ou=$1,")
	if [ "$unidad" != "" ]
	then
		echo "new-ldap: OU $1 already exist."
		exit 2
	else
		lsdget -o
		echo "¿Dónde desea crear la nueva OU $2 (r(raiz) o <nombre>)?"
		read opcion
		if [ "$opcion" == "r" -o "$opcion" == "R" ]
		then
			echo "dn: ou=$1,$dominio" > ./unidades.ldif
			echo "ou: $1" >> ./unidades.ldif
			echo "objectClass: organizationalUnit" >> ./unidades.ldif
			ldapadd -x -D $admin -W -f ./unidades.ldif
			rm ./unidades.ldif
		else
			ruta=$(slapcat | grep "^dn: ou=$opcion," | sed 's/dn: //g')
			if [ "$ruta" != "" ]
			then
				echo "dn: ou=$1,$ruta" > ./unidades.ldif
				echo "ou: $1" >> ./unidades.ldif
				echo "objectClass: organizationalUnit" >> ./unidades.ldif
				ldapadd -x -D $admin -W -f ./unidades.ldif
				rm ./unidades.ldif
			else
				echo "new-ldap: $opcion not exist in LDAP tree."
				exit 2
			fi
		fi
	fi
}

function creaGRP()
{
	grupo=$(slapcat | grep "^dn: cn=$1,")
	if [ "$grupo" != "" ]
	then
		echo "new-ldap: $1 object already exist."
		exit 2
	else
		lsdget -o
		echo "¿Dónde desea crear el nuevo grupo $1 (r(raiz) o <nombre>)?"
		read opcion
		lsdget -g
		echo "Indique un gidNumber libre"
		read gidNumber
		gidNumberLibre=$(ldapsearch -xLLL -b $dominio gidNumber=$gidNumber gidNUmber)
		if [ "$gidNumberLibre" = "" ]
		then
			if [ "$opcion" == "r" -o "$opcion" == "R" ]
			then
				echo "dn: cn=$1,$dominio" > ./grupos.ldif
				echo "cn: $1" >> ./grupos.ldif
				echo "objectClass: posixGroup" >> ./grupos.ldif
				echo "gidNumber: $gidNumber" >> ./grupos.ldif
				ldapadd -x -D $admin -W -f ./grupos.ldif
				rm ./grupos.ldif
			else
				ruta=$(slapcat | grep "^dn: ou=$opcion," | sed 's/dn: //g')
				if [ "$ruta" != "" ]
				then
					echo "dn: cn=$1,$ruta" > ./grupos.ldif
					echo "cn: $1" >> ./grupos.ldif
					echo "objectClass: posixGroup" >> ./grupos.ldif
					echo "gidNumber: $gidNumber" >> ./grupos.ldif
					ldapadd -x -D $admin -W -f ./grupos.ldif
					rm ./grupos.ldif
				else
					echo "new-ldap: $opcion not exist in LDAP tree."
					exit 2
				fi
			fi
		else
			echo "new-ldap: gidNumber already exist."
			exit 2
		fi
	fi
}

function creaUSR()
{
	usu=$(slapcat | grep "^dn: cn=$1,")
	if [ "$usu" != "" ]
	then
		echo "new-ldap: $1 object already exist."
		exit 2
	else
		lsdget -o
		echo "¿Dónde desea crear el nuevo usuario $1 (r(raiz) o <nombre>)?"
		read opcion
		if [ "$opcion" == "r" -o "$opcion" == "R" ]
		then
			ruta=$dominio
		else
			ruta=$(slapcat | grep "^dn: ou=$opcion," | sed 's/dn: //g')
			if [ "$ruta" = "" ]
			then
				echo "new-ldap: $opcion not exist in LDAP tree."
				exit 2
			fi
		fi
		lsdget -u
		echo "Indique un uidNumber libre: "
		read uidNumber
		uidNumberLibre=$(ldapsearch -xLLL -b $dominio uidNumber=$uidNumber uidNUmber)
		if [ "$uidNumberLibre" != "" ]
		then
			echo "new-ldap: uidNumber already exist."
			exit 2
		fi
		lsdget -g
		echo "Indique un gidNumber existente para el grupo principal"
		read gidNumberUsu
		gidNumberUsuExiste=$(ldapsearch -xLLL -b $dominio objectClass=posixGroup gidNumber | grep "^gidNumber: $gidNumberUsu$")
		if [ "$gidNumberUsuExiste" = "" ]
		then
			echo "new-ldap: then current gidNumber not exist."
			exit 2
		fi
		echo "Indique nombre de pila:"
		read nombre
		echo "Indique apellido/s:"
		read apellidos
		echo "Indique contraseña: "
		slappasswd > ./contra
		contraUsu=$(cat ./contra)
		rm ./contra
		echo "dn: cn=$1,$ruta" > ./usuarios.ldif
		echo "objectClass: inetOrgPerson" >> ./usuarios.ldif
		echo "objectClass: posixAccount" >> ./usuarios.ldif
		echo "objectClass: shadowAccount" >> ./usuarios.ldif
		echo "cn: $1" >> ./usuarios.ldif
		echo "uid: $1" >> ./usuarios.ldif
		echo "uidNumber: $uidNumber" >> ./usuarios.ldif
		echo "gidNumber: $gidNumberUsu" >> ./usuarios.ldif
		echo "givenName: '$nombre'" >> ./usuarios.ldif
		echo "sn: '$apellidos'" >> ./usuarios.ldif
		echo "userPassword: $contraUsu" >> ./usuarios.ldif		
		echo "homeDirectory: /home/$1" >> ./usuarios.ldif
		ldapadd -x -W -D $admin -f ./usuarios.ldif
		rm ./usuarios.ldif
	fi
}

#obtengo el nombre del dominio con las lineas de slapcat que empiezan por dn: dc=
#emtubo para invertir la búsqueda y que no aparezca nodomain por si acaso
dominio=$(slapcat | grep "^dn: dc=" | grep -v "nodomain" | sed 's/dn: //g')
#formo el dn del usuario admin
admin="cn=admin,$dominio"

if [ $# -eq 2 ]
then
	if [ "$1" = "-o" ]
	then
		creaOU $2
	elif [ "$1" == "-g" ]
	then
		creaGRP $2
	elif [ "$1" == "-u" ]
	then
		creaUSR $2
	else
		echo "new-ldap: First param must be -o, -g or -u."
		exit 2
	fi
else
	echo "new-ldap: Need two params."
	exit 2
fi
