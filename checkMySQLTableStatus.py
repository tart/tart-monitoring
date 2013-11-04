#!/usr/bin/env python
##
# Tart Database Operations
# Check MySQL Table Status
#
# @author  Emre Hasegeli <emre.hasegeli@tart.com.tr>
# @date    2012-01-31
##

class Value:
    def __init__ (self, value):
        '''Parses the value.'''
        if str (value) [-1:] in ('K', 'M', 'G', 'T'):
            self.__int = int (value [:-1])
            self.__unit = value [-1:]
        else:
            self.__int = int (value)
            self.__unit = None

    def __str__ (self):
        '''If necessary changes the value to number + unit format by rounding.'''
        if self.__unit:
            return str (self.__int) + self.__unit
        if self.__int > 10 ** 12:
            return str (round (self.__int / 10 ** 12)) [:-2] + 'T'
        if self.__int > 10 ** 9:
            return str (round (self.__int / 10 ** 9)) [:-2] + 'G'
        if self.__int > 10 ** 6:
            return str (round (self.__int / 10 ** 6)) [:-2] + 'M'
        if self.__int > 10 ** 3:
            return str (round (self.__int / 10 ** 3)) [:-2] + 'K'
        return str (self.__int)

    def __int__ (self):
        '''If necessary changes the value to number format.'''
        if self.__unit == 'K':
            return self.__int * 10 ** 3
        if self.__unit == 'M':
            return self.__int * 10 ** 6
        if self.__unit == 'G':
            return self.__int * 10 ** 9
        if self.__unit == 'T':
            return self.__int * 10 ** 12
        return self.__int

    def __cmp__ (self, other):
        return cmp (int (self), int (other))

class Table:
    def __init__ (self, schema, name, attributeValues):
        self.__schema = schema
        self.__name = name
        self.__attributeValues = attributeValues

    def __str__ (self):
        return self.__schema + '.' + self.__name

    def getAttribute (self, name):
        if self.__attributeValues.has_key (name):
            return self.__attributeValues [name]

class Database:
    def __init__ (self, host, port, user, passwd):
        import MySQLdb
        self.__connection = MySQLdb.connect (host = host, port = port, user = user, passwd = passwd)
        self.__cursor = self.__connection.cursor ()

    def __del__ (self):
        if self.__cursor:
            self.__cursor.close ()
            self.__connection.close ()

    def select (self, query):
        self.__cursor.execute (query)
        return self.__cursor.fetchall ()

    def getColumnPosition (self, name):
        column = [desc [0] for desc in self.__cursor.description]
        for position, column in enumerate (column):
            if column.lower () == name.lower ():
                return position

    def yieldTables (self, attributes):
        '''Iterate tables with selected attributes.'''
        for schemaRow in self.select ('Show schemas'):
            for tableRow in self.select ('Show table status in ' + schemaRow [0] + ' where Engine is not null'):
                attributeValues = {}
                for attribute in attributes:
                    columnPosition = self.getColumnPosition (attribute)
                    if tableRow [columnPosition]:
                        attributeValues [attribute] = (Value (tableRow [columnPosition]))
                yield Table (schemaRow [0], tableRow [0], attributeValues)

class Output:
    def __init__ (self, attribute, warningLimit = None, criticalLimit = None):
        self._attribute = attribute
        self._warningLimit = warningLimit
        self._criticalLimit = criticalLimit

    def getPerformanceData (self, name, value):
        '''Format performance data.'''
        message = name + '.' + self._attribute + '=' + str (value) + ';'
        if self._warningLimit:
            message += str (int (self._warningLimit))
        message += ';'
        if self._criticalLimit:
            message += str (int (self._criticalLimit))
        return message + ';0;'

class OutputAll (Output):
    def __init__ (self, *args):
        Output.__init__ (self, *args)
        self.__message = ''

    def addMessageForTable (self, table):
        if self.__message:
            self.__message += ' '
        self.__message += self.getPerformanceData (str (table), int (table.getAttribute (self._attribute)))

    def check (self, table):
        if table.getAttribute (self._attribute):
            self.addMessageForTable (table)

    def getMessage (self, name):
        if name == 'performance':
            return self.__message

class OutputTables (OutputAll):
    def __init__ (self, tableNames, *args):
        OutputAll.__init__ (self, *args)
        self.__tableNames = tableNames

    def check (self, table):
        if table.getAttribute (self._attribute):
            for tableName in self.__tableNames:
                if tableName == str (table):
                    self.addMessageForTable (table)

class OutputUpperLimit (Output):
    def __init__ (self, *args):
        Output.__init__ (self, *args)
        self.__messages = {}

    def addMessageForTable (self, name, table, limit):
        if not self.__messages.has_key (name):
            self.__messages [name] = ''
        else:
            self.__messages [name] += ' '
        self.__messages [name] += str (table) + '.' + self._attribute + ' = '
        self.__messages [name] += str (table.getAttribute (self._attribute)) + ' reached '
        self.__messages [name] += str (limit) + ';'

    def check (self, table):
        '''Check for warning and critical limits. Do not add message to both warning and critical lists.'''
        if table.getAttribute (self._attribute):
            if self._criticalLimit and table.getAttribute (self._attribute) > self._criticalLimit:
                self.addMessageForTable ('critical', table, self._criticalLimit)
            elif self._warningLimit and table.getAttribute (self._attribute) > self._warningLimit:
                self.addMessageForTable ('warning', table, self._warningLimit)

    def getMessage (self, name):
        if self.__messages.has_key (name):
            return self.__messages [name]

class OutputAverage (Output):
    def __init__ (self, *args):
        Output.__init__ (self, *args)
        self.__count = 0
        self.__total = 0

    def check (self, table):
        '''Count tables and sum values for average calculation.'''
        if table.getAttribute (self._attribute):
            self.__count += 1
            self.__total += int (table.getAttribute (self._attribute))

    def getValue (self):
        return Value (round (self.__total / self.__count))

    def getMessage (self, name):
        if self.__count:
            if name == 'ok':
                return 'average ' + self._attribute + ' = ' + str (self.getValue ()) + ';'
            if name == 'performance':
                return self.getPerformanceData ('average', int (self.getValue ()))

class OutputMaximum (Output):
    def __init__ (self, *args):
        Output.__init__ (self, *args)
        self.__table = None

    def check (self, table):
        '''Get table which has maximum value.'''
        if table.getAttribute (self._attribute):
            if not self.__table or table.getAttribute (self._attribute) > self.__table.getAttribute (self._attribute):
                self.__table = table

    def getMessage (self, name):
        if self.__table:
            if name == 'ok':
                message = 'maximum ' + self._attribute + ' = ' + str (self.__table.getAttribute (self._attribute))
                return message + ' for table ' + str (self.__table) + ';'
            if name == 'performance':
                return self.getPerformanceData ('maximum', int (self.__table.getAttribute (self._attribute)))

class OutputMinimum (Output):
    def __init__ (self, *args):
        Output.__init__ (self, *args)
        self.__table = None

    def check (self, table):
        '''Get table which has minimum value.'''
        if table.getAttribute (self._attribute):
            if not self.__table or table.getAttribute (self._attribute) < self.__table.getAttribute (self._attribute):
                self.__table = table

    def getMessage (self, name):
        if self.__table:
            if name == 'ok':
                message = 'minimum ' + self._attribute + ' = ' + str (self.__table.getAttribute (self._attribute))
                return message + ' for table ' + str (self.__table) + ';'
            if name == 'performance':
                return self.getPerformanceData ('minimum', int (self.__table.getAttribute (self._attribute)))

class Readme:
    def __init__ (self):
        '''Parse texts on the readme file on the repository to sections..'''
        readmeFile = open ('README.md')
        self.__sections = []
        for line in readmeFile.readlines ():
            if line [:2] == '##':
                self.__sections.append (line [3:-1] + ':\n')
            elif self.__sections and line [:-1] not in ('```', ''):
                self.__sections [-1] += line
        readmeFile.close ()

    def getSectionsConcatenated (self):
        body = ''
        for section in self.__sections:
            body += section + '\n'
        return body

class Checker:
    '''Modes used to check different values of tables. Multiple vales can be given comma separated to modes and limits.
    K for 10**3, M for 10**6, G for 10**9, T for 10**12 units can be used for limits.'''
    defaultModes = 'rows,data_length,index_length'
    def parseArguments (self):
        '''Create ArgumentParser instance. Return parsed arguments.'''
        try:
            readme = Readme ()
            epilog = readme.getSectionsConcatenated ()
        except IOError:
            epilog = None
        def options (value):
            return value.split (',')

        from argparse import ArgumentParser, RawTextHelpFormatter, ArgumentDefaultsHelpFormatter
        class Formatter (RawTextHelpFormatter, ArgumentDefaultsHelpFormatter): pass
        argumentParser = ArgumentParser (formatter_class = Formatter, description = self.__doc__, epilog = epilog)
        argumentParser.add_argument ('-H', '--host', dest = 'host', help = 'hostname', default = 'localhost')
        argumentParser.add_argument ('-P', '--port', type = int, dest = 'port', default = 3306)
        argumentParser.add_argument ('-u', '--user', dest = 'user', required = True, help = 'username')
        argumentParser.add_argument ('-p', '--pass', dest = 'passwd', required = True, help = 'password')
        argumentParser.add_argument ('-m', '--mode', type = options, dest = 'modes', default = self.defaultModes)
        argumentParser.add_argument ('-w', '--warning', type = options, dest = 'warnings', help = 'warning limits')
        argumentParser.add_argument ('-c', '--critical', type = options, dest = 'criticals', help = 'critical limits')
        argumentParser.add_argument ('-t', '--tables', type = options, dest = 'tables', help = 'show selected tables')
        argumentParser.add_argument ('-a', '--all', dest = 'all', action = 'store_true', help = 'show all tables')
        argumentParser.add_argument ('-A', '--average', dest = 'average', action = 'store_true', help = 'show averages')
        argumentParser.add_argument ('-M', '--maximum', dest = 'maximum', action = 'store_true', help = 'show maximums')
        argumentParser.add_argument ('-N', '--minimum', dest = 'minimum', action = 'store_true', help = 'show minimums')
        return argumentParser.parse_args ()

    def __init__ (self):
        arguments = self.parseArguments ()
        self.__attributes = []
        self.__outputs = []
        self.__database = Database (arguments.host, arguments.port, arguments.user, arguments.passwd)
        for counter, mode in enumerate (arguments.modes):
            self.__attributes.append (mode)
            warningLimit = None
            if arguments.warnings:
                if counter < len (arguments.warnings):
                    warningLimit = Value (arguments.warnings [counter])
            criticalLimit = None
            if arguments.criticals:
                if counter < len (arguments.criticals):
                    criticalLimit = Value (arguments.criticals [counter])
            self.__outputs.append (OutputUpperLimit (mode, warningLimit, criticalLimit))
            if arguments.all:
                self.__outputs.append (OutputAll (mode, warningLimit, criticalLimit))
            elif arguments.tables:
                self.__outputs.append (OutputTables (arguments.tables, mode, warningLimit, criticalLimit))
            if arguments.average:
                self.__outputs.append (OutputAverage (mode, warningLimit, criticalLimit))
            if arguments.maximum:
                self.__outputs.append (OutputMaximum (mode, warningLimit, criticalLimit))
            if arguments.minimum:
                self.__outputs.append (OutputMinimum (mode, warningLimit, criticalLimit))

    def concatenateMessages (self, messages):
        concatenatedMessage = ''
        for message in messages:
            if message:
                if concatenatedMessage:
                    concatenatedMessage += ' '
                concatenatedMessage += message
        return concatenatedMessage

    messageNames = ('ok', 'warning', 'critical', 'performance')
    def getMessages (self):
        '''Check all tables for all output instances. Return the messages.'''
        for table in self.__database.yieldTables (self.__attributes):
            for output in self.__outputs:
                output.check (table)
        messages = {}
        for name in Checker.messageNames:
            messages [name] = self.concatenateMessages ([output.getMessage (name) for output in self.__outputs])
        return messages

if __name__ == '__main__':
    print 'CheckMySQLTableStatus',
    import sys
    try:
        checker = Checker ()
        messages = checker.getMessages ()
    except Exception, exception:
        try:
            print 'unknown:', exception [1],
        except IndexError:
            print 'unknown:', exception,
        sys.exit (3)
    else:
        if messages ['critical']:
            print 'critical:', messages ['critical'],
        if messages ['warning']:
            print 'warning:', messages ['warning'],
        if not messages ['critical'] and not messages ['warning']:
            if messages ['ok']:
                print 'ok:', messages ['ok'],
            else:
                print 'ok',
        if messages ['performance']:
            print '|', messages ['performance'],
        if messages ['critical']:
            sys.exit (2)
        if messages ['warning']:
            sys.exit (1)
        sys.exit (0)
