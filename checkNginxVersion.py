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
from HTMLParser import HTMLParser

def main():
    if len(sys.argv) < 2:
        raise Exception('No argument.')
    if len(sys.argv) > 2:
        raise Exception('Too many arguments.')

    try:
        serverVersion = getServerVersion(sys.argv[1])
        publishedVersion = getPublishedVersion('http://nginx.org/en/download.html')
    except Exception as exception:
        print('Exception: ' + str(exception))
        sys.exit(3)

    print('Current version ' + serverVersion + ' stable version: ' + publishedVersion)

    if serverVersion != publishedVersion:
        sys.exit(1)
    sys.exit(0)

def getServerVersion(address):
    response = None
    try:
        response = urllib2.urlopen(address)
    except urllib2.HTTPError as error:
        response = error

    server = selectHeader(response.info().headers, 'Server')

    if not server:
        raise Exception('No server header.')

    split = server.strip().split('/')

    if split[0] != 'nginx':
        raise Exception('Server is not Nginx.')

    if len(split) < 2:
        raise Exception('No version on the server header.')

    return split[1]

def selectHeader(headers, key):
    for header in headers:
        if header.startswith(key + ':'):
            return header[(len(key) + 1):]

def getPublishedVersion(address):
    response = urllib2.urlopen(address)

    parser = NginxDownloadHTMLParser()
    parser.feed(response.read())
    stableVersion = parser.stableVersion()

    if not stableVersion:
        raise Exception('Could not get the stable version.')

    return stableVersion

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

if __name__ == '__main__':
    main()
