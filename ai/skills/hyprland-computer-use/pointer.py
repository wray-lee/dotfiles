#!/usr/bin/env python3
"""Absolute-position virtual pointer on /dev/uinput, driven by lines read from a FIFO.

ydotool's pointer is relative and goes through pointer acceleration, so absolute moves land
in the wrong place. This device reports ABS_X/ABS_Y in 0..AMAX, which the compositor maps to the output.
FIFO commands: "m X Y" (0..AMAX) | "d BTN" | "u BTN" | "w N" (wheel notches, + is up). BTN: 272 left, 273 right, 274 middle.
"""
import fcntl, os, struct, sys, time

AMAX = 32767
EV_SYN, EV_KEY, EV_REL, EV_ABS = 0, 1, 2, 3
BTNS = (0x110, 0x111, 0x112)
fifo = sys.argv[1]

fd = os.open("/dev/uinput", os.O_WRONLY | os.O_NONBLOCK)
for req, val in [(0x40045564, EV_KEY), (0x40045564, EV_ABS), (0x40045564, EV_REL),
                 (0x40045565, BTNS[0]), (0x40045565, BTNS[1]), (0x40045565, BTNS[2]),
                 (0x40045567, 0), (0x40045567, 1), (0x40045566, 8)]:
    fcntl.ioctl(fd, req, val)
for axis in (0, 1):
    fcntl.ioctl(fd, 0x401c5504, struct.pack("HHiiiiii", axis, 0, 0, 0, AMAX, 0, 0, 0))
fcntl.ioctl(fd, 0x405c5503, struct.pack("HHHH80sI", 0x03, 0x1234, 0x5678, 1, b"cu-abs-pointer", 0))
fcntl.ioctl(fd, 0x5501)


def emit(t, c, v):
    os.write(fd, struct.pack("llHHi", 0, 0, t, c, v))


def syn():
    emit(EV_SYN, 0, 0)


time.sleep(1)  # let the compositor notice the new device before the first event
try:
    os.write(1, b"ready\n")
    while True:
        with open(fifo) as f:  # blocks until a writer opens; EOF = writer closed, reopen
            for line in f:
                p = line.split()
                if not p:
                    continue
                if p[0] == "m":
                    emit(EV_ABS, 0, max(0, min(AMAX, int(p[1])))); emit(EV_ABS, 1, max(0, min(AMAX, int(p[2]))))
                elif p[0] in "du":
                    emit(EV_KEY, int(p[1]), 1 if p[0] == "d" else 0)
                elif p[0] == "w":
                    emit(EV_REL, 8, int(p[1]))
                syn()
finally:
    fcntl.ioctl(fd, 0x5502)
