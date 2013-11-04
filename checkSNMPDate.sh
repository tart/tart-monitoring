#!/bin/sh

# Nagios plugin to report time difference as received via SNMP compared to the local time.
# Make sure the machine this script runs on (poller/nagios host) is using NTP.

usage() {
# This function is called when a user enters impossible values.
echo "Usage: $0 -H HOSTADDRESS [-C COMMUNITY] [-w WARNING] [-c CRITICAL] [-v VERSION]"
echo
echo " -H HOSTADDRESS"
echo "     The host to check, either IP address or a resolvable hostname."
echo " -C COMMUNITY"
echo "     The SNMP community to use, defaults to public."
echo " -v VERSION"
echo "     The SNMTP version to use, defaults to 2c."
echo " -w WARNING"
echo "     The amount of seconds from where warnings start. Defaults to 60."
echo " -c CRITICAL"
echo "     The amount of seconds from where criticals start. Defaults to 120."
exit 3
}

readargs() {
# This function reads what options and arguments were given on the
# command line.
while [ "$#" -gt 0 ] ; do
  case "$1" in
   -H)
    if [ "$2" ] ; then
     host="$2"
     shift ; shift
    else
     echo "Missing a value for $1."
     echo
     shift
     usage
    fi
   ;;
   -C)
    if [ "$2" ] ; then
     community="$2"
     shift ; shift
    else
     echo "Missing a value for $1."
     echo
     shift
     usage
    fi
   ;;
   -w)
    if [ "$2" ] ; then
     warning="$2"
     shift ; shift
    else
     echo "Missing a value for $1."
     echo
     shift
     usage
    fi
   ;;
   -c)
    if [ "$2" ] ; then
     critical="$2"
     shift ; shift
    else
     echo "Missing a value for $1."
     echo
     shift
     usage
    fi
   ;;
   -v)
    if [ "$2" ] ; then
     version="$2"
     shift ; shift
    else
     echo "Missing a value for $1."
     echo
     shift
     usage
    fi
   ;;
   *)
    echo "Unknown option $1."
    echo
    shift
    usage
   ;;
  esac
done
}

checkvariables() {
# This function checks if all collected input is correct.
if [ ! "$host" ] ; then
  echo "Please specify a hostname or IP address."
  echo
  usage
fi
if [ ! "$community" ] ; then
  # The public community is used when a user did not enter a community.
  community="public"
fi
if [ ! "$version" ] ; then
  # Version 2c is used when a user did not enter a version.
  version="2c"
fi
if [ ! "$critical" ] ; then
  critical="120"
fi
if [ ! "$warning" ] ; then
  warning="60"
fi
}

getandprintresults() {
# This converts the date retreived from snmp to a unix time stamp.
rdatestring=$( snmpget -v $version -c $community $host HOST-RESOURCES-MIB::hrSystemDate.0 | gawk '{print $NF}' )

if [ ! "$rdatestring" ] ; then
  echo "Time difference could not be calculated; no time received."
  exit 3
fi

rdate=$( echo $rdatestring | gawk -F',' '{print $1}' )
rtime=$( echo $rdatestring | gawk -F',' '{print $2}' | gawk -F'.' '{print $1}' )
cldate=$( echo $rdate | gawk -F'-' '{printf("%4i",$1)}; {printf("%02i",$2)}; {printf("%02i",$3)};' )
cltime=$( echo $rtime | gawk -F':' '{printf("%02i",$1)}; {printf("%02i",$2)}; {printf(" %02i",$3)};' )
rdate_s=$( date -d "$cldate $cltime sec" +%s )
ldate_s=$(date +'%s')

# If the calculated difference is negative, make it positive again for comparison.
difference=$(($rdate_s - $ldate_s))
if [ "$difference" -lt 0 ] ; then
  positivedifference=$(($difference*-1))
else
  positivedifference=$difference
fi

if [ "$positivedifference" -gt "$critical" ] ; then
  echo "Time difference is more than $critical seconds: $difference|diff=$difference"
  exit 2
fi

if [ "$positivedifference" -gt "$warning" ] ; then
  echo "Time difference is more than $warning seconds: $difference|diff=$difference"
  exit 1
fi

echo "Time difference is less than $warning seconds: $difference|diff=$difference"
exit 0
}

# The calls to the different functions.
readargs "$@"
checkvariables
getandprintresults
