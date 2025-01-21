#!/bin/bash
echo ""
echo "Avaible Organizational Units"
echo ""
echo "--------------"


# Función que recibe una lista con las unidades organizativas del directorio en formato dn
function mostrarUnidades() {
    for datos in $@; do
        # Obtener el nombre de la unidad organizativa principal
        nombreOU=$(echo $datos | sed 's/^dn: ou=//g' | cut -d"," -f1 | sed 's/ou=//g')
        echo "$nombreOU"

        # Crear patrón para buscar subunidades organizativas dentro de esta unidad
        echo "^dn: ou=[[:alnum:]]+,$datos$" > patron
        subunidades=$(slapcat | grep -E -i -f patron | sed 's/^dn: ou=//g' | cut -d"," -f1)

        # Mostrar subunidades si existen
        if [ ! -z "$subunidades" ]; then
            for sub in $subunidades; do
                echo "   -$sub"
            done
        fi

    done
    echo ""
    # Limpiar el archivo temporal de patrones
    rm patron
}

# Obtener todas las unidades organizativas (OUs) principales (sin subunidades)
unidades=$(slapcat | grep "^dn: ou=" | sed 's/^dn: //g' | grep -v ",ou=")

# Procesar las unidades organizativas principales
mostrarUnidades $unidades
echo "--------------"
