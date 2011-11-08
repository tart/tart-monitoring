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
			echo "$0 [-h] [-H hostname] [-P port] [-u username] [-p password]"
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
queryProcesslist=$(echo "$processlist" | sed "/^[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\tNULL/d")
for queryTime in $(echo "$queryProcesslist" | cut -f 6)
	do
	totalQueries=$(expr $totalQueries + 1)
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

if [ $totalQueries -ge 55 ]
	then
	criticalString=$criticalString"$totalQueries queries reached 55; "
elif [ $totalQueries -ge 21 ]
	then
	warningString=$warningString"$totalQueries queries reached 21; "
fi
performanceData=$performanceData"totalQueries=$totalQueries;21;55 "

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
fi
if [ "$warningString" ]
	then
	echo -n "warning: $warningString"
fi
if [ ! "$criticalString" ] && [ ! "$warningString" ]
	then
	echo -n "ok: $(expr $total - 1) connections except this "
fi

if [ "$longestQueryString" ]
	then
	echo -n "longest query: $longestQueryString"
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
