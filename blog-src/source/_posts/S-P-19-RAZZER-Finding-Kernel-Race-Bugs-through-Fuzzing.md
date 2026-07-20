---
title: '[S&P''19] RAZZER: Finding Kernel Race Bugs through Fuzzing'
date: 2020-12-24 12:40:46
tags:
	- Race Bug
	- Fuzz Testing
	- Kernel
categories: Papers
---

### Abstract

A data race in a kernel is an important class of bugs, critically impacting the reliability and security of the associated system. As a result of a race, the kernel may become unresponsive. Even worse, an attacker may launch a privilege escalation attack to acquire root privileges.
<!--more-->
In this paper, we propose RAZZER, a tool to find race bugs in kernels. The core of RAZZER is in guiding fuzz testing towards potential data race spots in the kernel. RAZZER employs two techniques to find races efficiently: a static analysis and a deterministic thread interleaving technique. Using a static analysis, RAZZER identifies over-approximated potential data race spots, guiding the fuzzer to search for data races in the kernel more efficiently. Using the deterministic thread interleav- ing technique implemented at the hypervisor, RAZZER tames the non-deterministic behavior of the kernel such that it can deterministically trigger a race. We implemented a prototype of RAZZER and ran the latest Linux kernel (from v4.16-rc3 to v4.18- rc3) using RAZZER. As a result, RAZZER discovered 30 new races in the kernel, with 16 subsequently confirmed and accordingly patched by kernel developers after they were reported.

### Outline

- Target Problem: Find data race bugs in kernel, guiding fuzz testing towards potential data race spots
- What is data race (memory access bugs) （这咋感觉和syscall implicit dependencies很像呢）
  - Two threads fail to use proper synchronization 
    - Two threads access same memory address
    - At least one thread is a memory write instruction
    - They are issued from different contexts and executed concurrently
  - Cause inconsistent states or data losses
- Existing approaches to find race bug
  - R1: Traditional Fuzz testing -- Syzkaller
    - Focus on finding an input program executes RacePair<sub>cand</sub>
  - R2: Random Thread interleaving -- SKI or PCT algorihtm
    - explore all possible thread interleaving cases for a specific input program
- Difficulties of data racing bug:
  - Non-deterministic behavior of kernel
  - Data race often leads to silent failures, do not raise visible signals in short term 
    - Need proper post-race harmful behaviors (这个估计可以做点什么)
- Why this paper is accepted:
  - A specifically designed fuzz testing mechanism for race bug in kernel
  - Usefulness
    - More faster than Syzkaller (meet R1)
    - More efficient than SKI (meet R2)
    - No need to modify the kernel
      - static analysis is performed offline
      - using a tailored hypervisor (transparent)
    - Facilitate easy, low-cost patching for data races
      - Detailed analysis report consisting of race location (memory access instruction) and call stacks that assist developers to determine the root cause of the race and fix a reported race quickly
  - Novelty
    -  Making the race behavior deterministic leveraging a tailored hypervisor
- How it works:
  - Carry out static analysis first (LLVM Pass and SVF)
    - RacePair<sub>benign</sub> and RacePair<sub>harm</sub> equals to RacePair<sub>true</sub> belongs to RacePair<sub>cand</sub>
    - Obtain potential data race points (over-approximated) using point-to analysis
    - How to overcome the false positive and performance problem of point-to analysis
      - Accuracy: Allow over-approximate the race pair
        - Context-insensitive, flow insensitive but field sensitive and exclude must-not case (different member variables)
      - Performance: Tailored partition analysis of kernel
  - Perform dynamic fuzz testing 
    - Single thread fuzz testing 
      - finding a single-thread input program that executes potential race points
    - Multi thread interleaving
      - Find a thread interleaving for the input program P<sub>st</sub>
      - implemented  at hypervisor to render the race behavior deterministic P<sub>mt</sub>
        - Stall the execution at potential data race points
          - Set up breakpoint per CPU core: Virualized debug register, VT-x and VMI
          - Resume the execution of kernel threads after hitting breakpoint for concurrent execution with specified order 
          - Check if a race occurs (How to check): same memory address ?
        - Modified QEMU and KVM for x86_64
        - No modification of target kernel to be tested
- Evalution
  - 30 new races in kernel running 7 weeks
  - Effectiveness of static analysis
  - Performance overhead of hypervisor
  - Compare with Syzkaller and SKI
    - Compared with Syzkaller: Fuzzing throughput and \# of execution needed to find a harmful race bug 
    -  Compared with random thread interleaving: \# of execution needed to trigger previously known race
- Reflection
  - Syzkaller也有自己的线程交织吗 whereas Syzkaller spawns multiple worker threads to identify data races.
  - Static analysis does not consider synchronization primitives in the kernel
    - Synchronization information helps to determine memory pairs that must not race so that reduces the false positive rate (implemented by Paper Krace's happens before analysis)
  - Need proper post-race harmful behaviors, just randomly generated for this paper
- How to improve this work
  - Thread scheduling coverage?