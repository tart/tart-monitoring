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
import re

def main():
    if len(sys.argv) < 2:
        raise Exception('No argument.')
    if len(sys.argv) > 2:
        raise Exception('Too many arguments.')

    try:
        serverVersion = getServerVersion(sys.argv[1])
    except Exception as exception:
        print('Cannot get the server version: ' + str(exception))
        sys.exit(3)

    majorVersion = serverVersion.rsplit('.', 1)[0]

    try:
        publishedVersion = getPublishedVersion('http://nginx.org/en/download.html', majorVersion)
    except Exception as exception:
        print('Cannot get the published version: ' + str(exception))
        sys.exit(3)

    print('Server version: ' + serverVersion + ' published version: ' + publishedVersion)

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

def getPublishedVersion(address, majorVersion):
    response = urllib2.urlopen(address)

    versions = re.findall('nginx-' + majorVersion + '.[0-99]', response.read())  

    if not versions:
        raise Exception('Page does not include the major version.')

    return versions[0].split('-')[1]

if __name__ == '__main__':
    main()
