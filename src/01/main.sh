#!/bin/bash

if [ $# -ne 1 ]; then
    echo "Error: only 1 argument"
    exit 1
fi

param="$1"

# Проверяем, состоит ли аргумент только из цифр включая отицательных
if [[ "$param" =~ ^-?[0-9]+$ ]]; then
    echo "Error: argument is digit"
    exit 1
else
    echo "$param"
fi