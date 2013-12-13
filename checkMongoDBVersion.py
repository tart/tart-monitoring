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

import sys
import urllib2
import pymongo
import re

from HTMLParser import HTMLParser

class DownloadHTMLParser(HTMLParser):
    def __init__(self):
        HTMLParser.__init__(self)
        self.__inHeader = False
        self.__headers = []

    def handle_starttag(self, tag, attrs):
        if tag in ('h1', 'h2', 'h3', 'h4'):
            self.__inHeader = True

    def handle_data(self, data):
        if self.__inHeader:
            self.__headers.append(data)

    def lastMinorVersion(self, majorVersion):
        for header in self.__headers:
            version = re.search(majorVersion + '\.[0-9]+', header)

            if version:
                return version.group()

if len(sys.argv) < 2:
    raise Exception('No argument.')
if len(sys.argv) > 2:
    raise Exception('Too many arguments.')

serverInfo = pymongo.Connection(sys.argv[1]).server_info()
majorVersion = str(serverInfo['versionArray'][0]) + '.' + str(serverInfo['versionArray'][1])

response = urllib2.urlopen('http://www.mongodb.org/downloads')

parser = DownloadHTMLParser()
parser.feed(response.read())
lastMinorVersion = parser.lastMinorVersion(majorVersion)

if not lastMinorVersion:
    raise Exception('Could not get the last minor version.')

print('Current version ' + serverInfo['version'] + ' last minor version: ' + lastMinorVersion)

if serverInfo['version'] != lastMinorVersion:
    sys.exit(1)
sys.exit(0)

