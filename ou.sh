#!/bin/bash

# Función que recibe una lista con las unidades organizativas del directorio en formato dn
function mostrarUnidades() {
    for datos in $@; do
        # Obtener el nombre de la unidad organizativa
        nombreOU=$(echo $datos | sed 's/^dn: ou=//g' | cut -d"," -f1)
        echo "Unidad organizativa: $nombreOU"

        # Crear patrón para buscar subunidades organizativas dentro de esta unidad
        echo "^dn: ou=[[:alnum:]]+,$datos$" > patron
        subunidades=$(slapcat | grep -E -i -f patron | sed 's/^dn: ou=//g' | cut -d"," -f1)

        # Mostrar subunidades si existen
        if [ "$subunidades" != "" ]; then
            echo "- Subunidades organizativas:"
            for sub in $subunidades; do
                echo "   $sub"
            done
        fi

        echo "------------------------------------------------"
    done

    # Limpiar el archivo temporal de patrones
    rm patron
}

# Obtener todas las unidades organizativas (OUs)
unidades=$(slapcat | grep "^dn: ou=" | sed 's/^dn: //g')

# Procesar las unidades organizativas
mostrarUnidades $unidades