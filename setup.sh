#!/bin/bash

# Determine toolpath if not set already
relativepath="./" # Define relative path to go from this script to the root level of the tool
if [[ ! -v toolpath ]]; then scriptpath=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd ); toolpath=$(realpath --canonicalize-missing ${scriptpath}/${relativepath}); fi

# Create Folders
mkdir -p /etc/cooling-failure-protection
mkdir -p /opt/cooling-failure-protection

# Install App
cp -r opt/cooling-failure-protection/* /opt/cooling-failure-protection/

# Ensure Proper Permissions
chmod 755 /opt/cooling-failure-protection/cooling-failure-protection.sh

# Install Example Settings
cp -r etc/cooling-failure-protection/* /etc/cooling-failure-protection/

# Install Systemd Service
cp etc/systemd/system/cooling-failure-protection.service /etc/systemd/system/cooling-failure-protection.service

# Reload Systemd Daemon (at least to suppress warnings)
systemctl daemon-reload

# If NOT in Manual Debug Mode
if [[ "${DEBUG_MODE}" != "yes" ]]
then
    # Enable Service
    systemctl enable cooling-failure-protection.service

    # Restart Service
    systemctl restart cooling-failure-protection.service

    # Show Status of Service in case the are any Errors
    systemctl status cooling-failure-protection.service
fi
