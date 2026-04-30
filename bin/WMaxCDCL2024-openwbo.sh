#!/bin/zsh

SCRIPT_NAME=$0
SCRIPT_DIR=$(dirname "$SCRIPT_NAME")

INSTANCE=${@:$#:1}       # Last element
OPTIONS=${@:1:(${#@}-1)} # other elements

# Create a temporary file
TEMPFILE=$(mktemp)

# Delete the temporary file on script exit
trap "rm -f $TEMPFILE" EXIT

# Decompress and save to the temporary file
gunzip -c "$INSTANCE" > "$TEMPFILE"

${SCRIPT_DIR}/WMaxCDCL2024-openwbo ${OPTIONS} ${TEMPFILE} 1200

