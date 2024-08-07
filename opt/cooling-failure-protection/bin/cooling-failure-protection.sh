#!/bin/bash

# Trap the SIGTERM signal and forward it to the main process
# trap 'kill -SIGTERM $pidh; wait $pidh' SIGTERM

# Default Settings
if [[ -f "/etc/cooling-failure-protection/default.sh" ]]
then
    source /etc/cooling-failure-protection/default.sh
fi

# Load User Settings
if [[ -f "/etc/cooling-failure-protection/user.sh" ]]
then
    source /etc/cooling-failure-protection/user.sh
fi

# Log
log_message() {
    local llevel="${1}"
    local lmessage="${2}"

    echo "[${llevel}] ${lmessage}"
}

# Print Configuration
print_config() {
    # HDD
    log_message "INFO" "HDD Warning (Beep) Temperature Configured to ${hdd_warning_temp}°C"
    log_message "INFO" "HDD Critical (Shutdown) Temperature Configured to ${hdd_shutdown_temp}°C"

    # SSD
    log_message "INFO" "SSD Warning (Beep) Temperature Configured to ${ssd_warning_temp}°C"
    log_message "INFO" "SSD Critical (Shutdown) Temperature Configured to ${ssd_shutdown_temp}°C"

    # NVME
    log_message "INFO" "NVME Warning (Beep) Temperature Configured to ${nvme_warning_temp}°C"
    log_message "INFO" "NVME Critical (Shutdown) Temperature Configured to ${nvme_shutdown_temp}°C"
}

# Lookup UDEV Device
get_udev_device_property() {
    local lkname="${1}"
    local lproperty="${2}"

    if [[ -e "/dev/${lkname}" ]]
    then
        local lvalue
        lvalue=$(udevadm info "/dev/${lkname}" | grep "${lproperty}=" | sed -E "s|.*?${lproperty}=(.*?)\$|\1|")
        echo "${lvalue}"
    else
        log_message "ERROR" "Device /dev/${lkname} does NOT Exist."
    fi
}

get_udev_device_bus() {
    local lkname="${1}"
    local lbus
    lbus=$(get_udev_device_property "${lkname}" "ID_BUS")

    echo "${lbus}"
}

get_udev_device_serial() {
    local lkname="${1}"
    local lserial
    lserial=$(get_udev_device_property "${lkname}" "ID_SERIAL")

    echo "${lserial}"
}

# Print Configuration
print_config

# Infinite Loop
while true
do
    # Loop over Drives
    lsblk -d -o MODEL,WWN,SIZE,STATE,TYPE,ROTA,KNAME,HCTL,TRAN,VENDOR --json | jq -c '.blockdevices[]' | while read -r device; do
         # Get Device Kernel Name (e.g. "sda")
         kname=$(echo "${device}" | jq -r '.kname')

         # Get Transport (e.g. "ata", "usb", "scsi", ...)
         transport=$(echo "${device}" | jq -r '.tran')

         # Get Model
         model=$(echo "${device}" | jq -r '.model')

         # Get WWN
         wwn=$(echo "${device}" | jq -r '.wwn')

         # Declare Temperature
         temp=999

         # Exclude Virtual Devices (e.g. ZFS ZVOL) which have model=null and wwn=null
         if [ "${model}" != "null" ] && [ "${wwn}" != "null" ]
         then
             # Get BUS based on UDEV
             bus=$(get_udev_device_bus "${kname}")

             # Get Serial
             serial=$(get_udev_device_serial "${kname}")

             # Get Rotation
             rotation=$(echo "${device}" | jq -r '.rota')

             # Echo
             #log_message "DEBUG" "Device /dev/${kname} , /dev/disk/by-id/${bus}-${serial} , Transport = ${transport} , Rotation = ${rotation} , Temperature = ${temp}°C"

             if [[ "${rotation}" == "false" ]]
             then
                 # It is NOT an HDD
                 if [[ "${transport}" == "sata" ]]
                 then
                    # It is an SSD

                    # Define Device Path by ID AKA /dev/disk/by-id/<ata-XXXX> or /dev/disk/by-id/<nvme-XXXX>
                    devicepathbyid="${bus}-${serial}"

                    # Get Temperature
                    temp=$(smartctl -a --json "/dev/disk/by-id/${devicepathbyid}" | jq -r '.temperature.current')

                    # Echo
                    log_message "INFO" "SSD /dev/${kname} , /dev/disk/by-id/${devicepathbyid} , Transport = ${transport} , Temperature = ${temp}°C"

                    # Map Temperatures
                    warning_temp=${ssd_warning_temp}
                    shutdown_temp=${ssd_shutdown_temp}
                 elif [[ "${transport}" == "nvme" ]]
                 then
                    # It is an NVME Drive

                    # Define Device Path by ID AKA /dev/disk/by-id/<ata-XXXX> or /dev/disk/by-id/<nvme-XXXX>
                    devicepathbyid="${transport}-${serial}"

                    # Get Temperature
                    temp=$(smartctl -a --json "/dev/disk/by-id/${devicepathbyid}" | jq -r '.temperature.current')

                    # Echo
                    log_message "INFO" "NVME /dev/${kname} , /dev/disk/by-id/${devicepathbyid} , Transport = ${transport} , Temperature = ${temp}°C"

                    # Map Temperatures
                    warning_temp=${nvme_warning_temp}
                    shutdown_temp=${nvme_shutdown_temp}
                 else
                    # It is Something Else

                    # Define Device Path by ID AKA /dev/disk/by-id/<ata-XXXX> or /dev/disk/by-id/<nvme-XXXX>
                    devicepathbyid="${bus}-${serial}"

                    # Get Temperature
                    temp=$(smartctl -a --json "/dev/disk/by-id/${devicepathbyid}" | jq -r '.temperature.current')

                    # Echo
                    log_message "INFO" "UNKNOWN /dev/${kname} , /dev/disk/by-id/${devicepathbyid} , Transport = ${transport} , Temperature = ${temp}°C"

                    # Disabled
                    warning_temp=999
                    shutdown_temp=999
                 fi
             else
                 # It is an HDD

                 # Define Device Path by ID AKA /dev/disk/by-id/<ata-XXXX> or /dev/disk/by-id/<nvme-XXXX>
                 devicepathbyid="${bus}-${serial}"

                 # Get Temperature
                 temp=$(smartctl -a --json "/dev/disk/by-id/${devicepathbyid}" | jq -r '.temperature.current')

                 # It is an HDD
                 log_message "INFO" "HDD /dev/${kname} , /dev/disk/by-id/${devicepathbyid} , Transport = ${transport} , Rotation = ${rotation} , Temperature = ${temp}°C"

                 # Map Temperatures
                 warning_temp=${hdd_warning_temp}
                 shutdown_temp=${hdd_shutdown_temp}
             fi

             # Check if Temperature above the Shutdown Threshold
             if [[ "${temp}" -ge "${shutdown_temp}" ]]
             then
                 # Log the Critical Event
                 log_message "CRITICAL" "Device /dev/${kname} , /dev/disk/by-id/${bus}-${serial} exceeded CRITICAL Temperature (Device Temperature = ${temp}°C > Shutdown Temperature = ${shutdown_temp}°C)"
                 log_message "CRITICAL" "The System will now shutdown"

                 # Wait a few Seconds to make sure that Logs are written
                 sleep 2

                 # Shutdown
                 shutdown -h now
             # Check if Temperature above the Warning Threshold
             elif [[ "${temp}" -ge "${warning_temp}" ]]
             then
                 # Log the Warning Event
                 log_message "WARNING" "Device /dev/${kname} , /dev/disk/by-id/${bus}-${serial} exceeded WARNING Temperature (Device Temperature = ${temp}°C > Warning Temperature = ${warning_temp}°C)"

                 # Beep the Warning
                 beep -f 2500 -l 2000 -r 5 -D 1000
             elif [ "${temp}" -le "${warning_temp}" ] && [ "${temp}" != "null" ]
             then
                 # Echo
                 log_message "DEBUG" "Device /dev/${kname} , /dev/disk/by-id/${bus}-${serial} is HEALTHY (Device Temperature = ${temp}°C < Warning Temperature = ${warning_temp}°C)"
             else
                 # Echo
                 log_message "ERROR" "Device /dev/${kname} , /dev/disk/by-id/${bus}-${serial} is INVALID (Device Temperature = ${temp}°C)"
             fi

         else
             # Echo
             log_message "INFO" "Skipping Device /dev/${kname} which appears to be a Virtual Device - model=${model} and wwn=${wwn}"
         fi
    done

    # Wait
    sleep 30
done
