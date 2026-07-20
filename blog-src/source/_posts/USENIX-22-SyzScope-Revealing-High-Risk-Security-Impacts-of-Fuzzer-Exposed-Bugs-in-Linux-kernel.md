---
title: >-
  [USENIX'22] SyzScope: Revealing High-Risk Security Impacts of Fuzzer-Exposed
  Bugs in Linux kernel
date: 2022-05-20 16:14:07
tags: 
  - Static Analysis
  - Kernel
categories: Papers
---
#### Key: uncover new high-risk impacts given a bug with seemingly low-risk impacts

#### Abstract

Fuzzing has become one of the most effective bug finding approach for software. In recent years, 24*7 continuous fuzzing platforms have emerged to test critical pieces of software, e.g., Linux kernel. Though capable of discovering many bugs and providing reproducers (e.g., proof-of-concepts), a major problem is that they neglect a critical function that should have been built-in, i.e., evaluation of a bug’s security impact. It is well-known that the lack of understanding of security impact can lead to delayed bug fixes as well as patch propagation. In this paper, we develop SyzScope, a system that can automatically uncover new “high-risk” impacts given a bug with seemingly “low-risk” impacts. From analyzing over a thousand low-risk bugs on syzbot, SyzScope successfully determined that 183 low-risk bugs (more than 15%) in fact contain high-risk impacts, e.g., control flow hijack and arbitrary memory write, some of which still do not have patches available yet.

<!--more-->

#### 1. 定义什么是 High/Low risk

##### High risk bugs

1. UAF and heap OOB bugs that lead to function pointer deference => control flow hijacking, arbitrary code execution
2. UAF and OOB bugs that lead to write => corrupt data, privilege escalation
3. Invalid free

##### Low risk bugs

1. UAF or OOB bugs that lead to read
2. WARNING, INFO, BUG, and GPF

#### 2. Low risk 变为 High risk 的例子

1. Syzkaller stopped at line 8 due to slab-out-of-bounds of `exts->action`
2. OOB results from line 2: `cp->hash` can be larger than the size of array `cp->perfect`
3. If line 8 is successfully executed, invalid address access `action[i]` at line 14 (low-risk bug).
4. If `action[i]` is a valid address, there is arbitrary address write at line 16.
5. If line 16 is executed, `action[i]` is passed to `tcf_action_cleanup` and causes a function pointer dereference at line 36 (high-risk bug).

```
static void tcindex_free_perfect_hash(struct tcindex_data *cp) {
    for (int i = 0; i < cp->hash; i++) // cp->hash can be larger
        tcf_exts_destroy(&cp->perfect[i].exts);
    kfree(cp->perfect);
}

void tcf_exts_destroy(struct tcf_exts *exts) {
    if (exts->actions) // slab-out-of-bounds read
        tcf_action_destroy(exts->actions);
}

int tcf_action_destroy(struct tc_action *actions[]) {
    struct tc_action *a;
    for (i = 0; i < TCA_ACT_MAX_PRIO && actions[i]; i++) {
        a = actions[i];
        actions[i] = NULL; // Arbitrary address write
        ret = __tcf_idr_release(a);
    }
}

int __tcf_idr_release(struct tc_action *p) {
    if (__tcf_action_put(p, ...))
        ...
}

static int __tcf_action_put(struct tc_action *p, ...) {
    struct tcf_idrinfo *idrinfo = p->idrinfo;
    if (refcount_dec_and_mutex_lock(&p->tcfa_refcnt, &idrinfo->lock)) {
       ...
       tcf_action_cleanup(p); 
    }
}

static void tcf_action_cleanup(struct tc_action *p) {
    if (p->ops->cleanup)
        p->ops->cleanup(p); // Function pointer dereference
}
```

#### 3. 一些实验数据

The rate of bug discovery is much higher than the rate of bug fixes

- 51 days on average to fix a bug
- < 0.4 day to report a bug

Write bugs are often fixed sooner than read bugs

- Write vs. read for UAF: 37 days vs. 63 days
- Write vs. read for OOB: 29 days vs. 89 days

Patch propogation delays from upstream to downstream

- 59 days for OOB write bugs
- 83 days for WARNING errors

#### 4. 总结出来现有工作的问题

Syzbot neglect the evaluation of a bug’s security impact / automated bug triage.

- delayed bug fixes
- delayed patch propagation

#### 5. 提出来对应的解决方案

1. Prioritize opened bugs
   - static analysis - hidden impact estimation
   - symbolic execution - validation and evaluation
2. Analyze the impact of fixed bug
   - fuzzing component - vulnerable context exploration
3. 输入：一个bug的PoC和report
4. 工作流程：
   1. targeted fuzzing 找到更多跟这个bug有关的PoC
      1. 两种可能性：同一序列后面的路径 or 完全由不同的序列触发
      2. 方法：mutate给定的PoC
      3. 挑战
         1. 已触发的bug影响后续路径的探索
         2. 已经探索的路径也有机会触发bug
         3. 新的impact应该也来源于原来的bug
      4. 解决方案
         1. 问题触发了还继续执行
         2. 引来coverage的新的维度 impact aware fuzzing
         3. 限制Fuzzing可选的系统调用
            1. 只使用PoC中出现的系统调用
            2. 若1无效果，使用整个模块的系统调用
            3. 也允许删除PoC中的系统调用
      5. 还是有可能出现毫不相关的bug：利用已有的patch验证
         1. 如果仍然发生，则是不同的bug
         2. 如果不再发生了，则可能是之前的commit把他修复了，所以直接在当前commit应用patch
         3. 如果应用成功且不触发，就说明还是这个bug
         4. 如果无法应用，则在patch前的commit测试PoC，如果还可以崩溃，则说明是是同一个bug
         5. 如果应用后不崩溃了，则放弃这个PoC
   2. 静态分析看找到的低风险PoC是否有可能隐藏高风险
      1. 从报告提取信息 IR and binary mapping
         1. vulnerable object: 触发bug的对象
         2. vulnerability point: 触发bug的语句
      2. 对触发bug的对象做静态染色分析
         1. taint source: 触发bug的对象
         2. taint sink
            1. 指针解引用（函数指针 or 数据指针）
            2. 对tainted的内存区域进行写操作
      3. 记录高风险触发所需的分支，指导符号执行
      4. 实现：Dr. Checker
   3. 通过符号执行看隐藏的高风险是否可达
      1. 符号化触发bug的对象检验隐藏的高风险是否可达
         1. 利用静态分析记录的分支，避免路径爆炸
         2. 在最远的impact处结束分析
      2. 细粒度的分析high-risk impact
         1. 覆盖符号化的内存区域：UAF write or OOB write
         2. 任意值写/任意地址写
         3. 函数指针解引用
         4. double free or invalid free
         5. 实现：Angr

#### 6. 一些有关的工作

##### Infer the security impact of a patch statically （对比）

[NDSS’20] Precisely characterizing security impact in a flood of patches via symbolic rule comparison.

1. Static analysis has to make tradeoffs between soundness and completeness
2. Static analysis cannot determine whether the bug is actually triggerable and exploitable in reality

##### Automated exploit generation （互补）

[Security’18] FUZE: towards facilitating exploit generation for kernel use-after-free vulnerabilities

[Security’20] KOOBE: towards facilitating exploit generation of kernel out-of-bounds write vulnerabilities

1. UAF and OOB also exist distinction between high-risk and low-risk impacts
2. Write primitive is more dangerous than read primitive

#### 7. 问题出现的原因

1. Syzkaller stops the execution of buggy input as soon as any bug impact is discovered
2. Syzkaller的目的是最大化代码覆盖率和发现更多的bug

#### 8. Evaluation

183 out of 1170 low-risk bugs in fact contain high-risk impacts

- 42: control flow hijack
- 173: arbitraty memory write

1. 各项数据
2. 各组件的有效性
3. 误报和漏报
4. Case Study
