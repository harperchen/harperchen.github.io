---
title: '[CCS''17] DIFUZE: Interface Aware Fuzzing for Kernel Drivers '
date: 2020-12-21 18:54:50
tags:
	- Device Drivers
	- Static Analysis
	- Fuzz Testing
	- Kernel
categories: Papers
---
### Abstract

Device drivers are an essential part in modern Unix-like systems to handle operations on physical devices, from hard disks and print- ers to digital cameras and Bluetooth speakers. The surge of new hardware, particularly on mobile devices, introduces an explosive growth of device drivers in system kernels. Many such drivers are provided by third-party developers, which are susceptible to se- curity vulnerabilities and lack proper vetting. Unfortunately, the complex input data structures for device drivers render traditional analysis tools, such as fuzz testing, less effective, and so far, research on kernel driver security is comparatively sparse.
<!--more-->
In this paper, we present DIFUZE, an interface-aware fuzzing tool to automatically generate valid inputs and trigger the execu- tion of the kernel drivers. We leverage static analysis to compose correctly-structured input in the userspace to explore kernel dri- vers. DIFUZE is fully automatic, ranging from identifying driver handlers, to mapping to device file names, to constructing complex argument instances. We evaluate our approach on seven modern Android smartphones. The results show that DIFUZE can effectively identify kernel driver bugs, and reports 32 previously unknown vul- nerabilities, including flaws that lead to arbitrary code execution.

### Outline

- Difficulties of kernel driver fuzzing
    - ioctl comprises structured, deriver-dependent arguments 
    - int ioctl(int file_descriptor, int request, ...)  variable arguments
    - Highly constrained inputs, must know the knowledge of how driver process different command identifiers
    - Hard to detect cross-dependency between different arguments
- Why this paper is accepted
    - The first completely automated system that can be generalized to fuzz all Linux kernel drivers.
    - Usefulness
        - Facilitate fuzzing  of interface-sensitive targets and find 36 bugs on seven Android devices.
    - Novelty
        - This paper shows that fuzzing with accurate interface information is quite powerful.
- Inputs: source code of kernel (include source code of device deriver)
- How it works: Static analysis of kernel driver code
    - Interface recovery: LLVM Pass
        - Enable LLVM Analysis 
            - GCC Compilation
            - GCC-to-LLVM conversion (for bitcode)
            - Bitcode consolidation: consolidate bitcode files into one single file per driver
        - Identify ioctl handler by structures used to register ioctl handler
        - Analyze path of device file by registration functions
        - Recover valid set of ioctl commands identifiers
            -  Perform inter-procedural, path-sensitive analysis 
            - Collect equality constraints
        - Retrieve associated data structure definitions
            - Mapping from ioctl command identifiers to data structure
            - Identify the type of the destination operand of copy_from_user
    - Structure generation
        - Compose and mutate correctly-structured input
        - Favor integers that are likely trigger corner case
            - a power of two
            - or one less than a power of two
            - or one greater than a power of two 
    - On-device execution
        - Finalize generated structures and trigger ioctl
        - Pointer Fix up: build complete structure
        - Execution: open-ioctl-...; Target host does not restart very often
- Evaluation
    - Interface Recovery Evaluation
        - Device name identification: 59.44%; failures come from dynamically generated name 
        - Valid Command Identifiers: over approximates
        - User argument types:  53% of command identifier, the argument is pointer
        - Compare with manually analysis results on ioctl
    - Bug-finding capabilities
        - Compare DIFUZE with DIFUZE & Syzkaller (No coverage info, need recompilation)
        - Both the ioctl command identifiers and structure information matters
        - 36 unique bugs on seven Android devices
    - Augmented with coverage-guided fuzzing 
        - DIFUZE & Syzkaller (x86-64 instead of Android, can recompile)
        - Interface information increase basic block coverage
