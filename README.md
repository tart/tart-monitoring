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
* Queries running more than 10 seconds
* Queries running more than a minute
* Queries running more than 10 minutes
* Queries running more than an hour
* Longest query time
* Sleeping connections
* Querying connections
* Connecting connections
* Quitting connections
* Preparing connections
* Fetching connections
* Executing connections
* Delayed connections

### Exit Status

* 0 for ok
* 1 for warning
* 2 for critical
* 3 for unknown

## Usage

./checkMySQLProcesslist.sh -h

./checkMySQLProcesslist.sh [-H hostname] [-P port] [-u username] [-p password] \\
		[-c limits] [-w limits]

Hostname:

Hostname of the host.

Port:

Post of the MySQL server.

Username:

Username for the MySQL server.

Password:

Password for the MySQL server.

Limits:

Comma separated critical, warning limits. Written as c1,c2,c3... for critical,
as w1,w2,w3... for warning ordered by variable list given above.

### Example

./checkMySQLProcesslist.sh -u *** -p *** -c 377,55,21,8,3,1 -w 144,21,8,3,1
