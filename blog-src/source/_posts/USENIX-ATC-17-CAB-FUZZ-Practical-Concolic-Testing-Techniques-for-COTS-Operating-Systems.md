---
title: >-
  [USENIX ATC'17] CAB-FUZZ: Practical Concolic Testing Techniques for COTS
  Operating Systems 
date: 2020-12-20 21:31:34
tags:
	- Concolic Testing
	- Device Drivers
	- Kernel
categories: Papers
---
### Abstract

Discovering the security vulnerabilities of commercial off-the-shelf (COTS) operating systems (OSes) is chal- lenging because they not only are huge and complex, but also lack detailed debug information. Concolic testing, which generates all feasible inputs of a program by using symbolic execution and tests the program with the generated inputs, is one of the most promising approaches to solve this problem. Unfortunately, the state-of-the-art concolic testing tools do not scale well for testing COTS OSes because of state explosion. Indeed, they often fail to find a single bug (or crash) in COTS OSes despite their long execution time.

<!-- more -->

In this paper, we propose CAB-FUZZ (Context-Aware and Boundary-focused), a practical concolic testing tool to quickly explore interesting paths that are highly likely triggering real bugs without debug information. First, CAB-FUZZ prioritizes the boundary states of arrays and loops, inspired by the fact that many vulnerabilities originate from a lack of proper boundary checks. Second, CAB-FUZZ exploits real programs interacting with COTS OSes to construct proper contexts to explore deep and complex kernel states without debug information. We applied CAB-FUZZ to Windows 7 and Windows Server 2008 and found 21 undisclosed unique crashes, includ- ing two local privilege escalation vulnerabilities (CVE- 2015-6098 and CVE-2016-0040) and one information disclosure vulnerability in a cryptography driver (CVE- 2016-7219). CAB-FUZZ found vulnerabilities that are non-trivial to discover; five vulnerabilities have existed for 14 years, and we could trigger them even in the initial version of Windows XP (August 2001).

### Outline

- Difficulties of testing COTS OSes using concolic execution
    - COTS OS is huge and complex, lack debug information
    - Cannot explore program states  with pre-context
    - State explosion, fundamental scalability limitation of symbolic execution
    - Always closed-source, lack detailed documentation and test suites
- Drawbacks of previous work
    - No work to compare
- Why this paper is accepted
    - The first approach detects vulnerabilities in COTS OSes based on  concolic testing 
    - Usefulness
        - Practical system
            - overcomes scalability limitation of concolic testing
            - overcome the problem of lacking  execution contexts
        - Discover 21 unique crashes on drivers in Win 7 and Win Server 2008 
        - Portable, OS independent, work for closed-source OS
    - Novelty
        - Show the possibility of performing concolic testing on COTS OSes with acceptable scalability by sacrificing completeness
- How it works
    - Inputs: disk image of COTS OS, e.g., Windows
    - Synthetic symbolization
        - Synthesize program to symbolize from scratch
        - Use previously built user-space program
        - Prioritize boundary states which likely have vulnerabilities 
            - Avoid state explosion (Scalability)
                - Bugs mainly originate from a lack of  boundary checks
            - Array-boundary prioritization using KLEE's getRange method
                - Lowest memory address
                - Highest memory address
                - Arbitrary memory address between highest and lowest
            - Loop-boundary prioritization using repeatedly fork and kill
                - No loop execution
                - A single loop execution
                - largest number of loop executions
    - On-the-fly symbolization
        - 16 existing programs targeting 15 different drivers
        - Exploits real programs as concolic execution template
            - No need prior knowledge such as annotation
            - Construct proper contexts to explore deep kernel states
            - Symbolize part of the inputs of a target function
            - Hook device control API, leverage existing programs
- Evaluation
    - Apply CAB-Fuzz to Win7 and Win Server 2008
    - Synthetic symbolization: Mainly for the effectiveness of boundary prioritization
        - Apply boundary prioritization technique to known vulnerability
        - Discover new crashes in Windows and manually check the crashes
    - On-the-fly symbolization
