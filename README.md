CheckMySQLProcesslist a script to monitor MySQL processlist.

## Description

Executes just one "show processlist" query on the server. Parse the output.

Gives

* counts of the process' active for given seconds,
* notifications if the given limits exceeded,
* count of unauthenticated connections to identify DNS problems,
* counts of the querying, connecting, fetching, executing, sleeping connections,
* counts of the temporary table using, preparing, sorting, locked queries,
* longest query information,
* time of the longest process.

## Usage

```
./checkMySQLProcesslist.sh -h
```

```
./checkMySQLProcesslist.sh [-H hostname] [-P port] [-u username] [-p password] \
                           [-q] [-s seconds] [-w limits] [-c limits]
```    

-H hostname        Hostname to connect to the MySQL server.

-P port            Port to connect to the MySQL server.

-u username        Username to connect to the MySQL server.

-p password        Password to connect to the MySQL server.

-q                 Query mode: counts only process' with queries.

-s seconds         A second or seconds to count process'. Default is 0.

-w limits          A limit or limits to give warning for counted process'.

-c limits          A limit or limits to give critical for counted process'.

Multiple -s, -w, -c values can be given or a value can be given comma separated.
Limits relates to seconds by order.

### Exit Status

* 0 for ok
* 1 for warning
* 2 for critical
* 3 for unknown

### Examples

```
./checkMySQLProcesslist.sh -u *** -p *** -w 50% -c 80%
```

```
./checkMySQLProcesslist.sh -u *** -p *** -s 60 -w 20 -c 50
```

```
./checkMySQLProcesslist.sh -u *** -p *** -s 0 -s 60 -w 50% -c 80% -c 70%
```

```
./checkMySQLProcesslist.sh -u *** -p *** -q -w 20 -c 50
```

```
./checkMySQLProcesslist.sh -u *** -p *** -s 0,1,10,60,600,3600 \
                           -q -w 34,13,5,2,1 -c 144,55,21,8,3,1
```
