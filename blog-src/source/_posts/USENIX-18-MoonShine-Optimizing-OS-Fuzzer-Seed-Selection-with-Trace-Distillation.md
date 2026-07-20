---
title: '[USENIX''18] MoonShine: Optimizing OS Fuzzer Seed Selection with Trace Distillation'
date: 2021-01-30 20:29:28
tags:
    - Static Analysis
    - Seeds Generation
    - Fuzz Testing
    - Kernel
categories:
    - Papers
---

### Abstract

OS fuzzers primarily test the system-call interface between the OS kernel and user-level applications for security vulnerabilities. The effectiveness of all existing evolutionary OS fuzzers depends heavily on the quality and diversity of their seed system call sequences. However, generating good seeds for OS fuzzing is a hard problem as the behavior of each system call depends heavily on the OS kernel state created by the previously executed system calls. Therefore, popular evolutionary OS fuzzers often rely on hand-coded rules for generating valid seed sequences of system calls that can bootstrap the fuzzing process. Unfortunately, this approach severely restricts the diversity of the seed system call sequences and therefore limits the effectiveness of the fuzzers.

<!--more-->

 In this paper, we develop MoonShine, a novel strategy for distilling seeds for OS fuzzers from system call traces of real-world programs while still preserving the dependencies across the system calls. MoonShine leverages light-weight static analysis for efficiently detecting dependencies across different system calls. 

We designed and implemented MoonShine as an extension to Syzkaller, a state-of-the-art evolutionary fuzzer for the Linux kernel. Starting from traces containing 2.8 million system calls gathered from 3,220 real-world programs, MoonShine distilled down to just over 14,000 calls while preserving 86% of the original code coverage. Using these distilled seed system call sequences, MoonShine was able to improve Syzkaller’s achieved code coverage for the Linux kernel by 13% on average. MoonShine also found 17 new vulnerabilities in the Linux kernel that were not found by Syzkaller.

### Outline

#### 1. Difficulties of OS Kernel Fuzzing

Generating good seeds for OS fuzzing is a hard problem as the behavior of each system call depends heavily on the OS kernel state created by the previously executed system calls.

#### 2. Drawbacks of previous work

OS fuzzers, Trinity and Syzkaller, rely on hand-coded rules for generating valid seed sequences of system calls that can bootstrap the fuzzing process. Unfortunately, this approach severely restricts the diversity of the seed system call sequences and therefore limits the effectiveness of the fuzzers.

#### 3. Why this paper is accepted

- Introduce the concept of seed distillation for kernel, i.e., distilling traces from real world programs while maintaining both the system call dependencies and achieved code coverage 
- Instead of traversing all possible distill option, this paper propose to gather system call traces from diverse existing programs and use them to generate synthetic seed programs. This is because real programs are required to satisfy these dependencies in order to function correctly.

#### 4. How it works

Because randomly selecting system calls from existing program traces do not result in any coverage improvement over hand-coded rules, this paper leverages light-weight static analysis for efficiently detecting dependencies across different system calls.

#### 5. Technique details

MoonShine first executes a set a real-world programs and captures their system call traces along with the coverage achieved by each call. 

Next, it greedily selects the calls that contribute the most new coverage and for each such call, identifies all its dependencies using **lightweight static analysis** and groups them into seed programs.

Finally, those seed programs are fed as the seed of Syzkaller to fuzz the kernel.

<img src="https://i.loli.net/2021/01/31/b3wy1IDqFQeEadO.png" alt="image-20210131155144875" style="zoom:50%;" />

##### 5.1 Explicit Dependencies

MoonShine builds a dependency graph that consists of two types of nodes, results and arguments, to capture explicit dependencies.

##### 5.2 Implicit Dependencies

A call c~a~ is an implicit dependency of c~b~ if the intersection of c~a~’s write dependencies and c~b~’s read dependencies is nonempty. MoonShine’s implicit dependency tracker is build on Smatch.

#### 6. Evaluation

Starting from traces containing 2.8 million system calls gathered from 3,220 real-world programs, MoonShine distilled down to just over 14,000 calls while preserving 86% of the original code coverage.

Combine KASAN, UBSAN and Lock dependency tracker for deadlock and KMEMLEAK for memory leaks.

During each experiment, we restricted Syzkaller to only fuzz the calls contained in our traces to more accurately track the impact of our seeds.

##### 6.1 New Vulnerabilities?

 MoonShine found 17 new vulnerabilities in the Linux kernel that were not found by Syzkaller, out of which 10 vulnerabilities can only be found using implicit dependency distillation. Of the 17 bugs found by MoonShine, 6 were from the network subsystem, and 8 from file systems. 

<font color="red">Each of the bugs discovered using Moonshine(I+E) alone were concurrency bugs that were triggered by Syzkaller scheduling calls on different threads.</font>  果真检查implicit pair的方式和检查concurrency bug pair的方式是一样的。

##### 6.2 Improve code coverage?

Moonshine improves Syzkaller’s achieved code coverage for the Linux kernel by 13% on average.

##### 6.3 Efficiency in distilling traces while preserving coverage?

<img src="https://i.loli.net/2021/01/31/2wF9KAlj3yWvz4k.png" alt="image-20210131172627453" style="zoom: 67%;" />

#### 7. Examples

##### 7.1 inotify buffer overflow

Concurrency bug

```c++
mmap(...)
r0 = inotify_init()
r1 = inotify_add_watch(r0, &(0x7f0000000000)="2e", 0xfff)
chmod(&(0x7f0000001000)="2e", 0x1ed)
r2 = creat(&(0x7f0000002000)="short", 0x1ed) 
close(r2)
rename(&(0x7f000000a000)="short", &(0x7f0000006000-0xa)="long_name")
close(r0)
```

Lines 2 and 3 initialize an inotify instance to watch the current directory for all events.

inotify_add_watch is an implicit dependency of both rename and close so the calls were merged into one program

Syzkaller will randomly schedule calls on different threads. In this case, the rename and close were run in parallel.

##### 7.2 Integer Overflow in fcntl

```C++
long pipe_fcntl(...) {
    ...
    case F_SETPIPE_SZ:
        pipe_set_size(pipe, size); // size = 0
    ...
}
long pipe_set_size(pipe, size) {
    ...
    round_pipe_size(size);
    ...
}
unsigned int round_pipe_size(size) {
    ...
    nr_pages = (size + PAGE_SIZE - 1) >> PAGE_SHIFT; // = 0 UL
    return (1UL << fls_long(size - 1)) << PAGE_SHIFT; // fls_long (-1) returns 64
}
```

#### 8. Reflection

False Positives from Static Analysis. This problem is solved by HFL, which further perform concolic execution on runtime, to check if two syscalls read and write from the same struct field.

#### 9. Bug report

Our reports include a description of the bug, our kernel configs, and a Proof-ofConcept (POC) test input. 