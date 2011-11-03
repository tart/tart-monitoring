h1. Usage:

./checkMySQLProcesslist.sh [-H hostname] [-P port] [-u username] [-p password]

h1. Description

Executes just one "Show processlist" query on the server.

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
		<td >Queries runnig more than a minute</td>
		<td >3</td>
		<td >8</td>
	</tr>
	<tr >
		<td >Queries runnig more than 10 minutes</td>
		<td >1</td>
		<td >3</td>
		<td ></td>
	</tr>
	<tr >
		<td >Queries runnig more than a hour</td>
		<td ></td>
		<td >1</td>
	</tr>
	<tr >
		<td >Sleeping</td>
		<td ></td>
		<td ></td>
	</tr>
	<tr >
		<td >Quering</td>
		<td ></td>
		<td ></td>
	</tr>
	<tr >
		<td >Connecting</td>
		<td ></td>
		<td ></td>
	</tr>
	<tr >
		<td >Quiting</td>
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

