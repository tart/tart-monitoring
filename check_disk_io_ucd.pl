#! /usr/bin/perl -w

# Check DiskIO via SNMP.
# Plugin uses UCD-DISKIO MIB (1.3.6.1.4.1.2021.13.15.1).
# Used in net-snmp packages on linux.
# UCD-DISKIO on linux is only running ok starting with net-snmp version 5.2
# Releases below this version could deliver wrong figures.
#
#
# Copyright (C) 2009 by Herbert Stadler
# email: hestadler@gmx.at

# License Information:
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License 
# along with this program; if not, see <http://www.gnu.org/licenses/>. 
#
#

############################################################################


use POSIX;
use strict;
use Getopt::Long;

use lib ".";
use lib "/usr/lib/nagios/plugins";
use lib "/usr/lib64/nagios/plugins";
use lib "/usr/local/nagios/libexec";

use utils qw(%ERRORS);

use Net::SNMP qw(oid_lex_sort oid_base_match);

my ($opt_version,$opt_help,$opt_verbose);
my ($opt_timeout,$opt_license,$opt_device);
my ($opt_hostname,$opt_community,$opt_port,$opt_snmpvers);
my ($opt_username,$opt_authpasswd,$opt_authproto);
my ($opt_privpasswd,$opt_privproto);
my ($opt_warn,$opt_crit);
my ($PROGNAME,$REVISION);
my ($state,$msg);

use constant DEFAULT_TIMEOUT		=>30;
use constant DEFAULT_PORT    		=>161;
use constant DEFAULT_COMMUNITY  	=>"public";
use constant DEFAULT_SNMPVERS 		=>"2";
use constant DEFAULT_PRIVPROTO		=>"DES";
use constant DEFAULT_AUTHPROTO		=>"MD5";
use constant WAIT_BETWEEN_MEASUREMENT   =>5;
use constant COUNTER_MAXVAL             =>4294967295;

#  UCD-DISKIO MIB
my $dskIOTable     			="1.3.6.1.4.1.2021.13.15.1";
my  $dskIOEntry  			="1.3.6.1.4.1.2021.13.15.1.1";
my   $dskIOIndex			="1.3.6.1.4.1.2021.13.15.1.1.1";
my   $dskIODevice         		="1.3.6.1.4.1.2021.13.15.1.1.2";
my   $dskIONRead          		="1.3.6.1.4.1.2021.13.15.1.1.3";
my   $dskIONWritten       		="1.3.6.1.4.1.2021.13.15.1.1.4";
my   $dskIOReads         		="1.3.6.1.4.1.2021.13.15.1.1.5";
my   $dskIOWrites       		="1.3.6.1.4.1.2021.13.15.1.1.6";


$ENV{'PATH'}='';
$ENV{'BASH_ENV'}=''; 
$ENV{'ENV'}='';
$PROGNAME = "check_diskio_ucd";
$REVISION = "1.3";

# checking commandline arguments
my $arg_status = check_args();
if ($arg_status){
  print "ERROR: some arguments wrong\n";
  exit $ERRORS{"UNKNOWN"};
}

if ( $opt_verbose ) {
  printf("Net::SNMP Version: %s\n",Net::SNMP->VERSION);
}

# set alarmhandler for timeout handling
$SIG{'ALRM'} = sub {
  print ("ERROR: plugin timed out after $opt_timeout seconds \n");
  exit $ERRORS{"UNKNOWN"};
};

alarm($opt_timeout);

# let's see if the server wants to speak with us
my ($snmp_session,$snmp_error)=open_snmp_session($opt_hostname);
if ( ! defined ($snmp_session)) {
  print "ERROR: Could not open connection: $snmp_error \n";
  exit $ERRORS{'UNKNOWN'};
}

$snmp_session->translate(['-endofmibview'=>0,'-nosuchobject'=>0,'-nosuchinstance'=>0]);

if ( $opt_verbose ) {
  printf("1st Measurement of DiskIO-Load\n");
}

#  get diskIOTable 1st Measurement
my $hdskIOTable_1st=get_table($dskIOTable);

if ( $opt_verbose ) {
  printf("Waiting %d seconds\n",WAIT_BETWEEN_MEASUREMENT);
}

# now we are waiting some seconds
sleep (WAIT_BETWEEN_MEASUREMENT);

if ( $opt_verbose ) {
  printf("2nd Measurement of DiskIO-Load\n");
}

#  get diskIOTable 2nd Measurement
my $hdskIOTable_2nd=get_table($dskIOTable);

$snmp_session->close;

if ( $opt_verbose ) {
  print_hdskIOTable ("1st Measurement",$hdskIOTable_1st);
  print_hdskIOTable ("2nd Measurement",$hdskIOTable_2nd);
}


my $perfdata="";
my $hdskIOTableDiff=Build_Diff_Values();
my $s_DiskFound=0;

foreach my $l_key (oid_lex_sort(keys(%{$hdskIOTableDiff}))){
  next if (!(oid_base_match($dskIOIndex,$l_key)));

  my $l_val=$hdskIOTableDiff->{$l_key};
  next if ( $hdskIOTableDiff->{$dskIODevice.".".$l_val} ne $opt_device );

  $s_DiskFound=1;

  my $dskIOBytesTotal = $hdskIOTableDiff->{$dskIONRead.".".$l_val} + $hdskIOTableDiff->{$dskIONWritten.".".$l_val};

  my $dskIOTotal = $hdskIOTableDiff->{$dskIOReads.".".$l_val} + $hdskIOTableDiff->{$dskIOWrites.".".$l_val};

  my $IONReadMB   =$hdskIOTableDiff->{$dskIONRead.".".$l_val} /1024/1024;
  my $IONWrittenMB=$hdskIOTableDiff->{$dskIONWritten.".".$l_val} /1024/1024;

  my $IONReadMBsec   =$IONReadMB / WAIT_BETWEEN_MEASUREMENT;
  my $IONWrittenMBsec=$IONWrittenMB / WAIT_BETWEEN_MEASUREMENT;

  my $IOReadssec   = $hdskIOTableDiff->{$dskIOReads.".".$l_val} / WAIT_BETWEEN_MEASUREMENT;
  my $IOWritessec  = $hdskIOTableDiff->{$dskIOWrites.".".$l_val} / WAIT_BETWEEN_MEASUREMENT;
  my $IOTotalsec   = $IOReadssec + $IOWritessec;

  # Build performance data line
  $perfdata=sprintf("ReadMB=%.2fMB/s WriteMB=%.2fMB/s ReadIO=%.2fIO/s WriteIO=%.2fIO/s TotalIO=%.2fIO/s",$IONReadMBsec,$IONWrittenMBsec,$IOReadssec,$IOWritessec,$IOTotalsec);

  if ( $opt_verbose ) {
    printf ("Disk found in UCD-DISKIO Table\n");
    printf ("IndexNr       : %d\n",$l_val);
    printf ("Device        : %s\n",$hdskIOTableDiff->{$dskIODevice.".".$l_val});
    printf ("Bytes Read    : %d (%.2f MB)(%.2f MB/sec)\n",$hdskIOTableDiff->{$dskIONRead.".".$l_val},$IONReadMB,$IONReadMBsec);
    printf ("Bytes Written : %d (%.2f MB)(%.2f MB/sec)\n",$hdskIOTableDiff->{$dskIONWritten.".".$l_val},$IONWrittenMB,$IONWrittenMBsec);
    printf ("I/O Read      : %d (%.2f IO/sec)\n",$hdskIOTableDiff->{$dskIOReads.".".$l_val},$IOReadssec);
    printf ("I/O Writes    : %d (%.2f IO/sec)\n",$hdskIOTableDiff->{$dskIOWrites.".".$l_val},$IOWritessec);
  }

  # in case we use some other calculated fields for checking
  # $IONReadMBsec, $IOReadssec, $IOWritessec
  my $checkval=$IONWrittenMBsec;

  if ( $checkval < $opt_warn ) {
    $msg = sprintf("DISKIO OK - No Problems found (Write %d MB/s)",$checkval);
    $state = $ERRORS{'OK'};
  }elsif ( $checkval < $opt_crit ) {
    $msg = sprintf("DISKIO WARN - Write %d MB/s",$checkval);
    $state = $ERRORS{'WARNING'};
  }else{
    $msg = sprintf("DISKIO CRIT - Write %d MB/s",$checkval);
    $state = $ERRORS{'CRITICAL'};
  }
  last;
}


if ( $s_DiskFound == 1 ) {
  # attach performance data line
  $msg.="|".$perfdata;
}else{
  $msg=sprintf("DISKIO WARN - Disk %s not found",$opt_device);
  $state = $ERRORS{'WARNING'};
}

# and now "over and out"

print "$msg\n";
exit $state;




#--------------------------------------------------------------------------#
# S U B R O U T I N E S                                                    #
#--------------------------------------------------------------------------#

#--------------------------------------------------------------------------
sub open_snmp_session {
#--------------------------------------------------------------------------
  my ($l_host)=@_;

  my ($snmp_session,$snmp_error);

  # open SNMP Session to Server
  if ( $opt_snmpvers eq "3" ) {
    if ( defined ($opt_authpasswd)) {
      if ( defined ($opt_privpasswd)) {
	($snmp_session,$snmp_error)=Net::SNMP->session(
	    -hostname 		=> 	$l_host,
	    -port		=>	$opt_port,
	    -timeout		=>	2,
	    -retries		=>	2,
	    -maxmsgsize		=>	16384,
	    -version		=>	$opt_snmpvers,
	    -username		=> 	$opt_username,
	    -authpassword	=> 	$opt_authpasswd,
	    -authprotocol	=> 	$opt_authproto,
	    -privpassword	=> 	$opt_privpasswd,
	    -privprotocol	=> 	$opt_privproto,
	    );
      } else {
	($snmp_session,$snmp_error)=Net::SNMP->session(
	    -hostname 		=> 	$l_host,
	    -port		=>	$opt_port,
	    -timeout		=>	2,
	    -retries		=>	2,
	    -maxmsgsize		=>	16384,
	    -version		=>	$opt_snmpvers,
	    -username		=> 	$opt_username,
	    -authpassword	=> 	$opt_authpasswd,
	    -authprotocol	=> 	$opt_authproto,
	    );
      } 
    } else {
	($snmp_session,$snmp_error)=Net::SNMP->session(
	    -hostname 		=> 	$l_host,
	    -port		=>	$opt_port,
	    -timeout		=>	2,
	    -retries		=>	2,
	    -maxmsgsize		=>	16384,
	    -version		=>	$opt_snmpvers,
	    -username		=> 	$opt_username,
	    );
    }
  } else {
    ($snmp_session,$snmp_error)=Net::SNMP->session(
    	-hostname 	=> 	$l_host,
	-community 	=> 	$opt_community,
	-port		=>	$opt_port,
	-timeout	=>	2,
	-retries	=>	2,
	-maxmsgsize	=>	16384,
	-version	=>	$opt_snmpvers,
	);
  }
  return ($snmp_session,$snmp_error);
}

#--------------------------------------------------------------------------
sub create_msg {
#--------------------------------------------------------------------------
  my ($l_txt,$l_msg)=@_;

  if (! defined $l_txt) {return};

  if (defined $$l_msg) {
    $$l_msg.=", ";
  }
  $$l_msg.=$l_txt;
}

#--------------------------------------------------------------------------
sub get_table {
#--------------------------------------------------------------------------
  my ($l_oid)=@_;

  my $l_snmp_result=$snmp_session->get_table(
  	-baseoid 	=>	$l_oid
  	);

  if ($snmp_session->error_status != 0) {
    printf("ERROR %d: get_table: %s",$snmp_session->error_status,$snmp_session->error,"\n");
    $snmp_session->close;
    exit $ERRORS{'UNKNOWN'};
  }
  return $l_snmp_result;
}

#--------------------------------------------------------------------------
sub check_args {
#--------------------------------------------------------------------------
  Getopt::Long::Configure('bundling');
  GetOptions
	("V"   			=> \$opt_version,
	 "version"   		=> \$opt_version,
	 "L"   			=> \$opt_license, 
	 "license"   		=> \$opt_license, 
	 "v"   			=> \$opt_verbose, 
	 "verbose"   		=> \$opt_verbose, 
	 "h|?" 			=> \$opt_help,
	 "help"   		=> \$opt_help,
	 "t=i" 			=> \$opt_timeout, 
	 "timeout=i" 		=> \$opt_timeout, 
	 "H=s" 			=> \$opt_hostname, 
	 "hostname=s" 		=> \$opt_hostname, 
	 "d=s" 			=> \$opt_device, 
	 "device=s" 		=> \$opt_device, 
	 "C=s" 			=> \$opt_community, 
	 "community=s" 		=> \$opt_community, 
	 "p=i" 			=> \$opt_port, 
	 "port=i" 		=> \$opt_port, 
	 "s=s" 			=> \$opt_snmpvers, 
	 "snmpvers=s" 		=> \$opt_snmpvers, 
         "u=s"       		=> \$opt_username,
         "username=s"       	=> \$opt_username,
         "o=s"   		=> \$opt_authpasswd,
         "authpass=s"   	=> \$opt_authpasswd,
         "r=s"   		=> \$opt_authproto,
         "authprot=s"   	=> \$opt_authproto,
         "O=s"   		=> \$opt_privpasswd,
         "privpass=s"   	=> \$opt_privpasswd,
         "R=s"   		=> \$opt_privproto,
         "privprot=s"   	=> \$opt_privproto,
         "w=s"                  => \$opt_warn,
         "warn=s"               => \$opt_warn,
         "c=s"                  => \$opt_crit,
         "crit=s"               => \$opt_crit,
	 );

  if ($opt_license) {
    print_gpl($PROGNAME,$REVISION);
    exit $ERRORS{'OK'};
  }

  if ($opt_version) {
    print_revision($PROGNAME,$REVISION);
    exit $ERRORS{'OK'};
  }

  if ($opt_help) {
    print_help();
    exit $ERRORS{'OK'};
  }

  if ( ! defined($opt_hostname)){
    print "\nERROR: Hostname not defined\n\n";
    print_usage();
    exit $ERRORS{'UNKNOWN'};
  }

  if ( ! defined($opt_device)){
    print "\nERROR: Device not defined\n\n";
    print_usage();
    exit $ERRORS{'UNKNOWN'};
  }

  unless (defined $opt_snmpvers) {
    $opt_snmpvers = DEFAULT_SNMPVERS;
  }

  if (($opt_snmpvers ne "1") && ($opt_snmpvers ne "2") && ($opt_snmpvers ne "3")) {
    printf ("\nERROR: SNMP Version %s unknown\n",$opt_snmpvers);
    print_usage();
    exit $ERRORS{'UNKNOWN'};
  }

  unless (defined $opt_warn) {
    print "\nERROR: parameter -w <warn> not defined\n\n";
    print_usage();
    exit ($ERRORS{'UNKNOWN'});
  }

  unless (defined $opt_crit) {
    print "\nERROR: parameter -c <crit> not defined\n\n";
    print_usage();
    exit ($ERRORS{'UNKNOWN'});
  }

  if ( $opt_warn > $opt_crit) {
    print "\nERROR: parameter -w <warn> greater than parameter -c\n\n";
    print_usage();
    exit ($ERRORS{'UNKNOWN'});
  }

  unless (defined $opt_timeout) {
    $opt_timeout = DEFAULT_TIMEOUT;
  }

  unless (defined $opt_port) {
    $opt_port = DEFAULT_PORT;
  }

  unless (defined $opt_community) {
    $opt_community = DEFAULT_COMMUNITY;
  }

  if (defined $opt_privpasswd) {
    unless (defined $opt_privproto) {
      $opt_privproto = DEFAULT_PRIVPROTO;
    }
  }

  if (defined $opt_authpasswd) {
    unless (defined $opt_authproto) {
      $opt_authproto = DEFAULT_AUTHPROTO;
    }
  }

  if ($opt_snmpvers eq 3) {
    unless (defined $opt_username) {
      printf ("\nERROR: SNMP Version %s: please define username\n",$opt_snmpvers);
      print_usage();
      exit $ERRORS{'UNKNOWN'};
    }
  }

  return $ERRORS{'OK'};
}

#--------------------------------------------------------------------------
sub print_usage {
#--------------------------------------------------------------------------
  print "Usage: $PROGNAME [-h] [-L] [-t timeout] [-v] [-V] [-C community] [-p port] [-s 1|2|3] -H hostname -d diskdevice -w <warning> -c <critical>\n\n";
  print "SNMP version 3 specific: [-u username] [-o authpass] [-r authprot] [-O privpass] [-R privprot]\n";
}

#--------------------------------------------------------------------------
sub print_help {
#--------------------------------------------------------------------------
  print_revision($PROGNAME,$REVISION);
  printf("\n");
  print_usage();
  printf("\n");
  printf("   Check DiskIO via UCD-DISKIO SNMP MIB\n");
  printf("   e.g: used on linux in net-snmp agent.\n\n");
  printf("-t (--timeout)      Timeout in seconds (default=%d)\n",DEFAULT_TIMEOUT);
  printf("-H (--hostname)     Host to monitor\n");
  printf("-d (--device)       Disk to monitor\n");
  printf("-s (--snmpvers)     SNMP Version [1|2|3] (default=%d)\n",DEFAULT_SNMPVERS);
  printf("-C (--community)    SNMP Community (default=%s)\n",DEFAULT_COMMUNITY);
  printf("-p (--port)         SNMP Port (default=%d)\n",DEFAULT_PORT);
  printf("-w (--warn)         Parameter warning for MB Write/sec\n");
  printf("-c (--crit)         Parameter critical for MB Write/sec\n");
  printf("-h (--help)         Help\n");
  printf("-V (--version)      Programm version\n");
  printf("-v (--verbose)      Print some useful information\n");
  printf("-L (--license)      Print license information\n");
  printf("\nSNMP version 3 specific arguments:\n");
  printf("-u (--username)     Security Name\n");
  printf("-o (--authpassword) Authentication password\n");
  printf("-r (--authprotocol) Authentication protocol [md5|sha]\n");
  printf("-O (--privpassword) Privacy password\n");
  printf("-R (--privprotocol) Privacy protocol [des|aes|3des]\n");
  printf("\n");
}

#--------------------------------------------------------------------------
sub print_hdskIOTable {
#--------------------------------------------------------------------------
  my ($l_description,$hdskIOTable)=@_;

  printtable  (sprintf("UCD-DISKIO Table - %s",$l_description));
  print       ("======================================\n");
  foreach my $l_key (oid_lex_sort(keys(%{$hdskIOTable}))){
    next if (!(oid_base_match($dskIOIndex,$l_key)));

    my $l_val=$hdskIOTable->{$l_key};

    printtabular("Index",         $l_val);
    printtabular("IO Device",     $hdskIOTable->{$dskIODevice.".".$l_val});
    printtabular("Bytes Read",    $hdskIOTable->{$dskIONRead.".".$l_val});
    printtabular("Bytes Written", $hdskIOTable->{$dskIONWritten.".".$l_val});
    printtabular("I/O Read",      $hdskIOTable->{$dskIOReads.".".$l_val});
    printtabular("I/O Write",     $hdskIOTable->{$dskIOWrites.".".$l_val});
    printf("\n");
  }
}

#--------------------------------------------------------------------------
sub printhead {
#--------------------------------------------------------------------------
  my ($l_head)=@_;

  printf ("\n%-40s\n",$l_head);
}

#--------------------------------------------------------------------------
sub printtable {
#--------------------------------------------------------------------------
  my ($l_head)=@_;

  printf ("%-40s\n",$l_head);
}

#--------------------------------------------------------------------------
sub printscalar {
#--------------------------------------------------------------------------
  my ($l_arg,$l_oid)=@_;

  printf ("%-35s: %-30s\n",$l_arg,$l_oid);
}

#--------------------------------------------------------------------------
sub printtabular {
#--------------------------------------------------------------------------
  my ($l_arg,$l_oid)=@_;

  printf ("%-35s: %-30s\n",$l_arg,$l_oid);
}

#--------------------------------------------------------------------------
sub Build_Diff_Values {
#--------------------------------------------------------------------------
  my $hDiffTable={};

  foreach my $l_key (oid_lex_sort(keys(%{$hdskIOTable_2nd}))){
    next if (!(oid_base_match($dskIOIndex,$l_key)));

    my $index_2nd=$hdskIOTable_2nd->{$l_key};
    my $l_device=$hdskIOTable_2nd->{$dskIODevice.".".$index_2nd};

    next if ( $l_device ne $opt_device );
    my $index_1st=Get_Index_Nr_1st_Table($l_device);

    my $IONRead   =$hdskIOTable_2nd->{$dskIONRead.".".$index_2nd}    - $hdskIOTable_1st->{$dskIONRead.".".$index_1st};
    my $IONWritten=$hdskIOTable_2nd->{$dskIONWritten.".".$index_2nd} - $hdskIOTable_1st->{$dskIONWritten.".".$index_1st};
    my $IOReads   =$hdskIOTable_2nd->{$dskIOReads.".".$index_2nd}    - $hdskIOTable_1st->{$dskIOReads.".".$index_1st};
    my $IOWrites  =$hdskIOTable_2nd->{$dskIOWrites.".".$index_2nd}   - $hdskIOTable_1st->{$dskIOWrites.".".$index_1st};

    if ( $IONRead < 0 ) {
      $IONRead+=COUNTER_MAXVAL;
    } 
    if ( $IONWritten < 0 ) {
      $IONWritten+=COUNTER_MAXVAL;
    } 
    if ( $IOReads < 0 ) {
      $IOReads+=COUNTER_MAXVAL;
    } 
    if ( $IOWrites < 0 ) {
      $IOWrites+=COUNTER_MAXVAL;
    } 
    
    $hDiffTable->{$l_key}                        = $index_2nd;
    $hDiffTable->{$dskIODevice.".".$index_2nd}   = $l_device;
    $hDiffTable->{$dskIONRead.".".$index_2nd}    = $IONRead;
    $hDiffTable->{$dskIONWritten.".".$index_2nd} = $IONWritten;
    $hDiffTable->{$dskIOReads.".".$index_2nd}    = $IOReads;
    $hDiffTable->{$dskIOWrites.".".$index_2nd}   = $IOWrites;
  }

  return($hDiffTable);
}

#--------------------------------------------------------------------------
sub Get_Index_Nr_1st_Table {
#--------------------------------------------------------------------------
  my ($l_device)=@_;

  foreach my $l_key (keys(%{$hdskIOTable_1st})){
    next if (!(oid_base_match($dskIOIndex,$l_key)));

    my $l_val=$hdskIOTable_1st->{$l_key};
    my $l_device_1st=$hdskIOTable_1st->{$dskIODevice.".".$l_val};

    next if ( $l_device_1st ne $l_device );

    return($l_val);
  }

  return(undef);
}

#--------------------------------------------------------------------------
sub print_gpl {
#--------------------------------------------------------------------------
  print <<EOD;

  Copyright (C) 2009 by Herbert Stadler
  email: hestadler\@gmx.at

  License Information:
  This program is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 3 of the License, or
  (at your option) any later version.
 
  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.
 
  You should have received a copy of the GNU General Public License 
  along with this program; if not, see <http://www.gnu.org/licenses/>. 

EOD

}

#--------------------------------------------------------------------------
sub print_revision {
#--------------------------------------------------------------------------
  my ($l_prog,$l_revision)=@_;

  print <<EOD

$l_prog $l_revision, Copyright (C) 2009 Herbert Stadler

This program comes with ABSOLUTELY NO WARRANTY; 
for details type "$l_prog -L".
EOD
}




=head1 NAME

 check_diskio_ucd

=head1 DESCRIPTION

 Check Disks via UCD-DISKIO MIB.

 This plugin checks the disk-IO per second to a diskdevice. 

 The following values are shown:
   - Read MB/sec  
   - Write MB/sec
   - Read IO/sec
   - Write IO/sec

 It makes two measurements within 5 seconds and calculates the
 difference.

 Plugin created for Nagios Monitoring.

=head1 SYNOPSIS

 check_diskio_ucd -H <hostname> -w <warn> -c <crit> -d <diskname>  

 for more information concerning this plugin call:
     check_diskio_ucd -h
     perldoc check_diskio_ucd

 more information concerning the configuration of the UCD SNMP Package:
     man snmpd.conf


=head1 AUTHOR

 Herbert Stadler, Austria (hestadler@gmx.at)
 June 2009

 This plugin is a contribution to the nagios community.

=head1 REQUIRED SOFTWARE

 from search.cpan.org
   Net::SNMP Package   	e.g: Net-SNMP-5.2.0.tar.gz

 UCD-DISKIO on linux is only running ok starting with net-snmp version 5.2
 Releases below this version could deliver wrong figures.
 Example: net-snmp-5.3.1-24.el5_2.1

 To check your installed version enter:
 rpm -qa | grep snmp

 Please check also:
 http://rhn.redhat.com/errata/RHBA-2007-0738.html


=head1 HOW TO CHECK THE SERVER FUNCTIONALITY

 Example:
   snmpwalk -On -c public -v 1 <hostname> 1.3.6.1.4.1.2021.13.15.1

 should return some lines



=head1 CONFIGURATION IN NAGIOS

 Copy this plugin to the nagios plugin installation directory 
 e.g.: /usr/lib(64)/nagios/plugin

 COMMAND DEFINITION:

 # "check_diskio_ucd" command definition
 define command{
    command_name    check_diskio_ucd
    command_line    $USER1$/check_diskio_ucd -H $HOSTADDRESS$ ...
    }


=head1 PLUGIN HISTORY

 Version 1.0 - 2009-06-22	first release
 Version 1.1 - 2010-03-24       check error_status of snmp call
 Version 1.2 - 2010-05-04       Checking Counter32 overrun
 Version 1.3 - 2010-05-04       Correction perfdata line

=head1 COPYRIGHT AND DISCLAIMER

 Copyright (C) 2009 by Herbert Stadler
 email: hestadler@gmx.at

 License Information:
 This program is free software; you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation; either version 3 of the License, or
 (at your option) any later version.
 
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 
 You should have received a copy of the GNU General Public License 
 along with this program; if not, see <http://www.gnu.org/licenses/>. 
 

=cut



