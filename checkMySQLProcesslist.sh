#!/bin/sh
 ##
 # Tart Database Operations
 # Check MySQL Processlist
 #
 # @author      Emre Hasegeli <emre.hasegeli@tart.com.tr>
 # @author      Mete Sıral <mete.siral@tart.com.tr>
 # @date        2011-11-03
 ##

usage()
{
	echo "Script to monitor MySQL processlist"
	echo "Usage:"
	echo $0" [-H hostname] [-P port] [-u username] [-p password]"
        exit 3
}

connectionString=""
while getopts "H:P:u:p:" opt
	do
		case $opt in
		        H )	connectionString=$connectionString" --host=$OPTARG" ;;
		        P )	connectionString=$connectionString" --port $OPTARG" ;;
		        u )	connectionString=$connectionString" --user=$OPTARG" ;;
		        p )	connectionString=$connectionString" --password=$OPTARG" ;;
		        \?|h )	usage
		        	exit 3
		esac
	done
processlist=$(mysql$connectionString --execute="Show processlist" mysql)

criticalString=""
warningString=""
performanceData=""

total=$(echo "${processlist}"  | sed 1d | wc -l)
if [ $total -gt 377 ]
	then
	criticalString=$criticalString" connections="$total
elif [ $total -gt 144 ]
	then
	warningString=$warningString" connections="$total
fi
performanceData=$performanceData" connections="$total";144;377"

totalQuery=$(echo "${processlist}" | sed 1d | grep -P "\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]{5}" | wc -l)
if [ $total -gt 55 ]
	then
	criticalString=$criticalString" queries="$totalQuery
elif [ $total -gt 21 ]
	then
	warningString=$warningString" queries="$totalQuery
fi
performanceData=$performanceData" queries="$totalQuery";21;55"

longQuery=0
for time in $(echo "${processlist}" | sed 1d | grep -P "\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]{5}" | cut -f 6)
	do
	if [ $time -gt 10 ]
		then
		longQuery=$(expr $longQuery + 1)
		fi
	done
if [ $longQuery -gt 21 ]
	then
	criticalString=$criticalString" queriesRunningMoreThan10Seconds="$longQuery
elif [ $longQuery -gt 8 ]
	then
	warningString=$warningString" queriesRunningMoreThan10Seconds="$longQuery
fi
performanceData=$performanceData" queriesRunningMoreThan10Seconds="$longQuery";8;21"

longQuery=0
for time in $(echo "${processlist}" | sed 1d | grep -P "\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]{5}" | cut -f 6)
	do
	if [ $time -gt 60 ]
		then
		longQuery=$(expr $longQuery + 1)
		fi
	done
if [ $longQuery -gt 8 ]
	then
	criticalString=$criticalString" queriesRunningMoreThanAMinute="$longQuery
elif [ $longQuery -gt 3 ]
	then
	warningString=$warningString" queriesRunningMoreThanAMinute="$longQuery
fi
performanceData=$performanceData" queriesRunningMoreThanAMinute="$longQuery";3;8"

longQuery=0
for time in $(echo "${processlist}" | sed 1d | grep -P "\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]{5}" | cut -f 6)
	do
	if [ $time -gt 600 ]
		then
		longQuery=$(expr $longQuery + 1)
		fi
	done
if [ $longQuery -gt 3 ]
	then
	criticalString=$criticalString" queriesRunningMoreThan10Minutes="$longQuery
elif [ $longQuery -gt 1 ]
	then
	warningString=$warningString" queriesRunningMoreThan10Minutes="$longQuery
fi
performanceData=$performanceData" queriesRunningMoreThan10Minutes="$longQuery";3;8"

longQuery=0
for time in $(echo "${processlist}" | sed 1d | grep -P "\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]{5}" | cut -f 6)
	do
	if [ $time -gt 3600 ]
		then
		longQuery=$(expr $longQuery + 1)
		fi
	done
if [ $longQuery -gt 1 ]
	then
	criticalString=$criticalString" queriesRunningMoreThanAHour="$longQuery
fi
performanceData=$performanceData" queriesRunningMoreThanAHour="$longQuery";;1"

query=$(echo "${processlist}" | sed 1d | cut -f 5 | grep -c "Query")
performanceData=$performanceData" queringConnections="$query

connect=$(echo "${processlist}" | sed 1d | cut -f 5 | grep -c "Connect")
performanceData=$performanceData" connectiongConnections="$connect

quit=$(echo "${processlist}" | sed 1d | cut -f 5 | grep -c "Quit")
performanceData=$performanceData" quitingConnections="$quit

prepare=$(echo "${processlist}" | sed 1d | cut -f 5 | grep -c "Prepare")
performanceData=$performanceData" preparingConnections="$prepare

fetch=$(echo "${processlist}" | sed 1d | cut -f 5 | grep -c "Fetch")
performanceData=$performanceData" fetchingConnections="$fetch

execute=$(echo "${processlist}" | sed 1d | cut -f 5 | grep -c "Execute")
performanceData=$performanceData" executingConnections="$execute

sleep=$(echo "${processlist}" | sed 1d | cut -f 5 | grep -c "Sleep")
performanceData=$performanceData" sleepingConnections="$sleep

delayedInsert=$(echo "${processlist}" | sed 1d | cut -f 5 | grep -c "Delayed insert")
performanceData=$performanceData" delayedConnections="$delayedInsert

if [ ! $cricalString = "" ]
	then
	echo "MySQLProcesslist CRITICAL "$criticalString$warningString" |"$performanceData
	exit 2
	fi
if [ ! $warningString = "" ]
	then
	echo "MySQLProcesslist WARNING "$warningString" |"$performanceData
	exit 1
	fi
echo "MySQLProcesslist OK |"$performanceData
exit 0

