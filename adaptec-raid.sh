#!/bin/bash
#  .VERSION
#  0.2
# 
# .SYNOPSIS
#  Script with LLD support for getting data from Adaptec RAID Controller to Zabbix monitoring system.
#
#  .DESCRIPTION
#  The script may generate LLD data for Adaptec RAID Controllers, Logical Drives, Physical Drives.
#
# .NOTES
# Author: GOID1989
# Github: https://github.com/GOID1989/zbx-adaptec-raid
#

cli='/usr/local/sbin/arcconf'
cli_sg='/usr/bin/sg_scan'
cli_smart='/usr/sbin/smartctl'

action=$1
part=$2

LLDControllers() {
    ctrl_count=$($cli GETCONFIG 1 AL | grep "Controllers found:" | cut -f2 -d":" | sed -e 's/^ //' )
    
    i=1
    ctrl_json=""
    while [ $i -le $ctrl_count ]
    do
	ctrl_model=$($cli GETCONFIG $i AD | grep "Controller Model" | cut -f2 -d":" | sed -e 's/^ //' )
	ctrl_sn=$($cli GETCONFIG $i AD | grep "Controller Serial Number" | cut -f2 -d":" | sed -e 's/^ //' )
	
	ctrl_info="{\"{#CTRL.ID}\":\"$i\",\"{#CTRL.MODEL}\":\"$ctrl_model\",\"{#CTRL.SN}\":\"$ctrl_sn\"},"
	ctrl_json=$ctrl_json$ctrl_info
	
	i=$((i+1))
    done
    
    ctrl_json=$(echo $ctrl_json | sed -e 's/,$//')
    lld_data="{\"data\":[$ctrl_json]}"
    
    echo $lld_data
}

LLDBattery() {
    # No controllers with battery on Linux machine
    # NEED SIMULATE
    ctrl_count=$($cli GETCONFIG 1 AL | grep "Controllers found:" | cut -f2 -d":" | sed -e 's/^ //' )
    
    i=1
    bt_json=""
    while [ $i -le $ctrl_count ]
    do
	ctrl_bt=$($cli GETCONFIG $i AD | grep "Controller Battery Information" )
	len=${#ctrl_bt}
	if [ $len -ne 0 ]
	then
	    bt_status=$($cli GETCONFIG $i AD | grep -E "^\s+Status\s+[:]" | cut -f2 -d":" | sed -e 's/^ //' )
	    len=${#bt_status}
	    if [ $len -ne 0 ]
	    then
		bt_info="{\"{#CTRL.ID}\":\"$i\",\"{#CTRL.BATTERY}\":\"$i\"},"
		bt_json=$bt_json$bt_info
	    fi
	fi
	i=$((i+1))
    done
    
    bt_json=$(echo $bt_json | sed -e 's/,$//')
    lld_data="{\"data\":[$bt_json]}"
    
    echo $lld_data
    
    #echo "{\"data\":[]}"
}

LLDLogicalDrives() {
    ctrl_count=$($cli GETCONFIG 1 AL | grep "Controllers found:" | cut -f2 -d":" | sed -e 's/^ //' )
    
    i=1
    ld_json=""
    while [ $i -le $ctrl_count ]
    do
	ld_count=$($cli GETCONFIG $i AD | grep "Logical devices/Failed/Degraded" | cut -f2 -d":" | cut -f1 -d"/" | sed -e 's/^ //' )
	
	ld_ids=$($cli GETCONFIG $i LD | grep "Logical Device number " | cut -f4 -d" " | sed -e 's/^ //' )
	
	for ld_id in $ld_ids; do
	    ld_name=$($cli GETCONFIG $i LD $ld_id | grep "Logical device name" | cut -f2 -d":" | sed -e 's/^ //' )
	    ld_raid=$($cli GETCONFIG $i LD $ld_id | grep "RAID level" | cut -f2 -d":" | sed -e 's/^ //' )
	    
	    if [ "$ld_name" = "" ]
	    then
		ld_name=$ld_id
	    fi
	    
	    ld_info="{\"{#CTRL.ID}\":\"$i\",\"{#LD.ID}\":\"$ld_id\",\"{#LD.NAME}\":\"$ld_name\",\"{#LD.RAID}\":\"$ld_raid\"},"
	    ld_json=$ld_json$ld_info
	done
	
	i=$((i+1))
    done
    
    ld_json=$(echo $ld_json | sed -e 's/,$//')
    lld_data="{\"data\":[$ld_json]}"
    
    echo $lld_data
}

LLDPhysicalDrives() {
    ctrl_count=$($cli GETCONFIG 1 AL | grep "Controllers found:" | cut -f2 -d":" | sed -e 's/^ //' )
    
    i=1
    pd_json=""
    while [ $i -le $ctrl_count ]
    do
	pd_list=($($cli GETCONFIG $i PD | grep "Device #" | cut -f2 -d"#" ))
	pd_list_type=($($cli GETCONFIG 1 PD | grep 'Device is a' | sed -e 's/ /_/g'))
	
	# ToDo:  NEEED CHECK IS A HARD DRIVE OR SOMETHING ELSE
	for pd_id in "${pd_list[@]}"; do
	    type=${pd_list_type[$pd_id]}
	    case "$type" in
		"_________Device_is_a_Hard_drive")
		    pd_info="{\"{#CTRL.ID}\":\"$i\",\"{#PD.ID}\":\"$pd_id\"},"
		    pd_json=$pd_json$pd_info
		;;
	    esac
	done
    
	i=$((i+1))
    done
    
    pd_json=$(echo $pd_json | sed -e 's/,$//')
    lld_data="{\"data\":[$pd_json]}"
    
    echo $lld_data
}

LLDSmart() {
need_write="0"
echo "{"
echo "\"data\":["
$cli_sg | cut -f1 -d ":" | while read smart_dev
do
    if [ $need_write = "1" ]
    then
	echo ","
    fi
    echo "{\"{#ADAPTEC_DISK}\":\"$smart_dev\"}"
    need_write="1"
done
echo "]"
echo "}"
}

GetControllerStatus() {
    ctrl_id=$1
    ctrl_part=$2
    
    ctrl_status=""
    case "$ctrl_part" in
	"main")
	    ctrl_status=$($cli GETCONFIG $ctrl_id AD | grep "Controller Status" | cut -f2 -d":" | sed -e 's/^ //' )
	;;
	"battery")
	    ctrl_status=$($cli GETCONFIG $ctrl_id AD | grep -E "^\s+Status\s+[:]" | cut -f2 -d":" | sed -e 's/^ //' )
	;;
	"temperature")
	    ctrl_status=$($cli GETCONFIG $ctrl_id AD | grep -E "^\s+Temperature\s+[:]" | cut -f2 -d":" | awk '{print $1}' )
	;;
    esac
    
    echo $ctrl_status
}

GetLogicalDriveStatus() {
    ctrl_id=$1
    ld_id=$2

    ld_status=$($cli GETCONFIG $ctrl_id LD $ld_id | grep "Status of logical device" | cut -f2 -d":" | sed -e 's/^ //' )

    echo $ld_status
}

GetPhysicalDriveStatus() {
    ctrl_id=$1
    pd_id=$2
    pd_status=($($cli GETCONFIG $ctrl_id PD | grep -oP '^\s+State.*$' | cut -f2 -d":" ))
    
    echo ${pd_status[$pd_id]}
}


GetSmartHealth() {
    disk_dev=$1

    disk_health=$($cli_smart -H $disk_dev | grep "SMART Health Status" | cut -f2 -d":" | sed -e 's/^ //' )
    echo $disk_health
}

GetSmartTemp() {
    disk_dev=$1

    disk_temp=$($cli_smart -A $disk_dev | grep "Current Drive Temperature" | cut -f2 -d":" | cut -f1 -d"C" | sed -e 's/^ //' )
    echo $disk_temp
}

GetSmartTripTemp() {
    disk_dev=$1

    disk_temp=$($cli_smart -A $disk_dev | grep "Drive Trip Temperature" | cut -f2 -d":" | cut -f1 -d"C" | sed -e 's/^ //' )
    echo $disk_temp
}

GetSmartDefects() {
    disk_dev=$1

    disk_defects=$($cli_smart -A $disk_dev | grep "Elements in grown defect list" | cut -f2 -d":" | sed -e 's/^ //' )
    echo $disk_defects
}

case "$action" in
    "lld")
	case "$part" in
	    "ad")
		LLDControllers
	    ;;
	    "ld")
		LLDLogicalDrives
	    ;;
	    "pd")
		LLDPhysicalDrives
	    ;;
	    "bt")
		LLDBattery
	    ;;
	    "smart")
		LLDSmart
	    ;;
	esac
    ;;
    "health")
	case "$part" in
	    "ad")
		GetControllerStatus "$3" "$4"
	    ;;
	    "ld")
		GetLogicalDriveStatus "$3" "$4"
	    ;;
	    "pd")
		GetPhysicalDriveStatus "$3" "$4"
	    ;;
	esac
    ;;
    "smart")
	case "$part" in
	    "health")
		GetSmartHealth "$3" 
	    ;;
	    "temp")
		GetSmartTemp "$3" 
	    ;;
	    "triptemp")
		GetSmartTripTemp "$3" 
	    ;;
	    "defects")
		GetSmartDefects "$3" 
	    ;;
	esac
    ;;
*)
    echo "Invalid usage of script"
    ;;
esac
