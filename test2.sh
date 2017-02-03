#!/usr/bin/env bash
TEST_VAR=$3
echo "1) $1"
echo "2) $2"
echo "3) $TEST_VAR"

if [[ "$TEST_VAR" = true ]]; then
    echo "1"
else
    echo "0"
fi