#!/bin/sh
 ##
 # Tart Database Operations
 # Check MySQL Processlist
 #
 # @author	Emre Hasegeli <emre.hasegeli@tart.com.tr>
 # @author	Mete Sıral <mete.siral@tart.com.tr>
 # @date	2011-11-03
 ##

scriptHelp()
{
	echo "Script to monitor MySQL processlist"
	echo "Usage:"
	echo "$0 [-H hostname] [-P port] [-u username] [-p password]"
	echo "Source:"
	echo "github.com/tart/CheckMySQLProcesslist"
}

connectionString=""
while getopts "H:P:u:p:" opt
	do
	case $opt in
		H )	connectionString="$connectionString --host=$OPTARG" ;;
		P )	connectionString="$connectionString --port $OPTARG" ;;
		u )	connectionString="$connectionString --user=$OPTARG" ;;
		p )	connectionString="$connectionString --password=$OPTARG" ;;
		\? )	scriptHelp
			echo "MySQLProcesslist unknown: wrongParameter"
			exit 3
	esac
done

processlist=$(mysql$connectionString --execute="Show processlist" mysql 2>> /var/log/checkMySQLProcesslist | sed 1d)
if [ ! "$processlist" ]
	then
	echo "MySQLProcesslist unknown: noProcesslist"
	exit 3
fi

total=$(echo "$processlist" | wc -l)
if [ $total -ge 377 ]
	then
	criticalString=$criticalString"connections are $total, more than 377; "
elif [ $total -ge 144 ]
	then
	warningString=$warningString"connections are $total, more than 144; "
fi
performanceData=$performanceData"connections=$total;144;377 "

totalQueries=0
queriesRunningForAnHour=0
queriesRunningFor10Minutes=0
queriesRunningForAMinute=0
queriesRunningFor10Seconds=0
for queryTime in $(echo "$processlist" | grep -P "\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]{5}" | cut -f 6)
	do
	totalQueries=$(expr $totalQueries + 1)
	if [ $queryTime -ge 3600 ]
		then
		queriesRunningForAnHour=$(expr $queriesRunningForAnHour + 1)
	elif [ $queryTime -ge 600 ]
		then
		queriesRunningFor10Minutes=$(expr $queriesRunningFor10Minutes + 1)
	elif [ $queryTime -ge 60 ]
		then
		queriesRunningForAMinute=$(expr $queriesRunningForAMinute + 1)
	elif [ $queryTime -ge 10 ]
		then
		queriesRunningFor10Seconds=$(expr $queriesRunningFor10Seconds + 1)
	fi
done

if [ $totalQueries -ge 55 ]
	then
	criticalString=$criticalString"total queries are $totalQueries, more than 55; "
elif [ $totalQueries -ge 21 ]
	then
	warningString=$warningString"total queries are $totalQueries, more than 21; "
fi
performanceData=$performanceData"totalQueries=$totalQueries;21;55 "

if [ $queriesRunningFor10Seconds -ge 21 ]
	then
	criticalString=$criticalString"queries running for 10 seconds are $queriesRunningFor10Seconds, more than 21; "
elif [ $queriesRunningFor10Seconds -ge 8 ]
	then
	warningString=$warningString"queries running for 10 seconds are $queriesRunningFor10Seconds, more than 8; "
fi
performanceData=$performanceData"queriesRunningFor10Seconds=$queriesRunningFor10Seconds;8;21 "

if [ $queriesRunningForAMinute -ge 8 ]
	then
	criticalString=$criticalString"queries running for a minute are $queriesRunningForAMinute, more than 8; "
elif [ $queriesRunningForAMinute -ge 3 ]
	then
	warningString=$warningString"queries running for a minute are $queriesRunningForAMinute, more than 3; "
fi
performanceData=$performanceData"queriesRunningForAMinute=$queriesRunningForAMinute;3;8 "

if [ $queriesRunningFor10Minutes -ge 3 ]
	then
	criticalString=$criticalString"queries running for 10 minutes are $queriesRunningFor10Minutes, more than 3; "
elif [ $queriesRunningFor10Minutes -ge 1 ]
	then
	warningString=$warningString"queries running for 10 minutes are $queriesRunningFor10Minutes, more than 1; "
fi
performanceData=$performanceData"queriesRunningFor10Minutes=$queriesRunningFor10Minutes;1;3 "

if [ $queriesRunningForAnHour -ge 1 ]
	then
	criticalString=$criticalString"queries running for an hour are $queriesRunningForAnHour, more than 1; "
fi
performanceData=$performanceData"queriesRunningForAnHour=$queriesRunningForAnHour;;1 "

query=$(echo "$processlist" | cut -f 5 | grep -c "Query")
performanceData=$performanceData"queringConnections=$query;; "

connect=$(echo "$processlist" | cut -f 5 | grep -c "Connect")
performanceData=$performanceData"connectiongConnections=$connect;; "

quit=$(echo "$processlist" | cut -f 5 | grep -c "Quit")
performanceData=$performanceData"quitingConnections=$quit;; "

prepare=$(echo "$processlist" | cut -f 5 | grep -c "Prepare")
performanceData=$performanceData"preparingConnections=$prepare;; "

fetch=$(echo "$processlist" | cut -f 5 | grep -c "Fetch")
performanceData=$performanceData"fetchingConnections=$fetch;; "

execute=$(echo "$processlist" | cut -f 5 | grep -c "Execute")
performanceData=$performanceData"executingConnections=$execute;; "

sleep=$(echo "$processlist" | cut -f 5 | grep -c "Sleep")
performanceData=$performanceData"sleepingConnections=$sleep;; "

delayedInsert=$(echo "$processlist" | cut -f 5 | grep -c "Delayed insert")
performanceData=$performanceData"delayedConnections=$delayedInsert;; "

if [ "$criticalString" ]
	then
	echo "MySQLProcesslist critical: $criticalString warning: $warningString| $performanceData"
	exit 2
fi

if [ "$warningString" ]
	then
	echo "MySQLProcesslist warning: $warningString| $performanceData"
	exit 1
fi

echo "MySQLProcesslist ok | $performanceData"
exit 0
