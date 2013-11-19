#!/usr/bin/env python

# This Nagios plugin may be used to check the health of an RDP server, such
# as a Windows host offering remote desktop. Typically, a "strange" RDP
# response is a good indication of a Windows host is having trouble (while
# it is still responding to ping).

# It seems that the RDP protocol is based on a protocol called X.224,
# and this plugin only goes as far as checking very basic X.224
# protocol operations. Hence, the somewhat strange name of the plugin.

# Example of a check command definition, using this plugin:
# define command{
#         command_name    check_x224
#         command_line    /usr/local/nagios/check_x224 -H $HOSTADDRESS$
#         }
#
# A corresponding service definition might look like:
# define service{
#         service_description             Remote desktop
#         check_command                   check_x224
#         host_name                       somename.example.com
#         use                             generic-service
#         }

# Author: Troels Arvin <tra@sst.dk>
# Last modified: 2012-12-08.

# Copyright (c) 2011, Danish National Board of Health.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#     * Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in the
#       documentation and/or other materials provided with the distribution.
#     * Neither the name of the  the Danish National Board of Health nor the
#       names of its contributors may be used to endorse or promote products
#       derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY the Danish National Board of Health ''AS IS'' AND ANY
# EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL the Danish National Board of Health BE LIABLE FOR ANY
# DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

# References:
# TPKT:  http://www.itu.int/rec/T-REC-T.123/
# X.224: http://www.itu.int/rec/T-REC-X.224/en

default_rdp_port = 3389
default_warning_sec = 3
default_critical_sec = 50

def do_conn(hostname,port,setup_payload,teardown_payload):
    try:
        s = socket.socket()
        t1 = time.time()

        # connect
        s.connect((hostname,port))
        sent_bytes = s.send(setup_payload)
        if sent_bytes != len(setup_payload):
            print('Could not send RDP setup payload')
            sys.exit(2)
        setup_received = s.recv(1024)
        t2 = time.time()

        # disconnect
        sent_bytes = s.send(teardown_payload)
        if sent_bytes != len(teardown_payload):
            print('x224 CRITICAL: Could not send RDP teardown payload')
            sys.exit(2)
        s.close()

        elapsed = t2 - t1

        l_setup_received = len(setup_received)
        l_expected_short = 11
        l_expected_long  = 19
        if l_setup_received != l_expected_short and l_setup_received != l_expected_long:
            print('x224 CRITICAL: RDP response of unexpected length (%d)' % l_setup_received)
            sys.exit(2)
    except socket.error as e:
        if e.errno == -2:
            print("x224 UNKNOWN: Could not resolve hostname '%s': %s" % (hostname,e))
            sys.exit(3)
        print('x224 CRITICAL: Could not set up connection on port %d: %s' % (port,e))
        sys.exit(2)
    except Exception as e:
        print('x224 CRITICAL: Problem communicating with RDP server: %s' % e)
        sys.exit(2)
    return (elapsed,setup_received)

# wrapping in gigantic try-block to be able to return 3 if something
# unexpected goes wrong
try:
    import os
    import sys
    import getopt
    import socket
    import struct
    import time

    this_script = os.path.basename(__file__)

    def usage():
        print("""Usage: %s [-h|--help] -H hostname [-p|--port port] [-w|--warning seconds] [-c|--critical seconds]

    port            : tcp port to connect to; default: %d 
    warning seconds : number of seconds that an RDP response may take without
                      emitting a warning; default: %d
    critical seconds: number of seconds that an RDP response may take without
                      emitting status=critical; default: %d""" % (this_script,default_rdp_port,default_warning_sec,default_critical_sec))
        sys.exit(3)

    try:
        options, args = getopt.getopt(sys.argv[1:],
            "hw:c:H:p:",
                [
                    'help',
                    'warning=',
                    'critical=',
                    'port='
                ]
            )
    except getopt.GetoptError:
        usage()
        sys.exit(3)

    warning_sec = default_warning_sec
    critical_sec = default_critical_sec
    rdp_port = default_rdp_port
    hostname = ''

    for name, value in options:
        if name in ("-h", "--help"):
            usage()
        if name == '-H':
            hostname = value
        if name in ('-p', '--port'):
            try:
                rdp_port = int(value)
            except Exception:
                print("Unable to convert port to integer\n")
                usage()
        if name in ("-w", "--warning"):
            try:
                warning_sec = int(value)
            except Exception:
                print("Unable to convert warning_sec to integer\n")
                usage()
        if name in ("-c", "--critical"):
            try:
                critical_sec = int(value)
            except Exception:
                print("Unable to convert critical_sec to integer\n")
                usage()

    if rdp_port < 0:
        print('port number (%d) negative' % rdp_port)
        usage()

    if hostname == '':
        print('Hostname (-H) not indicated')
        usage()

    if (warning_sec > critical_sec):
        print('warning seconds (%d) may not be greater than critical_seconds (%d)' % (warning_sec,critical_sec))
        usage()

    # make sure that we don't give up before critical sec has had a chance to elapse
    socket.setdefaulttimeout(critical_sec+2)

    setup_x224_cookie = "Cookie: mstshash=\r\n".encode('ascii')
    setup_x224_rdp_neg_data = struct.pack(  # little-endian here, it seems ?
        '<BBHI',
        1, # type
        0, # flags
        8, # length
        3, # TLS + CredSSP
    )
    setup_x224_header = struct.pack(
        '!BBHHB',
        len(setup_x224_cookie)+6+8, # length,  1 byte
                                    #  6: length of this header, excluding length byte
                                    #  8: length of setup_x224_rdp_neg_data (static)
        224,                        # code,    1 byte (224 = 0xe0 = connection request)
        0,                          # dst-ref, 1 short
        0,                          # src-ref, 1 short
        0                           # class,   1 byte
    ) 
    setup_x224 = setup_x224_header + setup_x224_cookie + setup_x224_rdp_neg_data

    tpkt_total_len = len(setup_x224) + 4
    # 4 is the static size of a tpkt header
    setup_tpkt_header = struct.pack(
        '!BBH',
        3,                          # version,  1 byte
        0,                          # reserved, 1 byte
        tpkt_total_len              # len,      1 short
    )

    setup_payload = setup_tpkt_header + setup_x224

    #print('Len of cookie: %d'       % len(setup_x224_cookie))
    #print('Len of rdp_neg_data: %d' % len(setup_x224_rdp_neg_data))
    #print('Len of header: %d'       % len(setup_x224_header))
    #print('Len of setup_x224: %d'   % len(setup_x224))
    #print('tpkt_total_len: %d'   % tpkt_total_len)

    teardown_payload = struct.pack(
        '!BBHBBBBBBB',
        3,                          # tpkt version,  1 byte
        0,                          # tpkt reserved, 1 byte
        11,                         # tpkt len,      1 short
        6,                          # x224 len,      1 byte
        128,                        # x224 code,     1 byte
        0,                          # x224 ?,        1 byte
        0,                          # x224 ?,        1 byte
        0,                          # x224 ?,        1 byte
        0,                          # x224 ?,        1 byte
        0                           # x224 ?,        1 byte
    )

    elapsed,rec = do_conn(hostname,rdp_port,setup_payload,teardown_payload)

    if elapsed > critical_sec:
        print('x224 CRITICAL: RDP connection setup time (%f) was longer than (%d) seconds' % (elapsed,critical_sec))
        sys.exit(2)
    if elapsed > warning_sec:
        print('x224 WARNING: RDP connection setup time (%f) was longer than (%d) seconds' % (elapsed,warning_sec))
        sys.exit(1)

    rec_tpkt_header={}
    rec_x224_header={}
    rec_nego_resp  ={}

    # Older Windows hosts will return with a short answer
    if len(rec) == 11:
        rec_tpkt_header['version'],         \
            rec_tpkt_header['reserved'],    \
            rec_tpkt_header['length'],      \
                                            \
            rec_x224_header['length'],      \
            rec_x224_header['code'],        \
            rec_x224_header['dst_ref'],     \
            rec_x224_header['src_ref'],     \
            rec_x224_header['class'],       \
            = struct.unpack('!BBHBBHHB',rec)
    else:
        # Newer Windows hosts will return with a longer answer
        rec_tpkt_header['version'],         \
            rec_tpkt_header['reserved'],    \
            rec_tpkt_header['length'],      \
                                            \
            rec_x224_header['length'],      \
            rec_x224_header['code'],        \
            rec_x224_header['dst_ref'],     \
            rec_x224_header['src_ref'],     \
            rec_x224_header['class'],       \
                                            \
            rec_nego_resp['type'],          \
            rec_nego_resp['flags'],         \
            rec_nego_resp['length'],        \
            rec_nego_resp['selected_proto'] \
            = struct.unpack('!BBHBBHHBBBHI',rec)

    if rec_tpkt_header['version'] != 3:
        print('x224 CRITICAL: Unexpected version-value(%d) in TPKT response' % rec_tpkt_header['version'])
        sys.exit(2)

    # 13 = binary 00001101; corresponding to 11010000 shifted four times
    # dst_ref=0 and class=0 was asked for in the connection setup
    if (rec_x224_header['code'] >> 4) != 13 or \
            rec_x224_header['dst_ref'] != 0 or \
            rec_x224_header['class'] != 0:
        print('x224 CRITICAL: Unexpected element(s) in X.224 response')
        sys.exit(2)

except struct.error as e:
    print('x224 CRITICAL: Could not decode RDP response: %s' % e)
    sys.exit(2)
except SystemExit as e:
    # Special case which is needed in order to convert the return code
    # from other exception handlers.
    sys.exit(int(str(e)))
except Exception as e:
    # At this point, we don't know what's going on, so let's
    # not output the details of the error into something which
    # would appear in the Nagios web interface. Do print the details
    # on stderr, though, to ease debugging.
    print('x224 UNKNOWN: An unhandled error occurred')
    sys.stderr.write('Unhandled error: %s' % sys.exc_info()[1])
    sys.exit(3)

print('x224 OK. Connection setup time: %f sec.|time=%fs;%d;%d;0' % (elapsed,elapsed,warning_sec,critical_sec))
sys.exit(0)
