---
title: Kernel Coverage Analysis
date: 2022-04-29 14:27:43
tags:
   - Kernel
categories: Techniques
---
#### 1. Clang Santizer Coverage

给定如下程序`test.c`，该程序有三个边：
```
#include <stdio.h>

void foo(int *a) {
    if (a) {
        *a = 0;
    }
}

int main(int argc, char const *argv[]) {
    int a; 

    printf("Please enter one numbers:");
    scanf("%d", &a);

    foo(&a);
    printf("%d\n", a);
    return 0; 
}
```

<!--more-->

该函数有三个basic block，分别为A, B, C， 控制流程图如下所示：

```
A           A
|\          |\  
| \         | \
|  B   ==>  D  B
| /         | /
|/          |/
C           C
```

如果`A, B, C`三个块都被覆盖，那么边`A->B`和`B->C`必定已执行，但不确定边`A->C`是否已经执行，因此LLVM会插入一些无用的block，比如D，来区分这种critical的边，接下来查看插桩后的代码。

利用如下命令编译为`LLVM Bitcode`，`trace-pc`对应edge coverage，`no-prune`表示被认为重复的区块也会被插桩，并查看`LLVM IR`。ash

```
clang-12 test.c -o test.bc -emit-llvm -c -fsanitize-coverage=edge,trace-pc-guard,no-prune
llvm-dis-12 test.bc -o test.ll
```

编译后的`LLVM IR`如下所示，每个edge都有一个唯一的标识，区块5就是被额外插入的区块，没有任何额外的计算，只是用来区别critical的边是否被执行。

```
; Function Attrs: noinline nounwind optnone uwtable
define dso_local void @foo(i32* %0) #0 comdat {
  %2 = alloca i32*, align 8
  call void @__sanitizer_cov_trace_pc_guard(i32* getelementptr inbounds ([4 x i32], [4 x i32]* @__sancov_gen_, i32 0, i32 0)) #2
  store i32* %0, i32** %2, align 8
  %3 = load i32*, i32** %2, align 8
  %4 = icmp ne i32* %3, null
  br i1 %4, label %6, label %5

5:                                                ; preds = %1
  call void @__sanitizer_cov_trace_pc_guard(i32* inttoptr (i64 add (i64 ptrtoint ([4 x i32]* @__sancov_gen_ to i64), i64 4) to i32*)) #2
  br label %8

6:                                                ; preds = %1
  call void @__sanitizer_cov_trace_pc_guard(i32* inttoptr (i64 add (i64 ptrtoint ([4 x i32]* @__sancov_gen_ to i64), i64 8) to i32*)) #2
  %7 = load i32*, i32** %2, align 8
  store i32 0, i32* %7, align 4
  br label %8

8:                                                ; preds = %5, %6
  call void @__sanitizer_cov_trace_pc_guard(i32* inttoptr (i64 add (i64 ptrtoint ([4 x i32]* @__sancov_gen_ to i64), i64 12) to i32*)) #2
  ret void
}
```

若查看块覆盖率，用以下命令编译程序：

```
clang-12 test.c -o test.bc -emit-llvm -c -fsanitize-coverage=bb,trace-pc-guard,no-prune
llvm-dis-12 test.bc -o test.ll
```

插桩后的LLVM代码为，这里就只有三个区块。

```
; Function Attrs: noinline nounwind optnone uwtable
define dso_local void @foo(i32* %0) #0 comdat {
  %2 = alloca i32*, align 8
  call void @__sanitizer_cov_trace_pc_guard(i32* getelementptr inbounds ([3 x i32], [3 x i32]* @__sancov_gen_, i32 0, i32 0)) #2
  store i32* %0, i32** %2, align 8
  %3 = load i32*, i32** %2, align 8
  %4 = icmp ne i32* %3, null
  br i1 %4, label %5, label %7

5:                                                ; preds = %1
  call void @__sanitizer_cov_trace_pc_guard(i32* inttoptr (i64 add (i64 ptrtoint ([3 x i32]* @__sancov_gen_ to i64), i64 4) to i32*)) #2
  %6 = load i32*, i32** %2, align 8
  store i32 0, i32* %6, align 4
  br label %7

7:                                                ; preds = %5, %1
  call void @__sanitizer_cov_trace_pc_guard(i32* inttoptr (i64 add (i64 ptrtoint ([3 x i32]* @__sancov_gen_ to i64), i64 8) to i32*)) #2
  ret void
}
```

LLVM提供了`__sanitizer_cov_trace_pc_guard`的简单实现，如果要使用`__sanitizer_cov_trace_pc`，就需要用户自己定义。若用户不定义该函数，编译会失败：

```
➜  edgeCounter clang -g -fsanitize-coverage=trace-pc test.c
/usr/bin/ld: /tmp/test-75199c.o: in function `foo':
/home/weichen/edgeCounter/test.c:4: undefined reference to `__sanitizer_cov_trace_pc'
/usr/bin/ld: /home/weichen/edgeCounter/test.c:5: undefined reference to `__sanitizer_cov_trace_pc'
/usr/bin/ld: /home/weichen/edgeCounter/test.c:6: undefined reference to `__sanitizer_cov_trace_pc'
/usr/bin/ld: /tmp/test-75199c.o: in function `main':
/home/weichen/edgeCounter/test.c:10: undefined reference to `__sanitizer_cov_trace_pc'
```

定义该函数如下，输出当前PC地址，当前函数和行号：

```
// trace-pc.cpp
#include <stdint.h>
#include <stdio.h>
#include <sanitizer/coverage_interface.h>


extern "C" void __sanitizer_cov_trace_pc() {
    void *PC = __builtin_return_address(0);
    char PcDescr[1024];
    __sanitizer_symbolize_pc(PC, "%p %F %L", PcDescr, sizeof(PcDescr));
    printf("PC: %s\n", PcDescr);
}
```

定义好后，与用户编写的代码一起编译，就可以正常运行，输出相关信息。

```
➜  edgeCounter clang -g -fsanitize-coverage=trace-pc test.c trace-pc-guard.cpp
➜  edgeCounter ./a.out                                                        
PC: 0x429133 in main /home/weichen/edgeCounter/test.c:10
Please enter one numbers:12
PC: 0x4290e0 in foo /home/weichen/edgeCounter/test.c:4
PC: 0x429102 in foo /home/weichen/edgeCounter/test.c:6:10
0
```

Tips: DSO means dynamic shared object.

Reference: [SanitizerCoverage](https://clang.llvm.org/docs/SanitizerCoverage.html)

#### 2. Kernel Kcov

Kcov implement `__sanitizer_cov_trace_pc` for Linux kernel.

```
/*
 * Entry point from instrumented code.
 * This is called once per basic-block/edge.
 */
void notrace __sanitizer_cov_trace_pc(void)
{
    struct task_struct *t;
    unsigned long *area;
    unsigned long ip = canonicalize_ip(_RET_IP_);
    unsigned long pos;

    t = current;
    if (!check_kcov_mode(KCOV_MODE_TRACE_PC, t))
        return;

    area = t->kcov_area;
    /* The first 64-bit word is the number of subsequent PCs. */
    pos = READ_ONCE(area[0]) + 1;
    if (likely(pos < t->kcov_size)) {
        area[pos] = ip;
        WRITE_ONCE(area[0], pos);
    }
}
```

此函数将调用`__sanitizer_cov_trace_pc`时对应的返回地址写入`kcov`模块中，在Fuzzing过程中输出，例如地址`ffffffff849db21e`，查看反汇编代码可知，正好对应`r14 ffffffff849`处调用`__sanitizer_cov_trace_pc`函数的返回地址。

```
➜  linux-5.15 git:(64570fbc14f8) ✗ grep 'ffffffff849db21e' vmlinux.objdump -C 5
ffffffff849db20c:       74 08                   je     ffffffff849db216 <tty_open+0x376>
ffffffff849db20e:       4c 89 f7                mov    %r14,%rdi
ffffffff849db211:       e8 7a b0 36 fd          callq  ffffffff81d46290 <__asan_report_load8_noabort>
ffffffff849db216:       4d 8b 36                mov    (%r14),%r14
ffffffff849db219:       e8 62 26 e8 fc          callq  ffffffff8185d880 <__sanitizer_cov_trace_pc>
ffffffff849db21e:       49 81 fe 00 f0 ff ff    cmp    $0xfffffffffffff000,%r14
ffffffff849db225:       77 77                   ja     ffffffff849db29e <tty_open+0x3fe>
ffffffff849db227:       4d 85 f6                test   %r14,%r14
ffffffff849db22a:       74 72                   je     ffffffff849db29e <tty_open+0x3fe>
ffffffff849db22c:       e8 4f 26 e8 fc          callq  ffffffff8185d880 <__sanitizer_cov_trace_pc>
ffffffff849db231:       49 8d 7e 04             lea    0x4(%r14),%rdi
```

#### 3. Clang 编译内核

1. 编译环境和内核版本

   Clang-12

   Linux 5.15

2. 生成`.config`fig

   ```
   ➜  linux-5.15 git:(64570fbc14f8) ✗ make LLVM=1 V=1 CC=clang defconfig   
   make -f ./scripts/Makefile.build obj=scripts/basic
     clang -Wp,-MMD,scripts/basic/.fixdep.d -Wall -Wmissing-prototypes -Wstrict-prototypes -O2 -fomit-frame-pointer -std=gnu89         -o scripts/basic/fixdep scripts/basic/fixdep.c   
   make -f ./scripts/Makefile.build obj=scripts/kconfig defconfig
     clang -Wp,-MMD,scripts/kconfig/.conf.o.d -Wall -Wmissing-prototypes -Wstrict-prototypes -O2 -fomit-frame-pointer -std=gnu89       -c -o scripts/kconfig/conf.o scripts/kconfig/conf.c
     clang -Wp,-MMD,scripts/kconfig/.confdata.o.d -Wall -Wmissing-prototypes -Wstrict-prototypes -O2 -fomit-frame-pointer -std=gnu89       -c -o scripts/kconfig/confdata.o scripts/kconfig/confdata.c
     clang -Wp,-MMD,scripts/kconfig/.expr.o.d -Wall -Wmissing-prototypes -Wstrict-prototypes -O2 -fomit-frame-pointer -std=gnu89       -c -o scripts/kconfig/expr.o scripts/kconfig/expr.c
     flex -oscripts/kconfig/lexer.lex.c -L scripts/kconfig/lexer.l
     bison -o scripts/kconfig/parser.tab.c --defines=scripts/kconfig/parser.tab.h -t -l scripts/kconfig/parser.y
     clang -Wp,-MMD,scripts/kconfig/.lexer.lex.o.d -Wall -Wmissing-prototypes -Wstrict-prototypes -O2 -fomit-frame-pointer -std=gnu89      -I ./scripts/kconfig -c -o scripts/kconfig/lexer.lex.o scripts/kconfig/lexer.lex.c
     clang -Wp,-MMD,scripts/kconfig/.menu.o.d -Wall -Wmissing-prototypes -Wstrict-prototypes -O2 -fomit-frame-pointer -std=gnu89       -c -o scripts/kconfig/menu.o scripts/kconfig/menu.c
     clang -Wp,-MMD,scripts/kconfig/.parser.tab.o.d -Wall -Wmissing-prototypes -Wstrict-prototypes -O2 -fomit-frame-pointer -std=gnu89      -I ./scripts/kconfig -c -o scripts/kconfig/parser.tab.o scripts/kconfig/parser.tab.c
     clang -Wp,-MMD,scripts/kconfig/.preprocess.o.d -Wall -Wmissing-prototypes -Wstrict-prototypes -O2 -fomit-frame-pointer -std=gnu89       -c -o scripts/kconfig/preprocess.o scripts/kconfig/preprocess.c
     clang -Wp,-MMD,scripts/kconfig/.symbol.o.d -Wall -Wmissing-prototypes -Wstrict-prototypes -O2 -fomit-frame-pointer -std=gnu89       -c -o scripts/kconfig/symbol.o scripts/kconfig/symbol.c
     clang -Wp,-MMD,scripts/kconfig/.util.o.d -Wall -Wmissing-prototypes -Wstrict-prototypes -O2 -fomit-frame-pointer -std=gnu89       -c -o scripts/kconfig/util.o scripts/kconfig/util.c
     clang   -o scripts/kconfig/conf scripts/kconfig/conf.o scripts/kconfig/confdata.o scripts/kconfig/expr.o scripts/kconfig/lexer.lex.o scripts/kconfig/menu.o scripts/kconfig/parser.tab.o scripts/kconfig/preprocess.o scripts/kconfig/symbol.o scripts/kconfig/util.o   
   scripts/kconfig/conf  --defconfig=arch/x86/configs/x86_64_defconfig Kconfig
   #
   # configuration written to .config
   #
   ```

3. 根据Fuzzing的需要，修改`.config`，这里使用Syzkaller准备好的`.config`

   ```
   cp ~/syzkaller/dashboard/config/linux/upstream-apparmor-kasan.config .config
   ```

4. 上述`.config`是针对gcc的，所以要再运行如下命令，转换为clang的相应编译选项

   ```
   ➜  linux-5.15 git:(64570fbc14f8) ✗ make LLVM=1 V=1 CC=clang olddefconfig
   make -f ./scripts/Makefile.build obj=scripts/basic
   make -f ./scripts/Makefile.build obj=scripts/kconfig olddefconfig
   scripts/kconfig/conf  --olddefconfig Kconfig
   #
   # configuration written to .config
   #
   ```

5. 需要取消选项`CONFIG_UBSAN_OBJECT_SIZE`，否则Fuzzing的时候会一直报错。

   ```
   CONFIG_UBSAN_OBJECT_SIZE=n
   ```

6. 再去运行`olddefconfig`进行调整

   ```
   # CONFIG_UBSAN_OBJECT_SIZE is not set
   ```

7. 编译内核，生成`arch/x86/boot/bzImage`用于Fuzzing，切记保留`vmlinux`，便于查看汇编程序。

   ```
   make LLVM=1 V=1 CC=clang -j64
   ```

   运行如下命令，反汇编`vmlinux`

   ```
   objdump -d vmlinux > vmlinux.objdump
   ```

   由于clang编译内核时默认是以边代码覆盖率为插入目标，因此可以通过如下方式粗略的查看一些内核整体有265w个边。

   ```
   linux-5.15 git:(64570fbc14f8) ✗ grep 'callq  ffffffff8185d880 <__sanitizer_cov_trace_pc>' vmlinux.objdump  | wc -l
   2653206
   ```

8. 内核编译举例

   ```
   clang 
   -Wp,-MMD,arch/x86/kvm/../../../virt/kvm/.kvm_main.o.d  
   -nostdinc -isystem /usr/local/lib/clang/12.0.0/include 
   -I./arch/x86/include -I./arch/x86/include/generated  
   -I./include -I./arch/x86/include/uapi -I./arch/x86/include/generated/uapi 
   -I./include/uapi -I./include/generated/uapi 
   -include ./include/linux/compiler-version.h -include ./include/linux/kconfig.h 
   -include ./include/linux/compiler_types.h 
   -D__KERNEL__ -Qunused-arguments 
   -fmacro-prefix-map=./= -Wall -Wundef -Werror=strict-prototypes -Wno-trigraphs 
   -fno-strict-aliasing -fno-common -fshort-wchar -fno-PIE 
   -Werror=implicit-function-declaration -Werror=implicit-int -Werror=return-type -Wno-format-security 
   -std=gnu89 --target=x86_64-linux-gnu -fintegrated-as 
   -Werror=unknown-warning-option -Werror=ignored-optimization-argument 
   -mno-sse -mno-mmx -mno-sse2 -mno-3dnow -mno-avx 
   -fcf-protection=none -m64 -mno-80387 -mstack-alignment=8 
   -march=core2 -mno-red-zone -mcmodel=kernel 
   -DCONFIG_X86_X32_ABI -Wno-sign-compare 
   -fno-asynchronous-unwind-tables -fno-delete-null-pointer-checks 
   -Wno-frame-address -Wno-address-of-packed-member -O2 
   -Wframe-larger-than=2048 -fstack-protector-strong 
   -Wno-gnu -mno-global-merge -Wno-unused-const-variable 
   -fomit-frame-pointer -fno-stack-clash-protection -g 
   -Wdeclaration-after-statement -Wvla -Wno-pointer-sign 
   -Wno-array-bounds -fno-strict-overflow -fno-stack-check 
   -Werror=date-time -Werror=incompatible-pointer-types 
   -Wno-initializer-overrides -Wno-format -Wno-sign-compare 
   -Wno-format-zero-length -Wno-pointer-to-enum-cast 
   -Wno-tautological-constant-out-of-range-compare 
   -I ./arch/x86/kvm    
   -fsanitize=kernel-address -mllvm -asan-mapping-offset=0xdffffc0000000000  
   -mllvm -asan-globals=1  -mllvm -asan-instrumentation-with-call-threshold=10000   
   --param asan-instrument-allocas=1  -mllvm -asan-stack=1  
   -fsanitize=array-bounds -fsanitize=shift  
   -fsanitize-coverage=trace-pc -fsanitize-coverage=no-prune 
   -fsanitize-coverage=trace-cmp    
   -DKBUILD_MODFILE='"arch/x86/kvm/kvm"' 
   -DKBUILD_BASENAME='"kvm_main"' 
   -DKBUILD_MODNAME='"kvm"' 
   -D__KBUILD_MODNAME=kmod_kvm 
   -c -o arch/x86/kvm/../../../virt/kvm/kvm_main.o 
   arch/x86/kvm/../../../virt/kvm/kvm_main.c
   ```

#### 4. 生成内核Bitcode

1. 环境配置

2. 运行如下命令，进行命令替换，生成针对整个内核的bitcode编译脚本

   ```
   go run /home/weichen/Build_Linux_Kernel_Into_LLVM_Bitcode/02-replace_cmd_log/buildLLVMBitcode.go
   ```

   仍以`kvm_main.c`为例，修改后的编译命令如下

   ```
   clang 
    -Wp,-MMD,arch/x86/kvm/../../../virt/kvm/.kvm_main.o.d  
    -nostdinc -isystem /usr/local/lib/clang/12.0.0/include 
    -I./arch/x86/include -I./arch/x86/include/generated  
    -I./include -I./arch/x86/include/uapi -I./arch/x86/include/generated/uapi 
    -I./include/uapi -I./include/generated/uapi 
    -include ./include/linux/compiler-version.h -include ./include/linux/kconfig.h 
    -include ./include/linux/compiler_types.h 
    -D__KERNEL__ -Qunused-arguments 
    -fmacro-prefix-map=./= -Wall -Wundef -Werror=strict-prototypes -Wno-trigraphs 
    -fno-strict-aliasing -fno-common -fshort-wchar -fno-PIE 
    -Werror=implicit-function-declaration -Werror=implicit-int -Werror=return-type -Wno-format-security 
    -std=gnu89 --target=x86_64-linux-gnu -fintegrated-as 
    -Werror=unknown-warning-option -Werror=ignored-optimization-argument 
    -mno-sse -mno-mmx -mno-sse2 -mno-3dnow -mno-avx 
    -fcf-protection=none -m64 -mno-80387 -mstack-alignment=8 
    -march=core2 -mno-red-zone -mcmodel=kernel 
    -DCONFIG_X86_X32_ABI -Wno-sign-compare 
    -fno-asynchronous-unwind-tables -fno-delete-null-pointer-checks 
    -Wno-frame-address -Wno-address-of-packed-member -O2 
    -Wframe-larger-than=2048 -fstack-protector-strong 
    -Wno-gnu -mno-global-merge -Wno-unused-const-variable 
    -fomit-frame-pointer -fno-stack-clash-protection -g 
    -Wdeclaration-after-statement -Wvla -Wno-pointer-sign 
    -Wno-array-bounds -fno-strict-overflow -fno-stack-check 
    -Werror=date-time -Werror=incompatible-pointer-types 
    -Wno-initializer-overrides -Wno-format -Wno-sign-compare 
    -Wno-format-zero-length -Wno-pointer-to-enum-cast 
    -Wno-tautological-constant-out-of-range-compare 
    -I ./arch/x86/kvm    
    -fsanitize=kernel-address -mllvm -asan-mapping-offset=0xdffffc0000000000  
    -mllvm -asan-globals=1  -mllvm -asan-instrumentation-with-call-threshold=10000   
    --param asan-instrument-allocas=1  -mllvm -asan-stack=1  
    -fsanitize=array-bounds -fsanitize=shift  
    -fsanitize-coverage=trace-pc -fsanitize-coverage=no-prune 
    -fsanitize-coverage=trace-cmp    
    -DKBUILD_MODFILE='"arch/x86/kvm/kvm"' 
    -DKBUILD_BASENAME='"kvm_main"' 
    -DKBUILD_MODNAME='"kvm"' 
    -D__KBUILD_MODNAME=kmod_kvm 
    -w -g -fno-discard-value-names -emit-llvm 
    -c -o arch/x86/kvm/../../../virt/kvm/kvm_main.bc 
    arch/x86/kvm/../../../virt/kvm/kvm_main.c
   ```

   主要是加上了如下这行命令

   ```
   -w -g -fno-discard-value-names -emit-llvm 
   ```

3. 运行生成的脚本，会对每一个`.c`文件生成相应的`.bc`文件，并按照内核结构按模块链接为`built-in.bc`，其中需要注意如下两个`.bc`文件不能被链接进根目录的`built-in.bc`，否则会报错。

   ```
   kernel/built-in.bc
   mm/kasan/built-in.bc 
   ```

Github link: https://github.com/harperchen/Build_Linux_Kernel_Into_LLVM_Bitcode.git

#### 5. 内核结构分析

##### 5.1 内核模块分析

1. 编译时有个字段为`-DKBUILD_MODNAME='"kvm"'`，可以先简单的看一下有多少个`MODNAME`。

   ```
   ➜  linux-5.15 git:(64570fbc14f8) ✗ grep -oE  '\-DKBUILD_MODNAME=.*\"' build.sh | sort -u | wc -l
   3163
   ```

2. 根据链接的顺序寻找模块

   - Core
     - ipc `ipc/built-in.bc`
     - mm
       - mm/built-in.bc
       - arch/x86/mm/built-in.bc
     - certs `certs/built-in.bc`
     - security `security/built-in.bc`
       - security/keys
       - security/tomoyo
       - security/apparmor
       - security/landlock
       - security/integrity
     - lib
       - arch/x86/lib/built-in.bc
       - arch/x86/lib/lib.bc
       - lib/built-in.bc
       - lib/lib.bc
       - virt/lib/irqbypass.bc
     - crypto `arch/x86/crypto/built-in.bc`
   - Driver
     - kvm: arch/x86/kvm/built-in.bc
     - 
   - Network
   - FileSystem

3. 但不是所有的module都有对应的syzkaller写的模板，所以还要找一下有哪些系统调用对应。
