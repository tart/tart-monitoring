#!/bin/bash -e

status=$(supervisorctl $@ status)

if [ $? -gt 0 ]; then
    echo "UNKNOWN $status"
    exit 3
fi

critical=$(echo $status | while read line; do
    program=$(echo $line | cut -d ' ' -f 1)
    status=$(echo $line | cut -d ' ' -f 2)

    if [ $status = "FATAL" ] ; then
        echo -n "$program $status; "
    fi
done)

if [ "$critical" ]; then
    echo "CRITICAL $critical"
    exit 2
fi

warning=$(echo $status | while read line; do
    program=$(echo $line | cut -d ' ' -f 1)
    status=$(echo $line | cut -d ' ' -f 2)

   if [ $status != "RUNNING" ];  then
        echo -n "$program $status; "
    fi
done)

if [ "$warning" ]; then
    echo "WARNING $warning"
    exit 1
fi

echo "OK"
exit 0

