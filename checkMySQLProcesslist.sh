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

while getopts "H:P:u:p:h" opt
	do
	case $opt in
		H )	connectionString=$connectionString"--host=$OPTARG " ;;
		P )	connectionString=$connectionString"--port $OPTARG " ;;
		u )	connectionString=$connectionString"--user=$OPTARG " ;;
		p )	connectionString=$connectionString"--password=$OPTARG " ;;
		h )	echo "a script to monitor MySQL processlist"
			echo "Usage:"
			echo "$0 -h"
			echo "$0 [-H hostname] [-P port] [-u username] [-p password]"
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
		"Connect" )	connectiongConnections=$(expr $connectiongConnections + 1) ;;
		"Quit" )	quitingConnections=$(expr $quitingConnections + 1) ;;
		"Prepare" )	preparingConnections=$(expr $preparingConnections + 1) ;;
		"Fetch" )	fetchingConnections=$(expr $fetchingConnections + 1) ;;
		"Execute" )	executingConnections=$(expr $executingConnections + 1) ;;
		"Sleep" )	sleepingConnections=$(expr $sleepingConnections + 1) ;;
		"Delayed insert" )	delayedConnections=$(expr $delayedConnections + 1) ;;
	esac
done
if [ $connections -ge 377 ]
	then
	criticalString=$criticalString"$connections connections reached 377; "
elif [ $connections -ge 144 ]
	then
	warningString=$warningString"$connections connections reached 144; "
fi
performanceData=$performanceData"connections=$connections;144;377 "

performanceData=$performanceData"queringConnections=$queringConnections;; "
performanceData=$performanceData"connectiongConnections=$connectiongConnections;; "
performanceData=$performanceData"quitingConnections=$quitingConnections;; "
performanceData=$performanceData"preparingConnections=$preparingConnections;; "
performanceData=$performanceData"fetchingConnections=$fetchingConnections;; "
performanceData=$performanceData"executingConnections=$executingConnections;; "
performanceData=$performanceData"sleepingConnections=$sleepingConnections;; "
performanceData=$performanceData"delayedConnections=$delayedConnections;; "

queries=0
queriesRunningForAnHour=0
queriesRunningFor10Minutes=0
queriesRunningForAMinute=0
queriesRunningFor10Seconds=0
longestQueryTime=0
queryProcesslist=$(echo "$processlist" | sed "/^[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\tNULL/d")
for queryTime in $(echo "$queryProcesslist" | cut -f 6)
	do
	queries=$(expr $queries + 1)
	if [ $queryTime -ge 10 ]
		then
		queriesRunningFor10Seconds=$(expr $queriesRunningFor10Seconds + 1)
		if [ $queryTime -ge 60 ]
			then
			queriesRunningForAMinute=$(expr $queriesRunningForAMinute + 1)
			if [ $queryTime -ge 600 ]
				then
				queriesRunningFor10Minutes=$(expr $queriesRunningFor10Minutes + 1)
				if [ $queryTime -ge 3600 ]
					then
					queriesRunningForAnHour=$(expr $queriesRunningForAnHour + 1)
				fi
			fi
			if [ $queryTime -ge $longestQueryTime ]
				then
				longestQueryTime=$queryTime
			fi
		fi
	fi
done

if [ $queries -ge 55 ]
	then
	criticalString=$criticalString"$queries queries reached 55; "
elif [ $queries -ge 21 ]
	then
	warningString=$warningString"$queries queries reached 21; "
fi
performanceData=$performanceData"queries=$queries;21;55 "

if [ $queriesRunningFor10Seconds -ge 21 ]
	then
	criticalString=$criticalString"$queriesRunningFor10Seconds queries running for 10 seconds reached 21; "
elif [ $queriesRunningFor10Seconds -ge 8 ]
	then
	warningString=$warningString"$queriesRunningFor10Seconds queries running for 10 seconds reached 8; "
fi
performanceData=$performanceData"queriesRunningFor10Seconds=$queriesRunningFor10Seconds;8;21 "

if [ $queriesRunningForAMinute -ge 8 ]
	then
	criticalString=$criticalString"$queriesRunningForAMinute queries running for a minute reached 8; "
elif [ $queriesRunningForAMinute -ge 3 ]
	then
	warningString=$warningString"$queriesRunningForAMinute queries running for a minute reached 3; "
fi
performanceData=$performanceData"queriesRunningForAMinute=$queriesRunningForAMinute;3;8 "

if [ $queriesRunningFor10Minutes -ge 3 ]
	then
	criticalString=$criticalString"$queriesRunningFor10Minutes queries running for 10 minutes reached 3; "
elif [ $queriesRunningFor10Minutes -ge 1 ]
	then
	warningString=$warningString"$queriesRunningFor10Minutes queries running for 10 minutes reached 1; "
fi
performanceData=$performanceData"queriesRunningFor10Minutes=$queriesRunningFor10Minutes;1;3 "

if [ $queriesRunningForAnHour -ge 1 ]
	then
	criticalString=$criticalString"$queriesRunningForAnHour queries running for an hour reached 1; "
fi
performanceData=$performanceData"queriesRunningForAnHour=$queriesRunningForAnHour;;1 "

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
