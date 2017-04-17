#!/usr/bin/python3


import sys


TRIMS = [
    [1, 1],
    [2, 2],
    [4, 4],
    [8, 8],
    [1, 3],
    [2, 6],
]

TRIMS = [
    # alternating
    [1, 2, 1],   # 4
    [2, 4, 2],   # 8
    [4, 8, 4],   # 16
    #
    [1, 6, 1],   # 8
    [2, 12, 2],  # 16
    #
    [3, 2, 3],   # 8
    [6, 4, 6],   # 16
    #
    [1, 4, 2, 2, 2, 4, 1], # 16
    [4, 2, 4, 2, 4], # 16
]

def RenderTrim(t, l):
    s = ""
    while len(s) < l:
        for n, p in enumerate(t):
            c = " "
            if n % 2 == 1:
                c = "*"
            s += p * c
    return s

def RenderAllTrims():
    for t in TRIMS:
        print ()
        print (RenderTrim(t, 64))
        print (RenderTrim(t, 64))


def CommonTail(w, h):
    out = 1
    while w != 0 and h != 0 and (w & 1) == (h & 1):
        out = out  << 1
        w  = w >> 1
        h  = h >> 1
    return out


#def FindSuitableTrim(w, h):


TEST = [(4,2), (0xabc, 0x12c), (0,0),  (11,40), (0x111, 0x311)]

def Test():
    for a, b in TEST:
        print (a, b, CommonTail(a, b))

Test()
