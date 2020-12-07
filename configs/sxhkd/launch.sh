#!/usr/bin/env bash

# Terminate already running sxhkd instances (if exists)
killall -q sxhkd

sxhkd &

echo "Sxhkd launched..."
