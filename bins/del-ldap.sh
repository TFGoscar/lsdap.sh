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

#obtengo el nombre del dominio con las lineas de slapcat que empiezan por dn: dc=
#emtubo para invertir la búsqueda y que no aparezca nodomain por si acaso
dominio=$(slapcat | grep "^dn: dc=" | grep -v "nodomain" | sed 's/dn: //g')
#formo el dn del usuario admin
admin="cn=admin,$dominio"

if [ $# -eq 2 ]
then
	if [ "$1" = "-o" ]
	then
		unidad=$(slapcat | grep "^dn: ou=$2," | sed 's/dn: //g')
		if [ "$unidad" = "" ]
		then
			echo "No es una unidad"
			exit 2
		else
			echo "Va a la OU $unidad y todo su contenido, ¿desea continuar (Y/N)?"
			read opcion
			if [ "$opcion" == "Y" -o "$opcion" == "y" ]
			then
				ldapdelete -x -W -r -D $admin $unidad
				echo "$unidad borrado"
			fi
		fi
	else
		echo "del-ldap: First param must be -o."
		exit 2
	fi
elif [ $# -eq 1 ]
then
	objeto=$(slapcat | grep "^dn: cn=$1," | sed 's/dn: //g')
	if [ "$objeto" = "" ]
	then
		echo "No es un usuario ni un grupo"
		exit 2
	else
		echo "Va a borrar $objeto, ¿desea continuar (Y/N)?"
		read opcion
		if [ "$opcion" == "Y" -o "$opcion" == "y" ]
		then
			esGrupo=$(ldapsearch -xLLL -b $dominio "(&(objectClass=posixGroup)(cn=$1))" | grep "^gidNumber: " | sed 's/gidNumber: //g')
			if [ "$esGrupo" != "" ]
			then	
				esGrupoPpal=$(ldapsearch -xLLL -b $dominio "(&(objectClass=posixAccount)(gidNumber=$esGrupo))" | grep "^gidNumber: ")
				if [ "$esGrupoPpal" != "" ]
				then
					echo "del-ldap: El grupo $1 es grupo principal de algún/os usuario/s, borre primero el/los usuario/s"
					exit 2					
				fi
			fi
			ldapdelete -x -W -D $admin $objeto
			echo "$objeto borrado"
		fi
	fi
else
	echo "del-ldap: Need a LdapObject name"
	exit 2
fi

