---
title: '[USENIX''17] kAFL: Hardware-Assisted Feedback Fuzzing for OS Kernels'
date: 2020-12-18 15:02:13
tags: 
	- File System
	- Fuzz Testing
	- Kernel
categories: Papers
---
### Abstract

Many kinds of memory safety vulnerabilities have been endangering software systems for decades. Amongst other approaches, fuzzing is a promising technique to unveil various software faults. Recently, feedback-guided fuzzing demonstrated its power, pro- ducing a steady stream of security-critical software bugs. Most fuzzing efforts—especially feedback fuzzing—are limited to user space components of an operating system (OS), although bugs in kernel components are more severe, because they allow an attacker to gain access to a system with full privileges. Unfortunately, kernel components are difficult to fuzz as feedback mechanisms (i.e., guided code coverage) cannot be easily applied. Additionally, non-determinism due to interrupts, kernel threads, statefulness, and similar mechanisms poses problems. Furthermore, if a process fuzzes its own kernel, a kernel crash highly impacts the performance of the fuzzer as the OS needs to reboot.
<!-- more -->
In this paper, we approach the problem of coverage- guided kernel fuzzing in an OS-independent and hardware-assisted way: We utilize a hypervisor and In- tel’s Processor Trace (PT) technology. This allows us to remain independent of the target OS as we just require a small user space component that interacts with the targeted OS. As a result, our approach introduces almost no performance overhead, even in cases where the OS crashes, and performs up to 17,000 executions per second on an off-the-shelf laptop. We developed a framework called kernel-AFL (kAFL) to assess the security of Linux, macOS, and Windows kernel components. Among many crashes, we uncovered several flaws in the ext4 driver for Linux, the HFS and APFS file system of macOS, and the NTFS driver of Windows.

### Outline

- What is feedback-driven fuzzer 
    - learn the format of inputs: keep interesting inputs and discard inputs that do not trigger interesting behaviors
    - How to collect feedback
        - Dynamic Binary Instrumentation: Pin or DynamoRIO such as WinAFL
        - Virtualization: Qemu or Boch to monitor the code coverage, such as AFL
        - Hardware Assisted: Intel PT, such as kAFL, honggfuzz
    
- Difficulties of kernel fuzzing
    - Crashes and timeouts need virtualization
    - More non-determinism such as interrupts, kernel threads, stateful
    - Interact with kernel via system calls
    - Closed-source that cannot be instrumented
    
- Drawbacks of previous work
    - Triforce:  Emulation to gather feedback
    - Syzkaller: Recompilation, need open source 
    - Trinity: Not feedback-driven
    
- Why this paper is accepted
    - The first approach that can fuzz arbitrary x86-64 kernels without any customization and a near-native performance
    - Usefulness
        - Portable, OS-independent, even for closed source kernels
        - Small performance overhead, high-throughput
    - Novelty
        - Show the possibility of performing feedback-driven kernel fuzzing in an almost - OS-independent manner with the help of hypervisor and Intel PT to collect coverage 
    
- Inputs: Binary file for file system and a single system call

- How it works
  
    <img src="https://i.loli.net/2020/12/18/REtD1Xsgq6U5YSH.png" alt="image-20201218151357615" style="zoom:67%;" />
    
    - Feedback: Intel PT provides control flow information on running code
        - KVM-PT traces each vCPU, an implementation of Intel PT
        - Qemu-PT runs on top of KVM-PT and decode the trace data to AFL bitmap
            - JIT decoder
            - cache disassembled code
    - Intel's hardware virtualization features Intel VT-x
        - Fuzzing logic (kAFL): ring 3 process on host OS
        - VM Infrastructure: ring 3 QEMU-PT, ring 0 KVM-PT
        - User mode agent: run inside guest to run system call
    - Dealing with non-determinism
        - Do not reset the whole VM state after each execution, too costly
        - Filter out interrupts related PT trace data, by FUP packet
        - Blacklist any basic block that occurs non-deterministically, run multiple times
    - How to keep dependencies between different system calls
        - Seems like the evolutionary algorithm as AFL
    
- Evaluation
    - Perform fuzzing campaigns across different platform
        - Windows: NTFS file system;  fuzz a single system call
        - Linux: ext4 file system
        - MacOS: HFS file system; Apple file system kernel extension
    - Compare with Triforce
        - On a  created json parser driver
        - Syzkaller is not applicable to file system domain
    - Performance of KVM-PT: Small
    - Compare PT decoder with Intel decoder
        - Caching
        - JIT decode
