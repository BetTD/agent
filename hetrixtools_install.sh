#!/bin/bash
#
#
#	HetrixTools Server Monitoring Agent - Install Script
#	version 1.03
#	Copyright 2016 @  HetrixTools
#	For support, please open a ticket on our website https://hetrixtools.com
#
#
#		DISCLAIMER OF WARRANTY
#
#	The Software is provided "AS IS" and "WITH ALL FAULTS," without warranty of any kind, 
#	including without limitation the warranties of merchantability, fitness for a particular purpose and non-infringement. 
#	HetrixTools makes no warranty that the Software is free of defects or is suitable for any particular purpose. 
#	In no event shall HetrixTools be responsible for loss or damages arising from the installation or use of the Software, 
#	including but not limited to any indirect, punitive, special, incidental or consequential damages of any character including, 
#	without limitation, damages for loss of goodwill, work stoppage, computer failure or malfunction, or any and all other commercial damages or losses. 
#	The entire risk as to the quality and performance of the Software is borne by you, the user.
#
#

# Set PATH
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Check if install script is run by root
echo "Checking root privileges..."
if [ "$EUID" -ne 0 ]
  then echo "ERROR: Please run the install script as root."
  exit
fi
echo "... done."

# Fetch Server Unique ID
SID=$1

# Make sure SID is not empty
echo "Checking Server ID (SID)..."
if [ -z "$SID" ]
	then echo "ERROR: First parameter missing."
	exit
fi
echo "... done."

# Check if user has selected to run agent as 'root' or as 'hetrixtools' user
if [ -z "$2" ]
	then echo "ERROR: Second parameter missing."
	exit
fi

# Check if system has crontab
echo "Checking cronjobs..."
command -v crontab >/dev/null 2>&1 || { echo "ERROR: Cronjobs are required to run this agent." >&2; exit 1; }
echo "... done."

# Remove old agent (if exists)
echo "Checking if there's any old hetrixtools agent already installed..."
if [ -d /etc/hetrixtools ]
then
	echo "Old hetrixtools agent found, deleting it..."
	rm -rf /etc/hetrixtools
else
	echo "No old hetrixtools agent found..."
fi
echo "... done."

# Creating agent folder
echo "Creating the hetrixtools agent folder..."
mkdir -p /etc/hetrixtools
echo "... done."

# Fetching new agent
echo "Fetching the new agent..."
wget -t 1 -T 30 -qO /etc/hetrixtools/hetrixtools_agent.sh --no-check-certificate https://raw.github.com/hetrixtools/agent/master/hetrixtools_agent.sh
echo "... done."

# Inserting Server ID (SID) into the agent config
echo "Inserting Server ID (SID) into agent config..."
sed -i "s/SIDPLACEHOLDER/$SID/" /etc/hetrixtools/hetrixtools_agent.sh
echo "... done."

# Finding the public network interface name, based on your public IP address
echo "Finding your public network interface name..."
NetworkInterface=$(ip route | grep $(ip route get 8.8.8.8 | awk '{ print $NF; exit }') | awk '{ print $3 }')
echo "... done."

# Inserting the network interface name into the agent configuration
echo "Inserting network interface name into agent config..."
sed -i "s/ETHPLACEHOLDER/$NetworkInterface/" /etc/hetrixtools/hetrixtools_agent.sh
sed -i 's/\r$//' /etc/hetrixtools/hetrixtools_agent.sh
echo "... done."

# Checking if hetrixtools user exists
echo "Checking if hetrixtool user already exists..."
if id -u hetrixtools >/dev/null 2>&1
then
	echo "The hetrixtools user already exists, killing its processes..."
	pkill -9 -u `id -u hetrixtools`
	echo "Deleting hetrixtools user..."
	userdel hetrixtools
	echo "Creating the new hetrixtools user..."
	useradd hetrixtools -r -d /etc/hetrixtools -s /bin/false
	echo "Assigning permissions for the hetrixtools user..."
	chown -R hetrixtools:hetrixtools /etc/hetrixtools
	chmod -R 700 /etc/hetrixtools
else
	echo "The hetrixtools user doesn't exist, creating it now..."
	useradd hetrixtools -r -d /etc/hetrixtools -s /bin/false
	echo "Assigning permissions for the hetrixtools user..."
	chown -R hetrixtools:hetrixtools /etc/hetrixtools
	chmod -R 700 /etc/hetrixtools
fi
echo "... done."

# Removing old cronjob (if exists)
echo "Removing any old hetrixtools cronjob, if exists..."
crontab -u root -l | grep -v 'hetrixtools'  | crontab -u root - >/dev/null 2>&1
crontab -u hetrixtools -l | grep -v 'hetrixtools'  | crontab -u hetrixtools - >/dev/null 2>&1
echo "... done."

# Setup the new cronjob to run the agent either as 'root' or as 'hetrixtools' user, depending on client's installation choice.
# Default is running the agent as 'hetrixtools' user, unless chosen otherwise by the client when fetching the installation code from the hetrixtools website.
if [ "$2" -eq "1" ]
then
	echo "Setting up the new cronjob as 'root' user..."
	crontab -u root -l 2>/dev/null | { cat; echo "* * * * * bash /etc/hetrixtools/hetrixtools_agent.sh > /etc/hetrixtools/hetrixtools_cron.log"; } | crontab -u root - >/dev/null 2>&1
else
	echo "Setting up the new cronjob as 'hetrixtools' user..."
	crontab -u hetrixtools -l 2>/dev/null | { cat; echo "* * * * * bash /etc/hetrixtools/hetrixtools_agent.sh > /etc/hetrixtools/hetrixtools_cron.log"; } | crontab -u hetrixtools - >/dev/null 2>&1
fi
echo "... done."

# Cleaning up install file
echo "Cleaning up the installation file..."
if [ -f $0 ]
then
    rm -f $0
fi
echo "... done."

# Let HetrixTools platform know install has been completed
echo "Letting HetrixTools platform know the installation has been completed..."
POST="v=install&s=$SID"
wget -t 1 -T 30 -qO- --post-data "$POST" --no-check-certificate https://hetrixtools.com/s.php &> /dev/null
echo "... done."

# All done
echo "HetrixTools agent installation completed."