---
title: >-
  [USENIX'18] Charm: Facilitating Dynamic Analysis of Device Drivers of Mobile
  Systems
date: 2020-12-29 13:13:22
tags:
	- Kernel
	- Hardware Boostup
categories: Papers
---

#### Abstract

Mobile systems, such as smartphones and tablets, incorporate a diverse set of I/O devices, such as camera, audio devices, GPU, and sensors. This in turn results in a large number of diverse and customized device drivers running in the operating system kernel of mobile systems. These device drivers contain various bugs and vulnerabilities, making them a top target for kernel exploits. Unfortunately, security analysts face important challenges in analyzing these device drivers in order to find, understand, and patch vulnerabilities. More specifically, using the state-of-the-art dynamic analysis techniques such as interactive debugging, fuzzing, and record-and-replay for analysis of these drivers is difficult, inefficient, or even completely inaccessible depending on the analysis.

<!--more-->

In this paper, we present Charm1, a system solution that facilitates dynamic analysis of device drivers of mo- bile systems. Charm’s key technique is *remote device driver execution*, which enables the device driver to ex- ecute in a virtual machine on a workstation. Charm makes this possible by using the actual mobile system only for servicing the low-level and infrequent I/O operations through a low-latency and customized USB channel. Charm does not require any specialized hardware and is immediately available to analysts. We show that it is feasible to apply Charm to various device drivers, including camera, audio, GPU, and IMU sensor drivers, in different mobile systems, including LG Nexus 5X, Huawei Nexus 6P, and Samsung Galaxy S7. In an extensive evaluation, we show that Charm enhances the usability of fuzzing of device drivers, enables record-and- replay of driver’s execution, and facilitates detailed vulnerability analysis. Altogether, these capabilities have enabled us to find 25 bugs in device drivers, analyze 3 existing ones, and even build an arbitrary-code-execution kernel exploit using one of them.

![image-20201229181646372](https://i.loli.net/2020/12/29/g1VuLHYwJytkmX4.png)

#### Outline

- Target Problem
  - 移动设备中包含很多IO设备，但利用例如fuzzing、交互式调试等动态分析技术对其进行分析非常困难且效率低下，甚至完全无法访问。本文提出Charm，一种使驱动程序能够在虚拟机中运行的技术。在虚拟机中运行克服了对设备驱动进行动态分析的难点，促进驱动漏洞的检测。
- Existing approaches
  - [CCS'17] DIFUZE
    - 真机运行
    - 静态分析无法获取动态分配object和array的大小
    - 无法利用syzkaller的coverage-guided fuzzing
  - [USENIX'18] Charm：当驱动需要访问外设时，会被转移到物理设备上，否则则在虚拟机里运行。
    - 需要移植驱动
    - 需要手动分离驱动
    - 需要为每个分析实例提供真实的硬件设备
- Difficulties of performing dynamic analysis on drivers
  - 交互式调试和记录重放等动态分析需要驱动跑在一个完全可控制的环境里，例如虚拟机，但虚拟机并不支持模拟驱动
  - Fuzzing例如kAFL和Syzkaller有局限性
    - kAFL需要运行在基于x86的虚拟机上，而不支持ARM；
    - Syzkaller中很多fuzzing的feature，例如KASAN，KMSAN，KTSAN和KUBSAN等在移动设备的内核上都是不支持的，
    - KGDB需要控制台访问，需要UART硬件才可以实现，有的手机不支持，有的手机得自己找引脚，有的有插口还得有特殊的线
    - 另一个读取内核信息的工具adb却不能在捕获内核崩溃时的日志，因为adb也同时崩溃了
- Difficulties of running driver inside virtual machine
  - 驱动程序需要访问特定的IO设备硬件，没有相应的设备，驱动是无法完成初始化的
  - 由于驱动设备实在太多，所以模拟器不可能虚拟化模拟所有驱动
  - 驱动程序对特定内核有软件依赖，有些内核也不被支持虚拟化
  - 在移动设备的虚拟机里模拟驱动，然后利用设备直通使用主机的设备
    - 一般只支持x86的PCI设备，而不支持移动手机上的IO设备
    - ARM处理器虚拟化技术一般被移动设备禁止使用
- Why this paper is accepted
  - 本文提出技术在虚拟机里运行驱动的技术，使对驱动程序执行Fuzzing、record-and-reply等动态分析技术变得可能。
    - 虚拟机模拟可以使Fuzzing利用别的技术，例如利用record-and-reply来分析漏洞
    - 虚拟机模拟便于Fuzzing使用许多kernel sanitizer，因为驱动是运行在支持sanitizer的内核上的
    - 虚拟机模拟便于利用hypervisor捕获内核崩溃时的执行日志，利于定位bug
  - Usefulness
    - 驱动程序可以在虚拟机里运行，因此可观察执行情况和分析。
    - 不需要任何定制的硬件就可以直接给分析人员使用。
    - 本文提出技术找到4个驱动程序中的25个漏洞。
  - Novelty
    -  本文观察到驱动对IO设备的访问是不常见的，提出远程设备驱动执行技术。
    -  本文将设备驱动和物理设备解藕，允许驱动运行在其余主机的虚拟机中
    -  The replay of the driver does not even require having access to the actual mobile system
- How it works
  - 本文提出远程设备驱动执行技术，在x86虚拟机上运行驱动
    - 将真实物理设备以USB方式连接到主机上，仅将不常见的IO操作转发到真实设备上运行。
    - hypervisor监听并拦截对IO设备交互和IO设备抛出的中断，利用定制的低延迟的USB通道，将其传递至真实物理设备上运行。
      - 在hypervisor中实现stub模块，在物理设备上也实现stub模块，进而实现驱动与设备的通信
        - 访问设备寄存器：寄存器读/寄存器写
        - 中断：移动设备里的stub注册一个中断处理，代表实际驱动，每次接收到终端就交给驱动
        - 直接内存访问（外设直接访问内存而不经过CPU）DMA （目前不被支持）
      - 驱动初始化：如何让内核检测到这个本来不属于他的驱动
        - ARM使用device tree检测本机设备
        - x86使用ACPI检测本机设备
        - 使x86解析和使用device tree来检测远程IO设备
  - 定制USB通道，解决驱动和IO设备访问所需的实时性问题 （硬件依赖）
    - 虚拟机workstation和驱动的访问造成的延迟很容易产生time-out
    - 使用常见的USB接口，不需要定制特殊的硬件
    - USB gadget接口；5 endpoint；write batching
  - 如何在x86虚拟机上运行驱动？（本来就是C程序）移植驱动
    - 添加驱动代码及其依赖到内核代码，并编译
    - 将IO设备的device tree中的条目及依赖条目拷贝到x86虚拟机中
    - 建立USB和RPC通信渠道，来发送驱动对设备的操作
    - 处理来自设备的中断，关闭真机中的驱动
  - 利用远程RPC接口，解决驱动依赖匹配内核中特定的内核模块，而这些在通用虚拟机中不存在的问题（软件依赖）
    - 如果内核模块不被真机需要，就直接把它移到虚拟机里
    - 如果被真机需要（resident modules），就保留到真机上，使用RPC接口实现驱动和依赖内核模块的交互
      - 通用的RPC接口，使其能在不同移动设备的不同驱动上都能被使用
      -  Power and Clock management system, Pin controller hardware, and GPIO
  - 在Syzkaller中添加相应设备操作系统调用函数的模版
- Evalution
  - LG Nexus 5X：摄像头和音频驱动；Huawei Nexus 6P：GPU驱动；Samsung Galaxy S7：IMU驱动；
    - 少于1周的时间移植GPU驱动，大概2天时间移植IMU驱动
  - Performance of remote device deriver execution：和真实移动设备中运行Fuzzing相当（相同的吞吐量）
  - 在4个不同厂商的驱动中找到25个bug，其中14个未知bug，而且有两个是kernel sanitizer找到的，直接在真机上Fuzzing是找不到的
  - 可以重放设备驱动的执行情况，也可以使用调试器来分析驱动中的漏洞，并设计任意代码执行的exploit来攻击驱动。
    - Record-and-replay: 只记录和重放驱动和IO设备的交互，舍弃写操作，读操作根据日志读取相应值
- Reflection 
  - 这篇工作还是需要使用物理机来处理不常见的驱动对设备的底层IO操作
  - 这篇工作只支持开放源代码的驱动
  - 这篇工作还得解锁bootloader来重新部署手机的内核镜像
  - 这篇工作需要移植驱动到别的虚拟机支持的内核
- How to improve this work