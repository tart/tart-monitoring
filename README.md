CheckMySQLProcesslist a script to monitor MySQL processlist.

## Description

Executes just one "show processlist" query on the server. Parse the output.

Gives

* all of the following values as performance data,
* notifications if the limits for the following exceeded,
* longest query information if it is running for a minute.

### Variable List

* All connections
* All Queries
* Sleeping connections
* Querying connections
* Connecting connections
* Quitting connections
* Preparing connections
* Fetching connections
* Executing connections
* Delayed connections
* Longest query time

### Exit Status

* 0 for ok
* 1 for warning
* 2 for critical
* 3 for unknown

## Usage

```
./checkMySQLProcesslist.sh -h
```

```
./checkMySQLProcesslist.sh [-H hostname] [-P port] [-u username] [-p password] \
		[-s seconds] [-w limits] [-c limits]
```	

Hostname:

Hostname of the host.

Port:

Post of the MySQL server.

Username:

Username for the MySQL server.

Password:

Password for the MySQL server.

Seconds:

Seconds to to group process' and check the limits.

Limits:

Comma separated critical, warning limits. Written as c1,c2,c3... for critical,
as w1,w2,w3... for warning ordered by variable list given above.

### Example

./checkMySQLProcesslist.sh -u *** -p *** -s 0,1,10,60,600,3600 \
		-w 34,13,5,2,1 -c 144,55,21,8,3,1
