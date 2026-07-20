---
title: '[NDSS''20] HFL: Hybrid Fuzzing on the Linux Kernel'
date: 2021-01-24 14:02:50
tags:
    - Hybrid Fuzzing
    - Fuzz Testing
    - Kernel
categories: Papers
---
### Abstract

Hybrid fuzzing, combining symbolic execution and fuzzing, is a promising approach for vulnerability discovery because each approach can complement the other. However, we observe that applying hybrid fuzzing to kernel testing is challenging because the following unique characteristics of the kernel make a naive adoption of hybrid fuzzing inefficient: 1) having indirect control transfers determined by system call arguments, 2) controlling and matching internal system state via system calls, and 3) inferring nested argument type for invoking system calls. Failure to handling such challenges will render both fuzzing and symbolic execution inefficient, and thereby, will result in an inefficient hybrid fuzzing. Although these challenges are essential to both fuzzing and symbolic execution, to the best of our knowledge, existing kernel testing approaches either naively use each technique separately without handling such challenges or imprecisely handle a part of challenges only by static analysis.

<!-- more -->

To this end, this paper proposes HFL, which not only combines fuzzing with symbolic execution for hybrid fuzzing but also addresses kernel-specific fuzzing challenges via three distinct features: 1) converting indirect control transfers to direct transfers, 2) inferring system call sequence to build a consistent system state, and 3) identifying nested arguments types of system calls. As a result, HFL found 24 previously unknown vulnera- bilities in recent Linux kernels. Additionally, HFL achieves 15% and 26% higher code coverage than Moonshine and Syzkaller, respectively, and over kAFL/S2E/TriforceAFL, achieving even four times better coverage, using the same amount of resources (CPU, time, etc.). Regarding vulnerability discovery performance, HFL found 13 known vulnerabilities more than three times faster than Syzkaller.

### Outline

#### Difficulties of performing hybrid fuzzing on kernel

**P1: Having indirect control transfers determined by system call arguments**. Kernel prefers to use function pointer table to support polymorphism.

```C++
size_t (*ucma_table[])(struct ucma_file *file,
                       char __user *inbuf, int in_len, int out_len) = {
    [RDMA_CREATE_ID] = ucma_create_id,
    [RDMA_DESTROY_ID] = ucma_destroy_id,
    [RDMA_BIND_IP] = ucma_bind_ip,
    ...
    [RDMA_JOIN_MCAST] = ucma_join_multicast
};
ssize_t ucma_write(struct file *filp, char __user *buf,
                   size_t len, loff_t *pos) {
    struct rdma_ucm_cmd_hdr hdr;
    ...
    if (copy_from_user(&hdr, buf, sizeof(hdr)))
     ...
	// indirect function invocation
    ret = ucma_table[hdr.cmd](file, buf + sizeof(hdr), hdr.in, hdr.out);
}
```

**P2: Controlling and matching internal system state via system calls**. Correct system call execution order is necessary to touch the deep logic of syscall.

<img src="https://i.loli.net/2021/01/26/YUqptSdmC4TjFoE.png" alt="image-20210126165218803" style="zoom:45%;" />

**P3: Inferring nested argument type for invoking system calls**. A field number in one structure points to another structure. 

<img src="https://i.loli.net/2021/01/26/7SPG5oewQX8pdsy.png" alt="image-20210126170342251" style="zoom:67%;" />

#### Drawbacks of previous work

either naively use fuzzing/symbolic execution separately by not handling such challenges
- Razzer: Fuzzing
- Digtool
- kAFL: Fuzzing
- Periscope: Fuzzing
- perf fuzzer
- CAB-Fuzz: Hybrid Fuzzer without handling P1, P2, P3

or  imprecisely handle a part of challenges only by static analysis 
- Difuze (infer the structure of arguments of ioctl)
  - Handle P3 but only perform static analysis 
  - Cannot infer abstract pointer which is only avaiable at runtime
- IMF (analyze trace of macOS)
  - Handle P2, without handling P1, P3
- Moonshine (analyze trace of linux)
  - Handle P2, without handling P1, P3
  - Analyze explicit dependencies by performing static analysis on kernel
  - <font color="#dd0000">HFL further perform symbolic checking to get precise constants between system state varibles</font>

#### Why this paper is accepted

Novelty: first kernel hybrid fuzzer

- First work to handle hybrid kernel fuzzing :open_mouth:

Practical

- Apply Hybird fuzzing approach to test the linux kernel
- Achieve significant coverage improvement
- Uncover multiple previously unknown vulnerabilities

#### How it works

Kernel Fuzzing + Symbolic Execution

<img src="https://i.loli.net/2021/01/26/MtTgOQsUpL3wePW.png" alt="image-20210126191910353" style="zoom: 50%;" />

**IV-B:** converting indirect control transfers to direct transfers at compile time <font color="#dd0000">for symbolic analyze</font>

- resolve function pointer, unfold indirect transfer to direct one offline :+1:
- only interest in those index variable originates from syscall parameters by data flow analysis

```C++
// before translation
ret = ucma_table[hdr.cmd](...);

// after translation
if (hdr.cmd == RDMA_CREATE_ID)
    ret = ucma_create_id (...);
else if (hdr.cmd == RDMA_DESTROY_ID)
    ret = ucma_destroy_id (...);
...
```

**IV-C**: inferring system call sequence to build a consistent system state

- Step 1: point-to analysis to capture candidate read/write dependency pairs (<font color="#dd0000">offline</font>) (<font color="blue">the same as the static analysis step of Razzer</font>)
- Step 2: runtime validation to identify true dependencies (<font color="dd0000">infer execution order</font>)
  - check if they access the same address during symbolically execution
  - distinguish true dependency pairs & write must before read 
- Step 3: detect parameter dependencies (<font color="dd0000">infer parameter dependencies</font>)

**IV-D**: identifying nested arguments types of system calls at runtime

- monitor invocation of copy_from_user 
- using symbolic state to track offset and length of nested data structure
- not the same as S&P'20: EASIER :sweat_smile:

#### Technique details

**IV-A:** Fuzzing: Syzkaller

- :sparkles: Fully automated kernel-specific features instead of using manually written template of Syzkaller

**IV-C & IV-D:** Symbolic Execution: S2E

- All syscall parameters is symbolized `s2e_make_symbolic`

- :sparkles: Identify always-false or always-true branch as hard branch by maintaining a frequency table
- Pass user program that executes hard branch to symbolic analyzer
- Symbolize all syscall parameters and perform concolic execution to reach another branch

**IV-B:** Unfold indirect control flow (Kernel translator)

- GIMPLE representation in gcc

**IV-C:** Infer syscall order and syscall paramter dependency

- Static analysis: SVF using [LLVM Linux](https://wiki.linuxfoundation.org/llvmlinux)

Code https://bitbucket.org/anonyk/hfl-release/src/master/

<img src="https://i.loli.net/2021/01/27/4Hv2RrtBOhgj6MV.png" alt="image-20210127144429015" style="zoom:67%;" />

#### Evaluation

<img src="https://i.loli.net/2021/01/28/4N6LKfC7aOSPBk8.png" alt="image-20210128154525938" style="zoom: 67%;" />

- 24 previously unknown vulnerabilities in recent Linux kernels

- HFL achieves 15% and 26% higher code coverage than Moonshine and Syzkaller

  ![image-20210128153114085](https://i.loli.net/2021/01/28/7WHrBdL6ZClKb42.png)

- HFL measures the upper bound number of coverage for kernel 

<img src="https://i.loli.net/2021/01/28/bMXNVgZmiJDuETB.png" alt="image-20210128151958587" style="zoom:80%;" />

- HFL found 13 known vulnerabilities more than three times faster than Syzkaller
- Contribution of each feature in HFL by comparing with Syzkaller

#### Examples

Three example to overcome proposed difficulties

**Difficult 1:** Indirect control flow in RDS network

```C++
# define RDS_INFO_FIRST 10000
typedef void (*rds_info_func)(struct socket *sock, int len,
                              struct rds_info_iterator *iter, struct rds_info_lengths *lens);

rds_info_func rds_info_funcs[RDS_INFO_LAST - RDS_INFO_FIRST +1];
// An indirect control-flow in RDS network
int rds_info_getsockopt(struct socket *sock, int optname,
                        char __user *optval, int __user *optlen) {
    func = rds_info_funcs[optname - RDS_INFO_FIRST];
    ...
    func(sock, len, &iter, &lens);
    ...
}
```

**Difficult 2**: calling dependency across PPP ioctl

```C++
long ppp_ioctl(struct file *file, int cmd, long arg) {
    ...
    switch (cmd) {
        // 1. write dependency
        // [syscall]: ioctl(fd, PPPIOCNEWUNIT, {VAL}<-unit)
        // [NOTE]: VAL is written to untyped syscall argument
        case PPPNEWUNIT:
            // allocate an VAL to unit
            err = ppp_create_interface(net, file, &unit); 
            if (err < 0)
                break;
            // write the VAL toward userspace 
            if (put_user(unit, arg))
                break; 
            ...
        // 2. read dependency
        // [syscall]: ioctl(fd, PPPIOCCONNECT, {VAL}->unit) 
        // [NOTE]: VAL is read from untyped syscall argument
        case PPPCONNECT:
            // read VAL from userspace
            if (get_user(unit, arg))
                break;
            ppp = ppp_find_unit(pn, unit); // check the VAL for dependency
            // [FAIL]: return if (untyped) value dependency is violated
            if (!ppp)
                goto out;
            
            /* main connection procedure */
            ...
}
```

**Difficult 3**: Nested argument in PPP driver

```c++
struct ppp_option_data {
    __u8 __user *ptr; // unknown typed inner buffer __u32 len;
    int transmit;
};

int ppp_set_compress(struct ppp *ppp, unsigned long arg) {
    struct ppp_option_data data;
    // inferred buffer layout: {..|..|..}
    if (copy_from_user(&data, (void __user *)arg, sizeof(data))) goto out;
    ...
    // inferred buffer layout: {..|..|ptr} --> {...}
    if (copy_from_user(ccp_opt, (void __user *)data.ptr, data.len)) goto out;
    ...
}
```

### Related Work

| Kernel Testing |       Kernel        |                           Target                           | Coverage guided | Call Sequence Inference | Nested Syscall  Argument | Indirect Control Flow | Handle Branch Condition |  Remark  |
| :------------: | :-----------------: | :--------------------------------------------------------: | :-------------: | :---------------------: | :----------------------: | :-------------------: | :---------------------: | :------: |
|  perf_fuzzer   |        Linux        |        <font color="#dd0000">perf_event set</font>         |                 |                         |                          |                       |                         |          |
|    Digtool     |         Win         |                                                            |                 |                         |                          |                       |                         |          |
|      kAFL      | Win & Linux & MacOS | <font color="#dd0000"> file system & single syscall</font> |     :star:      |                         |                          |                       |                         |  Fuzzer  |
|     Razzer     |        Linux        |        <font color="#dd0000">syscall traces</font>         |     :star:      |                         |                          |                       |                         | Race Bug |
|   PeriScope    |        Linux        |        <font color="#dd0000">device drivers</font>         |                 |                         |                          |                       |                         |          |
|    FIRM-AFL    |      Firmware       |                                                            |                 |                         |                          |                       |                         |          |
|    CAB-Fuzz    |        Wind         |        <font color="#dd0000">device drivers</font>         |                 |                         |                          |                       |         :star:          |  Hybrid  |
|      IMF       |        Linux        |        <font color="#dd0000">syscall traces</font>         |                 |         :star:          |                          |                       |                         |  Fuzzer  |
|   Syzkaller    |        Linux        |        <font color="#dd0000">syscall traces</font>         |     :star:      |         :star:          |          :star:          |                       |                         |  Fuzzer  |
|   Moonshine    |        MacOS        |        <font color="#dd0000">syscall traces</font>         |     :star:      |         :star:          |                          |                       |                         |  Fuzzer  |
|     DIFUZE     |   Linux (Android)   |        <font color="#dd0000">device drivers</font>         |                 |                         |          :star:          |                       |                         |          |
|     JANUS      |        Linux        |          <font color="#dd0000">file system</font>          |                 |                         |                          |                       |                         |  Fuzzer  |
|     Krace      |        Linux        |          <font color="#dd0000">file system</font>          |     :star:      |                         |                          |                       |                         | Race Bug |
|      HFL       |        Linux        |        <font color="#dd0000">syscall traces</font>         |     :star:      |         :star:          |          :star:          |        :star:         |         :star:          |  Hybrid  |
|     Kminer     |                     |                                                            |                 |                         |                          |                       |                         |          |
|  Dr. checker   |                     |                                                            |                 |                         |                          |                       |                         |          |
|                |                     |                                                            |                 |                         |                          |                       |                         |          |

#### Reflection

- HFL虽然也进行了static point-to analysis，但HFL在runtime时利用符号执行验证识别true dependency，来修正false positive。
- kernel的子系统分开坐可能会降低难度

|  Category   | Analysis Target | Size (.bc) |                        Syscalls used                         |
| :---------: | :-------------: | :--------: | :----------------------------------------------------------: |
| File System |       fs/       |   75 MB    |               open, read, ioctl, write, lseek                |
|   Network   |      net/       |   255 MB   | socket, accept, bind, listen, ioctl, getsocket, setsocket, <br />sendto, recvfrom, sendmsg, recvmsg |
|   Drivers   |    drivers/     |   322 MB   |                   open, ioctl, write, read                   |

- 其实implicit dependencies的话，不是函数A在函数B前面就可以，他们的参数可能还有依赖关系，可能两个field字端要保持一致，也就是说，参数间的依赖关系，不止存在于explict dependencies例如open和read这种关系，还存在于如下这种情况。

```C++
ioctl(fd, DRM_ALLOC, {*_1});
ioctl(fd, DRM_BIND, {*_2});
// two ioctl have implicit dependency not only on execution order, but also paramter
// _1.ID = _2.ID is required
struct _1 {
    u64 x;
    u32 ID;
    u64 y;
}

struct _2 {
    u32 ID;
    u64 x;
}
```

