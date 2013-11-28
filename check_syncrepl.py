#!/usr/bin/python

import os
import sys
import getpass
import ldap
import time
import datetime
import re
import logging
from optparse import OptionParser

LdapDelta= "";

__doc__ = """
  This script checks if a consumer is in synch with its provider based on
  the contextCSN. The check can be performed for several consumers.
  If a threshold is specified, the consumer and its provider is considered
  in synch if the difference in contextCSN value is less than the threshold
  value.
  
  Version 1.1 with OpenLDAP 2.4 support
"""

def getUserPassword():
  """
  Get user password
  
  This function returns the password (string)
  """
  # get password input
  password = getpass.getpass('Password: ')
  return password

def create_logger(application, verbose=None, logfile=None):
  """
  Create logger instance to log to console and/or to file
    application - program's name (string)
    verbose - verbose logging (boolean)
    logfile - log file name (string)
  
  This function returns a logger instance
  """
    
  if verbose:
    lowestseverity = logging.DEBUG
  else:
    lowestseverity = logging.INFO

  # Create logger
  logger = logging.getLogger(application)
  logger.setLevel(lowestseverity)

  # Create console handler and set level to lowestseverity
  ch = logging.StreamHandler()
  ch.setLevel(lowestseverity)

  # Create formatter
  formatter = logging.Formatter("%(asctime)s - %(name)s - %(levelname)s - %(message)s")

  # Add formatter to console handler
  ch.setFormatter(formatter)

  # Add console handler to logger
  logger.addHandler(ch)

  if logfile:
    # Create file handler and set level to debug
    fh = logging.FileHandler(logfile)
    fh.setLevel(lowestseverity)
    # Add formatter to console handler and file handler
    fh.setFormatter(formatter)
    # Add file handler to logger
    logger.addHandler(fh)

  return logger

def ldap_connect(ldapuri, logger=None, binddn="", bindpw=""):
  """
  Perform LDAP connection and synchronous simple bind operation
    ldapuri - URI referring to the LDAP server (string)
    binddn - Distinguished Name used to bind (string)
    logger - Logger object instance
    
  This function returns an LDAPobject instance if successful, 
  None if failure
  """
    
  # Set debugging level
  ldap.set_option(ldap.OPT_DEBUG_LEVEL, 0)
  ldap_trace_level = 0    # If non-zero a trace output of LDAP calls is generated.
  ldap_trace_file = sys.stderr
 
  # Create LDAPObject instance
  if logger: logger.debug("Connecting to %s" % ldapuri)
  conn = ldap.initialize(ldapuri,
                         trace_level=ldap_trace_level,
                         trace_file=ldap_trace_file)

  # Set LDAP protocol version used
  if logger: logger.debug("LDAP protocol version 3")
  conn.protocol_version=ldap.VERSION3
  
  # Perform synchronous simple bind operation
  if binddn:
    password = bindpw
    if logger: logger.debug("Binding with %s" % binddn)
  else:
    if logger: logger.debug("Binding anonymously")
    password = "";
  try:
    conn.bind_s(binddn, password, ldap.AUTH_SIMPLE)
    return conn
  except ldap.LDAPError, error_message:
    if logger: logger.error("LDAP bind failed. %s" % error_message)
    print("FAILED : LDAP bind failed. %s" % error_message)
    return None
    
def ldap_search(ldapobj, basedn, scope, filter, attrlist):
  """
  Perform LDAP synchronous search operation
    ldapobj - LDAP object instance
    basedn - LDAP base dn (string)
    scope - LDAP search scope (integer)
    filter - LDAP filter (string)
    attrlist - LDAP attributes (list)
  
  This function returns a result set (list),
  None if no attribute was found
  """
  result_set = (ldapobj.search_s(basedn, scope, filter, attrlist))
  return result_set

def get_contextCSN(ldapobj, basedn, logger=None):
  """
  Retrieve contextCSN attribute value for the suffix dn
    ldapobj - LDAP object instance
    basedn - LDAP base dn (string)
    
  This function returns the contextCSN value (string),
  None if no value was found
  """
  result_list = ldap_search(ldapobj, basedn, ldap.SCOPE_BASE, '(objectclass=*)', ['contextCSN'])
  if result_list[0][1].has_key('contextCSN'):
    if logger: logger.debug("contextCSN = %s" % result_list[0][1]['contextCSN'][0] )
    return result_list[0][1]['contextCSN'][0]
  else:
    if logger: logger.error("No contextCSN was found")
    return None
    
def contextCSN_to_datetime(contextCSN):
  """
  Convert contextCSN string (YYYYmmddHHMMMSSZ#...) to datetime object
    contextCSN - Timestamp in YYYYmmddHHMMSSZ#... format (string)
    
  This function returns a datetime object instance
  """
  gentime = re.sub('(\.\d{6})?Z.*$','',contextCSN)
  return datetime.datetime.fromtimestamp(time.mktime(time.strptime(gentime,"%Y%m%d%H%M%S")))

def threshold_to_datetime(threshold):
  """
  Convert threshold in seconds to datetime object
    threshold - seconds (integer)
    
  This function returns a datetime object instance
  """
  nbdays, nbseconds = divmod(threshold, 86400)
  return datetime.timedelta(days=nbdays, seconds=nbseconds)

def is_insynch(provldapobj, consldapobj, basedn, threshold=None, logger=None):
  """
  Check if the consumer is in synch with the provider within the threshold
    provldapobj - Provider LDAP object instance
    consldapobj - Consumer LDAP object instance
    basedn - LDAP base dn (string)
    threshold - limit above which provider and consumer are not considered
    in synch (int)
  
  This function returns False if the provider and the consumer is not
  in synch, True if in synch within the threshold
  """
  if logger: logger.debug("Retrieving Provider contextCSN")
  provcontextCSN = get_contextCSN(provldapobj, basedn, logger)
  if logger: logger.debug("Retrieving Consumer contextCSN")
  conscontextCSN = get_contextCSN(consldapobj, basedn, logger)
  if (provcontextCSN and conscontextCSN):
    if (provcontextCSN == conscontextCSN):
      if logger: logger.info("  Provider and consumer exactly in SYNCH")
      print("OK - Provider and consumer exactly in SYNCH")
      return True
    else:
      delta = contextCSN_to_datetime(provcontextCSN) - contextCSN_to_datetime(conscontextCSN)
      LdapDelta= "Delta is: %s" % delta;
      if threshold:
        maxdelta = threshold_to_datetime(eval(threshold))
        if logger: logger.debug("Threshold is %s" % maxdelta)
        if (abs(delta) <= maxdelta):
          if logger:
            logger.info("  Consumer in SYNCH within threshold")
            logger.info("  Delta is %s" % delta)
	  print("OK - Delta is %s|%s" % (delta, delta))
          return True
        else:
          if logger: logger.info("  Consumer NOT in SYNCH within threshold")
      else:
        if logger: logger.info("  Consumer NOT in SYNCH")
      if logger: logger.info("  Delta is %s" % delta)
      print ("FAILED - Delta is %s|%s" % (delta, delta))
  else:
    if logger: logger.error("  Check failed: at least one contextCSN value is missing")
    print("Check failed: at least one contextCSN value is missing")
  return False

def main():
  IsInSync= True;
  usage = "\n  " + sys.argv[0] + """ [options] providerLDAPURI consumerLDAPURI ...
  This script takes at least two arguments:
        - providerLDAPURI is the provider LDAP URI (as defined in RFC2255)
        - consumerLDAPURI is the consumer LDAP URI (as defined in RFC2255)
  Additional consumer LDAP URIs can be specified.
  """
  
  parser = OptionParser(usage=usage)
  
  parser.add_option("-v", "--verbose", dest="verbose", action="store_true",
                    default=False,
                    help="""Enable more verbose output""")
  parser.add_option("-q", "--quiet", dest="quiet", action="store_true",
                    default=False,
                    help="""Disable console and file logging""")
  parser.add_option("-n", "--nagios", dest="nagios", action="store_true",
                    default=False,
                    help="""Enable for Nagios""")
  parser.add_option("-p", "--password", dest="password", 
                    default="",
                    help="""Bind password""")
  parser.add_option("-P", "--Password2", dest="password2", 
                    default="",
                    help="""Bind password2 for consumers""")
  parser.add_option("-l", "--logfile", dest="logfile", default=re.sub("\.[^\.]*$","",sys.argv[0]) + '.log',
                    help="""Log the actions of this script to this file
                            [ default : %default ]""")
  parser.add_option("-D", "--binddn",
                    dest="binddn", default="",
                    help="""Use the Distinguished Name to bind [default:
                    anonymous]. You will be prompted to enter the
                    associated password.""")    
  parser.add_option("-b", "--basedn",
                    dest="basedn", default="dc=amnh,dc=org",
                    help="LDAP base dn [default: %default].")
  parser.add_option("-t", "--threshold", dest="threshold",
                    default=None,
                    help="""Threshold value in seconds""")

  (options, args) = parser.parse_args()

  if not options.quiet:
    # Create the logger object to log to console and/or file
    logger = create_logger(os.path.basename(sys.argv[0]), options.verbose, options.logfile)
  else:
    logger = None

  if logger: logger.info("Provider is: %s" % re.sub("^.*\/\/", "", args[0]))
  ldapprov = ldap_connect(args.pop(0), logger, options.binddn, options.password)
  if ldapprov:
    for consumer in args:
      if logger: logger.info("Checking if consumer %s is in SYNCH with provider" % re.sub("^.*\/\/", "", consumer))
      ldapcons = ldap_connect(consumer, logger, options.binddn, options.password2)
      if ldapcons:
        IsInSync = IsInSync and is_insynch(ldapprov, ldapcons, options.basedn, options.threshold, logger)
        ldapcons.unbind_s()
      else:
	sys.exit(1)
        
    ldapprov.unbind_s()
    if (options.nagios):
	if (IsInSync):
	    sys.exit(0)
	else:
	    sys.exit(2)
  else:
    sys.exit(1)

if __name__ == '__main__':
    main()
