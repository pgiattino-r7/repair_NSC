#!/bin/bash
#This script reinstalls Nexpose, backing up necessary components prior to repair and restoring them after.
#Must be run as root
#Run 'tail -f /var/log/syslog | grep R7' concurrently for logging
#Created by Philip Giattino
#For more information, please email support@rapid7.com

##### DECLARE VARIABLES

NEXPATH=$(find / -name nsc.sh | cut -d '/' -f1-4)

##### DEFINE FUNCTIONS

#function to identify OS -- if not Linux, quit with error message
function check_os() {
	if [[ $OSTYPE != *linux-gnu* ]]; then
        	echo "System OS not Linux, cannot run script."
        	exit 1
	else logger "R7 - OS check passed, beginning repair."
	fi
}

#function to perform cleanup if script is exited unexpectedly
function cleanup() {
	mv $NEXPATH/plugins.bak $NEXPATH/plugins
	logger "R7 - Script interrupted, restoring moved files"
}

#function to acquire serial number of console and store as variable and print
function get_sn() {
	SN=$(cat $NEXPATH/nsc/conf/nsc.xml | grep -oP '(sn=".{40}")' | cut -c 5-41)
	echo "Nexpose Security Console serial number is $SN"
	logger - "R7 - Security Console serial number is $SN"
}

#function to stop nexpose console service
function stop_nexposeconsole() {
	if systemctl show -p SubState --value nexposeconsole == "running" > /dev/null; then
        	systemctl stop nexposeconsole
		logger "R7 - Nexposeconsole service stopped."
        fi
}

#function to stop postgresql services
function stop_postgresql() {
	pkill postgres
	logger "R7 - postgres services stopped."
}

#function to backup two important directories
function backup() {
	cp -p $NEXPATH/nsc/conf/userdb.xml $NEXPATH/nsc/conf/userdb.xml.bak
	mv $NEXPATH/plugins $NEXPATH/plugins.bak
	logger "R7 - plugins folder and userdb.xml backed up."
}

#function to delete update directories
function delete_dirs() {
	rm -r $NEXPATH/updates/stagingFileData
	rm -r $NEXPATH/updates/pending
	logger "R7 - update folders deleted."
}

#function to download most up-to-date Nexpose console installer
function download_installer() {
	rm Rapid7Setup-Linux64.bin > /dev/null
	wget http://download2.rapid7.com/download/InsightVM/Rapid7Setup-Linux64.bin
	#make file executable with chmod +x
	chmod +x Rapid7Setup-Linux64.bin
	logger "R7 - Nexpose installer downloaded to $PWD."
}

#run installer function with correct args
function run_installer() {
	logger "R7 - Installer running..."
	./Rapid7Setup-Linux64.bin
	logger "R7 - Installer finished."
}

#restore backed up folders
function restore_dirs() {
	mv $NEXPATH/nsc/conf/userdb.xml.bak $NEXPATH/nsc/conf/userdb.xml
	mv $NEXPATH/plugins.bak $NEXPATH/plugins
	logger "R7 - Plugins folder and userdb.xml restored to original location."
}

#check if services are running, if not, start services
function start_services() {
	systemctl start nexposeconsole
	logger "R7 - Nexposeconsole service started."
}

##### MAIN
check_os
trap cleanup SIGINT
stop_nexposeconsole
stop_postgresql
backup
delete_dirs
download_installer
run_installer
restore_dirs
start_services
get_sn
exit
