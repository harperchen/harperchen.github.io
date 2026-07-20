---
title: '[PLDI''14] Compiler Validation via Equivalence Modulo Inputs'
date: 2021-05-20 13:57:20
tags:
---

### Abstract

We introduce equivalence modulo inputs (EMI), a simple, widely applicable methodology for validating optimizing compilers. Our key insight is to exploit the close interplay between (1) dynamically executing a program on some test inputs and (2) statically compiling the program to work on all possible inputs. Indeed, the test inputs induce a natural collection of the original program’s EMI variants, which can help differentially test any compiler and specifically target the difficult-to-find miscompilations. 

<!--more-->

To create a practical implementation of EMI for validating C compilers, we profile a program’s test executions and stochastically prune its unexecuted code. Our extensive testing in eleven months has led to 147 confirmed, unique bug reports for GCC and LLVM alone. The majority of those bugs are miscompilations, and more than 100 have already been fixed. Beyond testing compilers, EMI can be adapted to validate program transformation and analysis systems in general. This work opens up this exciting, new direction.

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
