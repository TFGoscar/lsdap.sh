#!/bin/bash
# ROOT CHECK
    whoami=$(whoami)
    if [ "$whoami" != "root" ]; then
        echo "[!] YOU MUST RUN THIS SCRIPT LIKE ROOT. [!]"
        echo ""
        exit
    fi

	echo "[!] You are going to uninstall lsdap [!]" confirmation
	read -p "Are you sure?(Y/N)"
		if [ "$confirmation" = "Y" ] || [ "$confirmation" = "y" ]; then
			rm -r /etc/lsdap
			rm /usr/bin/lsdnew
			rm /usr/bin/lsdget			
			rm /usr/bin/lsduninstall
		echo "e"
		else 
			echo "[#] ABORTING [#]"
        fi