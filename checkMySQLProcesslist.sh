#!/bin/bash
 ##
 # Tart Database Operations
 # Check MySQL Processlist
 #
 # @author	Emre Hasegeli <emre.hasegeli@tart.com.tr>
 # @author	Mete Sıral <mete.siral@tart.com.tr>
 # @date	2011-11-03
 ##

echo -n "CheckMySQLProcesslist "

while getopts "H:P:u:p:c:w:h" opt
	do
	case $opt in
		H )	connectionString=$connectionString"--host=$OPTARG " ;;
		P )	connectionString=$connectionString"--port $OPTARG " ;;
		u )	connectionString=$connectionString"--user=$OPTARG " ;;
		p )	connectionString=$connectionString"--password=$OPTARG " ;;
		c )	criticalLimits=$OPTARG ;;
		w )	warningLimits=$OPTARG ;;
		h )	echo "a script to monitor MySQL processlist"
			echo "Usage:"
			echo "$0 -h"
			echo "$0 [-H hostname] [-P port] [-u username] [-p password] \\"
			echo "		[-c limits] [-w limits]"
			echo "Source:"
			echo "github.com/tart/CheckMySQLProcesslist"
			exit 3 ;;
		\? )	echo "unknown: wrong parameter"
			exit 3
	esac
done

processlist=$(mysql $connectionString--execute="Show processlist" | sed 1d | sed "/^[^\t]*\tsystem user/d")
if [ ! "$processlist" ]
	then
	echo "unknown: no processlist"
	exit 3
fi

connections=0
queringConnections=0
connectiongConnections=0
quitingConnections=0
preparingConnections=0
fetchingConnections=0
executingConnections=0
sleepingConnections=0
delayedConnections=0
for state in $(echo "$processlist" | cut -f 5)
	do
	connections=$(expr $connections + 1)
	case $state in
		"Query" )	queringConnections=$(expr $queringConnections + 1) ;;
		"Connect" )	connectingConnections=$(expr $connectingConnections + 1) ;;
		"Quit" )	quitingConnections=$(expr $quitingConnections + 1) ;;
		"Prepare" )	preparingConnections=$(expr $preparingConnections + 1) ;;
		"Fetch" )	fetchingConnections=$(expr $fetchingConnections + 1) ;;
		"Execute" )	executingConnections=$(expr $executingConnections + 1) ;;
		"Sleep" )	sleepingConnections=$(expr $sleepingConnections + 1) ;;
		"Delayed insert" )	delayedConnections=$(expr $delayedConnections + 1) ;;
	esac
done

connections=$(echo "$processlist" | wc -l)
connectionsCriticalLimit=$(echo "$criticalLimits" | cut -d , -f 1)
connectionsWarningLimit=$(echo "$warningLimits" | cut -d , -f 1)
if [ "$connectionsCriticalLimit" ] && [ $connections -ge $connectionsCriticalLimit ]
	then
	criticalString=$criticalString"connections are $connections reached $connectionsCriticalLimit; "
elif [ "$connectionsWarningLimit" ] && [ $connections -ge $connectionsWarningLimit ]
	then
	warningString=$warningString"connections are $connections reached $connectionsWarningLimit; "
fi
performanceData=$performanceData"connections=$connections;$connectionsWarningLimit;$connectionsCriticalLimit "



queries=0
queriesRunningFor10=0
queriesRunningFor60=0
queriesRunningFor600=0
queriesRunningFor3600=0
longestQueryTime=0
queryProcesslist=$(echo "$processlist" | sed "/^[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\tNULL/d")
for queryTime in $(echo "$queryProcesslist" | cut -f 6)
	do
	queries=$(expr $queries + 1)
	if [ $queryTime -gt 10 ]
		then
		queriesRunningFor10=$(expr $queriesRunningFor10 + 1)
		if [ $queryTime -gt 60 ]
			then
			queriesRunningFor60=$(expr $queriesRunningFor60 + 1)
			if [ $queryTime -gt 600 ]
				then
				queriesRunningFor600=$(expr $queriesRunningFor600 + 1)
				if [ $queryTime -gt 3600 ]
					then
					queriesRunningFor3600=$(expr $queriesRunningFor3600 + 1)
				fi
			fi
			if [ $queryTime -gt $longestQueryTime ]
				then
				longestQueryTime=$queryTime
			fi
		fi
	fi
done

queriesCriticalLimit=$(echo "$criticalLimits" | cut -d , -f 2 -s)
queriesWarningLimit=$(echo "$warningLimits" | cut -d , -f 2 -s)
if [ "$queriesCriticalLimit" ] && [ $queries -ge $queriesCriticalLimit ]
	then
	criticalString=$criticalString"$queries queries reached $queriesCriticalLimit; "
elif [ "$totalQueriesWarningLimit" ] && [ $totalQueries -ge $queriesWarningLimit ]
	then
	warningString=$warningString"$queries queries reached $queriesWarningLimit; "
fi
performanceData=$performanceData"queries=$queries;$queriesWarningLimit;$queriesCriticalLimit "

queriesRunningFor10CriticalLimit=$(echo "$criticalLimits" | cut -d , -f 3 -s)
queriesRunningFor10WarningLimit=$(echo "$warningLimits" | cut -d , -f 3 -s)
if [ "$queriesRunningFor10CriticalLimit" ] && [ $queriesRunningFor10 -ge $queriesRunningFor10CriticalLimit ]
	then
	criticalString=$criticalString"$queriesRunningFor10CriticalLimit queries running for 10 seconds reached $queriesRunningFor10CriticalLimit; "
elif [ "$queriesRunningFor10WarningLimit" ] && [ $queriesRunningFor10 -ge $queriesRunningFor10WarningLimit ]
	then
	warningString=$warningString"$queriesRunningFor10 queries running for 10 seconds reached $queriesRunningFor10WarningLimit; "
fi
performanceData=$performanceData"queriesRunningFor10Seconds=$queriesRunningFor10;$queriesRunningFor10WarningLimit;$queriesRunningFor10CriticalLimit "

queriesRunningFor60CriticalLimit=$(echo "$criticalLimits" | cut -d , -f 4 -s)
queriesRunningFor60WarningLimit=$(echo "$warningLimits" | cut -d , -f 4 -s)
if [ "$queriesRunningFor60CriticalLimit" ] && [ $queriesRunningFor60 -ge $queriesRunningFor60CriticalLimit ]
	then
	criticalString=$criticalString"$queriesRunningFor60 queries running for a minute reached $queriesRunningFor60CriticalLimit; "
elif [ "$queriesRunningFor60WarningLimit" ] && [ $queriesRunningFor60 -ge $queriesRunningFor60WarningLimit ]
	then
	warningString=$warningString"$queriesRunningFor60 queries running for a minute reached $queriesRunningFor60WarningLimit; "
fi
performanceData=$performanceData"queriesRunningFor60=$queriesRunningFor60;$queriesRunningFor60WarningLimit;$queriesRunningFor60CriticalLimit "

queriesRunningFor600CriticalLimit=$(echo "$criticalLimits" | cut -d , -f 5 -s)
queriesRunningFor600WarningLimit=$(echo "$warningLimits" | cut -d , -f 5 -s)
if [ "$queriesRunningFor600CriticalLimit" ] && [ $queriesRunningFor600 -ge $queriesRunningFor600CriticalLimit ]
	then
	criticalString=$criticalString"$queriesRunningFor600 queries running for 10 minutes reached $queriesRunningFor600CriticalLimit; "
elif [ "$queriesRunningFor600WarningLimit" ] && [ $queriesRunningFor600 -ge $queriesRunningFor600WarningLimit ]
	then
	warningString=$warningString"$queriesRunningFor600 queries running for 10 minutes reached $queriesRunningFor600WarningLimit; "
fi
performanceData=$performanceData"queriesRunningFor600=$queriesRunningFor600;$queriesRunningFor600WarningLimit;$queriesRunningFor600CriticalLimit "

queriesRunningFor3600CriticalLimit=$(echo "$criticalLimits" | cut -d , -f 6 -s)
queriesRunningFor3600WarningLimit=$(echo "$warningLimits" | cut -d , -f 6 -s)
if [ "$queriesRunningFor3600CriticalLimit" ] && [ $queriesRunningFor3600 -ge $queriesRunningFor3600CriticalLimit ]
	then
	criticalString=$criticalString"$queriesRunningFor3600 queries running for an hour reached $queriesRunningFor3600CriticalLimit; "
elif [ "$queriesRunningFor3600WarningLimit" ] && [ $queriesRunningFor3600 -ge $queriesRunningFor3600WarningLimit ]
	then
	warningString=$warningString"$queriesRunningFor3600 queries running for an hour reached $queriesRunningFor3600WarningLimit; "
fi
performanceData=$performanceData"queriesRunningFor3600=$queriesRunningFor3600;$queriesRunningFor3600WarningLimit;$queriesRunningFor3600CriticalLimit "

if [ $longestQueryTime -gt 0 ]
	then
	longestProcess=$(echo "$queryProcesslist" | grep -P "^[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t$longestQueryTime")
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

performanceData=$performanceData"queringConnections=$queringConnections;; "
performanceData=$performanceData"connectingConnections=$connectingConnections;; "
performanceData=$performanceData"quitingConnections=$quitingConnections;; "
performanceData=$performanceData"preparingConnections=$preparingConnections;; "
performanceData=$performanceData"fetchingConnections=$fetchingConnections;; "
performanceData=$performanceData"executingConnections=$executingConnections;; "
performanceData=$performanceData"sleepingConnections=$sleepingConnections;; "
performanceData=$performanceData"delayedConnections=$delayedConnections;; "

if [ "$criticalString" ]
	then
	echo -n "critical: $criticalString"
fi
if [ "$warningString" ]
	then
	echo -n "warning: $warningString"
fi
if [ ! "$criticalString" ] && [ ! "$warningString" ]
	then
	echo -n "ok: $(expr $connections - 1) connections except this; "
fi

if [ "$longestQueryString" ]
	then
	echo -n "longest query: $longestQueryString"
else
	echo -n "no query running for a minute; "
fi
echo "| $performanceData"

if [ "$criticalString" ]
	then
	exit 2
fi
if [ "$warningString" ]
	then
	exit 1
fi
exit 0
