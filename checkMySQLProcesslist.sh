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
			echo "Usage: $0 [-h] [-H hostname] [-P port] [-u username] [-p password] \\"
			echo "		[-c limits] [-w limits]"
			echo "Source: github.com/tart/CheckMySQLProcesslist"
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
totalCriticalLimit=$(echo "$criticalLimits" | cut -d , -f 1)
totalWarningLimit=$(echo "$warningLimits" | cut -d , -f 1)
if [ "$totalCriticalLimit" ] && [ $total -ge $totalCriticalLimit ]
	then
	criticalString=$criticalString"connections are $total reached $totalCriticalLimit; "
elif [ "$totalWarningLimit" ] && [ $total -ge $totalWarningLimit ]
	then
	warningString=$warningString"connections are $total reached $totalWarningLimit; "
fi
performanceData=$performanceData"connections=$total;$totalWarningLimit;$totalCriticalLimit "

totalQueries=0
queriesRunningFor3600=0
queriesRunningFor600=0
queriesRunningFor60=0
queriesRunningFor10=0
longestQueryTime=0
queryProcesslist=$(echo "$processlist" | sed "/^[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\tNULL/d")
for queryTime in $(echo "$queryProcesslist" | cut -f 6)
	do
	totalQueries=$(expr $totalQueries + 1)
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

totalQueriesCriticalLimit=$(echo "$criticalLimits" | cut -d , -f 2 -s)
totalQueriesWarningLimit=$(echo "$warningLimits" | cut -d , -f 2 -s)
if [ "$totalCriticalLimit" ] && [ $totalQueries -ge $totalQueriesCriticalLimit ]
	then
	criticalString=$criticalString"$totalQueries queries reached $totalQueriesCriticalLimit; "
elif [ "$totalQueriesWarningLimit" ] && [ $totalQueries -ge $totalQueriesWarningLimit ]
	then
	warningString=$warningString"$totalQueries queries reached $totalQueriesWarningLimit; "
fi
performanceData=$performanceData"totalQueries=$totalQueries;$totalQueriesWarningLimit;$totalQueriesCriticalLimit "

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
