---
title: '[Tech] Thread Safety'
date: 2020-12-30 18:31:01
tags:
---

### TSAN

https://github.com/google/sanitizers

https://clang.llvm.org/docs/ThreadSafetyAnalysis.html

<!--more-->

##### 1. Paper Skelton

- Data Race
  - Concurrently access a shared memory location
  - At least one of the access is write
- Difficulties to detect
  - Happens only under very specific circumstances => Hard to reproduce
  - Pass of all tests doesn't guarantee the absence of data races in code
- Existing work
  - Static: unlikely for complex and large code; too expensive to add annotation for static detector
  - Dynamic: Happens-before, lockset or hybrid type
    - On-the-fly: process program execution in parallel with execution
    - Postmortem: analyze the program execution offline
- How it work
  - Tsan Global state 
  - Per-ID state (Per-memory location state): dynamically updated during execution
    - Writer segment set: writes to ID
    - Reader segment set: read from ID
- Implementation
  - Valgind: provide execution trace at the same time
    - memory access events:
      - Read 
      - Write
    - synchronization events:
      - Locking: WRLock; RDLock; WRUnlock; RDUnlock 
      - Happens-before: Signal and Wait

- Performance: Google unit test
  - CPU consumption: on average 20-50 times slow down 
    - intercepting and analyzing memory access
  - Memory consumption: 3-4 times

##### 2. 初步探索

`ThreadSanitizer` (aka TSan) is a data race detector for C/C++. Data races are one of the most common and hardest to debug types of bugs in concurrent systems. A data race occurs when two threads access the same variable concurrently and at least one of the accesses is write. [C++11](http://en.wikipedia.org/wiki/C%2B%2B11) standard officially bans data races as *undefined behavior*.

![image-20201230183132892](https://i.loli.net/2020/12/30/YmrQityp2JcaGzN.png)

The cost of race detection varies by program, but for a typical program, memory usage may increase by 5-10x and execution time by 2-20x

##### 2. SPEC CPU 2006

our study on SPEC CPU2006 benchmarks [25] shows that the geometric mean overheads in- duced by AddressSanitizer (ASan) [23] and UndefinedBehaviorSanitizer (UBSan) [6] are, respectively, 73.8% and 160.1% (see Sec. 6)

19 C/C++ programs, in which 11 benchmarks can be compiled with clang and with ASan and UBSan enabled

Each SPEC benchmark is shipped with a training workload, a testing workload, and a reference workload.  Following the convention, we use the training workload to profile these programs and obtain the dynamic patterns of sanitizer checks.

Memory Overhead; CPU overhead;

#### KTSAN

https://github.com/google/ktsan

https://events.static.linuxfound.org/images/stories/slides/lfcs2013_vyukov.pdf

#### KCSAN (Kernel Concurrent Sanitizer)

• KCSAN, developed by Google 2019, found more than 300 race bugs.

https://github.com/google/ktsan/wiki/KCSAN

https://www.kernel.org/doc/html/latest//dev-tools/kcsan.html

#### SANRAZOR

![image-20210102211000993](https://i.loli.net/2021/01/02/niSJpdFLECZlNQ1.png)

- Target problem: reduce redundant sanitizer check, specially, ASAN and UBSAN
- What is sanitizer
  - Detect software bugs and vulnerabilities at runtime
  - Insert additional checks into program during compilation
  - Terminate program if it detects unsafe actions or states
  - c checks whether property P holds with regard to v
    - v can be critical program information such as code pointer
    - P can be null pointer deference
    - c can be either abort program execution or alert the user
- Problems of sanitizer
  - High runtime overhead: Asan 73.8% UBSAN 160.1%
- Drawbacks of previous work
  - Some approaches remove array bounds checks by checking whether the value range of an array index falls within the array size
    - Heavyweight static analysis
    - Aims to flag useless checks with dedicated program analysis (not scalable)
  - ASAP elides sanitizer checks deemed the most costly based on a user-provided overhead budget
    - Irrespective of importance of sanitizer
    - Over-optimistically remove sanitizer
- Why this paper is accepted
  - Propose a general sanitizer reduction approach
  - Usefulness
    - Maybe unsound but evaluation shows it maintains the sanitizer's effectiveness in discovering defects
    - Reduce runtime overhead 
    - Not depends on particular sanitizer implementation, thus can be used to reduce checks of different sanitizer
  - Novelty
    - Sanitizer check redundancies: same program property could be repeatedly validated by multiple checks
    - Introduce new approach to reduce the performance overhead incurred by sanitizer
- ASAN: Address Sanitizer
  - Instrumentation module
    - Allocates shadow memory regions for each memory address
    - Instrument each memory load and store operation
    - When memory address a is used to access memory, a will be mapped to shadow memory address sa
    - The value stored in sa is used to check if the access via a is safe
    - Directly using shadow memory address will be redirected to bad region, further leads to page protection violation
  - Runtime library
    - Hook malloc function to create poisoned readzones next to allocated memories to detect memory access error
    - Hook free function to put the entire deallocated memory region into redzone
- UBSAN: Undefined behaviors
  - detect a large set of common undefined behaviors
    - Out-of-bounds access
    - Integer overflow
    - divided by zero
    - Invalid shift
  - For out-of-bounds array access
    - Put extra if condition to compare array index with array size before loop
- Input: LLVM IR with sanitizer checks
- Output: LLVM IR with reduced sanitizer checks
- Motivation: Identify likely redundant sanitizer checks
  - For example, repeatedly validate same array index
  - If check c that detect bug B in program p is removed, B still can be detected
  - Identify redundant sanitizer checks is difficult, approximation version "likely ~" is proposed
- How it works
  - Identify sanitizer checks from user checks
  - Dynamic: code coverage patterns
    - How many times each check is executed
    - How many times the true and false branches are taken
  - Static: static input dependency patterns
    - Data-flow information from operands of each icmp statement
    - Backward-dependency analysis to construct data dependency graph
  - Correlation analysis regarding dynamic and static patterns
    - Decide if one check is redundant to the other
    - Dynamic: sanitizer check =?= user check
      - sb = ub and (stb = utb or stb = ufb)
      - sb = utb and (sb = stb or sb = sfb)
      - sb = ufb and (sb = stb or sb = sfb) 
    - Dynamic: sanitizer check =?= sanitizer check 
      - sb_i = sb_j and (stb_i = stb_j or stb_i = sfb_j)
    - Static: convert constructed value dependency tree to sets and compare if they are identical
      - L0: all leaf nodes
      - L1: all leaf nodes without constant except for constant operands used by icmp
      - L2: all leaf nodes without all constants
- Evaluation
  - Benchmark: SPEC CPU2006 benchmarks
  - Cost evaluation: Geometric mean runtime overhead reduction
    - ASan: 73.8% -> 28.0%-62.0%
    - UBSAN: 160.1% -> 36.6%-124.4%
  - Reduction accuracy
    - 33 out of 38 known CVEs can be still discovered after removing redundant sanitizer
    - more CVEs discovered than ASAP
  - Combine SANRAZOR with ASAP
    - runtime cost is reduced to 7.0%
- Reflection
  - Only appliable to single threaded program