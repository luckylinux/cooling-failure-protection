# cooling-failure-protection
Cooling Failure Protection for Servers/NAS/Desktops/etc.

# Introduction
This Tool is meant to be a (almost) last Resort to prevent permanent Damage or Severe Lifespan Reduction of your Drives.

It was Developed after a Cooling Failure caused several of my HDDs to reach very high Temperatures.

For a Variable Fan Speed Control for Supermicro IPMI Motherboards, please refer to my [Supermicro Fan Controller](https://github.com/luckylinux/supermicro-fan-control) Repository.

# Features
At the moment only Drives (HDD, SSD, NVME) are supported.

!! NVME Temperature Reading hasn't been extensively Tested !!

# Installation
Clone the Repository:
```
git clone https://github.com/luckylinux/cooling-failure-protection.git
```

Change Folder to the Project that was just cloned:
```
cd cooling-failure-protection
```

Run the Setup:
```
./setup.sh
```

# Configuration

## General
Fahrenheit Value is only displayed for Reference, it is NOT used in ANY Part of the Code !

The following Configuration Variables are currently defined:
| For Device |Variable | Default Value °C | Equivalent Value °F | Description | Action |
| --- | --- | --- | --- | --- | --- |
| HDD | `hdd_warning_temp`   | 45 | 113 | Warning Temperature for HDDs | Beep |
| HDD | `hdd_shutdown_temp`  | 50 | 122 | Shutdown Temperature for HDDs | Shutdown |
| SSD | `ssd_warning_temp`   | 60 | 140 | Warning Temperature for SSDs | Beep |
| SSD | `ssd_shutdown_temp`  | 70 | 158 | Shutdown Temperature for SSDs | Shutdown |
| NVME | `nvme_warning_temp`  | 70 | 158 | Warning Temperature for NVMEs | Beep |
| NVME | `nvme_shutdown_temp` | 80 | 176 | Shutdown Temperature for NVMEs | Shutdown |

## Default Settings
The Default Settings are installed in `/etc/cooling-failure-protection/default.sh`.

## User Settings
The User can define Custom Settings in installed in `/etc/cooling-failure-protection/user.sh`.


# Enable the Beep Module for early Warnings
Load the Kernel Module:
```
sudo modprobe pcspkr
```

Then perform a Test with:
```
beep -f 2500 -l 2000 -r 5 -D 1000
```

Set the Kernel Module to be automatically loaded at Startup:
```
echo "pcspkr" > /etc/modules-load.d/beep.conf
```
