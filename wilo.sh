#!/bin/bash

if [ "$EUID" -ne 0 ]
  then
  echo "Please run as root \"sudo -s -E ./wilo.sh\""
  echo "otherwise packet injection is not working"
  exit
fi


cd "$(dirname "$0")"

source venv/bin/activate
python3 wilo.py ${@:1}
