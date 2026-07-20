---
title: '[Tech] Binary Analysis'
date: 2021-04-28 16:06:43
tags:
---



Protections Againest Exploitation

ASLR:

DEP: Data Execution Protection

Stack Canaries:

CFI: Control flow integrity

ROP: Return-oriented programming

Closed Source Memory Errors:

1. Resort to blackbox fuzzing: resulting in shallow coverage close to the provided test cases
2. Rely on dynamic binary translation: instrument the binary at prohibitively high runtime cost (e.g., 10x to 100x for AFL fuzzing in QEMU mode on LAVA-M)
3. Use unsound static rewriting based on heuristics

Question: The fundamental difficulty for static rewriting techniques is disambiguating reference and scalar constants





There are three fundamental techniques to rewrite binaries:

1. recompilation [14], which attempts to lift the code to an intermediate representation; Lifting code to IR for recompilation requires correctly recovering type information from binaries, which remains an open problem. 

2. trampolines [15], [16], which relies on indirection to insert new code segments without changing the size of basic blocks;  Trampolines may significantly increase code size, and the extra level of indirection increases performance overhead. 
3. reassembleable assembly [12], [13], which creates an assembly file equivalent to what a compiler would emit, i.e., with relocation symbols for the linker to resolve. Consequently, we believe that resymbolizing binaries for reassembleable assembly is one the most promising technique for static binary rewriting.