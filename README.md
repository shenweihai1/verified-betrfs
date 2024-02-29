# Run 2pc baseline in c++
The goal is to run the baseline of 2PC in auto-generated c++.

Implementation:
- `bank-paper` exactly works as 2pc with mutexs, so just use it with slight modications; However, I encountered several issues to compile into C++, the major issue is `BigNumber` (refer to https://github.com/dafny-lang/dafny/issues/5095 for details and solutions)
- Issues on `bank-paper` dafny code in method `TryAccountTransfer`: (1) should guarantee `sourceAccountId != destAccountId`; (2) liveness: if locks are not acquired in order, it would cause a deadlock.

How to run it, note that we can't verify on function `TryAccountTransfer`, because I replaced `nat` into `uint64` which requires more efforts on overflowing:
```bash
cd concurrency/bank-paper
# generated Bundle.i.cpp and Impl.i.h
make 
git diff Bundle.i.cpp
git checkout Bundle.i.cpp
g++ -pthread -std=gnu++17 -g -O3 -I ../../.dafny/dafny/Binaries/ -I ../framework/ -DUSE_VSPACE -o Bundle.o Bundle.i.cpp
./Bundle.o
```


Throughput of `TryAccountTransfer`, looks good enough:
```
thread-id:0, runtime:3, suc/time:3941783, aborts/time:0
thread-id:2, runtime:3, suc/time:3936551, aborts/time:0
thread-id:1, runtime:3, suc/time:3917935, aborts/time:0
thread-id:5, runtime:3, suc/time:3830930, aborts/time:0
thread-id:6, runtime:3, suc/time:3807309, aborts/time:0
thread-id:3, runtime:3, suc/time:3810786, aborts/time:0
thread-id:4, runtime:3, suc/time:3856466, aborts/time:0
thread-id:7, runtime:3, suc/time:3892213, aborts/time:0
thread-id:8, runtime:3, suc/time:3909503, aborts/time:0
thread-id:9, runtime:3, suc/time:3913499, aborts/time:0
tol: 5001000000, initBalance: 5001, keyspace: 1000000
```





# Setting things up

## Automatic setup (Linux)

On Linux, use this script to install necessary tools, including an appropriately-recent
version of `mono`. The script will also build a copy of Dafny in the local
.dafny/ dir (using the veribetrfs variant of Dafny with support for linear
types).

```
sudo tools/prep-environment.sh
```

## Manual setup (Mac, Linux)

1. Install [.NET 5.0](https://dotnet.microsoft.com/download).

2. Run

```
./tools/install-dafny.sh
```

This will install VeriBetrFS's [custom version of Dafny](https://github.com/secure-foundations/dafny) which includes our linear types extension.

3. Install Python dependencies for our build chain.

```
pip3 install toposort
```

4. Install clang and libc++. You probably already have this if you're on a Mac.

# Building and running

## VeriBetrFS dafny

The above steps should have created a local installation of Dafny into `.dafny/`.
You can run veribetrfs-dafny manually with `tools/local-dafny.sh`.
The Makefile will use veribetrfs-dafny by default.

## Verify the software stack

Adjust -j# to exploit all of your cores.
```
make -j4 status
```

Expect this to take at least a couple of hours of CPU time. When it completes, it will
produce the result file `build/Impl/Bundle.i.status.pdf`. You should expect the results,
ideally, to be all green (passes verification). In practice, there will often be some
non-green files where work is in progress, unless we've recently made a push to get
everything green for a release build.

## Lightweight benchmarking

We have a very brief benchmark for a quick sanity check that everything is working. Note that you don't need to run verification before building and running the system.

```
make elf # Compile VeriBetrFS via the C++ backend
./build/Veribetrfs --benchmark=random-queries
```

## YCSB

YCSB is a serious benchmark suite for production key-value stores.

The C++ YCSB benchmark library and rocksdb are vendored as a git submodule. Run

```
$ ./tools/update-submodules.sh
```

to initialise git submodules and to update the checkouts of the modules.
We also recommend setting:

```
git config --global submodule.recurse true
```

This will ensure the submodules are updated when you do a git checkout.

Finally, to actually build the benchmark and all its dependencies (veribetrfs, rocsdb, the ycsb library, our ycsb library wrapper), run

```
$ make build/VeribetrfsYcsb
```

Our YCSB library wrapper is in `ycsb/wrappers`.

Some YCSB workload specifications are in `ycsb/*.spec`.

To run the benchmark, use

```
./build/VeribetrfsYcsb <workload_spec> <data_dir>
```

where `<data_dir>` should be an empty (or non-existing) directory that will contain the benchmark's files.

# Contributing

You can check out `docs/veridoc.md` for an overview of our source code.
