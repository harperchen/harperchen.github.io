---
title: RLTrace Related
date: 2021-02-02 13:03:23
tags:
---

##### readelf

readelf is used to detect virtual memory offset.

```bash
readelf -SW vmlinux
```

The meaning of the flags is as follows:

- -S - list section headers in the kernel image file
- -W - output each section header entry in a single line

<!--more-->

##### nm

nm is used to parse address and size of each function in the kernel image

```bash
nm -Ptx vmlinux
```

The meaning of the flags is as follows:

- -P - use the portable output format (Standard Output)
- -tx - write the numeric values in the hex format

Output is of the following form:

```bash
# symbol name | symbol type | symbol address | size
# t or T means text section
verify_cpu T ffffffff810000e0 00000000000000f1
```

<img src="https://i.loli.net/2021/02/02/hU2YP8Dqencr3XF.png" alt="image-20210202193136748" style="zoom: 50%;" />



##### objdump

The kernel image is disassembled using the following command:

```bash
$ objdump -d --no-show-raw-insn vmlinux
```

number of basic blocks in linux kernel, in total 501885

```bash
$ objdump -d vmlinux | grep -o 'callq  ffffffff81387f00 <__sanitizer_cov_trace_pc>'  | wc -l
493815

$ objdump -d vmlinux | grep -o 'jmpq   ffffffff81387f00 <__sanitizer_cov_trace_pc>'  | wc -l
8070
```

those left but also match __sanitizer_cov_trace_pc are 

```assembly
ffffffff81387f00 <__sanitizer_cov_trace_pc>:
ffffffff81387f1a:	75 32                	jne    ffffffff81387f4e <__sanitizer_cov_trace_pc+0x4e>
ffffffff81387f25:	75 27                	jne    ffffffff81387f4e <__sanitizer_cov_trace_pc+0x4e>
ffffffff81387f3e:	76 0e                	jbe    ffffffff81387f4e <__sanitizer_cov_trace_pc+0x4e>
```

##### addr2line

addr2line is used for mapping PC values exported by kcov and parsed by objdump to source code files and lines.

Multiple lines of source code means this instrutions belong to a inline function.

```bash
$ addr2line -afi -e vmlinux 0xFFFFFFFF81001CC6
0xffffffff81001cc6
trace_initcall_finish
/home/wchenbt/Projects/Fuzzer/syz/linux/./include/trace/events/initcall.h:48
do_one_initcall
/home/wchenbt/Projects/Fuzzer/syz/linux/init/main.c:888
```

##### Entry of each syscall

```c++
#define SYSCALL_DEFINE0(name)	   asmlinkage long sys_##name(void)
#define SYSCALL_DEFINE1(name, ...) SYSCALL_DEFINEx(1, _##name, __VA_ARGS__)
#define SYSCALL_DEFINE2(name, ...) SYSCALL_DEFINEx(2, _##name, __VA_ARGS__)
#define SYSCALL_DEFINE3(name, ...) SYSCALL_DEFINEx(3, _##name, __VA_ARGS__)
#define SYSCALL_DEFINE4(name, ...) SYSCALL_DEFINEx(4, _##name, __VA_ARGS__)
#define SYSCALL_DEFINE5(name, ...) SYSCALL_DEFINEx(5, _##name, __VA_ARGS__)
#define SYSCALL_DEFINE6(name, ...) SYSCALL_DEFINEx(6, _##name, __VA_ARGS__)
```

```javascript
0xffffffff8100702e
native_irq_enable
/home/wchenbt/Projects/Fuzzer/syz/linux/./arch/x86/include/asm/irqflags.h:52
arch_local_irq_enable
/home/wchenbt/Projects/Fuzzer/syz/linux/./arch/x86/include/asm/irqflags.h:90
do_syscall_64
/home/wchenbt/Projects/Fuzzer/syz/linux/arch/x86/entry/common.c:277

0xffffffff81007067
do_syscall_64
/home/wchenbt/Projects/Fuzzer/syz/linux/arch/x86/entry/common.c:288

0xffffffff81007075
array_index_mask_nospec
/home/wchenbt/Projects/Fuzzer/syz/linux/./arch/x86/include/asm/barrier.h:41
do_syscall_64
/home/wchenbt/Projects/Fuzzer/syz/linux/arch/x86/entry/common.c:289

0xffffffff810070dd
get_current
/home/wchenbt/Projects/Fuzzer/syz/linux/./arch/x86/include/asm/current.h:15
syscall_return_slowpath
/home/wchenbt/Projects/Fuzzer/syz/linux/arch/x86/entry/common.c:249
do_syscall_64
/home/wchenbt/Projects/Fuzzer/syz/linux/arch/x86/entry/common.c:293


0xffffffff81007115
native_irq_disable
/home/wchenbt/Projects/Fuzzer/syz/linux/./arch/x86/include/asm/irqflags.h:47
arch_local_irq_disable
/home/wchenbt/Projects/Fuzzer/syz/linux/./arch/x86/include/asm/irqflags.h:85
syscall_return_slowpath
/home/wchenbt/Projects/Fuzzer/syz/linux/arch/x86/entry/common.c:267
do_syscall_64
/home/wchenbt/Projects/Fuzzer/syz/linux/arch/x86/entry/common.c:293


0xffffffff810071a5
__read_once_size
/home/wchenbt/Projects/Fuzzer/syz/linux/./include/linux/compiler.h:193
prepare_exit_to_usermode
/home/wchenbt/Projects/Fuzzer/syz/linux/arch/x86/entry/common.c:194
syscall_return_slowpath
/home/wchenbt/Projects/Fuzzer/syz/linux/arch/x86/entry/common.c:268
do_syscall_64
/home/wchenbt/Projects/Fuzzer/syz/linux/arch/x86/entry/common.c:293

0xffffffff810071d5
prepare_exit_to_usermode
/home/wchenbt/Projects/Fuzzer/syz/linux/arch/x86/entry/common.c:211
syscall_return_slowpath
/home/wchenbt/Projects/Fuzzer/syz/linux/arch/x86/entry/common.c:268
do_syscall_64
/home/wchenbt/Projects/Fuzzer/syz/linux/arch/x86/entry/common.c:293

ioctl
0xffffffff81610d28
__x64_sys_ioctl
/home/wchenbt/Projects/Fuzzer/syz/linux/fs/ioctl.c:718

0xffffffff81610ca3
fdget
/home/wchenbt/Projects/Fuzzer/syz/linux/./include/linux/file.h:60
ksys_ioctl
/home/wchenbt/Projects/Fuzzer/syz/linux/fs/ioctl.c:707

0xffffffff81633373
__fdget
/home/wchenbt/Projects/Fuzzer/syz/linux/fs/file.c:778

0xffffffff81633184
get_current
/home/wchenbt/Proje cts/Fuzzer/syz/linux/./arch/x86/include/asm/current.h:15
__fget_light
/home/wchenbt/Projects/Fuzzer/syz/linux/fs/file.c:761

0xffffffff816332ea
__fget_light
/home/wchenbt/Projects/Fuzzer/syz/linux/fs/file.c:770

0xffffffff81632eb7
get_current
/home/wchenbt/Projects/Fuzzer/syz/linux/./arch/x86/include/asm/current.h:15
__fget
/home/wchenbt/Projects/Fuzzer/syz/linux/fs/file.c:710

0xffffffff81632f04
__read_once_size
/home/wchenbt/Projects/Fuzzer/syz/linux/./include/linux/compiler.h:193
__fcheck_files
/home/wchenbt/Projects/Fuzzer/syz/linux/./include/linux/fdtable.h:84
fcheck_files
/home/wchenbt/Projects/Fuzzer/syz/linux/./include/linux/fdtable.h:98
__fget
/home/wchenbt/Projects/Fuzzer/syz/linux/fs/file.c:715

0xffffffff81633050
__fget
/home/wchenbt/Projects/Fuzzer/syz/linux/fs/file.c:728

0xffffffff816332db
__fget_light
/home/wchenbt/Projects/Fuzzer/syz/linux/fs/file.c:767

0xffffffff81610cec
fdput 
/home/wchenbt/Projects/Fuzzer/syz/linux/./include/linux/file.h:43
ksys_ioctl
/home/wchenbt/Projects/Fuzzer/syz/linux/fs/ioctl.c:714
```

do_syscall_64 => SYSCALL_DEFINE3 => ksys_ioctl => fdget => _\_fdget  => _\_fget_light => _\_fget => _\_fget_light => __fdget => fdget => ksys_ioctl 

##### bind

```C++
int bind(int sockfd, const struct sockaddr *addr, socklen_t addrlen);

SYSCALL_DEFINE3(bind, int, fd, struct sockaddr __user *, umyaddr, int, addrlen)
{
    return __sys_bind(fd, umyaddr, addrlen);
}                                                                                     net/socket.c:1491

struct sockaddr {
    sa_family_t sa_family;      /* unsigned short, address family, AF_xxx */
    char        sa_data[14];    /* 14 bytes of protocol address */
};                                                                            
```

bind assigns the address specified by **addr** to the socket referred to by the file descriptor **sockfd**, different type of socket need to be bind with corresponding type of address, otherwise error handling

<img src="https://i.loli.net/2021/02/03/njPwoDeHCT4Q9yM.png" alt="image-20210203114926737" style="zoom: 60%;" />