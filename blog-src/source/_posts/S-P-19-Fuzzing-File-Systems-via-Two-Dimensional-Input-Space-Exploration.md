---
title: '[S&P''19] Fuzzing File Systems via Two-Dimensional Input Space Exploration'
date: 2020-12-30 14:08:25
tags:
	- File System
	- Fuzz Testing
	- Kernel
categories: Papers
---
#### Abstract

File systems, a basic building block of an OS, are too big and too complex to be bug free. Nevertheless, file systems rely on regular stress-testing tools and formal checkers to find bugs, which are limited due to the ever-increasing complexity of both file systems and OSes. Thus, fuzzing, proven to be an effective and a practical approach, becomes a preferable choice, as it does not need much knowledge about a target. However, three main challenges exist in fuzzing file systems: mutating a large image blob that degrades overall performance, generating image-dependent file operations, and reproducing found bugs, which is difficult for existing OS fuzzers.

<!--more-->

Hence, we present JANUS, the first feedback-driven fuzzer that explores the two-dimensional input space of a file system, i.e., mutating metadata on a large image, while emitting image-directed file operations. In addition, JANUS relies on a library OS rather than on traditional VMs for fuzzing, which enables JANUS to load a fresh copy of the OS, thereby leading to better reproducibility of bugs. We evaluate JANUS on eight file systems and found 90 bugs in the upstream Linux kernel, 62 of which have been acknowledged. Forty-three bugs have been fixed with 32 CVEs assigned. In addition, JANUS achieves higher code coverage on all the file systems after fuzzing 12 hours, when compared with the state-of-the-art fuzzer Syzkaller for fuzzing file systems. JANUS visits 4.19× and 2.01× more code paths in Btrfs and ext4, respectively. Moreover, JANUS is able to reproduce 88–100% of the crashes, while Syzkaller fails on all of them.

![image-20201230222916796](https://i.loli.net/2020/12/30/x254mrQz8qTFJ9d.png)

#### Outline

- Two component of file system 1）disk image 2）file system-specific operation
- Drawbacks of previous work on detecting bugs in file system
  - Stress testing：focus on the regression of file systems with minimal integrity checks
  - Model checking：需要对文件系统和内核状态有深层次的理解，不再适用于目前越来越复杂的操作系统
  - Fuzzing：只在file system的一个维度上做测试，但实际上文件系统的状态决定了系统调用可以在哪个文件对象上操作，而且系统调用的执行也更改了文件系统的状态，因此两者是互相作用、互相依赖的。而现有工作
    - 要么只将disk image作为二进制文件来mutate，例如kAFL和FuzzBSD
    - 要么只生成随机的操作文件的系统调用序列，例如Syzkaller、Trinity和TriforceAFL，不知道文件系统状态的情况下，无法对文件系统执行有效的操作
    - 而且还不重启内核和刷新文件系统的状态，导致很多bug无法复现
- Difficulties of fuzzing file systems
  - 输入一：a mounted disk image；输入二：a sequence of file operations (system calls)
  - Mutate a large image blob will degrade overall performance
    - disk image虽然是有结构的，但是很复杂，有的还是AFL maximum preferred size的100倍。由于读、写和保存image包含大量的IO操作，会极大降低Fuzzing的吞吐量。
    - 现有mutate image仅修改非零chunks，不完整且效率不高，因为没有利用文件系统的布局，实际上修改metadata block比data blocks更有效。
    - 在不了解文件系统布局的情况下，现有Fuzzer很难在修改metadata后修复metadata checksum
  - How to generate image-dependent file operations
    - 现有工作仅执行系统调用操作image上的file objects，但不知道image上到底有多少有效的文件可供操作
    - Syzkaller无法探索一组系统调用的集体影响，例如对同一路径执行多个open操作但是这个路径可能早就renamed或者removed
  - How to reproduce found bugs
    - 不重启会导致不稳定，系统调用的行为不一致（例如kmalloc），而且还不好debug
- Disk image
  - 包含用户数据和元数据metadata，其中元数据仅占有1%的大小
- Why this paper is accepted
  - The first feedback-driven fuzzer explores the two-dimensional input space of a file system (不仅修改文件系统镜像中的元数据，而且还生成用于特定镜像的文件操作)
  - Usefulness
    - Found 90 bugs in eight widely-used file systems in upstream kernel
    - Provide clean state OS for file system fuzzing which enable crash reproduce and debug
  - Novelty
    - Propose to mutate both the image bytes and file operations, in which image fuzzing is given higher priors
    - Muate file system image: mutate metadata blocks instead of data chunks and fix checksum
    - Mutate file system related syscall trace: generate context-aware workloads instead of blindly fuzzing file system
- How it works：schedule image mutator and system call fuzzer
  - 生成初始corpus
    - 1）利用image parser从最初的image中提取元数据；
    - 2）检索初始image状态，找到文件路径、类型等，组成测试用例；
    - 3）为每个测试用例，生成初始程序，以操作该文件对象
  - 对于每个corpus里的test case
    - 1）保持system call trace不变mutate image；
    - 2）几轮之后如果没有发现new coverage，再恢复image到最初状态，mutate system call的参数；
    - 3）几轮之后如果没有发现new coverage，再在现有syscall trace基础上添加新的系统调用
  - How to mutate a large image blob
    - shrunken blob，仅操作和保存元数据为seed，约占1%的比例
    - mutate metadata block, e.g. bit flipping, set interesting value (0, -1, INT_MAX)
    - add unchanged user data, recalculate checksum
  - How to generate image-dependent file operations
    - 不仅生成系统调用序列，还根据系统调用的功能猜测系统调用执行后，每个文件对象的状态
    - 对于普通参数的mutate，按照Syzkaller的生成方式
    - 对于与文件相关的参数的mutate，则利用抽取的文件系统的状态，选择合适的路径和属性等
  - How to reproduce found bugs
    - 每次都fresh操作系统状态 library OS LKL
      - LKL exposes kernel interfaces to user-space programs
    - 使LKL支持KASAN
      - KASAN在运行时分配shadow memory来记录内存中每个byte是否可以访问
    - 为了performance，利用写时复制技术，只有在发生写操作的时候才复制image
- Implementation
  - Implementation complexity of JANUS：AFL的基础上进行修改，加上了image mutator和system call fuzzer
  - 支持34个文件系统相关的系统调用：read(), write(), open(), seek(), mmap(), getdents64(), pread64(), pwrite64(), stat(), lstat(), rename(), fsync(), fdatasync(), syncfs(), sendfile(), access(), ftruncate(), truncate(), fstat(), statfs(), fstatfs(), utimes(), mkdir(), rmdir(), link(), unlink(), symlink(), readlink(), chmod(), fchmod(), setxattr(), fallocate(), listxattr(), and removexattr()
  - Mutate metadata for 256 rounds, the same as the non-deterministic mutation havoc stage for AFL
- Evaluation
  - 8个文件系统Fuzz了四个月，找到90个漏洞，其中62个被确认，43个被修复，32个CVE
  - 比较coverage时，将AFL格式的coverage=>Syzkaller格式的coverage再做对比
    - 其实Syzkaller的coverage计算方式更容易产生碰撞
    - Syzkaller用PC地址低32位代表每个basic block
    - AFL用随机数代表每个basic block
  - Fuzz image but executing fixed file operations
    - Syzkaller：syz_mount_image；non-zero chunks
    - 1.47-4.17x covered path after fuzzing 12h
  - Fuzz file operations without mutating file system image
    - at most 2.24x more paths
  - Exploring two-dimensional input space
    - Achieve more path coverage than both individual component, showing that fuzz file system via two dimentiional is necessary
    - at most 4.19x code paths
  - 使用library OS，与Syzkaller相比，Janus可以复现95%的crash，而Syzkaller却不能
- Reflection
- Appendix

<img src="https://i.loli.net/2021/01/01/iBDJ2wfSGUPqO9s.png" alt="image-20210101221541157" style="zoom:40%;" />

- Upstream kernel是linux社区维护的内核，Downstream kernel是厂商自己定制的内核

