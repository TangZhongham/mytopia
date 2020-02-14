#!/bin/bash

echo "Shell 传递参数实例！";
echo "执行的文件名：$0";

if [ $# -eq 1 ]; then echo "true"; fi
