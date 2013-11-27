#!/usr/bin/env python
# -*- coding: utf-8 -*-
##
# Tart Monitoring
#
# Copyright (c) 2013, Tart İnternet Teknolojileri Ticaret AŞ
#
# Permission to use, copy, modify, and/or distribute this software for any purpose with or without fee is hereby
# granted, provided that the above copyright notice and this permission notice appear in all copies.
#
# The software is provided "as is" and the author disclaims all warranties with regard to the software including all
# implied warranties of merchantability and fitness. In no event shall the author be liable for any special, direct,
# indirect, or consequential damages or any damages whatsoever resulting from loss of use, data or profits, whether
# in an action of contract, negligence or other tortious action, arising out of or in connection with the use or
# performance of this software.
##

from __future__ import print_function
import sys
import signal
import paramiko
from datetime import datetime

class SFTPServer:
    def __init__ (self, host, port, username, password, directory):
        '''Initialize SSH FTP connection.'''
        self.__transport = paramiko.Transport ((host, port))
        self.__username = username
        self.__password = password
        self.__directory = directory

    def __enter__ (self):
        self.__transport.connect (username = self.__username, password = self.__password)
        self.__client = paramiko.SFTPClient.from_transport(self.__transport)
        return self

    def modificationTime (self):
        maxTimestamp = max ([f.st_mtime for f in self.__client.listdir_attr ()])
        return datetime.fromtimestamp (maxTimestamp)

    def __exit__ (self, *arguments):
        self.__client.close ()
        self.__transport.close ()

class Timeout (Exception): pass

def timeoutRaiser (signum, frame):
        raise Timeout

class Checker:
    '''Connect to the given SSH FTP server. Check the motidification times of files on the given directory. Return
    warning or critical if the given limits exceeded.'''

    def parseArguments (self):
        '''Create ArgumentParser instance. Return parsed arguments.'''
        from argparse import ArgumentParser, RawTextHelpFormatter, ArgumentDefaultsHelpFormatter
        class Formatter (RawTextHelpFormatter, ArgumentDefaultsHelpFormatter): pass
        argumentParser = ArgumentParser (formatter_class = Formatter, description = self.__doc__)
        argumentParser.add_argument ('-H', '--host', dest = 'host', help = 'hostname', default = 'localhost')
        argumentParser.add_argument ('-P', '--port', type = int, dest = 'port', default = 22)
        argumentParser.add_argument ('-u', '--username', dest = 'username')
        argumentParser.add_argument ('-p', '--password', dest = 'password')
        argumentParser.add_argument ('-d', '--directory', dest = 'directory', default = '.')
        argumentParser.add_argument ('-w', '--warning', type = int, dest = 'warning', help = 'warning minutes')
        argumentParser.add_argument ('-c', '--critical', type = int, dest = 'critical', help = 'critical minutes')
        return argumentParser.parse_args ()

    def __init__ (self):
        signal.signal (signal.SIGALRM, timeoutRaiser)
        signal.alarm (20)
        arguments = self.parseArguments ()
        self.__host = arguments.host
        self.__port= arguments.port
        self.__username = arguments.username
        self.__password = arguments.password
        self.__directory = arguments.directory
        self.__warningLimit = arguments.warning
        self.__criticalLimit = arguments.critical

    def check (self):
        '''Run the main program.'''
        print ('CheckFTPModficationTime', end = ' ')
        try:
            with SFTPServer(self.__host, self.__port, self.__username, self.__password, self.__directory) as server:
                interval = datetime.now () - server.modificationTime ()
                minutes = interval.seconds / 60
        except Exception as exception:
            try:
                print ('unknown: ' + exception.__class__.__name__ + ': ' + exception [1])
            except IndexError:
                print ('unknown: ' + exception.__class__.__name__ + ': ' + str (exception))
            returnValue = 3
        else:
            if self.__criticalLimit is not None and  minutes > self.__criticalLimit:
                print ('critical: ', end = '')
                returnValue = 2
            elif self.__warningLimit is not None and minutes > self.__warningLimit:
                print ('warning: ', end = '')
                returnValue = 1
            else:
                print ('ok: ', end = '')
                returnValue = 0
            print (str (minutes) + ' minutes ', end = '')
            print ('| minutes=' + str (minutes) + ';' + str (self.__warningLimit or '') + ';' + str (self.__criticalLimit or '') + ';0;')
        return returnValue

if __name__ == '__main__':
    checker = Checker ()
    exit (checker.check ())

