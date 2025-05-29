#!/usr/bin/env bash

for BUILD_CONFIG in {1..20}; do
cat logs/testCases$BUILD_CONFIG | \
sort > logs/testCases$BUILD_CONFIG-reordered
done