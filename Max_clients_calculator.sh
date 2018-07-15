#!/bin/bash
PATH=$PATH:/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bon:/root/bin

########################################################################################

# SCRIPT FOR CALCULATING THE MAX CLIENTS AS PER THE AVAILABLE RESOURCES IN THE SERVER
# Author : Leegin Bernads T.S

########################################################################################

#The formula to calculate the Max_clients values to be set in the server is max clients = (Total amount of RAM – ( Max RAM allocation to MySQL + Amount of RAM used by OS) )/ Average size of Apache process

# Average size of Apache process
if [ -e /etc/issue ]; then
 APACHE="apache2"
elif [ -e /etc/redhat-release ]; then
 APACHE="httpd"
fi

AVG_PR_SIZE=$(ps -ylC $APACHE | awk '{x += $8;y += 1} END {print "Average $APACHE Proccess Size (MB): "x/((y-1)*1024)}'|cut -d":" -f2)
echo "Average size of $APACHE process for the server $HOSTNAME : AVG_PR_SIZE"

#Lets find the total RAM in our server
TOTAL_RAM=$(free -m | head -n 2 | tail -n 1 | awk '{print $2}')
echo "The total RAM in the server $HOSTNAME : $TOTAL_RAM MB"

#Max RAM allocation to MySQL
#We use the mysqltuner script to find the maximum possible memory usage by MYSQL.
cd /usr/local/bin
wget https://raw.githubusercontent.com/major/MySQLTuner-perl/master/mysqltuner.pl
chmod +x mysqltuner.pl
mysqltuner.pl > output.txt
MAX_RAM_MYSQL=$(cat output.txt | grep "Maximum possible memory usage" | awk '{print $6}')
echo "The Maximum RAM allocated for MySQL in the server $HOSTNAME : $MAX_RAM_MYSQL MB"


#Finding the amount of RAM used by the OS. For this we will be stopping apache and MySQL.
#Check whether the syntax is correct in Apache configuration and then proceed with stopping the service.
echo "+++++++++++++"
echo "Stopping $APACHE to calculate the amount of free memory"
echo "+++++++++++++"
apcachectl -t
output=$(apachectl -t | grep syantx | awk '{print $1 $2}')
if [ "$output"=='Syntax OK' ];then
/etc/init.d/$APACHE stop  > /dev/null > 2&>1
else
echo "Please check $APACHE configuration and correct it"
fi

echo "+++++++++++++"
echo "Stopping  MySQL to calculate the amount of free memory"
echo "+++++++++++++"
/etc/init.d/mysql stop > /dev/null  > 2&>1

#Calculate the memory used by OS
MEM_OS=$(ps aux | awk '{X +=$4}; END {print X}')
echo "The Maximum RAM allocated for OS in the server $HOSTNAME : $MEM_OS MB"

#Now start both the services again
echo "+++++++++++++"
echo "Starting $APACHE again"
echo "+++++++++++++"
/etc/init.d/$APACHE start > /dev/null > 2&>1
status=$(/etc/init.d/$APACHE status | grep Active | awk '{print $2}')
if [ "$status"== 'active' ];then
echo "$APACEHE has started successfully"
else 
echo "There seems to be some issue in starting the service please check"
fi

echo "+++++++++++++"
echo "Starting MySQL again"
echo "+++++++++++++"
/etc/init.d/mysql start > /dev/null > 2&>1
my_status=$(/etc/init.d/mysql status | grep -i active | awk '{print $2}')
if [ "$my_status"=='active' ];then
echo "MySQL has started successfully"
else
echo "There seems to be some issue in starting the service please check"
fi


#Now lets make the caclulations using the above values
MAX_CLIENTS=$((($TOTAL_RAM -($MAX_RAM_MYSQL+ $MEM_OS))/$AVG_PR_SIZE))
echo "The Max_clients value that is optimum for the server $HOSTNAME : $MAX_CLIENTS 

#We will aslo calculate the Minspareservers and Maxspareservers values for the server.
MINSPARESERVERS=$(expr $MAX_CLIENTS / 4)
MAXSPARESERVERS=$(expr $MAX_CLIENTS / 2)
echo "The minspareservers value for the server $HOSTNAME : $MINSPARESERVERS"
echo "The maxspareservers value for the server $HOSTNAME : $MAXSPARESERVERS"
