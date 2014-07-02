Compilation of monitoring scripts we use with Nagios. Most of them are written
by use. Some of them copied to here from other sources for convenience.


## Usage

#### checkNginxVersion.py

Gets the Nginx server version from the Server header. Searches for the minor version on the Nginx Download page.
Exits with warning code if the version does not match. Exits with problem code if the versions could not found.
Never exists with critical code.

Nginx `server_tokens` configuration should not be set to `off` on the given location.

```
./checkNginxVersion.py [HTTP address]
```

[1] http://nginx.org/en/download.html

#### checkMySQLProcesslist.sh

Executes just one "show processlist" query on the server. Parse the output.

Gives

* counts of the process' active for given seconds,
* notifications if the given limits exceeded,
* count of unauthenticated connections to identify DNS problems,
* counts of the querying, connecting, fetching, executing, sleeping connections,
* counts of the temporary table using, preparing, sorting, locked queries,
* longest query information,
* time of the longest process.

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

#### checkMySQLTableStatus.py

Executes "show table status" queries for all schemas on the server. Parse the output. Gives Nagios compatible warning,
critical notifications and performance data for selected values.

This one is Python 2 script. MySQLdb and argparse libraries are required.

Modes are the columns on the result of "show table status" query. Numeric ones are

* rows
* avg_row_length
* data_length
* max_data_length
* index_length
* data_free
* auto_increment

for MySQL 5.

#### check_postfix_queue.sh

Executes "mailq" command via SSH on the remote server. SSH public key of the user should be added to the same user
on the remote server. Prints the mail count on the queue.


## Compatibility

Exit statuses:

* 0 for ok
* 1 for warning
* 2 for critical
* 3 for unknown


## Examples

#### checkMySQLProcesslist.sh

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

#### checkMySQLTableStatus.py

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

#### check_postfix_queue.sh

```
./check_postfix_queue.sh -H *** -w 200 -c 500
```


## History

#### check_syncrepl.py

Retrieved from the Nagios Exchange [1] on 2013-11-27.

[1] http://exchange.nagios.org/directory/Plugins/Network-Protocols/LDAP/Openldap-Syncrepl/details

#### check_postfix_queue.sh

Retrieved from the Nagios Exchange [1] on 2014-06-12. Modified to be used for a remote server using SSH. Suffix added
to its name.

[1] http://exchange.nagios.org/directory/Plugins/Email-and-Groupware/Postfix/check_postfix_queue/details


## License

The scripts developed by us are released under the ISC License. The ISC License is registered with and approved by
the Open Source Initiative [1]. Licenses are included to the scripts.

[1] http://opensource.org/licenses/isc-license.txt
