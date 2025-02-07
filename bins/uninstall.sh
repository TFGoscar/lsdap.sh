#!/bin/bash
# ROOT CHECK
    whoami=$(whoami)
    if [ "$whoami" != "root" ]; then
        echo "[!] YOU MUST RUN THIS SCRIPT LIKE ROOT. [!]"
        echo ""
        exit
    fi
	echo ""
	echo "[!] You are one step to uninstall lsdap [!]" 
	read -p "Are you sure?(Y/N) --> " confirmation
		if [ "$confirmation" = "Y" ] || [ "$confirmation" = "y" ]; then
			rm -r /etc/lsdap
			rm /usr/bin/lsdnew
			rm /usr/bin/lsdget			
			rm /usr/bin/lsduninstall
		echo "Unistalled"
		else 
			echo "[#] ABORTING [#]"
        fi
