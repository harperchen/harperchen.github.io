---
title: '[S&P''20] KRACE: Data Race Fuzzing for Kernel File Systems'
date: 2020-12-24 12:42:43
tags:
	- Race Bug
	- File System
	- Fuzz Testing
	- Kernel
categories: Papers
---

### Abstract

Data races occur when two threads fail to use proper synchronization when accessing shared data. In kernel file systems, which are highly concurrent by design, data races are common mistakes and often wreak havoc on the users, causing inconsistent states or data losses. Prior fuzzing practices on file systems have been effective in uncovering hundreds of bugs, but they mostly focus on the sequential aspect of file system execution and do not comprehensively explore the concurrency dimension and hence, forgo the opportunity to catch data races.

<!--more-->

In this paper, we bring coverage-guided fuzzing to the concur- rency dimension with three new constructs: 1) a new coverage tracking metric, alias coverage, specially designed to capture the exploration progress in the concurrency dimension; 2) an evolution algorithm for generating, mutating, and merging multi- threaded syscall sequences as inputs for concurrency fuzzing; and 3) a comprehensive lockset and happens-before modeling for kernel synchronization primitives for precise data race detection. These components are integrated into KRACE, an end-to-end fuzzing framework that has discovered 23 data races in ext4, btrfs, and the VFS layer so far, and 9 are confirmed to be harmful.

### Outline

- What is data race (memory access bugs)
  - Two threads fail to use proper synchronization 
    - Two threads access same memory address
    - At least one thread is a memory write
    - They are issued from different contexts 
  - Cause inconsistent states or data losses
- Drawbacks of previous work
  - Stress testing relies on handwritten test suites that are not sufficient to cover enormous states
  - Existing file system fuzzing focus on sequential view of program execution
    - Effective in single-threaded syscall sequences generation/mutation 
    - Not suitable for multi-threaded scenarios
    - No existing work to synthesize multi-threaded sequences to maximize thread interleaving coverage
    - Different thread interleaving can result in same branch coverage
- Difficulties of data race fuzzing
  - Hard to detect and diagnose due to non-determinism in thread interleaving
  - Only a small fraction of interleavings may trigger a data race
  - Thread schedule consists of both user threads and kernel threads
  - Data race often leads to silent failures, do not raise visible signals in short term
- Why this paper is accepted
  - Usefulness
    - Bring coverage-guided fuzzing to concurrency dimension
  - Novelty
    -  A novel coverage tracking metric--alias instruction pair coverage
    -  An evolution algorithm for generate/mutate/merge-ing multi-threaded syscall sequences for concurrency fuzzing
    -  A comprehensive lockset and happens-before modeling for precise data race detection 
- How it works
  - Coverage Tracking (LLVM Instrumentation Pass)
    - Branch coverage for sequential dimension
    - Alias coverage for concurrency dimension
      - How many pairs of memory access instructions that may interleave against with each other have been covered
      - Tracking online, a new metrics to decide whether current fuzzing seed should be further mutated
  - Input generation  (Python)
    - Evolve and merge multi-threaded seeds (3 threads in total) to induce new interleaving
      - syscall specification, inter-dependencies among syscalls
      - mutation/addition/deletion/shuffling/<font color="#dd0000">merge</font> two seeds/primitive collection
    - Thread delay schedules: delays each memory access a random number of time
  - Bug manifestation
    - Detect data race given an execution trace by hooking memory access (Python)
      - How to confirm whether a data race is a true race
        - lockset: no locks are held by both contexts
        - happens-before: no ordering between two contexts  is guaranteed
          - fork-style relations
          - join-style relationship
          - publisher-subscriber model
    - A comprehensive framework of synchronization mechanisms
      - locking primitives modeling for lockset analysis
      - thread ordering primitive annotations for happens-before analysis
  - Clean kernel state after each execution for trackability and debuggability
- Evaluation
  - 23 data races in ext4 and btrfs
    - 9 harmful and 11 benign (2 months)
  - Throughput: at least 7 seconds for each execution
  - Fuzzing Characteristics
    - Branch coverage and alias coverage grow in synchronization (感觉怎么突破coverage的瓶颈是个合理的方向)
      - Branch coverage increase => Alias coverage increase
      - Branch coverage saturates => Alias coverage still increase
    - Instrumentation for alias overahead
    - Data race detection overhead
  - Component Evaluation
    - Alias coverage increase => Branch Coverage increase: codes handling contention
    - Delay injection effectiveness
    - Seed merging effectiveness
    - Components in data race checker
  - Compare with other fuzzers
    - Compare with Syzkaller with respect to coverage (merging operation is effective)
    - Compare with Razzer with respect to data race bugs
- Reflection
  - Fuzzing distributed file systems that involve not only thread interleavings but also network event ordering, which requires completely new coverage metrics to capture.

