#!/bin/bash

if [ $(id -u) -ne 0 ]
then
	echo "get-ldap: Permission denied."
	exit 2
fi

#variable global de tipo array donde se guardan las subUnidades que ya han sido mostradas por pantalla
declare -a hechos

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


#función que recibe el nombre de una ou y muestra en forma de lista los objetos almacenados en ella
function getLdap()
{
	#antes de empezar, comprueba con el array hechos, que esa ou no ha sido mostrada anteriormente como subunidad organizativa de otra superior
	for hecho in "${hechos[@]}"
	do
		#si alguno de los elementos del array coincide con $1 es que ya la hemos mostrado en alguna llamada recursiva anterior como sub unidad
		if [ "$hecho" = "$1" ]
		then
			salto="si"
		fi
	done
	#si la variable salto es diferente de "si", quiere decir que aún no la hemos mostrado, por tanto, pasamos a buscar y mostrar todos sus objetos
	if [ "$salto" != "si" ]
	then
		#añado espacios con el valor de $2, llamando a la función formatoEsp y, seguido, muestro el nombre de la unidad ($1)
		echo "$(formatoEsp $2)-$1 (ou)"
		#obtengo el dn completo de esa unidad para buscar dentro de ella y no en todo el árbol LDAP
		dnUnidad=$(slapcat | grep "^dn: ou=$1" | sed 's/dn: //g')

		#USUARIOS
		#obejtos cuyo objectClass sea posixAccount, es decir, usuarios
		usuarios=$(ldapsearch -xLLL -b "$dnUnidad" objectClass=posixAccount cn | grep "^cn: " | sed 's/cn: //g')
		#si la variable usuarios, que almancena la búsqueda, no está vacía, quiere decir que esa unidad tiene usuarios
		if [ "$usuarios" != "" ]
		then
			#los muestro, recorriendo uno a uno la lista contenida en usuarios, mediante la variable de control usuario
			for usuario in $usuarios
			do
				#como puede que el usuario sea uno almacenado en una sub unidad, me aseguro que su padre inmediantamente superior,...
				#... sea la unidad en la que estamos buscando
				usuarioDeOU=$(slapcat | grep "^dn: cn=$usuario,ou=$1")
				#si es de su padre inmediatamente superior, muestro los datos
				if [ "$usuarioDeOU" != "" ]
				then
					#obtengo su uidNumber y su gidNumber
					#podemos obtener así los atributos que queramos y añadirlos luego al echo donde se muestran
					uidUsu=$(ldapsearch -xLLL -b "$dnUnidad" cn="$usuario" uidNumber | grep "^uidNumber: ")
					gidUsu=$(ldapsearch -xLLL -b "$dnUnidad" cn="$usuario" gidNumber | grep "^gidNumber: ")
					#añado espacios con el valor de $2 sumándole 2, para que se tabule más hacía dentro que el nombre de su unidad padre
					#muestro el nombre del usuario, su uidNumber y su gidNumber
					echo "$(formatoEsp $(($2+2)))-$usuario (user) ($uidUsu) ($gidUsu)"
				fi
			done
		fi

		#GRUPOS
		#exactamente igual que los usuarios pero con grupos
		grupos=$(ldapsearch -xLLL -b "$dnUnidad" objectClass=posixGroup cn | grep "^cn: " | sed 's/cn: //g')
		if [ "$grupos" != "" ]
		then
			for grupo in $grupos
			do
				grupoDeOU=$(slapcat | grep "^dn: cn=$grupo,ou=$1")
				if [ "$grupoDeOU" != "" ]
				then
					gidGrupo=$(ldapsearch -xLLL -b "$dnUnidad" cn="$grupo" gidNumber | grep "^gidNumber: ")
					echo "$(formatoEsp $(($2+2)))-$grupo (group) ($gidGrupo)"
				fi
			done
		fi

		#SUB UNIDADES ORGANIZATIVAS (ou dentro de ou)
		#obtengo el nombre de todas las ou dentro de la que estamos tratando, excepto a sí misma
        	subUnidades=$(ldapsearch -xLLL -b "$dnUnidad" objectClass=organizationalUnit ou | grep "^ou: " | sed 's/ou: //g' | grep -v "^$1$")
		#si la variable subUnidades es cadena vacía, quiere decir que no tiene subUnidades dentro, en caso contrario si tiene
	        if [ "$subUnidades" != "" ]
        	then
			#recorro la lista contenida en subUnidades con la variable de control subUnidad
                	for subUnidad in $subUnidades
	                do
				#llamada recursiva a la función getLdap para que muestre los datos de la sub unidad
				#s1 es el nombre de la unidad, $2 es el valor de $2 de la función padre más 2, para que tabule la subunidad más adentro que la unidad padre
				getLdap $subUnidad $(($2+2))
				#indico que esta subunidad ya se ha mostrado, ya que la función getLdap muestra todas las unidades ya sean sub unidades o no...
				#...me aseguro así que cuando se llame a la función getLdap con la lista de todas las unidades (ya sean sub o no), si es sub, estará almacenada...
				#...en el array hechos, con lo que no la vuelvo a mostrar
				hechos=($subUnidad "${hechos[@]}")
        	        done
	        fi
	fi
}

#MAIN

#obtengo el nombre del dominio con las lineas de slapcat que empiezan por dn: dc=
#emtubo para invertir la búsqueda y que no aparezca nodomain por si acaso
dominio=$(slapcat | grep "^dn: dc=" | grep -v "nodomain" | sed 's/dn: //g')
echo ""
echo "----------------------"

#obtengo todas las unidades organizativas del dominio, formateándolas con grep y sed para quedarme con el dn limpio
unidades=$(ldapsearch -xLLL -b "$dominio" objectClass=organizationalUnit ou | grep "^ou: " | sed 's/ou: //g')

#recorro todas las unidades y en cada iteración llamo a la función getLdap para que obtenga toda la información de esa unidad
#$1 es el nombre de la unidad
#$2 se usa para darle valor a la funcion formatoEsp()
for unidad in $unidades
{
	getLdap $unidad 1
}
echo "----------------------"
echo ""
