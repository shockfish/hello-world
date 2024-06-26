#!/usr/bin/env sh

flask db upgrade

python hello_world/main.py