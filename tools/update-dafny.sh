#! /bin/bash

# Copyright 2018-2021 VMware, Inc.
# SPDX-License-Identifier: MIT


set -e
set -x

    

cd .dafny/dafny/
git fetch
if [ $1 ]; then
    ../../tools/checkout-dafny-commit.sh $1
else
    ../../tools/checkout-dafny-commit.sh
fi
git pull || true # don't try to pull if dafny pointer is to a specific commit, not a branch name
make exe
