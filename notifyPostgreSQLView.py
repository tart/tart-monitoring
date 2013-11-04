#!/usr/bin/env python
##
# Tart Server Administration
# Monitoring & Notification Scripts
# Notify About PostgreSQL View
#
# @author  Emre Hasegeli <hasegeli@tart.com.tr>
# @date    2013-01-08

"""Imports for Python 3 compatibility."""
from __future__ import print_function
try:
    import __builtin__
    __builtin__.input = __builtin__.raw_input
except ImportError: pass

import sys
import signal

class Database:
    def __init__ (self, *args):
        '''Initialize connection to the database.'''
        import psycopg2
        connectionString = "host='{0}' port='{1}' dbname='{2}' user='{3}' password='{4}'".format (*args)
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

    def getColumnNames (self):
        return [desc [0] for desc in self.__cursor.description]

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
        argumentParser.add_argument ('-p', '--pass', dest = 'passwd', required = True, help = 'password')
        argumentParser.add_argument ('-n', '--namespace', dest = 'namespace', required = True, help = 'database schema')
        argumentParser.add_argument ('-S', '--smtp', dest = 'sMTP', default = 'localhost', help = 'SMTP server')
        argumentParser.add_argument ('-s', '--subject', dest = 'subject', required = True, help = 'email subject')
        argumentParser.add_argument ('-e', '--email', dest = 'email', required = True, help = 'email address')
        argumentParser.add_argument ('-f', '--from', dest = 'fromEmail', default = 'monitoring', help = 'from address')
        argumentParser.add_argument ('-w', '--warning', type = int, dest = 'warning', default = 1,
                                     help = 'warning limit for one view')
        argumentParser.add_argument ('-t', '--timeout', type = int, dest = 'timeout', help = 'timeout')
        return argumentParser.parse_args ()

    def __init__ (self):
        arguments = self.parseArguments ()
        self.__database = Database (arguments.host, arguments.port, arguments.database, arguments.user, arguments.passwd)
        self.__namespace = arguments.namespace
        self.__sMTPServer = arguments.sMTP
        self.__subject = arguments.subject
        self.__email = arguments.email
        self.__fromEmail = arguments.fromEmail
        self.__warningLimit = arguments.warning
        if arguments.timeout:
            signal.signal (signal.SIGALRM, timeoutRaiser)
            signal.alarm (arguments.timeout)

    def sendEmail (self, message):
        import smtplib
        from email.mime.text import MIMEText
        mIME = MIMEText (message)
        mIME ['Subject'] = self.__subject
        mIME ['To'] = self.__email
        sMTP = smtplib.SMTP (self.__sMTPServer)
        sMTP.sendmail (self.__fromEmail, self.__email, mIME.as_string ())
        sMTP.quit ()

    def checkViews (self):
        '''Find views on the given schema of the database. Return the ones which has rows with row counts.'''
        message = ''
        query = "Select viewname from pg_views where schemaname = '{0}'".format (self.__namespace)
        views = self.__database.selectOneColumn (query)
        if not len (views):
            raise Exception ('There are no views in the {0} schema.'.format (self.__namespace))
        for view in views:
            result = self.__database.select ('Select * from {0}.{1}'.format (self.__namespace, view))
            columnNames= self.__database.getColumnNames ()
            if len (result) >= self.__warningLimit:
                message += '== ' + view + ' ==\n'
                for row in result:
                    for order, cell in enumerate (row):
                        if cell:
                            message += columnNames [order] + ': '
                            message += str (cell) + '\n'
                    message += '\n'
        if message:
            self.sendEmail (message)

class Timeout (Exception): pass
def timeoutRaiser (signum, frame):
    raise Timeout

if __name__ == '__main__':
    '''Run the main program.'''
    checker = Checker ()
    checker.checkViews ()

