#!/bin/sh


src=$(ls -t Shop*.apkx | head -n1)
dst="${src%x}"
cp "$src" "$dst"
echo "+++>>> $dst"
adb -s RFCW91FV79X install -r $dst
rm -f "$dst"
