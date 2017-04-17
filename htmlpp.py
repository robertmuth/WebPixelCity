#!/usr/bin/python3

import sys
import re

debug = re.compile("@@DEBUG")
end = re.compile("@@END")

mode = None
for line in sys.stdin:
    if "@@" in line:
        if debug.search(line):
            mode = "d"
        elif end.search(line):
            mode = None
        else:
            assert False, line
        continue
    if mode is None:
        print (line, end='')
