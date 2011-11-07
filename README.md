Script to monitor MySQL processlist

## Usage

./checkMySQLProcesslist.sh [-H hostname] [-P port] [-u username] [-p password]

## Description

Executes just one "show processlist" query on the server. Parse the output.
Gives values of the following. Exit with

* 0 for ok
* 1 for warning
* 2 for critical
* 3 for unknown

if the following limits exceeded. Logs errors to /var/log/checkMySQLProcesslist.

<table >
	<tr >
		<th >Counted Process'</th>
		<th >Warning Limit</th>
		<th >Critical Limit</th>
	</tr>
	<tr >
		<td >All</td>
		<td >144</td>
		<td >377</td>
	</tr>
	<tr >
		<td >Queries</td>
		<td >21</td>
		<td >55</td>
	</tr>
	<tr >
		<td >Queries running more than 10 seconds</td>
		<td >8</td>
		<td >21</td>
	</tr>
	<tr >
		<td >Queries running more than a minute</td>
		<td >3</td>
		<td >8</td>
	</tr>
	<tr >
		<td >Queries running more than 10 minutes</td>
		<td >1</td>
		<td >3</td>
		<td ></td>
	</tr>
	<tr >
		<td >Queries running more than an hour</td>
		<td ></td>
		<td >1</td>
	</tr>
	<tr >
		<td >Sleeping</td>
		<td ></td>
		<td ></td>
	</tr>
	<tr >
		<td >Querying</td>
		<td ></td>
		<td ></td>
	</tr>
	<tr >
		<td >Connecting</td>
		<td ></td>
		<td ></td>
	</tr>
	<tr >
		<td >Quitting</td>
		<td ></td>
		<td ></td>
	</tr>
	<tr >
		<td >Preparing</td>
		<td ></td>
		<td ></td>
	</tr>
	<tr >
		<td >Fetching</td>
		<td ></td>
		<td ></td>
	</tr>
	<tr >
		<td >Executing</td>
		<td ></td>
		<td ></td>
	</tr>
	<tr >
		<td >Delayed</td>
		<td ></td>
		<td ></td>
	</tr>
</table>
