---
title: Difficultise to find race bugs and how existing work solve them
date: 2020-12-24 15:21:02
tags:
	- Kernel
	- Race Bugs
categories: Surveys
---
### 1. Race Bug

两个访问内存区域的线程，当下面三个条件同时满足时，即可认定是Race bug。

1. 访问的内存区域地址相同
2. 其中一个内存访问是写操作
3. 两个线程的执行顺序是不受限制的

<!--more-->

Race bug又可分为harmful和benign两种：

1. Harmful: 数据竞态是不被期望的，数据的访问是需要遵守严格的先后顺序的，对数据的准确性是有要求的。此种竞态的出现可能会对内核的稳定性和安全性造成有害影响，例如，产生死锁，data overflow，double-free，use-after-free, 数据丢失等
2. Benign:数据竞态是可接受的，数据的准确性是不被要求的，一般用在性能计数器上，为了防止相互等待造成的延迟。

Race bug又可以分为single-varible race和multi-varible race

https://lifeasageek.github.io/papers/yoochan-exprace-bh.pdf

<img src="https://i.loli.net/2020/12/30/icZQWPUHudtnyp2.png" alt="image-20201230210147341" style="zoom:63%;" />

<center>Single-variable race</center>

<img src="https://i.loli.net/2020/12/30/gkD5fQ9zqoFlyZJ.png" alt="image-20201230205159941" style="zoom: 67%;" />



<center>Multi-variable race</center>

### 2. 识别Race Bug的难点

1. race bug 是非常不确定的，非常难复现
2. race bug 触发后很大可能不会导致系统崩溃，只有在后期回溯的时候才能发现

### 3. 需要解决哪些问题

其实可以根据定义延伸出一系列的问题：

1. 面对代码量非常大的内核，如何确定哪些指令访问同一内存地址？
2. 对于访问同一内存地址的指令，如何确定它们是否有可能出现竞态？
3. 对于有可能出现竞态的指令对，如何确定特定的线程执行顺序来触发竞态？
4. 对于触发的竞态，如何立即捕捉到？
5. 如何覆盖尽可能多的代码区域，来实施上述1-4的检测过程？
6. 由于Race Bug的不确定性，上述1-4的检测过程可能需要重复很多次。

### 4. 现有工作的解决方案

现在我主要看了两个工作Razzer和Krace，两个工作各有利弊，针对上述问题，提出了各自的解决方案。首先介绍两个工作的workflow：

Razzer 1）首先执行static analysis，分析出内核中访问同一内存区域的指令对。2）利用单线程fuzzing，找到执行每个指令对的系统调用序列。**3）判断两个指令是否访问同一内存区域** 4）利用多线程fuzzing，确定性的枚举两个线程在指令对处的执行顺序（也就是两个vCPU执行的先后顺序）。4）当找到一种线程交织使两个线程同时访问同一内存区域后，会后续系统调用进行mutate，期望触发竞态漏洞导致的有害影响，使内核崩溃。

Krace的工作流程是一个完整的Fuzzing过程，只是在常规Fuzzing过程中增加了一些针对于race bug的特殊处理。整个过程为 1）merge两个已有的多线程系统调用序列 2）执行mutate操作，生成新的多线程系统调用序列 2）清理虚拟机状态，多线程运行此系统调用序列 3）如果有新的branch coverage 或 alias coverage 则保留下来以进一步mutate 4）一旦有新的alias coverage 则offline启动竞态bug检测机制 5）此过程不断循环，有时还会，直到循环结束。

两个工作都会运行几周的时间来检测竞态bug，说明检测竞态bug实属不易，另外，两个工作的明显区别是，Razzer继承于Syzkaller，因此并不会在每条trace执行后清理虚拟机状态，而Krace每次回清理虚拟机状态，为了便于调试和定位原因。

#### 4.1 如何确定哪些指令访问同一内存区域？

##### 1. Razzer

利用静态points-to分析，分析内核的LLVM代码。

**a. 优点**：

1. 此过程offline，对实效性要求并不高。
2. 提前对kernel有全面的把握，覆盖率问题可以得到解决。

**b. 缺点**：

1. 内核代码这么多，怎么高效检测？
   - 分模块分析，不考虑模块间的指令对，是under-approximated的；不考虑同步元语，是over-approximated的。
2. 如何解决静态分析固有的false-positive比较高的问题？（见问题3）
3. 对于访问同一内存区域的指令，如何找到相应的程序来运行这些指令？
   - 利用fuzzing，先找到相应的单线程程序，同时覆盖两个指令对，再进行多线程交织。

##### 2. Krace

动态运行时检测，提出alias coverage的概念，并应用到coverage-guided fuzzing中。其中，alias coverage指的是有多少可能会出现竞态漏洞的指令对被覆盖。

**a. 优点**：

1. 动态过程自然而然解决了false-positive的问题，准确率比较满意
2. 此过程先有相应的执行序列，再检测到有两个指令访问相同的内存区域，自然解决了为指令找序列的问题。

**b. 缺点**：

1. 此过程是online的，如何执行高效的检测机制是一个需要克服的问题？ (inter-context define-and-use)
   - 对每个内存地址，记录最后一个对其进行写入操作的指令，然后看是否有来自不同线程的指令对其进行写操作。
2. 面对两个程序这么多组可能的指令对，如何高效查找其中访问相同内存区域的指令？（见问题4.3）
3. 类似于进度条式的处理方式，对内核状态逐步探索，那么应如何提高代码覆盖率，尽可能多的覆盖指令对？
   - 利用coverage-guided fuzzing，提出了针对多线程程序的进化算法，其中创新点是merge操作，区别于以往的直接concat操作。

#### 4.2 对于访问同一内存地址的指令，如何确定它们是否有可能出现竞态？

##### 1. Razzer

不考虑此问题，在后续Fuzzing过程中进行处理，在得到正确的多线程交织后（两个指令访问同一内存地址），进一步mutate后续的系统调用序列，期待合理的后续系统调用的执行能够触发竞态造成的有效影响。

**a. 优点：**

1. 不需要对kernel的同步机制进行系统的建模。
2. 生成的系统调用序列可以真实的触发程序崩溃，因此大多是发现的竞态bug都是harmful的bug。

**b. 缺点：**

1. 极其依赖syscall序列的后续处理过程，由于大多数情况下，竞态漏洞并不能立即崩溃系统，因此需要合理的后续系统调用的执行，触发竞态漏洞导致的有害影响，而本步骤在Razzer中是利用fuzzing实现的，其效率可能有待提高。（可能是可以突破的地方）

##### 2. Krace

针对内核文件系统中常见的锁和同步机制建模，对于访问同一内存地址的指令，offline执行精确、全面的竞态监测，主要是针对第三个条件，两个线程的执行顺序是不受限制的，检测过程经历如下两个步骤：

1. Lockset Analysis：针对锁操作，两个线程针对内存的操作是没有上锁的话，说明执行顺序是不受控制的。当对于同一内存地址，两个线程的分别的读写锁相交为空，且写锁也相交为空时，说明两个线程的执行顺序是不受控制的。
2. Happens before Analysis：针对同步元语，两个线程之间没有同步元语进行同步的话，即没有特别指明线程A一定在线程B之前运行，那么说明执行顺序是不受控制的。该步骤利用hook操作，建立起各语句间的有向无环图，利用节点是否联通来判断是否有happens-before关系。

**a. 优点**

1. 非常准确，而且基本上不需要后续操作就可以辨别是不是竞态。

**b. 缺点**

1. 工程量会比较大，需要对其进行全方位建模，还需要包含特定（ad hoc）的锁和同步机制。
2. 性能上可能会有问题，该算法不能执行过多次，否则影响fuzzing的性能。
3. 此类分析会发现benign和harmful的bug，还需要进一步筛选benign的竞态漏洞，本论文利用heuristics来筛选出benign的漏洞。

#### 4.3 对于有可能出现竞态的指令对，如何确定特定的线程执行顺序来触发竞态？

##### 1. Razzer

利用定制的hypervisor，给每个可能出现竞态的指令对加入断点，使两个线程自动执行到设置断点的位置，然后随机启动其中一个线程，使两个线程按不同的顺序交织。

**a. 优点**

1. 不需要对kernel有任何改变
2. 对线程交织进行确定性处理，摒弃了其中的不确定因素，利用hypervisor对其执行顺序进行确定性控制

**b.缺点**

1. 可以处理的线程数是非常有限的
2. 断点和再启动会影响系统调用序列的执行速度

##### 2. Krace

delay schedule，间接控制线程的执行顺序。在每个内存访问指令处，随机抽取一个随机数，并将内存操作指令延后相应时间

**a. 优点**

1. 便于实现，也同时处理多个线程（论文利用了3个线程）

**b. 缺点**

1. 需要对内核进行编译时插桩
2. 不能遍历所有的内存访问先后顺序，有效性可能有所打折
3. delay操作会影响系统调用序列的执行速度。
4. 难以复现，因为不是对所有的内核代码都进行了插桩

#### 4.4 对于触发的竞态，如何立即捕捉到？

见问题4.2

#### 4.5 如何覆盖尽可能多的代码区域，来实施上述1-4的检测过程？

##### 1. Razzer

coverage-guided fuzzing，缺点是有时不同的线程交织会造成相同的branch coverage，不利于在多线程的上下文中发现更多的线程交织情况。

##### 2. Krace

branch covearge+alias coverage，并提出针对多线程系统调用序列的merge操作，可以产生更多的线程交织可能性。

### 5. 哪些可以改进的地方

1. 如何生成合理的后续系统调用序列来显式触发有害的race bug造成的影响。

2. 如何实现多个线程的交织，当前的研究主要是2个或3个线程，王帅提出可以用PCA来处理线程交织的coverage。

3. 可以将该想法应用到分布式系统里，例如常见的分布式系统kafka和etcd，常见的分布式文件系统ceph、minio和hdfs。

> Fuzzing distributed file systems that involve not only thread interleavings but also network event ordering, which requires completely new coverage metrics to capture.

### Related Work

1. [USENIX'21] ExpRace: Exploiting Kernel Races through Raising Interrupts (conditional accept)

