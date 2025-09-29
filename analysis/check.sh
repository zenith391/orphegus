#!/bin/sh
cd ..
zig build run
cd analysis
python3 main.py
