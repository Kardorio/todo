#!/bin/sh
set -eu
cd "$(dirname "$0")"
if [ "$#" -eq 0 ]; then
    echo "Usage : ./build.sh {test|check|package|devlink|link|unlink|clean}"
    echo "Tests : FACTORIO_BIN=/chemin/factorio ./build.sh test"
    exit 0
fi
exec python3 tools/build.py "$@"
