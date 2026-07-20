---
title: '[NDSS''18] K-miner: Uncovering memory corruption in linux'
date: 2021-02-01 15:39:37
tags:
  - Static Analysis
  - Kernel
categories: Papers
---
### Abstract

Operating system kernels are appealing attack targets: compromising the kernel usually allows attackers to bypass all deployed security mechanisms and take control over the entire system. Commodity kernels, like Linux, are written in low-level programming languages that offer only limited type and memory-safety guarantees, enabling adversaries to launch sophisticated run-time attacks against the kernel by exploiting memory-corruption vulnerabilities.

<!--more-->

Many defenses have been proposed to protect operating systems at run time, such as control-flow integrity (CFI). However, the goal of these runtime monitors is to prevent exploitation as a symptom of memory corruption, rather than eliminating the underlying root cause, i.e., bugs in the kernel code. While finding bugs can be automated, e.g., using static analysis, all existing approaches are limited to local, intra-procedural checks, and face severe scalability challenges due to the large kernel code base. Consequently, there currently exist no tools for conducting global static analysis of operating system kernels.

In this paper, we present *K-Miner*, a new framework to efficiently analyze large, commodity operating system kernels like Linux. Our novel approach exploits the highly standardized interface structure of the kernel code to enable scalable pointer analysis and conduct global, context-sensitive analysis. Through our inter-procedural analysis we show that K-Miner systematically and reliably uncovers several different classes of memory-corruption vulnerabilities, such as dangling pointers, user-after-free, double-free, and double-lock vulnerabilities. We thoroughly evaluate our extensible analysis framework, which leverages the popular and widely used LLVM compiler suite, for the current Linux kernel and demonstrate its effectiveness by reporting several memory-corruption vulnerabilities.

### Outline

#### 1. Difficulties of OS Kernel Fuzzing

Currently, Linux comprises over 24 million lines of code. The huge size and complexity of its monolithic code base makes precise data-flow analysis for kernel code difficult. The number of possible paths grows exponentially with the code size, and hence, static analysis approaches face severe scalability problems

#### 2. Drawbacks of previous work

1. Run-time monitors are designed to defend against a specific class of attacks. A combination of many different defenses is required to protect the kernel against multiple classes of adversaries.
2. Compile-time verification is feasible for small model, but impractical for commodity monolithic kernels due to their size and extensive use of machine-level code
3. Static analysis safely over-approximates program execution, allowing for strong statements in the case of negative analysis results.
4. All analysis frameworks for kernel code (Coccinelle/Smatch/TypeChef/APISAN/EBA) are limited to *intra-procedural* analysis, i.e., local checks per function, or simple file-based analysis.
5. None of existing static analysis framework supports *inter-procedural* data-flow analyses therefore they cannot uncover memory corruption caused by global pointer relationships.
6. scalable static analysis designed for user space programs cannot simply be applied in kernel setting due to the non-trivial entry point

#### 3. Why this paper is accepted

- Observation
  - the interface to user space is highly standardized 
  - partition the kernel code along separate execution paths using the system call interface as a starting point
- Challenge of partition the kernel code
  - frequent reuse of global data structures
  - the synchronization between the per-system call
  - global memory states (contexts)
  - complicated and deeply nested aliasing relationships of pointers
- **Enable global static analysis for kernel code:** The observation significantly reduces the number of relevant paths, allowing us to conduct even complex, inter-procedural data-flow analysis in the kernel.

#### 4. How it works

Because randomly selecting system calls from existing program traces do not result in any coverage improvement over hand-coded rules, this paper leverages light-weight static analysis for efficiently detecting dependencies across different system calls.

#### 5. Technique details

Built on top of LLVM Pass to analyze system calls simultaneously

For every system call, K-Miner generates a call graph (CG), a value- flow graph (VFG), a pointer-analysis graph (PAG), and several other internal data structures by taking the entry point of the system call function as a starting point.



compute a list of all globally allocated kernel objects, are reachable by any single system call. 

#### 6. Evaluation

Applying the proposed static analysis framework to all system calls across many different Linux versions



Uncover several known memory-corruption vulnerabilities that previously required manual inspection of the code



#### 7. Examples

integer overflows (IO), use-after-free (UAF), 

**dangling pointers (DP):**  A memory location is freed but the pointer is still accessible.

double free (DF), buffer overflow (BO), missing pointer checks (MPC), uninitialized data (UD), type errors (TE), or synchronization errors (SE)

#### 8. Reflection



#### 9. Bug report

