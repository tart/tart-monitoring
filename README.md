Compilation of monitoring scripts we use with Nagios.  Most of them are written by us.  Some of them copied
from other sources for convenience.  There are links for most of the sources.

The scripts developed by us are released under the ISC License. The ISC License is registered with and approved by
the Open Source Initiative [1].  The scripts from other sources have different licenses.  The licenses are included
on the scripts.

[1] http://opensource.org/licenses/isc-license.txt


# Scripts

Scripts are explained below in alphabetical order.


## checkCronJobRunningTime.py

Checks a given log file to monitor a scheduled job runs as expected.  Currently, it is a half-baked script.  It is not
really configurable and suitable for general use.


## checkFTPModificationTime.py

Connects to an SSH FTP server and checks the modification times of the files on a given directory.  Exits with
the warning code, 1, or the critical code, 2, if the least time exceeds given limits.


# checkMySQLProcesslist.sh

Executes just one "show processlist" query on the server.  Parses the output.

Gives:

* counts of the process' active for given seconds
* notifications if the given limits exceeded
* count of unauthenticated connections to identify DNS problems
* counts of the querying, connecting, fetching, executing, sleeping connections
* counts of the temporary table using, preparing, sorting, locked queries
* longest query information
* time of the longest process

Usage:

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

Multiple -s, -w, -c values can be given or a value can be given comma separated.  The limits and the seconds match
by their order.

Examples:

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


## checkMySQLTableStatus.py

Executes "show table status" queries for all schemas on the MySQL server.  Parses the output.  Gives
Nagios compatible warning, critical notifications and performance data for selected values.

This one is Python 2 script.  MySQLdb and argparse libraries are required.

Modes are the columns on the result of "show table status" query.  Numeric ones are

* rows
* avg_row_length
* data_length
* max_data_length
* index_length
* data_free
* auto_increment

for MySQL 5.

Examples:

```
./checkMySQLTableStatus.py -H *** -u *** -p *** -m rows,data_length,index_length,data_free,auto_increment \
                           -w 100M,50G,50G,500M,2G
```

```
./checkMySQLTableStatus.py -u *** -p *** -w 10M,10G -c 100M
```

```
./checkMySQLTableStatus.py -m auto_increment -w 2G -t Library.Book,Library.User
```

```
./checkMySQLTableStatus.py -m data_length,index_length,data_free -w 50G,50G,500M -l 5M,5M,5M -aAMN
```


## checkNginxVersion.py

Gets the Nginx server version from the Server header.  Searches for the minor version on the Nginx Download page.
Exits with warning code, 1, if the versions do not match.  Exits with unknown code, 3, if the versions could not found.
Never checks for the major version and exists with critical code, 3.

Nginx `server_tokens` configuration should not be set to `off` on the given location.

Usage:

```
./checkNginxVersion.py [HTTP address]
```

[1] http://nginx.org/en/download.html


## check_postfix_queue.sh

Executes "mailq" command via SSH on the remote server. SSH public key of the user should be added to the same user
on the remote server. Prints the mail count on the queue.

Examples:

```
./check_postfix_queue.sh -H *** -w 200 -c 500
```

[1] http://exchange.nagios.org/directory/Plugins/Email-and-Groupware/Postfix/check_postfix_queue/details


## check_syncrepl.py

Retrieved from the Nagios Exchange [1] on 2013-11-27.

[1] http://exchange.nagios.org/directory/Plugins/Network-Protocols/LDAP/Openldap-Syncrepl/details
