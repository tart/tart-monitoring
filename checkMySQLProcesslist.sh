#!/bin/sh
 ##
 # Tart Database Operations
 # Check MySQL Processlist
 #
 # @author	Emre Hasegeli <emre.hasegeli@tart.com.tr>
 # @author	Mete Sıral <mete.siral@tart.com.tr>
 # @date	2011-11-03
 ##

while getopts "H:P:u:p:h" opt 2>> /var/log/checkMySQLProcesslist
	do
	case $opt in
		H )	connectionString=$connectionString"--host=$OPTARG " ;;
		P )	connectionString=$connectionString"--port $OPTARG " ;;
		u )	connectionString=$connectionString"--user=$OPTARG " ;;
		p )	connectionString=$connectionString"--password=$OPTARG " ;;
		h )	echo "Script to monitor MySQL processlist"
			echo "Usage:"
			echo "$0 [-h] [-H hostname] [-P port] [-u username] [-p password]"
			echo "Source:"
			echo "github.com/tart/CheckMySQLProcesslist"
			exit 3 ;;
		\? )	echo "MySQLProcesslist unknown: wrongParameter"
			exit 3
	esac
done

processlist=$(mysql $connectionString--execute="Show processlist" mysql 2>> /var/log/checkMySQLProcesslist)
processlist=$(echo "$processlist" | sed 1d | sed "/^[0-9]*\tsystem user/d")
if [ ! "$processlist" ]
	then
	echo "MySQLProcesslist unknown: noProcesslist"
	exit 3
fi

total=$(echo "$processlist" | wc -l)
if [ $total -ge 377 ]
	then
	criticalString=$criticalString"connections are $total reached 377; "
elif [ $total -ge 144 ]
	then
	warningString=$warningString"connections are $total reached 144; "
fi
performanceData=$performanceData"connections=$total;144;377 "

totalQueries=0
queriesRunningForAnHour=0
queriesRunningFor10Minutes=0
queriesRunningForAMinute=0
queriesRunningFor10Seconds=0
longestQueryTime=0
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

	if [ $queryTime -ge $longestQueryTime ]
		then
		longestQueryTime=$queryTime
	fi
done

if [ $totalQueries -ge 55 ]
	then
	criticalString=$criticalString"total queries are $totalQueries reached 55; "
elif [ $totalQueries -ge 21 ]
	then
	warningString=$warningString"total queries are $totalQueries reached 21; "
fi
performanceData=$performanceData"totalQueries=$totalQueries;21;55 "

if [ $queriesRunningFor10Seconds -ge 21 ]
	then
	criticalString=$criticalString"queries running for 10 seconds are $queriesRunningFor10Seconds reached 21; "
elif [ $queriesRunningFor10Seconds -ge 8 ]
	then
	warningString=$warningString"queries running for 10 seconds are $queriesRunningFor10Seconds reached 8; "
fi
performanceData=$performanceData"queriesRunningFor10Seconds=$queriesRunningFor10Seconds;8;21 "

if [ $queriesRunningForAMinute -ge 8 ]
	then
	criticalString=$criticalString"queries running for a minute are $queriesRunningForAMinute reached 8; "
elif [ $queriesRunningForAMinute -ge 3 ]
	then
	warningString=$warningString"queries running for a minute are $queriesRunningForAMinute reached 3; "
fi
performanceData=$performanceData"queriesRunningForAMinute=$queriesRunningForAMinute;3;8 "

if [ $queriesRunningFor10Minutes -ge 3 ]
	then
	criticalString=$criticalString"queries running for 10 minutes are $queriesRunningFor10Minutes reached 3; "
elif [ $queriesRunningFor10Minutes -ge 1 ]
	then
	warningString=$warningString"queries running for 10 minutes are $queriesRunningFor10Minutes reached 1; "
fi
performanceData=$performanceData"queriesRunningFor10Minutes=$queriesRunningFor10Minutes;1;3 "

if [ $queriesRunningForAnHour -ge 1 ]
	then
	criticalString=$criticalString"queries running for an hour are $queriesRunningForAnHour reached 1; "
fi
performanceData=$performanceData"queriesRunningForAnHour=$queriesRunningForAnHour;;1 "

if [ $longestQueryTime -ge 60 ]
	then
	longestProcess=$(echo "$processlist" | grep -P "\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t$longestQueryTime\t[^\t]*\t[^\t]{5}")
	longestQueryString=$longestQueryString"id is $(echo "$longestProcess" | cut -f 1); "
	longestQueryString=$longestQueryString"user is $(echo "$longestProcess" | cut -f 2); "
	longestQueryString=$longestQueryString"host is $(echo "$longestProcess" | cut -f 3); "
	longestQueryString=$longestQueryString"schema is $(echo "$longestProcess" | cut -f 4); "
	longestQueryString=$longestQueryString"command is $(echo "$longestProcess" | cut -f 5); "
	longestQueryString=$longestQueryString"is running for $(echo "$longestProcess" | cut -f 6) seconds; "
	longestQueryString=$longestQueryString"state is $(echo "$longestProcess" | cut -f 7); "
	longestQueryString=$longestQueryString"executing \"$(echo "$longestProcess" | cut -f 8)\"; "
fi
performanceData=$performanceData"longestQueryTime=$longestQueryTime;; "

queringConnections=$(echo "$processlist" | cut -f 5 | grep -c "Query")
performanceData=$performanceData"queringConnections=$queringConnections;; "

connectiongConnections=$(echo "$processlist" | cut -f 5 | grep -c "Connect")
performanceData=$performanceData"connectiongConnections=$connectiongConnections;; "

quitingConnections=$(echo "$processlist" | cut -f 5 | grep -c "Quit")
performanceData=$performanceData"quitingConnections=$quitingConnections;; "

preparingConnections=$(echo "$processlist" | cut -f 5 | grep -c "Prepare")
performanceData=$performanceData"preparingConnections=$preparingConnections;; "

fetchingConnections=$(echo "$processlist" | cut -f 5 | grep -c "Fetch")
performanceData=$performanceData"fetchingConnections=$fetchingConnections;; "

executingConnections=$(echo "$processlist" | cut -f 5 | grep -c "Execute")
performanceData=$performanceData"executingConnections=$executingConnections;; "

sleepingConnections=$(echo "$processlist" | cut -f 5 | grep -c "Sleep")
performanceData=$performanceData"sleepingConnections=$sleepingConnections;; "

delayedConnections=$(echo "$processlist" | cut -f 5 | grep -c "Delayed insert")
performanceData=$performanceData"delayedConnections=$delayedConnections;; "

if [ "$criticalString" ]
	then
	echo -n "critical: $criticalString"
	if [ "$warningString" ]
		then
		echo -n "warning: $warningString"
	fi
	if [ "$longestQueryString" ]
		then
		echo -n "longest query: $longestQueryString"
	fi
	echo "| $performanceData"
	exit 2
fi

if [ "$warningString" ]
	then
	echo "warning: $warningString"
	if [ "$longestQueryString" ]
		then
		echo -n "longest query: $longestQueryString"
	fi
	echo "| $performanceData"
	exit 1
fi

echo "ok | $performanceData"
exit 0
