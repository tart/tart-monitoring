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
import xmlrpclib

def exitCode(state):
    if state == 'FATAL':
        return 2
    if state != 'RUNNING':
        return 1
    return 0

def main(argv):
    if len(argv) < 2:
        raise Exception('No argument.')
    if len(argv) > 2:
        raise Exception('Too many arguments.')

    server = xmlrpclib.Server(argv[1])
    processes = server.supervisor.getAllProcessInfo()

    if not processes:
        raise Exception('No process.')

    processesByState = {}
    for process in processes:
        if process['statename'] not in processesByState:
            processesByState[process['statename']] = []
        processesByState[process['statename']].append(process)

    for state in sorted(processesByState, key=exitCode, reverse=True):
        print(state, end=': ')
        if len(processesByState[state]) / (exitCode(state) + 1) < 5:
            for process in processesByState[state]:
                print(process['name'], end=' ')
                if process.get('description'):
                    print(process['description'], end=' ')
        else:
            print(str(len(processesByState[state])) + ' process', end=' ')

    print()
    return max((exitCode(state) for state in processesByState))

if __name__ == '__main__':
    try:
        sys.exit(main(sys.argv))
    except Exception as exception:
        print('Error: ' + str(exception))
        sys.exit(3)

