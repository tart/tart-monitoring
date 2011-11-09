CheckMySQLProcesslist a script to monitor MySQL processlist

## Usage

./checkMySQLProcesslist.sh [-H hostname] [-P port] [-u username] [-p password]

## Description

Executes just one "show processlist" query on the server. Parse the output.

Gives

* all of the following values as performance data,
* notifications if the following limits exceeded,
* longest query information if it is running for a minute.

Exit with

* 0 for ok,
* 1 for warning,
* 2 for critical,
* 3 for unknown.

<table >
	<tr >
		<th ></th>
		<th >Warning</th>
		<th >Critical</th>
	</tr>
	<tr >
		<td >Connections</td>
		<td >144</td>
		<td >377</td>
	</tr>
	<tr >
		<td >Sleeping connections</td>
		<td ></td>
		<td ></td>
	</tr>
	<tr >
		<td >Querying connections</td>
		<td ></td>
		<td ></td>
	</tr>
	<tr >
		<td >Connecting connections</td>
		<td ></td>
		<td ></td>
	</tr>
	<tr >
		<td >Quitting connections</td>
		<td ></td>
		<td ></td>
	</tr>
	<tr >
		<td >Preparing connections</td>
		<td ></td>
		<td ></td>
	</tr>
	<tr >
		<td >Fetching connections</td>
		<td ></td>
		<td ></td>
	</tr>
	<tr >
		<td >Executing connections</td>
		<td ></td>
		<td ></td>
	</tr>
	<tr >
		<td >Delayed connections</td>
		<td ></td>
		<td ></td>
	</tr>
	<tr >
		<td >Queries</td>
		<td >21</td>
		<td >55</td>
	</tr>
	<tr >
		<td >Queries running for 10 seconds</td>
		<td >8</td>
		<td >21</td>
	</tr>
	<tr >
		<td >Queries running for a minute</td>
		<td >3</td>
		<td >8</td>
	</tr>
	<tr >
		<td >Queries running for 10 minutes</td>
		<td >1</td>
		<td >3</td>
		<td ></td>
	</tr>
	<tr >
		<td >Queries running for an hour</td>
		<td ></td>
		<td >1</td>
	</tr>
	<tr >
		<td >Longest query time</td>
		<td ></td>
		<td ></td>
	</tr>
</table>
