#!/bin/bash

# Note you need to run create-cgroups.sh first.

set -e

MEM=`python3 -c "print(4 * 1024 * 1024 * 1024)"`

echo $MEM > /sys/fs/cgroup/memory/VeribetrfsExp/memory.limit_in_bytes
echo 0    > /sys/fs/cgroup/memory/VeribetrfsExp/memory.swappiness
