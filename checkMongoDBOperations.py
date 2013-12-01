#!/usr/bin/env python
# -*- coding: utf-8 -*-
##
# Tart Monitoring
#
# Copyright(c) 2013, Tart İnternet Teknolojileri Ticaret AŞ
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
import pymongo
import argparse

class Server:
    '''Connects to the MongoDB server, executes operations.'''

    def __init__(self, address, port):
        self.__connection = pymongo.Connection(address, port)

    def currentOperationCount(self):
        '''Execute currentOp operation on the server. Return count of operations.'''
        return len(self.__connection.admin.current_op()['inprog'])

class Timeout(Exception): pass

def timeoutRaiser(signum, frame):
        raise Timeout

class Checker:
    '''Checks operations on the MongoDB server. Returns warning or critical if given limits exceeded.'''

    def parseArguments(self):
        '''Create ArgumentParser instance. Return parsed arguments.'''
        class Formatter(argparse.RawTextHelpFormatter, argparse.ArgumentDefaultsHelpFormatter): pass
        argumentParser = argparse.ArgumentParser(formatter_class=Formatter, description=self.__doc__)
        argumentParser.add_argument('-H', '--host', dest='host', help='hostname', default='localhost')
        argumentParser.add_argument('-P', '--port', type=int, dest='port', default=27017)
        argumentParser.add_argument('-w', '--warning', type=int, dest='warning', help='warning limit')
        argumentParser.add_argument('-c', '--critical', type=int, dest='critical', help='critical limit')
        return argumentParser.parse_args()

    def __init__(self):
        signal.signal(signal.SIGALRM, timeoutRaiser)
        signal.alarm(10)
        arguments = self.parseArguments()
        assert arguments.warning is None or arguments.critical is None or arguments.warning < arguments.critical
        self.__host = arguments.host
        self.__port = arguments.port
        self.__warningLimit = arguments.warning
        self.__criticalLimit = arguments.critical

    def checkOperationCount(self):
        '''Run the main program.'''
        print('CheckMongoDBConnections ', end='')
        try:
            server = Server(self.__host, self.__port)
            currentOperationCount = server.currentOperationCount()
        except Exception as exception:
            try:
                print('unknown: ' + exception[1])
            except IndexError:
                print('unknown: ' + str(exception))
            returnValue = 3
        else:
            if self.__criticalLimit is not None and currentOperationCount > self.__criticalLimit:
                print('critical: ', end=' ')
                returnValue = 2
            elif self.__warningLimit is not None and currentOperationCount > self.__warningLimit:
                print('warning:', end=' ')
                returnValue = 1
            else:
                print('ok:', end=' ')
                returnValue = 0
            print(str(currentOperationCount) + ' operations', end=' ')
            print('| operationCount=' + str(currentOperationCount) + ';' + str(self.__warningLimit or '') + ';' + str(self.__criticalLimit or '') + ';0;')
        return returnValue

if __name__ == '__main__':
    checker = Checker()
    exit(checker.checkOperationCount())
