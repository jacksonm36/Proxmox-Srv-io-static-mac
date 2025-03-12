#!/usr/bin/bash
#
# vf_add_maddr.sh Version 2.6 (Remove Old Random MACs and Assign Static MACs for All 31 VFs)
#

# Paths
CTCONFDIR="/etc/pve/nodes/proxmox2/lxc"
VMCONFDIR="/etc/pve/nodes/proxmox2/qemu-server"
TMP_FILE="/tmp/vf_add_maddr.tmp"
MAC_DB_FILE="/etc/vf_mac_db.conf"  # File to store static MAC addresses for VFs
LOGFILE="/var/log/vf_add_maddr.log"

# **Define the Correct SFP+ 10Gb Interface**
IFBRIDGE="enp4s0f1"  #  enp4s0f1 (10Gb SFP+)
LBRIDGE="vmbr1"      # 10Gb LAN Bridge

# Colors
C_RED='\e[0;31m'
C_GREEN='\e[0;32m'
C_YELLOW='\e[0;33m'
C_NC='\e[0m'

# Static MAC addresses for all 31 VFs
declare -A STATIC_MACS=(
    ["enp4s0f1v0"]="02:00:00:00:00:01"
    ["enp4s0f1v1"]="02:00:00:00:00:02"
    ["enp4s0f1v2"]="02:00:00:00:00:03"
    ["enp4s0f1v3"]="02:00:00:00:00:04"
    ["enp4s0f1v4"]="02:00:00:00:00:05"
    ["enp4s0f1v5"]="02:00:00:00:00:06"
    ["enp4s0f1v6"]="02:00:00:00:00:07"
    ["enp4s0f1v7"]="02:00:00:00:00:08"
    ["enp4s0f1v8"]="02:00:00:00:00:09"
    ["enp4s0f1v9"]="02:00:00:00:00:0a"
    ["enp4s0f1v10"]="02:00:00:00:00:0b"
    ["enp4s0f1v11"]="02:00:00:00:00:0c"
    ["enp4s0f1v12"]="02:00:00:00:00:0d"
    ["enp4s0f1v13"]="02:00:00:00:00:0e"
    ["enp4s0f1v14"]="02:00:00:00:00:0f"
    ["enp4s0f1v15"]="02:00:00:00:00:10"
    ["enp4s0f1v16"]="02:00:00:00:00:11"
    ["enp4s0f1v17"]="02:00:00:00:00:12"
    ["enp4s0f1v18"]="02:00:00:00:00:13"
    ["enp4s0f1v19"]="02:00:00:00:00:14"
    ["enp4s0f1v20"]="02:00:00:00:00:15"
    ["enp4s0f1v21"]="02:00:00:00:00:16"
    ["enp4s0f1v22"]="02:00:00:00:00:17"
    ["enp4s0f1v23"]="02:00:00:00:00:18"
    ["enp4s0f1v24"]="02:00:00:00:00:19"
    ["enp4s0f1v25"]="02:00:00:00:00:1a"
    ["enp4s0f1v26"]="02:00:00:00:00:1b"
    ["enp4s0f1v27"]="02:00:00:00:00:1c"
    ["enp4s0f1v28"]="02:00:00:00:00:1d"
    ["enp4s0f1v29"]="02:00:00:00:00:1e"
    ["enp4s0f1v30"]="02:00:00:00:00:1f"
)

# Initialize logging
log() {
    local message="$1"
    local color="$2"
    echo -e "[$(date)] ${color}${message}${C_NC}" | tee -a "$LOGFILE"
}

# Check if required directories exist
if [ ! -d "$CTCONFDIR" ] || [ ! -d "$VMCONFDIR" ]; then
    log "ERROR: Required directories not found. Exiting." "$C_RED"
    exit 1
fi

# Gather MAC addresses from Proxmox VMs & Containers
MAC_LIST_VMS="$(grep -hEo '([[:xdigit:]]{1,2}[:-]){5}[[:xdigit:]]{1,2}' ${VMCONFDIR}/*.conf | tr '[:upper:]' '[:lower:]')"
MAC_LIST_CTS="$(grep -hEo '([[:xdigit:]]{1,2}[:-]){5}[[:xdigit:]]{1,2}' ${CTCONFDIR}/*.conf | tr '[:upper:]' '[:lower:]')"

# Get bridge's own MAC address
MAC_ADD2LIST="$(cat /sys/class/net/$LBRIDGE/address)"
MAC_LIST="$MAC_LIST_VMS $MAC_LIST_CTS $MAC_ADD2LIST"

# Read existing MAC addresses in the database file
declare -A MAC_DB

while IFS='=' read -r iface mac; do
    iface=$(echo "$iface" | tr -d '[:space:]')  # Remove any whitespace from the interface name
    mac=$(echo "$mac" | tr -d '[:space:]')      # Remove any whitespace from the MAC address

    MAC_DB["$iface"]=$mac
done < "$MAC_DB_FILE"

# Remove old random MAC addresses and set static MAC addresses for all 31 VFs
VF_INTERFACES=$(ip link show | grep "enp4s0f1v" | awk -F: '{print $2}' | tr -d ' ')

for vf_interface in $VF_INTERFACES; do
    # Get the static MAC address for the VF
    if [[ -n "${STATIC_MACS[$vf_interface]}" ]]; then
        static_mac="${STATIC_MACS[$vf_interface]}"
    else
        log "No static MAC defined for $vf_interface - skipping" "$C_YELLOW"
        continue
    fi

    # Get the current MAC address of the VF from the MAC DB
    current_mac="${MAC_DB[$vf_interface]}"

    # Remove old random MAC address if it doesn't match the static one
    if [[ "$current_mac" != "$static_mac" && "$current_mac" != "00:00:00:00:00:00" ]]; then
        log "Removed old random MAC address for $vf_interface: $current_mac" "$C_YELLOW"
    fi

    # Set the static MAC address for the VF
    if ip link set "$IFBRIDGE" vf "${vf_interface##*v}" mac "$static_mac"; then
        log "Set static MAC address for $vf_interface to $static_mac" "$C_GREEN"
        # Update the database with the static MAC address
        MAC_DB["$vf_interface"]=$static_mac
    else
        log "Failed to set MAC address for $vf_interface: Permission denied" "$C_RED"
    fi
done

# Write updated MAC addresses back to the database file
for iface in "${!MAC_DB[@]}"; do
    echo "$iface=${MAC_DB[$iface]}" >> "$MAC_DB_FILE"
done

exit 0
