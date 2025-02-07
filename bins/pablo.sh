#!/bin/bash

#si el usuario no es root, muestra un error y sale con 2
if [ $(id -u) -ne 0 ]
then
	echo "get-ldap: Permission denied."
	exit 2
fi

#función que añade espacios sin saltar de línea
#se usa para 'tabular' los objetos que se van mostrando por pantalla, con el fin de mostrar la lista de forma más clara
#$1 número de espacios que queremos añadir a la línea
function formatoEsp()
{
	for ((i=0;i<=$1;i++))
	do
		echo -n " "
	done
}

#busca y obtiene los usuarios de una OU (en ese nivel), pasando el dn de la misma
function getUsuarios()
{
	#USUARIOS
	#obejtos cuyo objectClass sea posixAccount, es decir, usuarios
	usuarios=$(ldapsearch -xLLL -s one -b "$1" objectClass=posixAccount cn | grep "^cn: " | sed 's/cn: //g')
	#si la variable usuarios, que almancena la búsqueda, no está vacía, quiere decir que esa unidad tiene usuarios
	if [ "$usuarios" != "" ]
	then
		#los muestro, recorriendo uno a uno la lista contenida en usuarios, mediante la variable de control usuario
		for usuario in $usuarios
		do
			#obtengo su uidNumber y su gidNumber
			#podemos obtener así los atributos que queramos y añadirlos luego al echo donde se muestran
			uidUsu=$(ldapsearch -xLLL -b "$1" cn="$usuario" uidNumber | grep "^uidNumber: ")
			gidUsu=$(ldapsearch -xLLL -b "$1" cn="$usuario" gidNumber | grep "^gidNumber: ")
			#añado espacios con el valor de $2 sumándole 2, para que se tabule más hacía dentro que el nombre de su unidad padre
			#muestro el nombre del usuario, su uidNumber y su gidNumber
			echo "$(formatoEsp $(($2+2)))-$usuario (user) ($uidUsu) ($gidUsu)"
		done
	fi
}

#busca y obtiene los grupos de una OU (en ese nivel), pasando el dn de la misma
function getGrupos()
{
	#GRUPOS
	#exactamente igual que los usuarios pero con grupos
	grupos=$(ldapsearch -xLLL -s one -b "$1" objectClass=posixGroup cn | grep "^cn: " | sed 's/cn: //g')
	if [ "$grupos" != "" ]
	then
		for grupo in $grupos
		do
			gidGrupo=$(ldapsearch -xLLL -b "$1" cn="$grupo" gidNumber | grep "^gidNumber: ")
			echo "$(formatoEsp $(($2+2)))-$grupo (group) ($gidGrupo)"
		done
	fi
}

#busca y obtiene las sub OU de una OU (en ese nivel), pasando el dn de la misma
function getUnidades()
{
	#SUB UNIDADES ORGANIZATIVAS (ou dentro de ou)
	#obtengo el nombre de todas las ou dentro de la que estamos tratando, excepto a sí misma
    subUnidades=$(ldapsearch -xLLL -b "$1" -s one objectClass=organizationalUnit ou | grep "^ou: " | sed 's/ou: //g' | grep -v "^$1$")
	#si la variable subUnidades es cadena vacía, quiere decir que no tiene subUnidades dentro, en caso contrario si tiene
    if [ "$subUnidades" != "" ]
    then
		#recorro la lista contenida en subUnidades con la variable de control subUnidad
		for subUnidad in $subUnidades
		do
			#llamada recursiva a la función getLdap para que muestre los datos de la sub unidad
			#s1 es el nombre de la unidad, $2 es el valor de $2 de la función padre más 2, para que tabule la subunidad más adentro que la unidad padre
			getLdap $subUnidad $(($2+2)) $3
		done
    fi
}


#función que recibe el nombre de una ou y muestra en forma de lista los objetos almacenados en ella
function getLdap()
{
	#obtengo el dn completo de esa unidad para buscar dentro de ella y no en todo el árbol LDAP
	dnUnidad=$(slapcat | grep "^dn: ou=$1" | sed 's/dn: //g')
	#$3 es el $1 del script, recibe -o, -g o -u. Si no se recibe, muestra todo
	if [ "$3" = "" ]
	then
		#añado espacios con el valor de $2, llamando a la función formatoEsp y, seguido, muestro el nombre de la unidad ($1)
		echo "$(formatoEsp $2)-$1 (ou)"
		#USUARIOS, llamada a la función getUsuarios
		getUsuarios $dnUnidad $2

		#GRUPOS, llamada a la función getGrupos
		getGrupos $dnUnidad $2

		#SUB UNIDADES ORGANIZATIVAS, llamada a la función getUnidades
		getUnidades $dnUnidad $2 $3
	#si recibe -u, muestra los usuarios de las unidades de forma recursiva
	elif [ "$3" = "-u" ]
	then
		#añado espacios con el valor de $2, llamando a la función formatoEsp y, seguido, muestro el nombre de la unidad ($1)
		echo "$(formatoEsp $2)-$1 (ou)"
		#USUARIOS, llamada a la función getUsuarios
		getUsuarios $dnUnidad $2
		#SUB UNIDADES ORGANIZATIVAS, llamada a la función getUnidades
		getUnidades $dnUnidad $2 $3
	#si recibe -g, muestra los grupos de las unidades de forma recursiva
	elif [ "$3" = "-g" ]
	then
		#añado espacios con el valor de $2, llamando a la función formatoEsp y, seguido, muestro el nombre de la unidad ($1)
		echo "$(formatoEsp $2)-$1 (ou)"
		#GRUPOS, llamada a la función getGrupos
		getGrupos $dnUnidad $2
		#SUB UNIDADES ORGANIZATIVAS, llamada a la función getUnidades
		getUnidades $dnUnidad $2 $3
	#si recibe -o, muestra solo las sub unidades de las unidades de forma recursiva
	elif [ "$3" = "-o" ]
	then
		#añado espacios con el valor de $2, llamando a la función formatoEsp y, seguido, muestro el nombre de la unidad ($1)
		echo "$(formatoEsp $2)-$1 (ou)"
		#SUB UNIDADES ORGANIZATIVAS, llamada a la función getUnidades
		getUnidades $dnUnidad $2 $3
	#en cualquier otro caso, error en el primer parámetro del script, que es el tercero en la función getLdap()
	else
		echo "Error en parámetros."
		exit 2
	fi
}

#MAIN
clear
if [ $# -gt 1 ]
then
	echo "get-ldap: Numbers of params incorrect."
	exit 2
else
	#obtengo el nombre del dominio con las lineas de slapcat que empiezan por dn: dc=
	#emtubo para invertir la búsqueda y que no aparezca nodomain por si acaso
	dominio=$(slapcat | grep "^dn: dc=" | grep -v "nodomain" | sed 's/dn: //g')
	echo "--------------------------------------------"
	echo $dominio
	echo "--------------------------------------------"

	#obtengo todas las unidades organizativas del dominio, formateándolas con grep y sed para quedarme con el dn limpio
	unidades=$(ldapsearch -xLLL -b "$dominio" objectClass=organizationalUnit ou -s one | grep "^ou: " | sed 's/ou: //g')
	
	#para incluir en la búsqueda grupos y usuarios que se encuentran en el directorio raiz
	grupos=$(ldapsearch -xLLL -s one -b "$dominio" objectClass=posixGroup | grep "^cn: " | sed 's/cn: //g')
	
	if [ "$grupos" != "" ]
	then
		getGrupos $dominio -1
	fi
	
	usuarios=$(ldapsearch -xLLL -s one -b "$dominio" objectClass=posixAccount | grep "^cn: " | sed 's/cn: //g')
	
	if [ "$usuarios" != "" ]
	then
		getUsuarios $dominio -1
	fi

	#recorro todas las unidades y en cada iteración llamo a la función getLdap para que obtenga toda la información de esa unidad
	#$1 es el nombre de la unidad
	#$2 se usa para darle valor a la funcion formatoEsp()
	for unidad in $unidades
	do
		getLdap $unidad 1 $1 #$1 es la opción con la que se ejecuta el script -u, -g o -o
	done
	echo "--------------------------------------------"
fi

