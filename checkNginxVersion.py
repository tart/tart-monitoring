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

if len(sys.argv) < 2:
    raise Exception('No argument.')
if len(sys.argv) > 2:
    raise Exception('Too many arguments.')

response = None
try:
    response = urllib2.urlopen(sys.argv[1])
except urllib2.HTTPError as error:
    response = error

if not response:
    raise Exception('No response.')

info = response.info()

def getHeaderValue(info, key):
    for header in info.headers:
        if header.startswith(key + ':'):
            return header[(len(key) + 1):]

server = getHeaderValue(info, 'Server')

if not server:
    raise Exception('No server header.')

split = server.strip().split('/')

if split[0] != 'nginx':
    raise Exception('Server is not Nginx.')

if len(split) < 2:
    raise Exception('No version on the server header.')

currentVersion = split[1]

response = urllib2.urlopen('http://nginx.org/en/download.html')

from HTMLParser import HTMLParser

class NginxDownloadHTMLParser(HTMLParser):
    def __init__(self):
        HTMLParser.__init__(self)
        self.__lastTag = None
        self.__h4 = None
        self.__stableVersion = None

    def handle_starttag(self, tag, attrs):
        self.__lastTag = tag

    def handle_data(self, data):
        if self.__lastTag == 'h4':
            self.__h4 = data

        if self.__h4 == 'Stable version' and data[:6] == 'nginx-':
            self.__stableVersion = data[6:]

    def stableVersion(self):
        return self.__stableVersion

parser = NginxDownloadHTMLParser()
parser.feed(response.read())
stableVersion = parser.stableVersion()

if not stableVersion:
    raise Exception('Could not get the stable version.')

print('Current version ' + currentVersion + ' stable version: ' + stableVersion)

if currentVersion != stableVersion:
    sys.exit(1)
sys.exit(0)

