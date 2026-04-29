#!/bin/zsh

SCRIPT_NAME=$0
SCRIPT_DIR=$(dirname "$SCRIPT_NAME")

INSTANCE=${@:$#:1}       # Last element
OPTIONS=${@:1:(${#@}-1)} # other elements

# 一時ファイルを作成
TEMPFILE=$(mktemp)

# スクリプト終了時に一時ファイルを削除
trap "rm -f $TEMPFILE" EXIT

# 解凍して一時ファイルに保存
gunzip -c "$INSTANCE" > "$TEMPFILE"

${SCRIPT_DIR}/MaxCDCL2024-openwbo ${OPTIONS} ${TEMPFILE} 300

