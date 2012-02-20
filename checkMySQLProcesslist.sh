#!/bin/bash
 ##
 # Tart Database Operations
 # Check MySQL Processlist
 #
 # @author    Emre Hasegeli <emre.hasegeli@tart.com.tr>
 # @date    2011-11-03
 ##

echo -n "CheckMySQLProcesslist "

#
# Fetching the parameters
#

while getopts "H:P:u:p:s:c:w:qh" opt; do
    case $opt in
        H )  connectionString=$connectionString"--host=$OPTARG " ;;
        P )  connectionString=$connectionString"--port $OPTARG " ;;
        u )  connectionString=$connectionString"--user=$OPTARG " ;;
        p )  connectionString=$connectionString"--password=$OPTARG " ;;
        s )  secondsArray=(${secondsArray[*]} $OPTARG) ;;
        c )  criticalLimitsArray=(${criticalLimitsArray[*]} $OPTARG) ;;
        w )  warningLimitsArray=(${warningLimitsArray[*]} $OPTARG) ;;
        q )  queryMode=1 ;;
        h )  echo "a script to monitor MySQL processlist"
             echo "Usage:"
             echo "$0 -h"
             echo "$0 [-H hostname] [-P port] [-u username] [-p password] \\"
             echo "        [-q] [-s seconds] [-w limits] [-c limits]"
             echo "Source:"
             echo "github.com/tart/CheckMySQLProcesslist"
             exit 3 ;;
        \? ) echo "unknown: wrong parameter"
             exit 3
    esac
done

if [ ! "$secondsArray" ]; then
    secondsArray=(0)
fi

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

maxConnections=$(echo "$globalVariables" | grep ^max_connections | cut -f 2)
if [ $queryMode ]; then
    timeout=$(echo "$globalVariables" | grep ^interactive_timeout | cut -f 2)
else
    timeout=$(echo "$globalVariables" | grep ^wait_timeout | cut -f 2)
fi

id=0
for seconds in ${secondsArray[*]}; do
    for second in $(echo $seconds | sed "s/,/ /g"); do
        secondPercent=$(echo $second | grep % | sed "s/%//")
        if [ $secondPercent ]; then
            secondArray[$id]=$[$[$timeout*$secondPercent]/100]
        elif [ $second ]; then
            secondArray[$id]=$second
        fi
        id=$[$id+1]

        if [ ! $shortestSecond ] || [ $second -lt $shortestSecond ]; then
            shortestSecond=$second
        fi
    done
done

id=0
for criticalLimits in ${criticalLimitsArray[*]}; do
    for criticalLimit in $(echo $criticalLimits | sed "s/,/ /g"); do
        criticalLimitPercent=$(echo $criticalLimit | grep % | sed "s/%//")
        if [ $criticalLimitPercent ]; then
            criticalLimitArray[$id]=$[$[$maxConnections*$criticalLimitPercent]/100]
        else
            criticalLimitArray[$id]=$criticalLimit
        fi
        id=$[$id+1]
    done
done

id=0
for warningLimits in ${warningLimitsArray[*]}; do
    for warningLimit in $(echo $warningLimits | sed "s/,/ /g"); do
        warningLimitPercent=$(echo $warningLimit | grep % | sed "s/%//")
        if [ $warningLimitPercent ]; then
            warningLimitArray[$id]=$[$[$maxConnections*$warningLimitPercent]/100]
        else
            warningLimitArray[$id]=$warningLimit
        fi
        id=$[$id+1]
    done
done

for id in ${!secondArray[*]}; do
    countArray[$id]=0
done

if [ $queryMode ]; then
    processlist=$(echo "$processlist" | sed "/^[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\tNULL/d")
fi

for time in $(echo "$processlist" | cut -f 6); do
    for id in ${!secondArray[*]}; do
        if [ $time -ge ${secondArray[$id]} ]; then
            countArray[$id]=$[${countArray[$id]}+1]
        fi
    done

    if [ ! $longestTime ] || [ $time -gt $longestTime ]; then
        longestTime=$time
    fi
done

if [ ! $queryMode ]; then
    unauthenticatedConnections=0
    for user in $(echo "$processlist" | cut -f 2); do
        case $user in
            "unauthenticated user") unauthenticatedConnections=$[$unauthenticatedConnections+1] ;;
        esac
    done

    queringConnections=0
    connectiongConnections=0
    fetchingConnections=0
    executingConnections=0
    sleepingConnections=0
    for command in $(echo "$processlist" | cut -f 5); do
        case $command in
            "Query") queringConnections=$[$queringConnections+1] ;;
            "Connect") connectingConnections=$[$connectingConnections+1] ;;
            "Fetch") fetchingConnections=$[$fetchingConnections+1] ;;
            "Execute") executingConnections=$[$executingConnections+1] ;;
            "Sleep") sleepingConnections=$[$sleepingConnections+1] ;;
        esac
    done
fi

if [ $queryMode ]; then
    tempTableUsingQueries=0
    preparingQueries=0
    sortingQueries=0
    lockedQueries=0
    returningQueries=0
    for state in $(echo "$processlist" | cut -f 7); do
        case $state in
            "Copying to group table") tempTableUsingQueries=$[$tempTableUsingQueries+1] ;;
            "Copying to tmp table") tempTableUsingQueries=$[$tempTableUsingQueries+1] ;;
            "Copying to tmp table on disk") tempTableUsingQueries=$[$tempTableUsingQueries+1] ;;
            "Creating tmp table") tempTableUsingQueries=$[$tempTableUsingQueries+1] ;;
            "optimizing") preparingQueries=$[$preparingQueries+1] ;;
            "preparing") preparingQueries=$[$preparingQueries+1] ;;
            "statistics") preparingQueries=$[$preparingQueries+1] ;;
            "Sorting for group") sortingQueries=$[$sortingQueries+1] ;;
            "Sorting for order") sortingQueries=$[$sortingQueries+1] ;;
            "Sorting index") sortingQueries=$[$sortingQueries+1] ;;
            "Sorting result") sortingQueries=$[$sortingQueries+1] ;;
            "Locked") lockedQueries=$[$lockedQueries+1] ;;
            "System lock") lockedQueries=$[$lockedQueries+1] ;;
            "Table lock") lockedQueries=$[$lockedQueries+1] ;;
            "Waiting for commit lock") lockedQueries=$[$lockedQueries+1] ;;
            "Waiting for global read lock") lockedQueries=$[$lockedQueries+1] ;;
            "Waiting for table level lock") lockedQueries=$[$lockedQueries+1] ;;
            "Waiting for event metadata lock") lockedQueries=$[$lockedQueries+1] ;;
            "Waiting for schema metadata lock") lockedQueries=$[$lockedQueries+1] ;;
            "Waiting for stored function metadata lock") lockedQueries=$[$lockedQueries+1] ;;
            "Waiting for stored procedure metadata lock") lockedQueries=$[$lockedQueries+1] ;;
            "Waiting for table metadata lock") lockedQueries=$[$lockedQueries+1] ;;
            "Waiting for trigger metadata lock") lockedQueries=$[$lockedQueries+1] ;;
            "Sending data") returningQueries=$[$returningQueries+1] ;;
            "Writing to net") returningQueries=$[$returningQueries+1] ;;
        esac
    done
fi

#
# Preparing the output
#

for id in ${!secondArray[*]}; do
    second=${secondArray[$id]}
    if [ $queryMode ]; then
        title="${countArray[$id]} queries"
        performanceData=$performanceData"queries"
    else
        title="${countArray[$id]} connections"
        performanceData=$performanceData"connections"
    fi
    

    if [ $second == 0 ]; then
        title=$title" of $maxConnections"
    else
        title=$title" active for"
        performanceData=$performanceData"ActiveFor$second"
        if [ $second == 3600 ]; then
            title=$title" an hour"
        elif [ $[$second%3600] == 0 ]; then
            title=$title" $[$second/3600] hours"
        elif [ $second == 60 ]; then
            title=$title" a minute"
        elif [ $[$second%60] == 0 ]; then
            title=$title" $[$second/60] minutes"
        elif [ second == 1 ]; then
            title=$title" a second"
        else
            title=$title" $second seconds"
        fi
    fi
    performanceData=$performanceData"=${countArray[$id]};${warningLimitArray[$id]};${criticalLimitArray[$id]};0;$maxConnections "

    if [ ${criticalLimitArray[$id]} ] && [ ${countArray[$id]} -ge ${criticalLimitArray[$id]} ]; then
        criticalString=$criticalString"$title reached ${criticalLimitArray[$id]}; "
    elif [ ${warningLimitArray[$id]} ] && [ ${countArray[$id]} -ge ${warningLimitArray[$id]} ]; then
        warningString=$warningString"$title reached ${warningLimitArray[$id]}; "
    elif [ $second == $shortestSecond ]; then
        okString="$title; "
    fi
done

if [ ! $queryMode ]; then
    performanceData=$performanceData"unauthenticatedConnections=$unauthenticatedConnections;;;0;$maxConnections "
    performanceData=$performanceData"queringConnections=$queringConnections;;;0;$maxConnections "
    performanceData=$performanceData"connectingConnections=$connectingConnections;;;0;$maxConnections "
    performanceData=$performanceData"fetchingConnections=$fetchingConnections;;;0;$maxConnections "
    performanceData=$performanceData"executingConnections=$executingConnections;;;0;$maxConnections "
    performanceData=$performanceData"sleepingConnections=$sleepingConnections;;;0;$maxConnections "
fi

if [ $queryMode ]; then
    performanceData=$performanceData"tempTableUsingQueries=$tempTableUsingQueries;;;0;$maxConnections "
    performanceData=$performanceData"preparingQueries=$preparingQueries;;;0;$maxConnections "
    performanceData=$performanceData"sortingQueries=$sortingQueries;;;0;$maxConnections "
    performanceData=$performanceData"lockedQueries=$lockedQueries;;;0;$maxConnections "
    performanceData=$performanceData"returningQueries=$returningQueries;;;0;$maxConnections "

	if [ $longestTime -gt 0 ]; then
	    longestQuery=$(echo "$processlist" | grep -P "^[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t$longestTime" | head -n 1)
	    longestQueryString=$longestQueryString"time is $(echo "$longestQuery" | cut -f 6); "
	    longestQueryString=$longestQueryString"id is $(echo "$longestQuery" | cut -f 1); "
	    longestQueryString=$longestQueryString"user is $(echo "$longestQuery" | cut -f 2); "
	    longestQueryHost=$(echo "$longestQuery" | cut -f 3)
	    if [ $longestQueryHost != "localhost" ]; then
	        longestQueryString=$longestQueryString"host is $(echo "$longestQuery" | cut -f 3); "
	    fi
	    longestQuerySchema=$(echo "$longestQuery" | cut -f 4)
	    if [ $longestQuerySchema != "NULL" ]; then
	        longestQueryString=$longestQueryString"schema is $(echo "$longestQuery" | cut -f 4); "
	    fi
	    longestQueryString=$longestQueryString"executing \"$(echo "$longestQuery" | cut -f 8)\"; "
	    longestQueryString=$longestQueryString"state is $(echo "$longestQuery" | cut -f 7); "
	fi
fi
performanceData=$performanceData"longestTime=$longestTime;;0;$timeout "

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
