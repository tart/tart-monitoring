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

"""Imports for Python 3 compatibility."""
from __future__ import print_function
try:
    import __builtin__
    __builtin__.input = __builtin__.raw_input
except ImportError: pass

import sys
import signal

class Database:
    def __init__ (self, host, port, dbname, user, password):
        '''Initialize connection to the database.'''
        import psycopg2
        connectionString = "host='{0}' port='{1}' dbname='{2}' user='{3}'".format (host, port, dbname, user)
        if password:
            connectionString += " password='{4}'".format (password)
        self.__connection = psycopg2.connect (connectionString)
        self.__cursor = self.__connection.cursor ()

    def __del__ (self):
        '''Close connection to the database.'''
        if self.__cursor:
            self.__cursor.close ()
            self.__connection.close ()

    def select (self, query):
        '''Execute a select query on the database.'''
        self.__cursor.execute (query)
        return self.__cursor.fetchall ()

    def selectOneColumn (self, query):
        '''Execute a select query on the database. Return first column of the result.'''
        return [row [0] for row in self.select (query)]

    def selectOneCell (self, query):
        '''Execute a select query on the database. Return first column on first row of the result.'''
        return self.select (query) [0] [0]

class Checker:
    '''Checks views on the integrity schema of the given database. Returns warning if any rows exists.'''

    def parseArguments (self):
        '''Create ArgumentParser instance. Return parsed arguments.'''
        from argparse import ArgumentParser, RawTextHelpFormatter, ArgumentDefaultsHelpFormatter
        class Formatter (RawTextHelpFormatter, ArgumentDefaultsHelpFormatter): pass
        argumentParser = ArgumentParser (formatter_class = Formatter, description = self.__doc__)
        argumentParser.add_argument ('-H', '--host', dest = 'host', help = 'hostname', default = 'localhost')
        argumentParser.add_argument ('-P', '--port', type = int, dest = 'port', default = 5432)
        argumentParser.add_argument ('-D', '--database', dest = 'database', required = True, help = 'database name')
        argumentParser.add_argument ('-u', '--user', dest = 'user', required = True, help = 'username')
        argumentParser.add_argument ('-p', '--pass', dest = 'passwd', help = 'password')
        argumentParser.add_argument ('-n', '--namespace', dest = 'namespace', required = True, help = 'database schema')
        argumentParser.add_argument ('-w', '--warning', type = int, dest = 'warning', required = False, default = 1,
                                     help = 'warning limit for one view')
        argumentParser.add_argument ('-c', '--critical', type = int, dest = 'critical', required = False,
                                     help = 'critical limit one view')
        argumentParser.add_argument ('-t', '--timeout', type = int, dest = 'timeout', required = False,
                                     help = 'timeout')
        return argumentParser.parse_args ()

    def __init__ (self):
        arguments = self.parseArguments ()
        self.__database = Database (arguments.host, arguments.port, arguments.database, arguments.user, arguments.passwd)
        self.__namespace = arguments.namespace
        self.__warningLimit = arguments.warning
        self.__criticalLimit = arguments.critical
        if arguments.timeout:
            signal.signal (signal.SIGALRM, timeoutRaiser)
            signal.alarm (arguments.timeout)

    def checkViews (self):
        '''Find views on the given schema of the database. Return the ones which has rows with row counts.'''
        warnings = []
        criticals = []
        query = "Select viewname from pg_views where schemaname = '{0}'".format (self.__namespace)
        views = self.__database.selectOneColumn (query)
        if not len (views):
            raise Exception ('There are no views in the {0} schema.'.format (self.__namespace))
        for view in views:
            count = self.__database.selectOneCell ('Select count (*) from {0}.{1}'.format (self.__namespace, view))
            if count >= self.__warningLimit:
                if self.__criticalLimit and count >= self.__criticalLimit:
                    criticals.append ((view, count))
                else:
                    warnings.append ((view, count))
        return warnings, criticals

class Timeout (Exception): pass
def timeoutRaiser (signum, frame):
    raise Timeout

if __name__ == '__main__':
    '''Run the main program.'''
    print ('CheckPostgreSQLView', end = ' ')
    try:
        checker = Checker ()
        warnings, criticals = checker.checkViews ()
    except Exception as exception:
        print ('unknown:', end = ' ')
        try:
            print (exception [1])
        except IndexError:
            print (exception)
        sys.exit (3)
    else:
        if criticals:
            print ('critical:', end = ' ')
            for view, count in criticals:
                print ('{0} rows on {1},'.format (count, view), end = ' ')
        if warnings:
            print ('warning:', end = ' ')
            for view, count in warnings:
                print ('{0} rows on {1},'.format (count, view), end = ' ')
        if criticals:
            print ()
            sys.exit (2)
        elif warnings:
            print ()
            sys.exit (1)
        else:
            print ('ok')
            sys.exit (0)

