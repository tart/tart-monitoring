#!/usr/bin/env python
##
# Tart Server Administration
# Nagios Scripts
# Check Cron Job Running Time
#
# @author  Emir Bostan <emir.bostan@tart.com.tr>
# @date    2012-12-19

from __future__ import with_statement
from __future__ import print_function
from datetime import datetime, timedelta
import argparse

fatalString = "PHP Fatal error"
beginString = "CLI_CONTROLLER_STARTED"
endString = "CLI_CONTROLLER_FINISHED"

optionParser = argparse.ArgumentParser(description='This Python script checks whether a running action begins or ends in a given time period.')
optionParser.add_argument("-c", "--critical", type = int, dest = "criticalLimit", help = "Critical time limit for the actions.")
optionParser.add_argument("-w", "--warning", type = int, dest = "warningLimit", help = "Warning time limit for the actions.")
optionParser.add_argument("-f", "--file", type = str, dest = "logFile", help = "Input log file for checking")
options = optionParser.parse_args()

def checkTimeDifference(row, missingAction):
    words = row.split()
    controllerName = words[3]
    actionName = words[4]
    lastTime = words[0] + " " + words[1]
    lastTime = lastTime[1:-1]
    formattedLastTime = datetime.strptime(lastTime, '%Y-%m-%d %H:%M:%S')
    currentTime = datetime.now()
    timeDifference = currentTime - formattedLastTime
    if (timeDifference >= timedelta(minutes=options.warningLimit) and timeDifference < timedelta(minutes=options.criticalLimit)):
        print('warning: ' + controllerName + " controller's " + actionName + " action has a problem. it didn't " + missingAction + " for " + str(timeDifference.seconds/60) + " minutes.")
        return 1
    elif (timeDifference >= timedelta(minutes=options.warningLimit) and timeDifference >= timedelta(minutes=options.criticalLimit)):
        print('critical: ' + controllerName + " controller's " + actionName + " action has a problem. it didn't " + missingAction + " for " + str(timeDifference.seconds/60) + " minutes.")
        return 2
    else :
        print('ok: ' + controllerName + " controller's " + actionName + " cron has been running ok for " + str(timeDifference.seconds/60) + " minutes.")
        return 0

def check():
    returnValue = 0
    checkFlag = 0
    fatalLogs = ''
    with open(options.logFile,"r") as f:
        file = reversed(list(f))
        for row in file:
            if fatalString in row:
                fatalLogs += row
                returnValue = max(returnValue, 1)
            if beginString in row:
                if checkFlag == 1:
                    break
                checkValue = checkTimeDifference(row, "finished")
                returnValue = max(checkValue, returnValue)
                break
            if endString in row:
                checkFlag = 1
                checkValue = checkTimeDifference(row, "started")
                returnValue = max(checkValue, returnValue)
        print(fatalLogs,end='')        
        return returnValue

if __name__ == '__main__':
    exit(check())

