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

#
# Fetching the parameters
#

while getopts "H:P:u:p:c:w:h" opt; do
	case $opt in
		H )	connectionString=$connectionString"--host=$OPTARG " ;;
		P )	connectionString=$connectionString"--port $OPTARG " ;;
		u )	connectionString=$connectionString"--user=$OPTARG " ;;
		p )	connectionString=$connectionString"--password=$OPTARG " ;;
		c )	criticalLimitsArray=(${criticalLimitsArray[*]} $OPTARG) ;;
		w )	warningLimitsArray=(${warningLimitsArray[*]} $OPTARG) ;;
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

#
# Querying the database
#

processlist=$(mysql $connectionString--execute="Show processlist" | sed 1d | sed "/^[^\t]*\tsystem user/d")
if [ ! "$processlist" ]; then
	echo "unknown: no processlist"
	exit 3
fi

globalVariables=$(mysql $connectionString--execute="Show global variables")
if [ ! "$globalVariables" ]; then
	echo "unknown: no global variables"
	exit 3
fi

#
# Parsing the resources
#

connections=0
queringConnections=0
connectiongConnections=0
quitingConnections=0
preparingConnections=0
fetchingConnections=0
executingConnections=0
sleepingConnections=0
delayedConnections=0
for state in $(echo "$processlist" | cut -f 5); do
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
	
queries=0
queriesRunningFor10=0
queriesRunningFor60=0
queriesRunningFor600=0
queriesRunningFor3600=0
longestQueryTime=0
queryProcesslist=$(echo "$processlist" | sed "/^[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\tNULL/d")
for queryTime in $(echo "$queryProcesslist" | cut -f 6); do
	queries=$(expr $queries + 1)
	if [ $queryTime -gt 10 ]; then
		queriesRunningFor10=$(expr $queriesRunningFor10 + 1)
		if [ $queryTime -gt 60 ]; then
			queriesRunningFor60=$(expr $queriesRunningFor60 + 1)
			if [ $queryTime -gt 600 ]; then
				queriesRunningFor600=$(expr $queriesRunningFor600 + 1)
				if [ $queryTime -gt 3600 ]; then
					queriesRunningFor3600=$(expr $queriesRunningFor3600 + 1)
				fi
			fi
			if [ $queryTime -gt $longestQueryTime ]; then
				longestQueryTime=$queryTime
			fi
		fi
	fi
done

maxConnections=$(echo "$globalVariables" | grep max_connections | cut -f 2)
interactiveTimeout=$(echo "$globalVariables" | grep interactive_timeout | cut -f 2)

id=0
for criticalLimits in ${criticalLimitsArray[*]}; do
	for criticalLimit in $(echo "$criticalLimits" | sed "s/,/ /g"); do
		criticalLimitPercent=$(echo "$criticalLimit" | grep % | sed "s/%//")
		if [ "$criticalLimitPercent" ]; then
			criticalLimitArray[$id]=$(expr $maxConnections"00" / $(expr 10000 / $criticalLimit))
		else
			criticalLimitArray[$id]=$criticalLimit
		fi
		id=$(expr $id + 1)
	done
done

id=0
for warningLimits in ${warningLimitsArray[*]}; do
	for warningLimit in $(echo "$warningLimits" | sed "s/,/ /g"); do
		warningLimitPercent=$(echo "$warningLimit" | grep % | sed "s/%//")
		if [ "$warningLimitPercent" ]; then
			warningLimitArray[$id]=$(expr $maxConnections"00" / $(expr 10000 / $warningLimit))
		else
			warningLimitArray[$id]=$warningLimit
		fi
		id=$(expr $id + 1)
	done
done

#
# Preparing the output
#

if [ ${criticalLimitArray[0]} ] && [ $connections -ge ${criticalLimitArray[0]} ]; then
	criticalString=$criticalString"$connections connections of $maxConnections reached ${criticalLimitArray[0]}; "
elif [ ${warningLimitArray[0]} ] && [ $connections -ge ${warningLimitArray[0]} ]; then
	warningString=$warningString"$connections connections of $maxConnections reached ${warningLimitArray[0]}; "
fi
okString=$okString"$connections connections of $maxConnections; "
performanceData=$performanceData"connections=$connections;${warningLimitArray[0]};${criticalLimitArray[0]};0;$maxConnections "

if [ ${criticalLimitArray[1]} ] && [ $queries -ge ${criticalLimitArray[1]} ]; then
	criticalString=$criticalString"$queries queries reached ${criticalLimitArray[1]}; "
elif [ ${warningLimitArray[1]} ] && [ $queries -ge ${warningLimitArray[1]} ]; then
	warningString=$warningString"$queries queries reached ${warningLimitArray[1]}; "
fi
performanceData=$performanceData"queries=$queries;${warningLimitArray[1]};${criticalLimitArray[1]};0;$maxConnections "

if [ ${criticalLimitArray[2]} ] && [ $queriesRunningFor10 -ge ${criticalLimitArray[2]} ]; then
	criticalString=$criticalString"${criticalLimitArray[2]} queries running for 10 seconds reached ${criticalLimitArray[2]}; "
elif [ ${warningLimitArray[2]} ] && [ $queriesRunningFor10 -ge ${warningLimitArray[2]} ]; then
	warningString=$warningString"$queriesRunningFor10 queries running for 10 seconds reached ${warningLimitArray[2]}; "
fi
performanceData=$performanceData"queriesRunningFor10Seconds=$queriesRunningFor10;${warningLimitArray[2]};${criticalLimitArray[2]};0;$maxConnections "

if [ ${criticalLimitArray[3]} ] && [ $queriesRunningFor60 -ge ${criticalLimitArray[3]} ]; then
	criticalString=$criticalString"$queriesRunningFor60 queries running for a minute reached ${criticalLimitArray[3]}; "
elif [ ${warningLimitArray[3]} ] && [ $queriesRunningFor60 -ge ${warningLimitArray[3]} ]; then
	warningString=$warningString"$queriesRunningFor60 queries running for a minute reached ${warningLimitArray[3]}; "
fi
performanceData=$performanceData"queriesRunningFor60=$queriesRunningFor60;${warningLimitArray[3]};${criticalLimitArray[3]};0;$maxConnections "

if [ ${criticalLimitArray[4]} ] && [ $queriesRunningFor600 -ge ${criticalLimitArray[4]} ]; then
	criticalString=$criticalString"$queriesRunningFor600 queries running for 10 minutes reached ${criticalLimitArray[4]}; "
elif [ ${warningLimitArray[4]} ] && [ $queriesRunningFor600 -ge ${warningLimitArray[4]} ]; then
	warningString=$warningString"$queriesRunningFor600 queries running for 10 minutes reached ${warningLimitArray[4]}; "
fi
performanceData=$performanceData"queriesRunningFor600=$queriesRunningFor600;${warningLimitArray[4]};${criticalLimitArray[4]};0;$maxConnections "

if [ ${criticalLimitArray[5]} ] && [ $queriesRunningFor3600 -ge ${criticalLimitArray[5]} ]; then
	criticalString=$criticalString"$queriesRunningFor3600 queries running for an hour reached ${criticalLimitArray[5]}; "
elif [ ${warningLimitArray[5]} ] && [ $queriesRunningFor3600 -ge ${warningLimitArray[5]} ]; then
	warningString=$warningString"$queriesRunningFor3600 queries running for an hour reached ${warningLimitArray[5]}; "
fi
performanceData=$performanceData"queriesRunningFor3600=$queriesRunningFor3600;${warningLimitArray[5]};${criticalLimitArray[5]};0;$maxConnections "

performanceData=$performanceData"queringConnections=$queringConnections;;;0;$maxConnections "
performanceData=$performanceData"connectingConnections=$connectingConnections;;;0;$maxConnections "
performanceData=$performanceData"quitingConnections=$quitingConnections;;;0;$maxConnections "
performanceData=$performanceData"preparingConnections=$preparingConnections;;;0;$maxConnections "
performanceData=$performanceData"fetchingConnections=$fetchingConnections;;;0;$maxConnections "
performanceData=$performanceData"executingConnections=$executingConnections;;;0;$maxConnections "
performanceData=$performanceData"sleepingConnections=$sleepingConnections;;;0;$maxConnections "
performanceData=$performanceData"delayedConnections=$delayedConnections;;;0;$maxConnections "

if [ $longestQueryTime -gt 0 ]; then
	longestProcess=$(echo "$queryProcesslist" | grep -P "^[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t$longestQueryTime")
	longestQueryString=$longestQueryString"id is $(echo "$longestProcess" | cut -f 1); "
	longestQueryString=$longestQueryString"user is $(echo "$longestProcess" | cut -f 2); "
	longestQueryString=$longestQueryString"host is $(echo "$longestProcess" | cut -f 3); "
	longestQueryString=$longestQueryString"schema is $(echo "$longestProcess" | cut -f 4); "
	longestQueryString=$longestQueryString"command is $(echo "$longestProcess" | cut -f 5); "
	longestQueryString=$longestQueryString"is running for $(echo "$longestProcess" | cut -f 6) seconds; "
	longestQueryString=$longestQueryString"state is $(echo "$longestProcess" | cut -f 7); "
	longestQueryString=$longestQueryString"executing \"$(echo "$longestProcess" | cut -f 8)\"; "
else
	okString=$okString"no query running for a minute; "
fi
performanceData=$performanceData"longestQueryTime=$longestQueryTime;;0;$interactiveTimeout "

#
# Quiting
#

if [ "$criticalString" ]; then
	echo -n "critical: $criticalString"
fi
if [ "$warningString" ]; then
	echo -n "warning: $warningString"
fi
if [ ! "$criticalString" ] && [ ! "$warningString" ]; then
	echo -n "ok: $okString"
fi

if [ "$longestQueryString" ]; then
	echo -n "longest query: $longestQueryString"
fi
echo "| $performanceData"

if [ "$criticalString" ]; then
	exit 2
fi
if [ "$warningString" ]; then
	exit 1
fi
exit 0
