---
title: '[S&P''20] Ex-vivo dynamic analysis framework for Android device drivers'
date: 2020-12-27 19:06:47
tags:
	- Kernel
	- Hardware Boostup
categories: Papers
---

### Abstract

The ability to execute and analyze code makes many security tasks such as exploit development, reverse engineering, and vulnerability detection much easier. However, on embedded devices such as Android smartphones, executing code in-vivo, on the device, for analysis is limited by the need to acquire such devices, the speed of the device, and in some cases the need to flash custom code onto the devices. The other option is to execute the code ex-vivo, off the device, but this approach either requires porting or complex hardware emulation.

<!--more-->

In this paper, we take advantage of the observation that many execution paths in drivers are only superficially dependent on both the hardware and kernel on which the driver executes, to create an ex-vivo dynamic driver analysis framework for Android devices that requires neither porting nor emulation. We achieve this by developing a generic *evasion* framework that enables driver initialization by evading hardware and kernel dependen- cies instead of precisely emulating them, and then developing a novel *Ex-vivo AnalySIs framEwoRk (EASIER)* that enables off-device analysis with the initialized driver state. Compared to on-device analysis, our approach enables the use of userspace tools and scales with the number of available commodity CPU’s, not the number of smartphones.

We demonstrate the usefulness of our framework by targeting privilege escalation vulnerabilities in system call handlers in platform device drivers. We find it can load 48/62 (77%) drivers from three different Android kernels: MSM, Xiaomi, and Huawei. We then confirm that it is able to reach and detect 21 known vulnerabilities. Finally, we have discovered 12 new bugs which we have reported and confirmed.

<img src="https://i.loli.net/2020/12/28/8HLgaI6wWkPjVmq.png" alt="image-20201228135046211" style="zoom: 50%;" />

### Outline
- Target Problem
  - 对嵌入式系统例如Android设备的分析经常需要flash系统，例如重新编译linux来利用kcov收集coverage进行coverage-guided fuzzing。在设备外运行分析的话，需要模拟化或者移植，观察到很多驱动程序的代码只是表面上依赖硬件和内核，因此提出不需要模拟化和移植的对驱动程序的动态分析框架。
- Existing approaches
  - [CCS'17] DIFUZE
    - 真机运行
    - 静态分析无法获取动态分配object和array的大小
    - 无法利用syzkaller的coverage-guided fuzzing
  - [USENIX'18] Charm：当驱动需要访问外设时，会被转移到物理设备上，否则则在虚拟机里运行。
    - 需要移植驱动
    - 需要手动分离驱动
    - 需要为每个分析实例提供真实的硬件设备
- Difficulties of ex-vivo derive analysis
  - In-vivo: 在设备内运行动态分析的扩展性不够好，因为对内核的动态分许需要
    - 特定硬件的支持：kAFL利用Intel PT特性是在Arm上不支持的
    - 有足够高的特权操作内核：Syzkaller需要对内核进行重新编译来启动kcov和kasan功能
  - Ex-vivo：一般是需要硬件模拟器，然而对于驱动的分析
    - 驱动是生来就依赖硬件的，这些相应的硬件在虚拟机中是不支持的
      - 尽管这些硬件是支持的，驱动在模拟器中也没有合适的环境
    - 驱动也在软件上依赖内核，但其实很多硬件特定的内核也没法在虚拟机里运行
    - 为了在虚拟机里运行相应的驱动，需要将驱动移植到可以被模拟运行的内核中，但费时费力
- Why this paper is accepted
  - Usefulness
    - 可以设备外执行驱动程序的动态分析，不需设备移植，也不需真实的物理设备
    - 发现了针对IOCTL的29个特权提升的漏洞，其中12个为零日漏洞
  - Novelty
    -  观察驱动程序对硬件和软件的依赖是非常表面的，而且这些路径上是有漏洞的。
       -  例如具备读取设备寄存器的能力而不关心实际寄存器的值。
       -  例如只需要特定的函数返回success代码，并不依赖这个函数的实际语义
    -  实现一种逃避依赖的方案，不需要真的被依赖的软件和硬件，就可以对驱动进行加载和初始化 
    -  该技术允许AFL和Manticore（符号执行工具）等用户级的漏洞检测技术应用到对驱动程序的分析中
- How it works
  - Evasion kernel: 利用可以被虚拟化的内核（vexpress和virt）加载和初始化不被支持的内核相关联的驱动
    - 内核数据结构、全局变量、系统调用中使用的内核API数据结构和例如MIMO内存范围等资源、以及中断等都需要被初始化
    - 为什么不直接重新编译驱动使其在能被虚拟化的内核中运行呢？
      - 因为驱动依赖主机内核特定的子系统、头文件和配置文件等
  - EASIER (Ex-vivo Analysis framework)：在用户空间对驱动进行fuzzing或符号执行
    - 利用Qemu模拟器，初始化驱动和内核，运行应用程序调用ioctl，在进入内核空间时提取内存快照，导出所有内存页和寄存器的值
    - 利用CPU模拟器dUnicorn加载内存和恢复寄存器的值，从文件中读取传递给系统调用的参数，模拟执行系统调用直到返回用户空间
- Implementation details for Evasion (需满足的条件)
  - 满足驱动对内核的软件依赖：三个stub替代依赖的内核函数，利用模块的导出函数表，查找内核代码中相应函数的签名，将签名信息插入到ELF文件的section中，后续被evasion内核子定义模块使用来确定具体需要哪一个stub函数
    - stub0：返回0，替代所有返回值是int的函数，因为Linux经常用0表示成功，其他非零值为错误代码
    - stubP：开辟内存空间，用于替代返回值为指针的函数，这种情况下原函数一般是返回一个指向结构的指针
    - stub1：返回1，针对少数非零值才表示成功的函数
  - 隐藏驱动对硬件的硬件依赖
    - 重用device tree条目， 如果主机内核device tree文件
      - 可用，直接在evasion kernel中进行使用
      - 不可用，或者没有搜索到对应的条目，evasion直接使用最常用的合理值生成一个条目
    - 忽略驱动与设备的通信
      - 重定向注册MIMO range的函数为kzalloc，读写操作被忽略
      - 监听和替换15个kernel函数
  - 确保内核和驱动之间传输数据结构的一致性
    - 结构体各字段要对齐，偏移量要一致
    - 若主机内核代码不可访问，则对比二进制中字段的偏移量，插入填充使字段对齐
    - 若主机内核代码可访问，直接尝试不同配置编译evasion，使最终各字段一致
- Implementation details for EASIER (Ex-vivo Analysis framework)
  - dUnicorn是一个CPU模拟器，仅模拟Arm指令集，不支持任何硬件，需要监听和重定位所有内核的函数
    - 没有MMU，替换所有kzalloc、krealloc和kfree为定制的内存分配器
    - 监听进程调度函数，例如 _cond_resched，直接返回到用户空间
    - 选择性关闭log函数，例如printk
  - 恢复IOCTL的结构体参数格式
    - 动态恢复ioctl所需的数据结构布局，监听copy_from_user，动态开辟所需的数据结构
    - 所有用户空间和内核空间的数据交互都是用copy_from_user
  - 如何收集Coverage进行Fuzzing
    - AFL-Unicorn，工作原理类似于Fuzz二进制的AFL-Qemu模式
  - 执行Symbolic Execution
    - Manticore框架，符号化执行用户态ELF Binary
    - 扩展其Manticore使其能从内存快照中获取执行状态
    - 恢复IOCTL的command参数
- Evalution
  - 表面依赖的假设是否成立？
    - 对于26个已知的程序漏洞，给定触发程序下，可以触发其中81%，说明该方案是有效的
  - 逃避技术是否能够加载和初始化驱动
    - 针对3个设备上的62个驱动，实现对其中77%的驱动的加载和初始化
  - 是否能利用Fuzzing找到真的IOCTL的漏洞，针对32个drivers
    - fuzz过程发现29个漏洞，其中12个是零日漏洞
  - Fuzzing的吞吐量
    - 1167 executions per second for MSM kernel drivers
    - 525 executions per second for Xiaomi derivers
    - Whereas Charm only achieve 20 executions per second
    - No need to restart the device after reboot
- Reflection 
  - 这篇感觉是DiFUZE的后续工作，DIFUZE就是需要刷机才能支持Syzkaller的kcov功能，采用x86模拟了一些驱动来检测生成ioctl结构体信息的有效性，这里既然可以解决这个问题，说不定可以两者结合。
- How to improve this work