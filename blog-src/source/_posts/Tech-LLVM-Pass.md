---
title: LLVM Pass
date: 2021-01-08 21:09:24
tags:
    - Compiler
    - LLVM
categories: Techniques
---
### 1. 查看LLVM IR

使用LLVM的编译流程：源码 -> AST -> LLVM IR (`.ll`)-> LLVM Bitcode (`.bc`) -> ASM -> Native

- `llvm-as`：把LLVM IR从人类能看懂的文本格式汇编成二进制格式。注意：此处得到的**不是**目标平台的机器码。
- `llvm-dis`：`llvm-as`的逆过程，即反汇编。 不过这里的反汇编的对象是LLVM IR的二进制格式，而不是机器码。
- `opt`：优化LLVM IR。输出新的LLVM IR。
- `llc`：把LLVM IR编译成汇编码。需要用`as`进一步得到机器码。
- `lli`：解释执行LLVM IR

<!--more-->

LLVM编译过程的举例 https://www.jianshu.com/p/ccd467ff5209

<img src="https://i.loli.net/2021/01/12/bSe35pXlxgEafwC.png" alt="image-20210112131915095" style="zoom:47%;" />

1) .c -> AST

```bash
clang -Xclang -ast-dump -fsyntax-only test.cpp
```

<img src="https://i.loli.net/2021/01/11/nSwWy7EOp4ZF82P.png" alt="image-20210110151724272" style="zoom: 67%;" />

or

```bash
clang++ -Xclang -ast-view test.cpp # require the llvm to be compiled in Debug mode
```

<img src="https://i.loli.net/2021/01/10/4q7FotgY5MdRAN6.png" alt="image-20210110180350012" style="zoom:57%;" />

2) .c -> LLVM IR (.ll)

```bash
clang++ -S -emit-llvm test.cpp
```

A sample of LLVM IR

```bash
$ cat test.ll
define i32 @mult(i32 %a, i32 %b) #0 {
  %1 = mul nsw i32 %a, %b
  ret i32 %1
}
```

or generate LLVM IR from bitcode

```bash
llvm-dis test.bc # test.ll
```

3) LLVM -> bitcode

```bash
llvm-as test.ll # test.bc
clang -c -emit-llvm test.cpp
```

The output is generated in the `test.bc` file, which is in bit stream format;

4) bitcode -> ASM

```bash
llc test.bc -o test.s
llc test.ll -o test.s
```

The output is generated in test.S file, which is the assembly code.

```x86asm
	.text
	.file	"test.cpp"
	.globl	main                            # -- Begin function main
	.p2align	4, 0x90
	.type	main,@function
main:                                   # @main
	.cfi_startproc
# %bb.0:
	pushq	%rbp
	.cfi_def_cfa_offset 16
	.cfi_offset %rbp, -16
	movq	%rsp, %rbp
	.cfi_def_cfa_register %rbp
	subq	$32, %rsp
	...
```

or use clang to dump assembly code from the bitcode file format

```bash
clang -S test.bc -o test.s
clang++ -S test.cpp -o test.s 
```

5) ASM -> binary

```bash
clang++ test.s -o test.o
clang++ test.bc -o test.o
```

### 2. LLVM IR语法

官方文档  https://llvm.org/docs/LangRef.html

官方ppt https://llvm.org/devmtg/2019-04/slides/Tutorial-Bridgers-LLVM_IR_tutorial.pdf

LLVM IR 在线平台 https://godbolt.org/

知乎链接 LLVM IR Tour 上 https://zhuanlan.zhihu.com/p/66793637

知乎链接 LLVM IR Tour 下 https://zhuanlan.zhihu.com/p/66909226

<img src="https://i.loli.net/2021/01/12/fO1rKVMFdHAp8xW.png" alt="image-20210112132036280" style="zoom:47%;" />

#### 2.1 Module 

Module 可以被视为一个.c文件的 IR 表示，如果用Java的描述的话， Module相当于Java里的类，是独立存在的一个东西。

每个 Module都是相对独立的东西，主要包含了声明或者定义的函数、声明或定义的全局变量、当前 Module的基本信息，因为在开发 Pass的过程中，基本打交道的就是 Function 和 GlobalVariable 这两个东西。

多个 Module之间是相互隔离的、无法获取对方的内容。平时为了获取 Module 的主要信息，使用它的 M.dump() 方法就会在屏幕上打印出全部信息。LLVM  IR 文件的开头是

```bash
; ModuleID = 'test.cpp'
source_filename = "test.cpp"
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"
```

`;`后面的注释指明了module的标识，`source_filename`是表明这个module是从什么文件编译得到的，如果该modules是通过链接得到的，这里的值就会是`llvm-link`。后面的`target datalayout`和`targe triple`用来描述target的信息，包括大小端等。

接下来是字符串`@.str`的定义，llvm中的标识符分为两种类型：全局的和局部的。全局的标识符包括函数名和全局变量，会加一个`@`前缀，全局变量永远是指针，局部的标识符会加一个`%`前缀。一般地，可用标识符对应的正则表达式为`[%@][-a-zA-Z$._][-a-zA-Z$._0-9]*`。

```x86asm
@.str = private unnamed_addr constant [4 x i8] c"xx\0A\00", align 1
```

然后是各函数的声明和定义，最后是一些其他相关信息，例如在文件的下面有attribute group的信息，因为attribute group可能很包含很多attribute且复用到多个函数，所以用attribute group ID(即`#0`)的形式指明函数的attribute。

```bash
attributes #0 = { noinline norecurse optnone uwtable "correctly-rounded-divide-sqrt-fp-math"="false" "disable-tail-calls"="false" "frame-pointer"="all" "less-precise-fpmad"="false" "min-legal-vector-width"="0" "no-infs-fp-math"="false" "no-jump-tables"="false" "no-nans-fp-math"="false" "no-signed-zeros-fp-math"="false" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "unsafe-fp-math"="false" "use-soft-float"="false" }
```

#### 2.2 Function 

Function 是 Module中以List的方式存放的，如果用Java的描述的话， Function相当于Java里的Method，无法单独存在，必须是在某个 Module里的。主要包含了大量 BasicBlock 、参数和返回值类型、可变参数列表、函数的attribute和其他函数的基本信息（例如函数名、所在 Module等）

Function由无数个 BasicBlock组成，使用列表存放，有且仅有一个 EntryBlock ，是列表中的第一个 BasicBlock，代码真正执行的时候，就从 EntryBlock开始执行。因为函数不一定只有一个出口，所以 Function是无法知道它退出时的Block的，没有这个API，如果非要知道的话可以手动去判断每个 BasicBlock是否有后继。

Function有两个很实用的函数， F.dump() 可以打印出全部信息， F.viewCfg() 可以将ControlFlowGraph按照dot的方式存到文件里。

函数main的定义如下，`dso_local`是一个Runtime Preemption说明符，表明该函数会在同一个链接单元（即该函数所在的文件以及包含的头文件）内解析符号。

```x86asm
define dso_local i32 @main(i32 %0, i8** %1) #0 {
  %3 = alloca i32, align 4
  %4 = alloca i32, align 4
  %5 = alloca i8**, align 8
  %6 = alloca i32*, align 8
  store i32 0, i32* %3, align 4
  store i32 %0, i32* %4, align 4
  store i8** %1, i8*** %5, align 8
  %7 = call noalias nonnull i8* @_Znam(i64 40) #3
  %8 = bitcast i8* %7 to i32*
  store i32* %8, i32** %6, align 8
  %9 = load i32*, i32** %6, align 8
  %10 = getelementptr inbounds i32, i32* %9, i64 5
  store i32 0, i32* %10, align 4
  %11 = load i32*, i32** %6, align 8
  %12 = load i32, i32* %4, align 4
  %13 = sext i32 %12 to i64
  %14 = getelementptr inbounds i32, i32* %11, i64 %13
  %15 = load i32, i32* %14, align 4
  %16 = icmp ne i32 %15, 0
  br i1 %16, label %17, label %19

17:                                               ; preds = %2
  %18 = call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([4 x i8], [4 x i8]* @.str, i64 0, i64 0))
  br label %19

19:                                               ; preds = %17, %2
  ret i32 0
}
```

在一对花括号里的就是函数体，函数体是由一系列basic blocks(BB)组成的，这些BB形成了函数的控制流图(Control Flow Graph, CFG)，该函数的含义如下所示：

- 1: %0 是argc, %1是argv
- 2-3: %3 %4 是i32
- 4-5: %5 是i8\*\** %6是i32*\*
- 6-8: *(%3)=0；\*(%4)=%0； \*(%5)=%1
- 9-10: %8=(int *) new int[10]
- 11: *(%6)=%8*
- 12-14: %10=%8+5；*(%10)=0；a[5]=0
- 15-19:  %11=%8；%12=argc；%15=a[argc] 
- 20-21: if %15 != 0: br %17 else %19

LLVM的IR是一个强类型语言，每一条指令都显式地指出了实参的类型，例如`mul nsw i32 %call, 7`表明要将两个`i32`的数值相乘，`icmp eq i32 %mul, 42`表明要将两个i32的数据类型进行相等比较（这里`%mul`是一个变量，而`mul`是一条指令，可以看出IR加前缀的好处）。此外，我们还很容易推断出返回值的类型，比如`i32`的数相乘的返回值就是`i32`类型，比较两个数值的相等关系的返回值就是`i1`类型。

可以使用如下命令生成控制流程图。

```bash
opt -analyze -dot-cfg-only test.cpp
opt -analyze -dot-cfg test.cpp
```

<img src="https://i.loli.net/2021/01/10/icTWFOy1l7Q9Emb.png" alt="image-20210110194638257" style="zoom: 67%;" />

#### 2.3 Baisc Block

BasicBlock，是 Function 中以List方式存放的，和Soot里的 BasicBlock概念很像，无法单独存在，必须是在某个Function里的，是真正存放可执行代码的容器。主要包含了大量的 Instruction ，前驱、后继的 BasicBlock，以及一些基本信息（例如名字什么的），相比 Function ，它的校验也更加严格，例如不可以凭空出现、不可以处于游离状态。

BasicBlock由很多 Instruction组成，按照是否为 TerminatorInst 可以将指令分为两类，一类是普通的指令，一类是可以成为 TerminatorInst 的指令；因此 BasicBlock一定要以 TerminatorInst类的指令结尾，而且除了最后一个指令是 TerminatorInst，其他指令都是普通指令。常见的 TerminatorInst 有 BranchInst 、 IndirectBrInst 、 SwitchInst 和 Return ，C++里还有一些异常处理：（call不算terminator）

- Branch: br
- Return: rt
- Switch: switch
- Unreachable: unreachable
- Exception handling instructions

<img src="https://i.loli.net/2021/01/12/plSRyaQiH3MqIuV.png" alt="image-20210112144417317" style="zoom:45%;" />

每个 BasicBlock都可以视为一段顺序执行的代码，完全不会有任何的分支，有分支就会通过 TerminatorInst进行跳转。

BasicBlock 有两种创建方式，一种是凭空创建，然后插入到之前的CFG里；一种比较方便，使用 SplitBasicBlock ，切为相连的两块，可能会遇到PhiNode的问题。

#### 2.4 Instruction

Instruction ，是 BasicBlock 中以List方式存放的，和Soot里的Stmt的概念很像，无法单独存在，必须是在某个 BasicBlock 里的，可以视为 IR 层面的汇编语句，或者说指令。类型非常多。

##### 2.4.1 简单数组

```x86asm
@array = global [17 x i8] zeroinitializer      

constant size: 17
element type: i8
initializer: zeroinitializer

<result> = getelementptr <ty>, <ty>* <ptrval>, [i32 <idx>]
%new_ptr = getelementptr i32, i32* %base, i32 0
# idx offsets by the base type
# idx NOT change the pointer type
```

##### 2.4.2 复杂数组

<img src="https://i.loli.net/2021/01/12/YpbfTmGwciHNEk6.png" alt="image-20210112160447352" style="zoom:25%;" />

<img src="https://i.loli.net/2021/01/16/H57i1kxS4QaYhZy.png" alt="image-20210112160638986" style="zoom:25%;" />

###### 2.4.3 结构体

```x86asm
%MyStruct = type { i8, i32, [3 x i32]}
```

<img src="https://i.loli.net/2021/01/16/JrHu61kifZCNsmO.png" alt="image-20210112160859746" style="zoom:25%;" />



```C++
// @COUNTER_SCBranchInfotest = global [2 x { i64, [3 x i64] }] zeroinitializer
// Create the component types of the table
auto* int64Ty    = Type::getInt64Ty(context); // i64
auto* int64ArrTy = ArrayType::get(int64Ty, 3); // 3 x i64

auto* structTy   = StructType::get(context, {int64Ty, int64ArrTy}, false); // {i64, [3 x i64]}
auto* tableTy    = ArrayType::get(structTy, 2); // [2 x {i64, [3 x i64]}]
ArrayRef<uint64_t> COUNT = {0, 0, 0};
auto* COUNTs = ConstantDataArray::get(context, COUNT); // {0, 0, 0} to initialize the array
auto* ID = ConstantInt::get(int64Ty, 0, false); // 0

// Compute and store an externally visible array of branch information.
std::vector<Constant*> values;
std::transform(
    toCount.begin(),
    toCount.end(),
    std::back_inserter(values),
    [ID, COUNTs, structTy, str](Instruction* Inst) {
        Constant* structFields[] = {ID, COUNTs};
        return ConstantStruct::get(structTy, structFields);
    }); // two structs  2 x {i64, [3 x i64]} zeroinitializer
auto* BranchTable = ConstantArray::get(tableTy, values); // a table [2 x { i64, [3 x i64] }] zeroinitializer
new GlobalVariable(m,
                   tableTy,
                   false,
                   GlobalValue::ExternalLinkage,
                   BranchTable,
                   "COUNTER_"+str);
```

#### 2.5 Operand

Operand是 Instruction里的各个参数（如果有的话）。每个 Operand 都是 Value ，就是任意的东西， Function可以作为某些指令的参数、 BasicBlock也可以作为某些指令的参数、甚至 Instruction本身也可以作为某些指令的参数。

在IR中，每个变量都在使用前都必须先定义，且每个变量只能被赋值一次，所以我们称IR是静态单一赋值的。此时在循环中，就有可能会破坏这个规则，一个变量被赋值很多次。例如针对下述循环：

```c++
int compiler_factorial(int val) {
  int temp = 1;
  for (int i = 2; i <= val; ++i)
    temp *= i;
  return temp;
}
```

理论上是觉得可以按照如下LLVM IR的写法：

```x86asm
define i32 @factoriali(i32 %val) {
entry:
  %i = add i32 0, 2
  %temp = add i32 0, 1
  br label %check_for_condition
check_for_condition:                                           
  %i_leq_val = icmp sle i32 %i, %val
  br i1 %i_leq_val, label %for_body, label %end_loop

for_body:                                               
  %temp = mul i32 %temp, %i
  %i = add i32 %i, 1
  br label %check_for_condition
  
end_loop:
  ret i32 %temp
}
```

但实际上`%temp`和`%i`被赋值了很多次，此时需要`phi`语句，该语句从上一个执行的basic block中选择变量的值。

```x86asm
<result> = phi <ty> [<val0>, <label0>], [<val1>, <label1>] ...
```

```x86asm
define i32 @factoriali(i32 %val) {
entry:
  br label %check_for_condition
check_for_condition:                                           
  %current_i = phi i32 [ 2, %entry ], [ %i_plus_one, %for_body ]
  %temp      = phi i32 [ 1, %entry ], [ %new_temp, %for_body ]
  %i_leq_val = icmp sle i32 %current_i, %val
  br i1 %i_leq_val, label %for_body, label %end_loop

for_body:                                               
  %new_temp = mul nsw i32 %temp, %current_i
  %i_plus_one = add i32 %current_i, 1
  br label %check_for_condition
  
end_loop:
  ret i32 %temp
}
```

### 3. Mac配置LLVM 

https://www.ctolib.com/topics-118972.html

https://www.jianshu.com/p/b48c1b482c82

https://blog.51cto.com/6095891/2348778

#### 3.1 Xcode编译LLVM Project

下载[LLVM](https://github.com/llvm/llvm-project/releases/download/llvmorg-11.0.0/llvm-11.0.0.src.tar.xz)和[Clang](https://github.com/llvm/llvm-project/releases/download/llvmorg-11.0.0/clang-11.0.0.src.tar.xz)并解压，将Clang目录放置到llvm/tools目录下，llvm-10.0.0无法编译通过，选择llvm-11.0.0。

```bash
tar -xzvf llvm-11.0.0.src.tar.xz
tar -xzvf clang-11.0.0.src.tar.xz
```

从官网下载[.dmg](https://github.com/Kitware/CMake/releases/download/v3.19.2/cmake-3.19.2-macos-universal.dmg)文件，安装cmake，配置环境变量。

```bash
$> which cmake
/Applications/CMake.app/Contents/bin/cmake
```

进入llvm目录，新建build目录，进入build目录执行cmake生成配置文件。

```bash
mkdir build
cd build
cmake -G Xcode CMAKE_BUILD_TYPE="Debug" ..
```

点击build目录下的LLVM.xcodeproj工程文件，提示是否自动创建schemes，点击manually manage schemes手动创建，并添加ALL_BUILD，如下图。

<img src="https://i.loli.net/2021/01/09/Y5XfyPxaQGcSgEu.png" alt="开发和调试第一个 LLVM Pass" style="zoom: 45%;" />

在Xcode中编译llvm，全程约半个小时。

![image-20210109165627072](https://i.loli.net/2021/01/09/ztK5RETxmkU71w4.png)

Tips: [macOS使用源码build的clang无法编译c/cpp的问题: fatal error: 'stdio.h' file not found](https://www.cnblogs.com/LittleSec/p/12757964.html)

#### 3.2 Xcode编译LLVM Pass

若要再添加新的LLVM Pass，需要将代码放置到`lib/Transform`目录下后，将下面信息加入`llvm/lib/Transforms/CMakeLists.txt`中。

```cmake
add_subdirectory(SRPass)
```

重新进入`build`的目录执行`cmake`命令，然后再次加载Xcode Project文件，会看到新的LLVM Pass已经加载到了工程中。

<img src="https://i.loli.net/2021/01/11/RgknqFWA9MYb1zo.png" alt="image-20210111224621797" style="zoom:40%;" />

选择Manage Schemes，将新的LLVM Pass设置为Scheme，编译LLVM Pass，生成的dylib在`build/Debug/lib/`目录下。

<img src="https://i.loli.net/2021/01/11/UaYyz6nJcw9EIhT.png" alt="image-20210111234433374" style="zoom:70%;" />

给定如下程序`test.cpp`，首先编译为llvm bitcode。

```C++
#include <stdio.h>

int main(int argc, char** argv) {
    int* a = new int[10];
    a[5] = 0;
    if (a[argc])
        printf("xx\n");
    return 0;
}
```

利用opt运行LLVM Pass如下，运行成功。

```bash
# https://www.cs.cornell.edu/~asampson/blog/clangpass.html
#include "llvm/IR/LegacyPassManager.h"
#include "llvm/Transforms/IPO/PassManagerBuilder.h"
clang++ -gline-tables-only -flto -fsanitize=address -c test.cpp -o test.orig.bc -isysroot `xcrun --show-sdk-path`

opt -load SRPass.dylib -dcc -o test.cov.o test.orig.bc

# clang++要和opt是一起编译出来的才行
```

<img src="https://i.loli.net/2021/01/11/SmCxYaDPkpn3r85.png" alt="image-20210111234620100" style="zoom:47%;" />

#### 3.3 Xcode 调试 LLVM Pass

用opt为target来调试这个Pass，Xcode中添加opt的目标文件到scheme中。

<img src="https://i.loli.net/2021/01/11/MKa2EV48fY6kXFl.png" alt="image-20210111235014164" style="zoom:77%;" />

编辑scheme的启动参数，和命令行中的保持一致。

<img src="https://i.loli.net/2021/01/11/BX4GxdHpnb9zCuS.png" alt="image-20210111235127009" style="zoom:77%;" />

command+r运行，在`DynamicCallCounter.cpp`的函数`runOnModule`中加入断点，就可以调试LLVM Pass了。

<img src="https://i.loli.net/2021/01/12/5klbasJQOiz6IAC.png" alt="image-20210112001157315" style="zoom:67%;" />

为了在执行 opt 时能自动检测 Pass有没有被修改，若修改则重新编译，可以把 `SRPass` 加到 opt 的依赖里面，编辑 tools/opt/CMakeLists.txt如下：

```cmake
add_llvm_tool(opt
  AnalysisWrappers.cpp
  BreakpointPrinter.cpp
  GraphPrinters.cpp
  NewPMDriver.cpp
  PassPrinters.cpp
  PrintSCC.cpp
  opt.cpp

  DEPENDS
  intrinsics_gen
  SRPass
  )
```

### 4. Ubuntu配置LLVM

#### 4.1 Ubuntu编译LLVM Project

```bash
svn co http://llvm.org/svn/llvm-project/llvm/tags/RELEASE_900/final llvm
cd llvm/tools
svn co http://llvm.org/svn/llvm-project/cfe/tags/RELEASE_900/final clang
cd ..
cd tools/clang/tools
svn co http://llvm.org/svn/llvm-project/clang-tools-extra/tags/RELEASE_900/final extra
cd ../../..
cd projects
svn co http://llvm.org/svn/llvm-project/compiler-rt/tags/RELEASE_900/final compiler-rt
cd ..
cd projects
svn co http://llvm.org/svn/llvm-project/libcxx/tags/RELEASE_900/final libcxx
svn co http://llvm.org/svn/llvm-project/libcxxabi/tags/RELEASE_900/final libcxxabi
cd ..
mkdir bulid
cd build
cmake -G "Unix Makefiles" -DCMAKE_BUILD_TYPE=Release -DLLVM_TARGETS_TO_BUILD="X86" ..
make -j 12
sudo make install
```

#### 4.2 命令行编译LLVM Pass

Move the source code of SanRazor into your llvm project:

```bash
mv src/SRPass llvm/lib/Transforms/
mv src/SmallPtrSet.h llvm/include/llvm/ADT/
```

Add the following command to `CMakeLists.txt` under `llvm/lib/Transforms`:

```
add_subdirectory(SRPass)
```

Compile your llvm project again:

```
cd llvm/build
make -j 12
```

How to run a LLVM Pass

```bash
opt -load SRPass.so -hello < hello.bc
```

or 

```bash
clang -Xclang -load -Xclang SRPass.so ...
```

How to get the option of LLVM Pass

```bash
opt -load SRPass.so -help
```

<img src="https://i.loli.net/2021/01/11/v6W9y7Q83pGcjFl.png" alt="image-20210111150707330" style="zoom:67%;" />

#### 4.3 Clion编译LLVM Pass

修改clion的环境变量 https://llvm.org/docs/CMake.html#cmake-out-of-source-pass

<img src="https://i.loli.net/2021/01/11/ENtIQYoGUuph6PX.png" alt="image-20210111205335982" style="zoom:67%;" />

在CMakeList.txt中加入如下语句 https://ld246.com/article/1541748937641

```cmake
cmake_minimum_required(VERSION 3.17)
find_package(LLVM 9 REQUIRED CONFIG)
project(SRPass)

add_definitions(${LLVM_DEFINITIONS})
include_directories(${LLVM_INCLUDE_DIRS})

list(APPEND CMAKE_MODULE_PATH "${LLVM_CMAKE_DIR}")
include(AddLLVM)
link_directories(${LLVM_LIBRARY_DIRS})
```

Reload cmake file, then compile it.

<img src="https://i.loli.net/2021/01/11/Q7SUNhd96AgRWLb.png" alt="image-20210111214459943" style="zoom:67%;" />

或者按照以下目录

```
├── CMakeLists.txt
├── README.md
└── skeleton
    ├── CMakeLists.txt
    └── Skeleton.cpp
```

在根目录下的 `CMakeLists.txt` 内容如下：

```cmake
sk in llvm-detectDataPass/skeleton at Lab on  master
➜ cat CMakeLists.txt
cmake_minimum_required(VERSION 3.4)
if(NOT DEFINED ENV{LLVM_HOME})
    message(FATAL_ERROR "$LLVM_HOME is not defined")
endif()
if(NOT DEFINED ENV{LLVM_DIR})
    set(ENV{LLVM_DIR} $ENV{LLVM_HOME}/lib/cmake/llvm)
endif()

find_package(LLVM REQUIRED CONFIG)

add_definitions(${LLVM_DEFINITIONS})
include_directories(${LLVM_INCLUDE_DIRS})

add_subdirectory(skeleton)  # Use your pass name here.

list(APPEND CMAKE_MODULE_PATH "${LLVM_CMAKE_DIR}")
include(AddLLVM)
```

在 Pass 目录的 `CMakeLists.txt` 的内容如下所示：

```cmake
add_llvm_library(SkeletonPass MODULE
        # List your source files here.
        Skeleton.cpp
        )

## Use C++11 to compile your pass (i.e., supply -std=c++11).
target_compile_features(SkeletonPass PRIVATE cxx_range_for cxx_auto_type)

# LLVM is (typically) built with no C++ RTTI. We need to match that;
# otherwise, we'll get linker errors about missing RTTI data.
set_target_properties(SkeletonPass PROPERTIES
        COMPILE_FLAGS "-D__GLIBCXX_USE_CXX11_ABI=0 -fno-rtti"
        )
```

#### 4.4 Clion调试LLVM Pass

在Clion中加载整个LLVM项目，load最顶层的`CMakeList.txt`，首先选择SRPass为编译目标，编译出`SRPass.so`。

<img src="https://i.loli.net/2021/01/12/nwErFPyhx3VReQ7.png" alt="image-20210112003019185" style="zoom:50%;" />

编译出的so文件在`cmake-build-debug/lib/SRPass.so `中。将`test.cpp`程序编译成LLVM bitcode

```bash
 build/bin/clang++ -gline-tables-only -flto -fsanitize=address -c test.cpp -o test.orig.bc
 
 opt -load cmake-build-debug/lib/SRPass.so -dcc -o test.cov.o test.orig.bc
```

然后选择`opt`为编译目标，配置其运行参数如上，在`runOnModel`函数上打断点，编译运行调试opt。

<img src="https://i.loli.net/2021/01/12/vt4S7Wic2a6z8JT.png" alt="image-20210112003618457" style="zoom:40%;" />

程序停在断点处，调试成功。

![image-20210112014730638](https://i.loli.net/2021/01/12/qjnOP3yTfcxR2K4.png)

#### 4.5 命令行编译单个LLVM Pass文件

```bash
$ clang++ -c Hello.cpp `llvm-config --cxxflags` -fPIC
$ clang++ -shared -o Hello.so Hello.o `llvm-config --ldflags`
$ ls
CMakeLists.txt  Hello.cpp  Hello.exports  Hello.o  Hello.so
$ vim test.cpp
$ clang -c -emit-llvm test.cpp
$ opt -load ./Hello.so -hello ./test.bc
WARNING: You're attempting to print out a bitcode file.
This is inadvisable as it may cause display problems. If
you REALLY want to taste LLVM bitcode first-hand, you
can force output with the `-f' option.

Hello: main
```

`llvm-config`提供了`CXXFLAGS`与`LDFLAGS`参数方便查找LLVM的头文件与库文件。 如果链接有问题，还可以用`llvm-config --libs`提供动态链接的LLVM库。 `-fPIC -shared` 显然是编译动态库的必要参数。

### 5. Write LLVM Pass

Pass编写 https://www.leadroyal.cn/?p=719

AFL也是一个LLVM Pass https://zhuanlan.zhihu.com/p/122522485

继承现有的Pass的类：All LLVM passes are subclasses of the [Pass](https://llvm.org/doxygen/classllvm_1_1Pass.html) class, which implement functionality by overriding virtual methods inherited from `Pass`. Depending on how your pass works, you should inherit from the [ModulePass](https://llvm.org/docs/WritingAnLLVMPass.html#writing-an-llvm-pass-modulepass) , [CallGraphSCCPass](https://llvm.org/docs/WritingAnLLVMPass.html#writing-an-llvm-pass-callgraphsccpass), [FunctionPass](https://llvm.org/docs/WritingAnLLVMPass.html#writing-an-llvm-pass-functionpass) , or [LoopPass](https://llvm.org/docs/WritingAnLLVMPass.html#writing-an-llvm-pass-looppass), or [RegionPass](https://llvm.org/docs/WritingAnLLVMPass.html#writing-an-llvm-pass-regionpass) classes, which gives the system more information about what your pass does, and how it can be combined with other passes. One of the main features of the LLVM Pass Framework is that it schedules passes to run in an efficient way based on the constraints that your pass meets (which are indicated by which class they derive from).

Configure and build LLVM, put your code under directory `llvm/lib/Transforms/Hello`, add the following cmake file to compile the source code into a shared object `lib/LLVMHello.so`. This file can be dynamically loaded by the opt tool via `-load` option.

```cmake
add_llvm_library( LLVMHello MODULE
  Hello.cpp

  PLUGIN_TOOL
  opt
  )
```

Write the code `Hello.cpp`. Start out with several header files. This pass operates on functions.

```C++
#include "llvm/Pass.h"
#include "llvm/IR/Function.h"
#include "llvm/Support/raw_ostream.h"
```

Next we have the following code, which is required because the functions from the include files live in the llvm namespace.

```C++
using namespace llvm;
```

Then we start out an anonymous namespace. Anonymous namespaces are to C++ what the “`static`” keyword is to C (at global scope). It makes the things declared inside of the anonymous namespace visible only to the current file.

Next we declare our own class `Hello` which is a subclass of `FunctionPass`. This class operates on a function at a time. This declares pass identifier used by LLVM to identify pass. This allows LLVM to avoid using expensive C++ runtime information. We declare a [runOnFunction](https://llvm.org/docs/WritingAnLLVMPass.html#writing-an-llvm-pass-runonfunction) method, which overrides an abstract virtual method inherited from [FunctionPass](https://llvm.org/docs/WritingAnLLVMPass.html#writing-an-llvm-pass-functionpass). This is where we are supposed to do our thing, so we just print out our message with the name of each function.

```C++
namespace {
    struct Hello : public FunctionPass {
        static char ID;
        Hello() : FunctionPass(ID) {}
        bool runOnFunction(Function &F) override {
            errs() << "Hello: ";
            errs().write_escaped(F.getName()) << '\n';
            return false;
        }
    }; // end of struct Hello
}  // end of anonymous namespace
```

We initialize pass ID here. LLVM uses ID’s address to identify a pass, so initialization value is not important. Lastly, we [register our class](https://llvm.org/docs/WritingAnLLVMPass.html#writing-an-llvm-pass-registration) `Hello`, giving it a command line argument “`hello`”, and a name “Hello World Pass”. The last two arguments describe its behavior: if a pass walks CFG without modifying it then the third argument is set to `true`; if a pass is an analysis pass, for example dominator tree pass, then `true` is supplied as the fourth argument.

```C++
char Hello::ID = 0;

// Register for opt
static RegisterPass<Hello> X("hello", "Hello World Pass",
                             false /* Only looks at CFG */,
                             false /* Analysis Pass */);
```

If we want to register the pass as a step of an existing pipeline, some extension points are provided, e.g. `PassManagerBuilder::EP_EarlyAsPossible` to apply our pass before any optimization, or `PassManagerBuilder::EP_FullLinkTimeOptimizationLast` to apply it after Link Time Optimizations.

```c++
// Register for clang
#include "llvm/IR/LegacyPassManager.h"
#include "llvm/Transforms/IPO/PassManagerBuilder.h"

static llvm::RegisterStandardPasses Y(
    llvm::PassManagerBuilder::EP_EarlyAsPossible,
    [](const llvm::PassManagerBuilder &Builder,
       llvm::legacy::PassManagerBase &PM) { PM.add(new Hello()); });
```

 `static RegisterPass<Hello> X`是给opt加载Pass用的， `static RegisterStandardPasses Y`是给clang加载Pass用的， 若使用`opt`加载Pass，则只需要`X`，若使用`clang`加载Pass，则两个都需要。

如果在编写的Pass中需要使用到其它Pass提供的函数功能，需要在函数`getAnalysisUsage`中说明，比如像要获取程序中存在循环的信息，可以在该函数里面申请需要依赖的Pass是`LoopInfoWrapperPass`，导入相应头文件，并在 getAnalysisUsage 中写下如下语句：

```C++
virtual void getAnalysisUsage(AnalysisUsage &AU) const;

#include "llvm/Analysis/LoopInfo.h"
void getAnalysisUsage(AnalysisUsage& AU) const {
    AU.addRequired<LoopInfoWrapperPass>();
	AU.setPreservesAll();
}
```

然后就可以通过它提供接口获取存在循环的个数。

```c++
LoopInfo &LI = getAnalysis<LoopInfoWrapperPass>().getLoopInfo();
int loopCounter = 0;
for (LoopInfo::iterator i = LI.begin(), e = LI.end(); i != e; ++i) {
    loopCounter++;
}
errs() << "loop num:" << loopCounter << "\n";
```

### 6. Read LLVM Pass

https://llvm.org/docs/ProgrammersManual.html

https://llvm.org/docs/ProgrammersManual.html#helpful-hints-for-common-operations

https://llvm.org/docs/ProgrammersManual.html#the-core-llvm-class-hierarchy-reference

https://github.com/imdea-software/LLVM_Instrumentation_Pass/blob/master/InstrumentFunctions/Pass.cpp

#### 6.1 例子一

查看文件中有没有main函数，如果没有main函数就创建main函数并调用所有模块中的其他函数。

```C++
#include "llvm/Pass.h"
#include "llvm/IR/IRBuilder.h"
#include "llvm/IR/IntrinsicInst.h"
#include "llvm/IR/LegacyPassManager.h"
#include "llvm/Transforms/IPO/PassManagerBuilder.h"

#include <string>

using namespace std;
using namespace llvm;

namespace llvm {
    class SimpleInvoker: public ModulePass {
    public:
        static char ID;
        
        SimpleInvoker() : ModulePass(ID) {}
        bool runOnModule(Module &M) override {
            if (!M.getFunction("main")) { // 是否有main函数
                errs() << "Main Function Not Found! So create.\n";
                // 创建main函数类型
                FunctionType *FT = FunctionType::get(Type::getInt32Ty(M.getContext()), false);
                // 根据类型创建函数
                Function *F = Function::Create(FT, GlobalVariable::LinkageTypes::ExternalLinkage, "main", &M);
                // 创建main函数的entry basic block
                BasicBlock *EntryBB = BasicBlock::Create(M.getContext(), "EntryBlock", F);
                IRBuilder<> IRB(EntryBB);
                for (Function &FF: M) {
                    if (FF.getName() == "main")
                        continue;
                    if (FF.empty())
                        continue;
                    // 调用模块中其余函数
                    IRB.CreateCall(&FF);
                }
                //为main函数添加return 0
                IRB.CreateRet(ConstantInt::get(Type::getInt32Ty(M.getContext()), 0));
            }
            return true;
        }
    
    };

    char SimpleInvoker::ID = 0;
    static RegisterPass<SimpleInvoker> Y("showname", "");

}
```

#### 6.2 例子二

输出栈上和全局的字符串。

```C++
#include "llvm/Pass.h"
#include "llvm/IR/IRBuilder.h"
#include "llvm/IR/IntrinsicInst.h"

#include <string>

using namespace std;
using namespace llvm;

void declarePrintf(Function &F);
void insertRodata(Function &F);
void insertData(Function &F);
void insertStack(Function &F);

namespace llvm {
    class ShowName: public FunctionPass {
    public:
        static char ID;
        ShowName() : FunctionPass(ID) {}
        bool runOnFunction(Function &F) override {
            errs() << "enter ShowName" << F.getName() << "\n";
            declarePrintf(F);
            insertRodata(F);
            insertData(F);
            insertStack(F);
            return true;
        }
    };

    char ShowName::ID = 0;
    static RegisterPass<ShowName> Y("showname", "");
}

void declarePrintf(Function &F) {
    // 获取print函数
    Function *func_printf = F.getParent()->getFunction("printf");
    if (!func_printf) {
        // 如果没有print函数就声明printf函数，同样先定义函数类型，再创建相应函数。
        FunctionType *FT = FunctionType::get(Type::getInt8Ty(F.getContext()), true);
        Function::Create(FT, Function::ExternalLinkage, "printf", F.getParent());
    }
}

void insertRodata(Function &F) {
    // 获取entry block
    BasicBlock *entryBlock = &F.getEntryBlock();
    // 创建一个名为printfRodataBlock的空Block
    BasicBlock *printfBlock = BasicBlock::Create(F.getContext(), "printfRodataBlock", &F, entryBlock);
    string function_string = "Function ";
    function_string += F.getName();
    function_string += "is invoked! @rodata\n";
    IRBuilder<> IRB(printfBlock);
    // 获取printf函数
    Function *func_printf = F.getParent()->getFunction("printf");
    if (!func_printf)
        assert(false && "printf not found");
    // 创建一个全局字符串function_strings
    Value *str = IRB.CreateGlobalStringPtr(function_string);
    // 调用printf，以str为参数
    IRB.CreateCall(func_printf, {str});
    // 给当前block添加terminator语句为结尾
    IRB.CreateBr(entryBlock);
}

void insertData(Function &F) {
    // 获取entry block
    BasicBlock *entryBlock = &F.getEntryBlock();
    // 创建一个名为printfDataBlock的空Block
    BasicBlock *printfBlock = BasicBlock::Create(F.getContext(), "printfDataBlock", &F, entryBlock);
    string function_string = "Function ";
    function_string += F.getName();
    function_string += " is invoked! @data\n";
    IRBuilder<> IRB(printfBlock);
    // 获取printf函数
    Function *func_printf = F.getParent()->getFunction("printf");
    if (!func_printf)
        assert(false && "printf not found");
    // 创建全局字符串function_strings
    GlobalVariable *GV = IRB.CreateGlobalString(function_string);
    // 使其变成非constant
    GV->setConstant(false);
    // 创建一个0
    Constant *Zero = ConstantInt::get(Type::getInt32Ty(F.getContext()), 0);
    // 创建一个二级索引
    Constant *Indices[] = {Zero, Zero};
    // 获取指向字符串第一个元素的指针
    Value *str = ConstantExpr::getInBoundsGetElementPtr(GV->getValueType(), GV, Indices);
    // 调用printf，以str为参数
    IRB.CreateCall(func_printf, {str});
    // 给当前block添加terminator语句为结尾
    IRB.CreateBr(entryBlock);
}

void insertStack(Function &F) {
    BasicBlock *entryBlock = &F.getEntryBlock();
    BasicBlock *printfBlock = BasicBlock::Create(F.getContext(), "printfStackBlock", &F, entryBlock);
    string function_string = "Function ";
    function_string += F.getName();
    function_string += " is invoked! @stack\n";
    IRBuilder<> IRB(printfBlock);
    Function *func_printf = F.getParent()->getFunction("printf");
    if (!func_printf)
        assert(false && "printf not found");
    // 创建0
    Value *Zero = ConstantInt::get(Type::getInt8Ty(F.getContext()), 0);
    // 创建长度function_string.size() + 1
    Value *Size = ConstantInt::get(Type::getInt64Ty(F.getContext()), function_string.size() + 1);
    // 创建布尔值false
    Value *Bool = ConstantInt::get(Type::getInt1Ty(F.getContext()), 0);
    
    //创建一个array类型
    ArrayType *arrayType = ArrayType::get(IntegerType::getInt8Ty(F.getContext()), function_string.size() + 1);
    // 找到memset这个函数
    Function *func_memset = Intrinsic::getDeclaration(F.getParent(), Intrinsic::memset, {IntegerType::getInt8PtrTy(F.getContext()), IntegerType::getInt64Ty(F.getContext())});
    // 在栈上开辟arrayType类型的局部变量
    AllocaInst *alloc = IRB.CreateAlloca(arrayType);
    alloc->setAlignment(16);
    // 获取该类型首地址
    Value *str = IRB.CreateGEP(alloc, {Zero, Zero});
    // 调用memset对其进行初始化
    IRB.CreateCall(func_memset, {str, Zero, Size, Bool});
    
    for (unsigned int i = 0; i < function_string.size(); i++) {
        // 索引
        Value *Index = ConstantInt::get(Type::getInt64Ty(F.getContext()), i);
        // 被设置的值
        Value *CDATA = ConstantInt::get(Type::getInt8Ty(F.getContext()), function_string[i]);
        // 找到相应指针
        Value *GEP = IRB.CreateGEP(alloc, {Zero, Index});
        // 将字符存储到对应位置
        IRB.CreateStore(CDATA, GEP);
    }
    // 调用printf，以str为参数
    IRB.CreateCall(func_printf, {str});
    // 给当前block添加terminator语句为结尾
    IRB.CreateBr(entryBlock);
}

```

### 7. 项目SanRazor

#### 7.1 测试程序

给定C++程序

```C++
#include <stdio.h>

int main(int argc, char** argv) {
    int* a = new int[10];
    a[5] = 0;
    if (a[argc])
        printf("xx\n");
    return 0;
}
```

编写Makefile编译该程序

```makefile
.SUFFIXES:.c .o

CXX=clang++

DIR := ${CURDIR} # 使用绝对路径 防止后续被覆盖
SRCS=$(DIR)/test.cpp
OBJS=$(SRCS:.c=.o)
EXEC=main

start: $(OBJS)
	$(CXX) $(CFLAGS) -o $(EXEC) $(OBJS)
	@echo "-----------------------------OK-----------------------"

.c.o:
	$(CXX) $(CFLAGS) -o $@ -c $<

clean:
	rm -rf $(EXEC)

```

执行make编译程序

```bash
➜  temp make
clang++  -o main /home/harper/Projects/llvm/temp/test.cpp
-----------------------------OK-----------------------
➜  temp 
```

#### 7.2 插桩程序

`SRPass.so`的用法如下，首先插桩，用来记录每个分支的执行次数。

```bash
export SR_STATE_PATH="$(pwd)/Cov"
export SR_WORK_PATH="../coverage.sh"   # 生成包含插桩所需外部函数的C文件
SanRazor-clang -SR-init
make clean
make CC=SanRazor-clang CXX=SanRazor-clang++ CFLAGS="-Wall -Winline -g -O3 -fsanitize=address"  LDFLAGS="-fsanitize=address"
```
执行结果如下
```bash
➜  llvm export PATH=/home/harper/Projects/llvm/build/bin:$PATH
➜  llvm cd temp
➜  temp ls
Cov  coverage.sh  _home_harper_Projects_llvm_temp_test.cpp  main  Makefile  test.cpp  test.cpp.o
➜  temp export SR_STATE_PATH="$(pwd)/Cov"
➜  temp SanRazor-clang++ -SR-init
# Initialized Cov folder in /home/harper/Projects/llvm/temp/Cov. Now run:
export SR_STATE_PATH="/home/harper/Projects/llvm/temp/Cov"
➜  temp make clean
rm -rf main
➜  temp ls
Cov  coverage.sh  _home_harper_Projects_llvm_temp_test.cpp  Makefile  test.cpp  test.cpp.o
➜  temp make CC=SanRazor-clang CXX=SanRazor-clang++ CFLAGS="-Wall -Winline -g -O3 -fsanitize=address"  LDFLAGS="-fsanitize=address"

SanRazor-clang++ -Wall -Winline -g -O3 -fsanitize=address -o main /home/harper/Projects/llvm/temp/test.cpp
["/home/harper/Projects/llvm/build/bin/clang++", "-gline-tables-only", "-flto", "-Wall", "-Winline", "-g", "-O3", "-fsanitize=address", "-o", "/home/harper/Projects/llvm/temp/test.cpp.o", "-c", "/home/harper/Projects/llvm/temp/test.cpp", "-o", "/home/harper/Projects/llvm/temp/Cov/objects/home/harper/Projects/llvm/temp/test.cpp.orig.bc"]
["/home/harper/Projects/llvm/temp/Cov/../coverage.sh", "_home_harper_Projects_llvm_temp_test", "/home/harper/Projects/llvm/temp/Cov/objects/home/harper/Projects/llvm/temp/test.cpp.glob.o", "/home/harper/Projects/llvm/temp/Cov/", ""]
["/home/harper/Projects/llvm/build/bin/opt", "-load", "SRPass.so", "-dcc", "-o", "/home/harper/Projects/llvm/temp/Cov/objects/home/harper/Projects/llvm/temp/test.cpp.cov.o", "/home/harper/Projects/llvm/temp/Cov/objects/home/harper/Projects/llvm/temp/test.cpp.orig.bc"]
Start SCIPass on /home/harper/Projects/llvm/temp/test.cpp
End SCIPass on /home/harper/Projects/llvm/temp/test.cpp
_home_harper_Projects_llvm_temp_test
S check : :---S check : :---U check : if.end:if.then---/home/harper/Projects/llvm/temp/test.cpp :: 2 :: 1
Insert call functions for SC branches in /home/harper/Projects/llvm/temp/test.cpp!
Insert call functions for UC branches in /home/harper/Projects/llvm/temp/test.cpp!
DCC Pass completed
["/home/harper/Projects/llvm/build/bin/opt", "-load", "SRPass.so", "-dcc", "-o", "/home/harper/Projects/llvm/temp/Cov/objects/home/harper/Projects/llvm/temp/test.cpp.cov.bc", "/home/harper/Projects/llvm/temp/Cov/objects/home/harper/Projects/llvm/temp/test.cpp.orig.bc"]
Start SCIPass on /home/harper/Projects/llvm/temp/test.cpp
End SCIPass on /home/harper/Projects/llvm/temp/test.cpp
_home_harper_Projects_llvm_temp_test
S check : :---S check : :---U check : if.end:if.then---/home/harper/Projects/llvm/temp/test.cpp :: 2 :: 1
Insert call functions for SC branches in /home/harper/Projects/llvm/temp/test.cpp!
Insert call functions for UC branches in /home/harper/Projects/llvm/temp/test.cpp!
DCC Pass completed
["/home/harper/Projects/llvm/build/bin/llc", "-O3", "-filetype=obj", "-relocation-model=pic", "-o", "/home/harper/Projects/llvm/temp/Cov/objects/home/harper/Projects/llvm/temp/test.cpp.loc.o", "/home/harper/Projects/llvm/temp/Cov/objects/home/harper/Projects/llvm/temp/test.cpp.cov.o"]
["ld", "-r", "/home/harper/Projects/llvm/temp/Cov/objects/home/harper/Projects/llvm/temp/test.cpp.glob.o", "/home/harper/Projects/llvm/temp/Cov/objects/home/harper/Projects/llvm/temp/test.cpp.loc.o", "-o", "/home/harper/Projects/llvm/temp/test.cpp.o"]
["/home/harper/Projects/llvm/build/bin/clang++", "-Wall", "-Winline", "-g", "-O3", "-fsanitize=address", "-o", "main", "/home/harper/Projects/llvm/temp/test.cpp.o"]
-----------------------------OK-----------------------
```

这一步实际执行的命令如下

```bash
clang++ -gline-tables-only -flto -fsanitize=address -o test.cpp.o -c test.cpp -o test.orig.bc # 先生成llvm ir
../coverage.sh _home_harper_Projects_llvm_temp_test test.glob.o Cov/  # 生成test.glob.o，其中包含插桩所调用的函数
opt -load SRPass.so -dcc -o test.cov.o test.orig.bc # 插桩，记录每个分支的执行情况
opt -load SRPass.so -dcc -o test.cov.bc test.orig.bc # 等同于上一条语句 只是输出的文件格式不同
llc -O3 -filetype=obj -relocation-model=pic -o test.loc.o test.cov.o # 变成obj文件
ld -r test.glob.o test.loc.o -o test.o # 链接成test.o
clang++ -o test test.o # 生成最后的可执行程序
```

我们可以查看`test.orig.bc`和`test.cov.bc`的区别，通过llvm-dis将其转换为可读的格式。

![image-20210117141032037](https://i.loli.net/2021/01/17/C7GnhFcYDimRQ94.png)

我们发现所有跟memory sanitizer相关的指令都被标注了出来，而且每个sanity check和user check前都被插桩，调用函数来记录每个分支的执行次数，执行生成的可执行文件，执行情况就被分别存储在`_home_harper_Projects_llvm_temp_test_UC.txt`和`_home_harper_Projects_llvm_temp_test_SC.txt`中。

#### 7.3 删除多余sanitizer

```bash
SanRazor-clang -SR-opt -san-level=L2 -use-asap=1.0
make clean
make CC=SanRazor-clang CXX=SanRazor-clang++ CFLAGS="-Wall -Winline -g -O3 -fsanitize=address"  LDFLAGS="-fsanitize=address" -j 12
```

执行情况如下

```bash
➜  temp SanRazor-clang++ -SR-opt -san-level=L2 -use-asap=1.0
L2
L2
1.0
➜  temp make clean
rm -rf main                                                                                                               
➜  temp make CC=SanRazor-clang CXX=SanRazor-clang++ CFLAGS="-Wall -Winline -g -O3 -fsanitize=address"  LDFLAGS="-fsanitize=address"

SanRazor-clang++ -Wall -Winline -g -O3 -fsanitize=address -o main /home/harper/Projects/llvm/temp/test.cpp
***********************
asan
["/home/harper/Projects/llvm/build/bin/opt", "-load", "SRPass.so", "-DynPassL2", "-scovL2=/home/harper/Projects/llvm/temp/Cov/_home_harper_Projects_llvm_temp_test_SC.txt",
"-ucovL2=/home/harper/Projects/llvm/temp/Cov/_home_harper_Projects_llvm_temp_test_UC.txt", "-logL2=/home/harper/Projects/llvm/temp/Cov/check.txt", "-use-asapL2=1.0", "-o", "/home/harper/Projects/llvm/temp/Cov/objects/home/harper/Projects/llvm/temp/test.cpp.sr.o", "/home/harper/Projects/llvm/temp/Cov/objects/home/harper/Projects/llvm/temp/test.cpp.orig.bc"]
Start SCIPass on /home/harper/Projects/llvm/temp/test.cpp
End SCIPass on /home/harper/Projects/llvm/temp/test.cpp
DynPassL2 on /home/harper/Projects/llvm/temp/test;/home/harper/Projects/llvm/temp/Cov/_home_harper_Projects_llvm_temp_test_SC.txt
2:2----
Harper Optimized on /home/harper/Projects/llvm/temp/Cov/objects/home/harper/Projects/llvm/temp/test.cpp.orig.bc
Reduced::UC:0SC:1:1--------
1:1----
UC num :: 1;SC Num :: 2;SC percent after L1 :: 5.000000e+01%;SC percent after L2 :: 5.000000e+01%
SC cost percent:: 1.000000e+02;SC cost percent after L1 :: 5.000000e+01%;SC cost percent after L2 :: 5.000000e+01%
com:1:1:1:1
test:1:1
Total asap cost:18Reduced total asap cost9
SafePass jj on /home/harper/Projects/llvm/temp/test
Total cost:18 ,total num:2
1::1Budget:5.000000e-02 ,budget removed:0.000000e+00 ,budget new:0.000000e+00
10.000000e+000.000000e+000.000000e+000.000000e+00
["/home/harper/Projects/llvm/build/bin/opt", "-load", "SRPass.so", "-DynPassL2", "-scovL2=/home/harper/Projects/llvm/temp/Cov/_home_harper_Projects_llvm_temp_test_SC.txt", "-ucovL2=/home/harper/Projects/llvm/temp/Cov/_home_harper_Projects_llvm_temp_test_UC.txt", "-logL2=/home/harper/Projects/llvm/temp/Cov/check.txt", "-use-asapL2=1.0", "-o", "/home/harper/Projects/llvm/temp/Cov/objects/home/harper/Projects/llvm/temp/test.cpp.sr.bc", "/home/harper/Projects/llvm/temp/Cov/objects/home/harper/Projects/llvm/temp/test.cpp.orig.bc"]
Start SCIPass on /home/harper/Projects/llvm/temp/test.cpp
End SCIPass on /home/harper/Projects/llvm/temp/test.cpp
DynPassL2 on /home/harper/Projects/llvm/temp/test;/home/harper/Projects/llvm/temp/Cov/_home_harper_Projects_llvm_temp_test_SC.txt
2:2----
Harper Optimized on /home/harper/Projects/llvm/temp/Cov/objects/home/harper/Projects/llvm/temp/test.cpp.orig.bc
Reduced::UC:0SC:1:1--------
1:1----
UC num :: 1;SC Num :: 2;SC percent after L1 :: 5.000000e+01%;SC percent after L2 :: 5.000000e+01%
SC cost percent:: 1.000000e+02;SC cost percent after L1 :: 5.000000e+01%;SC cost percent after L2 :: 5.000000e+01%
com:1:1:1:1
test:1:1
Total asap cost:18Reduced total asap cost9
SafePass jj on /home/harper/Projects/llvm/temp/test
Total cost:18 ,total num:2
1::1Budget:5.000000e-02 ,budget removed:0.000000e+00 ,budget new:0.000000e+00
10.000000e+000.000000e+000.000000e+000.000000e+00
["/home/harper/Projects/llvm/build/bin/opt", "-O3", "-o", "/home/harper/Projects/llvm/temp/Cov/objects/home/harper/Projects/llvm/temp/test.cpp.opt.o", "/home/harper/Projects/llvm/temp/Cov/objects/home/harper/Projects/llvm/temp/test.cpp.sr.o"]
["/home/harper/Projects/llvm/build/bin/opt", "-load", "SRPass.so", "-SCClean", "-o", "/home/harper/Projects/llvm/temp/Cov/objects/home/harper/Projects/llvm/temp/test.cpp.opt.o", "/home/harper/Projects/llvm/temp/Cov/objects/home/harper/Projects/llvm/temp/test.cpp.opt.o"]
["/home/harper/Projects/llvm/build/bin/opt", "-O3", "-o", "/home/harper/Projects/llvm/temp/Cov/objects/home/harper/Projects/llvm/temp/test.cpp.opt.o", "/home/harper/Projects/llvm/temp/Cov/objects/home/harper/Projects/llvm/temp/test.cpp.opt.o"]
["/home/harper/Projects/llvm/build/bin/llc", "-O3", "-filetype=obj", "-relocation-model=pic", "-o", "/home/harper/Projects/llvm/temp/test.cpp.o", "/home/harper/Projects/llvm/temp/Cov/objects/home/harper/Projects/llvm/temp/test.cpp.opt.o"]
["/home/harper/Projects/llvm/build/bin/llc", "-O3", "-filetype=obj", "-relocation-model=pic", "-o", "/home/harper/Projects/llvm/temp/Cov/objects/home/harper/Projects/llvm/temp/test.cpp.bc", "/home/harper/Projects/llvm/temp/Cov/objects/home/harper/Projects/llvm/temp/test.cpp.opt.o"]
["/home/harper/Projects/llvm/build/bin/clang++", "-Wall", "-Winline", "-g", "-O3", "-fsanitize=address", "-o", "main", "/home/harper/Projects/llvm/temp/test.cpp.o"]
```

实际上执行的命令如下

```bash
opt -load SRPass.so -DynPassL2 -scovL2=test_SC.txt -ucovL2=test_UC.txt -logL2=check.txt -use-asapL2=1.0 -o test.sr.o test.orig.bc # 读取执行次数，标记冗余的check，将其设置为false
opt -load SRPass.so -DynPassL2 -scovL2=test_SC.txt -ucovL2=test_UC.txt -logL2=check.txt -use-asapL2=1.0 -o test.sr.bc test.orig.bc # 同上
opt -O3 -o test.opt.o test.sr.o
opt -load SRPass.so -SCClean -o test.opt.o test.opt.o # 删除冗余的check
opt -O3 -o test.opt.o test.opt.o
llc -O3 -filetype=obj -relocation-model=pic -o test.o test.opt.o
llc -O3 -filetype=obj -relocation-model=pic -o test.bc test.opt.o
clang++ -o test test.o
```

我们首先比较`test.orig.bc`和`test.sr.bc`，第二个冗余的分支语句被设置为了false。

![image-20210117142006991](https://i.loli.net/2021/01/17/oScGwrnBs1PQxdq.png)

然后比较`test.sr.bc`和`test.opt.bc`，可以发现有些语句直接被删除了。

![image-20210117142941747](https://i.loli.net/2021/01/17/UnSOy7zrQLjPt45.png)

经O3优化后，所有第二个sanity check都被删除

![image-20210117143531357](https://i.loli.net/2021/01/17/7JCIjQiSMgtADdm.png)

#### 7.4 代码逻辑

Search for `RegisterPass` in the whole project, find the customized features of this `SRPass.so` file

<img src="https://i.loli.net/2021/01/11/V8QW1lRq9zHs3Ei.png" alt="image-20210111150855153" style="zoom:77%;" />

For this project, there are 7 customized featrures, which corresponds to seven option

`-SCIPass`对应SCIPass类，是最基本的类，该类分析所有的check list，包括user check和sanity check

`-dcc`对应DynamicCallCounter类，该类继承自ModulePass，处理对SC和UC进行插桩，统计在给定workload的情况下每个分支的执行次数

`-DynPassL0/L1/L2` 对应DynPassL0/L1/L2类，该类继承自ModulePass，每次处理一个program，根据执行次数和静态依赖信息将冗余的sanity check的if语句设置为永远false

`-SCClean`用于删除冗余sanitizer对应的指令

