---
title: '[Tech] OpenArk Compiler'
date: 2021-01-08 16:49:25
tags:
---

#### 1. Maple IR前端

Maple IR是方舟编译器的中间表示语言，设计原则是尽可能多的保留源文件的信息，其中信息包括声明部分（符号表）和代码部分。Maple IR是平台无关的，不依赖任何处理器。Maple IR也有配套的Maple VM，可以直接运行Maple IR。可以利用不同的前端将C/C++，Java等不同的语言转化成Maple IR，也可以扩展支持别的语言。

<!--more-->

Maple IR支持所有已知的程序分析和优化操作，它支持在不同语义层面表示程序代码，也就是说，不同于LLVM IR的显示单层IR表示，方舟编译器的Maple IR提出多层中间表示：

- 高层中间表示尽可能的保留源码内部的信息，适合language-specific的分析和优化；
- 低层中间表示接近汇编指令，差不多和汇编指令有一对一的映射，可以进行通用general purpose的优化；

越高层次的IR，支持的Opcode越多，越底层的IR，支持的Opcode越接近处理器的汇编；高层次的IR，程序结构是有层级的，低层次的IR，程序结构是扁平的，变成了序列化指令的形式；高层次的IR是与平台无关的，低层次的IR变得和平台有关。多层IR表示能够最大化在IR层的优化效果。（不知道能否显式表现出多层IR）

Maple IR存储到文件的时候有两个格式，一个是mpl，一个是mplt。mplt是声明文件，mpl是定义文件。Maple IR的定位本身就是一种高级语言。mplt对应C++的`.h`，里面存放类的声明，mpt文件对应C++的`.cpp`文件，里面存放方法的实现。

##### 1.1 C/C++ to Maple

`ast2mpl`是C和C++的前端，将clangAst转换为mpl格式的中间表示语言。

```bash
ast2mpl printHuawei.c -I /usr/lib/gcc/x86_64-linux-gnu/8/include # generate printHuawei.mpl
```

##### 1.2 Java to Maple

`jbc2mpl`是Java的前端，java bytecode转化为mpl格式的中间表示语言，用jar或class作为输入都可以。java-core是java语言的基础类库，想要使用java的基础包就需要这个类库的支持。

```bash
# use .class as input
jbc2mpl -mplt /home/wchenbt/OpenArkCompiler/output/aarch64-clang-release/libjava-core/java-core.mplt -inclass HelloWorld.class -out HelloWorld
# use .jar as input
jbc2mpl -mplt /home/wchenbt/OpenArkCompiler/output/aarch64-clang-release/libjava-core/java-core.mplt -injar HelloWorld.jar -out HelloWorld
# use java-core.jar as input
jbc2mpl -injar /home/wchenbt/OpenArkCompiler/output/aarch64-clang-release/libjava-core/java-core.jar -inclass HelloWorld.class -out HelloWorld
```

##### 1.3 Others

方舟编译器利用如下前端将除C/C++和Java以外的语言转化为中间表示语言Maple：

- dex2mpl
- js2mpl
- mplfe：前端开发框架，多个前端开发作准备

#### 2. Maple IR设计

Maple IR有二进制格式和ASCII码格式，但不是`.mpl`和`.mplt`。ASCII码格式包含

- declaration statements（声明语句）：符号表信息
- executable states（执行语句）：程序代码

每个Maple IR文件对应一个CU编译单元，编译单元由全局范围内的声明组成。声明是由函数组成的，也称为PU，PU则包含局部声明。

（类比于LLVM IR的Module，Function和Baisc Block）

<img src="https://i.loli.net/2021/01/20/xVlMuHn41mqTSfp.png" alt="image-20210120222004928" style="zoom:40%;" />

Maple IR中的execution node有三种：

- Leaf nodes (terminal nodes)：constant or the value of a storeage unit
- Expression nodes: An expression node performs an operation on its operands to compute a result. Each operand can be either a leaf node or another expression node. Expression nodes are the internal nodes of expression trees.
- Statement nodes

In all the executable nodes, the *opcode* field specifies the operation of the node, followed by additional field specification relevant to the opcode. The operands for the node are specified inside *parentheses* separated *commas*. The general form is:

*opcode fields (opnd0, opnd1, opnd2)*

例如C语言中的赋值语句 "a = b" 对应的Maple IR使用 dassign (direct assignment opcode) 将b的值赋给a。

```
dassign $a (dread i32 $b)
```

若有嵌套，需要另起一行，例如表达式a = b + c - d对应的Maple IR如下

```
dassign $a (
  sub i32(
    add i32(dread i32 $b, dread i32 $c),
    dread i32 $d))
```

方舟的IR和LLVM IR的区别为

- 方舟编译器的IR专门为Javascript预留了12个基本类型，这显然是为了后续支持Javascript所做的准备
- LLVM IR的整型设计的更加简洁，直接用iN来表示。而方舟编译器IR是用了i16/i32/i64/u16/u32/u64来表示

##### 2.1 From Java

如下是HelloWorld.java程序对应的Maple IR。

```java
public class HelloWorld {
    public static void main(String[] args) {
        System.out.println("Hello World!");
    }
}
```

首先是一些这个类的基本信息，称为Module Declaration。

```java
flavor 1 // how the IR was produced, indicating the state of the compilation process
srclang 3 // gives the source language that produces the Maple IR module
id 65535 // unique module id assigned to the module
numfuncs 2 // number of function definitions in the module,

import "HelloWorld.mplt"
import "/home/wchenbt/OpenArkCompiler/output/aarch64-clang-release/libjava-core/java-core.mplt"

// entry point
entryfunc &LHelloWorld_3B_7Cmain_7C_28ALjava_2Flang_2FString_3B_29V

fileinfo {
  @INFO_filename "HelloWorld.class"}

srcfileinfo {
  1 "HelloWorld.java"}
```

接下来是符号表信息，每个文件里有一个global符号表，每个函数又分别有一个local符号表，每个符号表中有变量信息、类型信息和函数原型信息。代码中通过名字引用符号表中的信息。

```java
// 这个类的信息
javaclass $LHelloWorld_3B <$LHelloWorld_3B> public
// 两个函数原型声明
func &LHelloWorld_3B_7C_3Cinit_3E_7C_28_29V public constructor (var %_this <* <$LHelloWorld_3B>>) void
func &LHelloWorld_3B_7Cmain_7C_28ALjava_2Flang_2FString_3B_29V public static (var %Reg2_R742 <* <[] <* <$Ljava_2Flang_2FString_3B>>>>) void
// 全局变量
var $_C_STR_d9bd4a0c2c2117158ed933ab7468a461 fstatic <[4] u64> readonly = [0, 0x1900000000, 0x6c6c6548c63cb61d, 0x21646c726f57206f] // "Hello World"
var $Ljava_2Flang_2FSystem_3B_7Cout extern <* <$Ljava_2Fio_2FPrintStream_3B>> final public static // System.out
var $__cinf_Ljava_2Flang_2FString_3B extern <$__class_meta__>

func &MCC_GetOrInsertLiteral () <* <$Ljava_2Flang_2FString_3B>>
```

接下来，是两个声明函数的定义，一个是构造函数，一个是main函数，函数开头是局部符号表信息。

```java
func &LHelloWorld_3B_7C_3Cinit_3E_7C_28_29V public constructor (var %_this <* <$LHelloWorld_3B>>) void {
  // 局部符号表信息
  funcid 48971
  var %Reg1_R44446 <* <$LHelloWorld_3B>>
  var %Reg0_R44446 <* <$LHelloWorld_3B>>
  var %Reg0_R57 <* <$Ljava_2Flang_2FObject_3B>>

  dassign %Reg1_R44446 0 (dread ref %_this)
  #LINE HelloWorld.java : 15, INSTIDX : 0||0000:  aload_0
LOC 1 15
  dassign %Reg0_R44446 0 (dread ref %Reg1_R44446)
  #LINE HelloWorld.java : 15, INSTIDX : 1||0001:  invokespecial
  dassign %Reg0_R57 0 (retype ref <* <$Ljava_2Flang_2FObject_3B>> (dread ref %Reg0_R44446))
  callassigned &Ljava_2Flang_2FObject_3B_7C_3Cinit_3E_7C_28_29V (dread ref %Reg0_R57) {}
  #LINE HelloWorld.java : 15, INSTIDX : 4||0004:  return
  return ()
}

func &LHelloWorld_3B_7Cmain_7C_28ALjava_2Flang_2FString_3B_29V public static (var %Reg2_R742 <* <[] <* <$Ljava_2Flang_2FString_3B>>>>) void {
  // 局部符号表信息
  funcid 48972
  var %Reg0_R561 <* <$Ljava_2Fio_2FPrintStream_3B>>
  var %Reg1_R43 <* <$Ljava_2Flang_2FString_3B>>
  var %L_STR_163987 <* <$Ljava_2Flang_2FString_3B>>
  // main的参数
ALIAS %args %Reg2_R742 <* <[] <* <$Ljava_2Flang_2FString_3B>>>>
  intrinsiccallwithtype <$LHelloWorld_3B> JAVA_CLINIT_CHECK ()
  #LINE HelloWorld.java : 17, INSTIDX : 0||0000:  getstatic
LOC 1 17 // System.out.println("Hello World!");
  intrinsiccallwithtype <$Ljava_2Flang_2FSystem_3B> JAVA_CLINIT_CHECK ()
  dassign %Reg0_R561 0 (dread ref $Ljava_2Flang_2FSystem_3B_7Cout)
  #LINE HelloWorld.java : 17, INSTIDX : 3||0003:  ldc
  // 引用HelloWorld字符串对应的变量
  callassigned &MCC_GetOrInsertLiteral (addrof ptr $_C_STR_d9bd4a0c2c2117158ed933ab7468a461) { dassign %L_STR_163987 0 }
  dassign %Reg1_R43 0 (dread ptr %L_STR_163987)
  #LINE HelloWorld.java : 17, INSTIDX : 5||0005:  invokevirtual
  // System.out.println
  virtualcallassigned &Ljava_2Fio_2FPrintStream_3B_7Cprintln_7C_28Ljava_2Flang_2FString_3B_29V (dread ref %Reg0_R561, dread ref %Reg1_R43) {}
  #LINE HelloWorld.java : 18, INSTIDX : 8||0008:  return
LOC 1 18
  return ()
}
```

再看一个Java代码对应的Maple IR，感受一下Maple IR如何做算术运算。

```java
public class HelloWorld {
    public static void main(String[] args) {
        int a = 0;
        int b = 1;
        int c = a + b;
    }
}
```

这里我们从main函数中可以看出，不同于LLVM IR，Maple IR不是SSA，一个变量可以被赋值多次，和LLVM IR相同的是，每个操作数都指明了类型。语句中经常在中间位置有一个0，这是field-ID，涉及结构体或class成员的编号，对于基本数据类型，field-ID都是0。

```java
// 文件信息
flavor 1
srclang 3
id 65535
numfuncs 2
import "HelloWorld.mplt"
import "/home/wchenbt/OpenArkCompiler/output/aarch64-clang-release/libjava-core/java-core.mplt"
entryfunc &LHelloWorld_3B_7Cmain_7C_28ALjava_2Flang_2FString_3B_29V
fileinfo {
  @INFO_filename "HelloWorld.class"}
srcfileinfo {
  1 "HelloWorld.java"}

// 全局符号表
javaclass $LHelloWorld_3B <$LHelloWorld_3B> public
func &LHelloWorld_3B_7C_3Cinit_3E_7C_28_29V public constructor (var %_this <* <$LHelloWorld_3B>>) void
func &LHelloWorld_3B_7Cmain_7C_28ALjava_2Flang_2FString_3B_29V public static (var %Reg5_R742 <* <[] <* <$Ljava_2Flang_2FString_3B>>>>) void
var $__cinf_Ljava_2Flang_2FString_3B extern <$__class_meta__>
func &MCC_GetOrInsertLiteral () <* <$Ljava_2Flang_2FString_3B>>
    
// 构造函数
func &LHelloWorld_3B_7C_3Cinit_3E_7C_28_29V public constructor (var %_this <* <$LHelloWorld_3B>>) void {
  funcid 48971
  var %Reg1_R44446 <* <$LHelloWorld_3B>>
  var %Reg0_R44446 <* <$LHelloWorld_3B>>
  var %Reg0_R57 <* <$Ljava_2Flang_2FObject_3B>>

  dassign %Reg1_R44446 0 (dread ref %_this)
  #LINE HelloWorld.java : 15, INSTIDX : 0||0000:  aload_0
LOC 1 15
  dassign %Reg0_R44446 0 (dread ref %Reg1_R44446)
  #LINE HelloWorld.java : 15, INSTIDX : 1||0001:  invokespecial
  dassign %Reg0_R57 0 (retype ref <* <$Ljava_2Flang_2FObject_3B>> (dread ref %Reg0_R44446))
  callassigned &Ljava_2Flang_2FObject_3B_7C_3Cinit_3E_7C_28_29V (dread ref %Reg0_R57) {}
  #LINE HelloWorld.java : 15, INSTIDX : 4||0004:  return
  return ()
}

  // main函数
func &LHelloWorld_3B_7Cmain_7C_28ALjava_2Flang_2FString_3B_29V public static (var %Reg5_R742 <* <[] <* <$Ljava_2Flang_2FString_3B>>>>) void {
  // 局部符号表信息
  funcid 48972
  var %Reg0_I i32
  var %Reg2_I i32
  var %Reg3_I i32
  var %Reg1_I i32
  var %Reg4_I i32

ALIAS %a %Reg2_I i32
ALIAS %c %Reg4_I i32
ALIAS %b %Reg3_I i32
// main的参数
ALIAS %args %Reg5_R742 <* <[] <* <$Ljava_2Flang_2FString_3B>>>>
  intrinsiccallwithtype <$LHelloWorld_3B> JAVA_CLINIT_CHECK ()
  #LINE HelloWorld.java : 17, INSTIDX : 0||0000:  iconst_0
LOC 1 17 // int a = 0;
  dassign %Reg0_I 0 (constval i32 0)
  #LINE HelloWorld.java : 17, INSTIDX : 1||0001:  istore_1
  dassign %Reg2_I 0 (dread i32 %Reg0_I)
  #LINE HelloWorld.java : 18, INSTIDX : 2||0002:  iconst_1
LOC 1 18 // int b = 1;
  dassign %Reg0_I 0 (constval i32 1)
  #LINE HelloWorld.java : 18, INSTIDX : 3||0003:  istore_2
  dassign %Reg3_I 0 (dread i32 %Reg0_I)
  #LINE HelloWorld.java : 19, INSTIDX : 4||0004:  iload_1
LOC 1 19 // int c = a + b;
  dassign %Reg0_I 0 (dread i32 %Reg2_I)
  #LINE HelloWorld.java : 19, INSTIDX : 5||0005:  iload_2
  dassign %Reg1_I 0 (dread i32 %Reg3_I)
  #LINE HelloWorld.java : 19, INSTIDX : 6||0006:  iadd
  dassign %Reg0_I 0 (add i32 (dread i32 %Reg0_I, dread i32 %Reg1_I))
  #LINE HelloWorld.java : 19, INSTIDX : 7||0007:  istore_3
  dassign %Reg4_I 0 (dread i32 %Reg0_I)
  #LINE HelloWorld.java : 20, INSTIDX : 8||0008:  return
LOC 1 20
  return ()
}
```

##### 2.2 From C/C++

如下显示C代码对应Maple IR的例子

C代码

```C
int main() {
  printf("Hello World\n");
  return 0;
}
```

Maple IR，每个函数都被赋予了一个funcid。

```
func &main public () i32 {
  funcid 108
  funcinfo {
    @INFO_funcname "main",
    @INFO_signature "main|",
    @INFO_classname "",
    @INFO_fullname "main|()I"}

  var %retvar_7 i32
  var %retvar_8 i32

LOC 2 19
  #printf("Hello World\n");
  callassigned &printf (conststr a64 "Hello World\x0a") { dassign %retvar_8 0 }
LOC 2 20
  #return 0;
  return (constval i32 0)
}
```

C代码

```c
int foo(int i,int j){
  return (i + j) * -998;
}
```

Maple IR用树的形式表示statement，类似于AST的格式，组织嵌套的statement。

```
func &foo public (var %i i32, var %j i32) i32 {
  funcid 108
  funcinfo {
    @INFO_funcname "foo",
    @INFO_signature "foo|II",
    @INFO_classname "",
    @INFO_fullname "foo|(II)I"}

  var %retvar_7 i32

LOC 2 19
  #return (i + j) * -998;
  return (mul i32 (
    add i32 (dread i32 %i, dread i32 %j),
    neg i32 (constval i32 998)))
}
```

C代码

```c
float a[10];
void init(void) {
  int i;
  for(i=0; i<10; i++)
    a[i]=i*3;
}
```

Maple IR，从这里其实可以看出，可读的Maple IR还是处于比较高层次的，因为用到了while关键字。

```
...
var $a <[10] f32> public used
...
func &init public () void {
  funcid 108
  funcinfo {
    @INFO_funcname "init",
    @INFO_signature "init|",
    @INFO_classname "",
    @INFO_fullname "init|()V"}

  var %i i32 public used
  var %condvar_9 i32
  var %post_10 i32

LOC 2 20
  #int i;
LOC 2 21
  #for(i=0; i<10; i++)
  #i=0; i<10; i++)
  dassign %i 0 (constval i32 0)
  dassign %condvar_9 0 (lt i32 i32 (dread i32 %i, constval i32 10))
  while (dread i32 %condvar_9) {
LOC 2 22
    #a[i]=i*3;
    iassign <* f32> 0 (
      array 0 ptr <* <[10] f32>> (addrof ptr $a, dread i32 %i), 
      cvt f32 i32 (mul i32 (dread i32 %i, constval i32 3)))
    dassign %post_10 0 (dread i32 %i)
    dassign %i 0 (add i32 (dread i32 %i, constval i32 1))
    dassign %condvar_9 0 (lt i32 i32 (dread i32 %i, constval i32 10))
  }
}
```

C代码

```c
typedef struct SS{
  int f1;
  char f2:6;
  char f3:2;
}SS;
SS foo(SS x){
  x.f2=33;
  return x;
}
```

Maple IR，这里我们可以看到field-ID不再是0，field-ID是为了方便直接访问一个结构体之中的field，而不是访问整个结构体。

- 支持field-ID的结构有三种：struct、class、interface；除了这三种结构，field-ID也存在，其值为0，
- field-ID的扩展主要是为了方便dassign、dread、iassign、iread这几条指令使用。
- field-ID赋值的时候，最顶层的结构是给0，然后访问其内部的每个field，每个field给一个唯一的编号，然后每个field递增1，所以访问f2时field ID是2；
- 如果要分配编号的field是一个结构，那么给其一个field-ID编号，并对其内部嵌套的field继续进行编号；
- 对于class而言，父类就像是子类的内部的结构，子类的第一个field就是父类；
- 如果一个结构既单独存在，又嵌套在另外一个结构之中，那么从不同的角度出发，这个结构的field会被分配不同field-ID编号，因为field-ID的分配是从顶层结构开始的；

```
...
type $SS <struct {
  @f1 i32 public,
  @f2 :6 i8 public,
  @f3 :2 i8 public}>
...
func &foo public (var %x <$SS>) <$SS> {
  funcid 108
  funcinfo {
    @INFO_funcname "foo",
    @INFO_signature "foo|SS;",
    @INFO_classname "",
    @INFO_fullname "foo|(SS;)SS;"}

  var %retvar_7 <$SS>

LOC 2 24
  #x.f2=33;
  dassign %x 2 (cvt i8 i32 (constval i32 33))
LOC 2 25
  #return x;
  return (dread agg %x)
}
```

C代码

```C
int fact(int n) {
  if(n!=1)
    return n*fact(n-1);
  else return 1;
}
```

Maple IR实现递归。

```
func &fact public (var %n i32) i32 {
  funcid 108
  funcinfo {
    @INFO_funcname "fact",
    @INFO_signature "fact|I",
    @INFO_classname "",
    @INFO_fullname "fact|(I)I"}

  var %retvar_7 i32
  var %retvar_8 i32

LOC 2 19
  #if(n!=1)
  if (ne i32 i32 (dread i32 %n, constval i32 1)) {
LOC 2 20
    #return n*fact(n-1);
    callassigned &fact (sub i32 (dread i32 %n, constval i32 1)) { dassign %retvar_8 0 }
    dassign %retvar_7 0 (mul i32 (dread i32 %n, dread i32 %retvar_8))
    goto @exit6
  }
  else {
LOC 2 21
    #return 1;
    dassign %retvar_7 0 (constval i32 1)
    goto @exit6
  }
@exit6   
  return (dread i32 %retvar_7)
}
```

给定该Java程序

```Java
class A {
    // LA_3B_7C_3Cinit field-id is 1
    public int a; // field-id is 4
    public void seta(int b) { // LA_3B_7Cseta_7C field-id is 2
        a = b;
    }
    public int geta() { // LA_3B_7Cgeta_7C field-id is 3
        return a; 
    }
}

class B extends A {
    public void seta(int b) {
        a = b + 1;
    }
}

public class FieldId {
    public static void main(String[] args) {
        B obj = new B();
        obj.seta(3);
        int num = obj.geta();
        System.out.println(num);
    }
}
```

class A的field ID情况下：

1、LA_3B_7C_3Cinit....

2、LA_3B_7Cseta_7C....

3、LA_3B_7Cgeta_7C...

4、a

B的情况：

1、A

2、LA_3B_7C_3Cinit....

3、LA_3B_7Cseta_7C...

4、LA_3B_7Cgeta_7C...

5、a

6、LB_3B_7C_3Cinit....

7、LB_3B_7Cseta_7C...

```
type %SS <struct { @g1 f64, @g2 f64 }>
var %s [struct{@f1i32, @f2 <%SS>, @f3:4 i32} = 
      [ 1 = 99,
        2 = [1= 10.0],          # field f2.g1 has field ID 1 in struct %SS and is initialized to 10.0
        4 = 22.2,               # field f2.g2 has field ID 4 in struct %s and is initialized to 22.2
        5 = 15 ]                # field f3 (4 bits in size) has field ID 5 in struct %s and is initialized to 15
```

#### 3. 配置OpenArk

首先配置方舟编译器主项目，主项目最后只能生成汇编程序`.s`，之后介绍两个的孵化器项目mapleall和maple engine，可以再处理`.s`分别至运行C/C++的`.out`文件和java程序的`.so`文件，并分别利用`qemu-aarch64`和`maple_engine`运行。

##### 3.1 OpenArk Compiler

方舟编译器的总目录，下述项目mapleall属于FutureWei编译器分支，未来会合并到总目录这里。方舟编译器目录结构为：

- build：环境设置脚本，和一些build所用的Makefile
- samples：示例程序目录，本次发布共公开了六个示例程序
- src目录：源码目录，先介绍其中的mapleall目录
  - bin：直接提供的可执行文件
  - mpl_phase：maple phase的基本框架的代码
  - maple_driver：maple可执行程序的主要源码所在的位置，它会调用其他的maple_开头的目录的部分内容
  - maple_ipa：interleaved_manager和module_phase_manager的相关代码
  - maple_ir：针对maple的ir的基本操作的相关代码，与LLVM针对IR的基本操作类似，主要是对IR进行基本的分析，获取IR所要表达的信息，为之后的优化作准备。
  - maple_me：有关MeFuncPhase类别的phase的框架及其具体内容，这是phase相关的一部分，所有的具体的MeFuncPhase的子类，实现都在该目录之下。
  - mpl2mpl：包含从maple ir到maple ir的转换，这种转换都是为了后续的me做准备，该目录下的主题内容是ModulePhase类别的Phase的具体实现。
- tools目录：为编译和使用过程中所用到的其他工具所预留的目录，该目录后续将存放llvm、gn、ninja

首先安装如下依赖

```bash
sudo apt-get -y install openjdk-8-jdk git-core build-essential zlib1g-dev libc6-dev-i386 g++-multilib gcc-multilib linux-libc-dev gcc-5-aarch64-linux-gnu g++-5-aarch64-linux-gnu unzip tar curl python3-paramiko python-paramiko python-requests
```

在OpenArkcompiler目录下执行以下命令，编译出OpenArkCompiler，默认输出路径output/TYPE/bin。

```bash
source build/envsetup.sh arm debug # 设置环境变量
make setup # 自动下载依赖包
make # 编译OpenArkCompiler
make libcore #编译maple runtime
make testall # 该命令会失败
```

编译完成后，在`output/aarch64-clang-release/bin`目录下，可以看到编译出来的二进制文件，其中`dex2mpl/java2jar/jbc2mpl`在编译前就已经在目录`src/mapleall/bin`下了，只有maple是编译来的。

###### 3.3.1 java2jar

```bash
OUTPUT=$1                                       # HelloWorld.jar
CORE_ALL_JAR=$2                                 # libjava-core/java-core.jar
shift 2
javac -g -d . -bootclasspath ${CORE_ALL_JAR} $@ # -bootclasspath => -sourcepath
                                                # HelloWorld.java => HelloWorld.class
jar -cvf ${OUTPUT} *.class                      # HelloWorld.class => HelloWorld.jar
```

该脚本类似于javac和jar的联合体，将java文件变成class文件后，再打包成jar文件，使用方法如下

```bash
# HelloWorld.java => HelloWorld.class => HelloWorld.jar
➜  helloworld git:(master) ✗ java2jar  HelloWorld.jar /home/wchenbt/OpenArkCompiler/output/aarch64-clang-release/libjava-core/java-core.jar "HelloWorld.java"
added manifest
adding: HelloWorld.class(in = 534) (out= 329)(deflated 38%)
➜  helloworld git:(master) ✗ ls
HelloWorld.class  HelloWorld.jar  HelloWorld.java  Makefile
➜  helloworld git:(master) ✗
```

###### 3.3.2 jbc2mpl

将class文件或者jar文件转化为maple IR格式，生成的是maple IR的最高级形态，用法如下，运行后生成文件`HelloWorld.mpl`和`HelloWorld.mplt`。

```bash
➜  helloworld git:(master) ✗ jbc2mpl -mplt /home/wchenbt/OpenArkCompiler/output/aarch64-clang-release/libjava-core/java-core.mplt  HelloWorld.jar
➜  helloworld git:(master) ✗ ls
HelloWorld.class  HelloWorld.jar  HelloWorld.java  HelloWorld.mpl  HelloWorld.mplt  Makefile
➜  helloworld git:(master) ✗
```

也可以用如下命令运行该工具将`java-core.jar`转换为`mpl`格式以后续使用，编译别的文件需要加上`-mplt java-core.mplt`，因为java-core是java的核心类库。

```bash
jbc2mpl -injar java-core.jar -out libjava-core
```

###### 3.3.3 maple

所有的编译器都会有一个统一的命令入口，例如gcc命令，这个命令可以调用很多的工具来完成整个编译的过程，包括linker。在方舟编译器中，这个命令是maple，通过maple命令完成前端输入解析，中端优化，后端代码生成和链接。

针对maple IR的一个工具，可以利用`--run=cmd1:cmd2`命令运行

- jbc2mpl：实际上是命令行运行和3.3.2的工具
- me&mpl2mpl：执行Module和Function的优化，生成HelloWorld.VtableImpl.mpl文件。
- mplcg：将maple文件编译成汇编格式，生成HelloWorld.VtableImpl.s文件

```bash
➜  helloworld git:(master) ✗ maple --run=me:mpl2mpl --option=" --O2 --quiet: --O2 --quiet --regnativefunc --no-nativeopt --maplelinker --emitVtableImpl" ./HelloWorld.mpl
Starting mpl2mpl&mplme
Starting:./maple --run=me:mpl2mpl --option=" --O2 --quiet: --O2 --quiet --regnativefunc --no-nativeopt --maplelinker --emitVtableImpl" ./HelloWorld.mpl
Starting parse input
Parse consumed 0s
Processing mpl2mpl&mplme
[mpl2mpl] Module phases cost 117ms
[me] Function phases cost 0ms
[mpl2mpl] Module phases cost 17ms
 Mpl2mpl&mplme consumed 0s
➜  helloworld git:(master) ✗ ls
HelloWorld.class  HelloWorld.jar  HelloWorld.java  HelloWorld.mpl  HelloWorld.mplt  HelloWorld.VtableImpl.mpl  Makefile
```

也可以直接运行如下命令，直接生成最终的汇编文件。java-core是java语言的基础类库，想要使用java的基础包就需要这个类库的支持。

```bash
maple -O2 --mplt /home/wchenbt/OpenArkCompiler/output/aarch64-clang-release/libjava-core/java-core.mplt HelloWorld.jar
```

###### 3.3.4 mplcg

该工具将mpl格式生成后段汇编代码，用法如下，需要通过maple来运行mplcg，运行后生成汇编文件`HelloWorld.VtableImpl.s`：

```bash
➜  helloworld git:(master) ✗ maple --run=mplcg --option=" --O2 --quiet --no-pie --verbose-asm --fpic --maplelinker" --infile ./HelloWorld.VtableImpl.mpl
Mplcg Parser consumed 319ms
Starting mplcg
Starting:./maple --run=mplcg --option=" --O2 --quiet --no-pie --verbose-asm --fpic --maplelinker" --infile ./HelloWorld.VtableImpl.mpl
Processing mplcg
Mplcg consumed 0s
➜  helloworld git:(master) ✗ ls
HelloWorld.class  HelloWorld.java  HelloWorld.mplt            HelloWorld.VtableImpl.primordials.txt  Makefile
HelloWorld.jar    HelloWorld.mpl   HelloWorld.VtableImpl.mpl  HelloWorld.VtableImpl.s
```

###### 3.3.5 irbuild

该工具不开源，是操作mplt文件，将其转换为二进制或者mpl文件。mplt是mpl的头文件，跟C一样，相当于`.h`，在maple的非后端过程中，都是使用mplt的头文件作为输入即可，链接的时候才需要使用mpl文件。将maple当成C语言来看待，maple的处理过程相当于C语言的编译过程，只需要使用其他单元的头文件声明处理当前的单元，链接的时候才需要其它的单元定义。

执行如下命令可以将`HelloWorld.mplt`转换为文本格式`HelloWorld.irb.mpl`。

```bash
$> irbuild i HelloWorld.mplt 
$> ls
HelloWorld.class    HelloWorld.jar   HelloWorld.mpl   HelloWorld.VtableImpl.mpl
HelloWorld.irb.mpl  HelloWorld.java  HelloWorld.mplt  Makefile
```

转换后文件内容如下，可以看出类似于C++的头文件。

```java
flavor 1
srclang 3
id 65535
numfuncs 0
type $LHelloWorld_3B <class <$Ljava_2Flang_2FObject_3B> {
  @INFO_srcfile "HelloWorld.java",
  @INFO_classname "LHelloWorld_3B",
  @INFO_classnameorig "LHelloWorld;",
  @INFO_superclassname "Ljava_2Flang_2FObject_3B",
  @INFO_attribute_string " public ",
  @INFO_access_flags 33,
  &LHelloWorld_3B_7C_3Cinit_3E_7C_28_29V public constructor (<* <$LHelloWorld_3B>>) void,
  &LHelloWorld_3B_7Cmain_7C_28ALjava_2Flang_2FString_3B_29V public static (<* <[] <* <$Ljava_2Flang_2FString_3B>>>>) void}>
type $Ljava_2Flang_2FString_3B <classincomplete {}>
type $Ljava_2Flang_2FObject_3B <classincomplete {}>
```

###### 3.3.6 others

- dex2mpl
- java2d8
- maplegen

到目前为止，我们完成了Java的编译过程`.jave =>.class =>.jar =>.mpl =>.s`。

<img src="https://i.loli.net/2021/01/22/cAOmhzBoknJZ7qe.png" alt="image-20210122190033739" style="zoom:50%;" />

##### 3.2 Mapleall for C/C++

https://gitee.com/openarkcompiler-incubator/mapleall 该项目是华为的孵化器项目，用来编译运行C/C++程序的项目。

`bin/ast2mpl`是方舟编译器针对C的前端，用来将clangAST转化为方舟编译器的IR Maple，但是并没开源，是直接上传的二进制。

```bash
cd mapleall
make setup
# choose one of the following four options
source envsetup.sh arm release # for aarch64 target.s
source envsetup.sh engine release # for maple engine target.s
source envsetup.sh ark release # the same as engine
source envsetup.sh riscv release # for riscv target.s
# ---
make 
make install
```

生成的二进制文件在`bin`目录下，每种编译方式对应不同目录`aarch64-clang-release`或`ark-clang-release`：

- ast2mpl
- irbuild
- maple
- mplcg

若要运行C程序，执行如下命令

```bash
source envsetup.sh arm release # for aarch64 target.s
make 
make install
```

进入`examples/C`目录，运行`maple_aarch64_with_ast2mpl.sh`运行例子C程序`printHuawei.c`，该编译过程使用华为的前端`ast2mpl`，将ClangAST变为Maple IR中间语言，编译过程为`.c -> .mpl -> .s -> .out`，执行的命令如下。

```bash
# printHuawei.c => printHuawei.mpl
mapleall/bin/ast2mpl printHuawei.c -I /usr/lib/gcc/x86_64-linux-gnu/8/include
# printHuawei.mpl => printHuawei.s
mapleall/bin/aarch64-clang-release/maple -exe=me,mplcg -option="-O2 --quiet:-O2 -quiet" printHuawei.mpl
# printHuawei.s => printHuawei.out
aarch64-linux-gnu-gcc -o printHuawei.out printHuawei.s
qemu-aarch64 -L /usr/aarch64-linux-gnu/ printHuawei.out
```

![image-20210118213627783](https://i.loli.net/2021/01/26/UWHA7fpgh38MOir.png)

运行`maple_aarch64_with_whirl2mpl.sh`运行例子C程序`printHuawei.c`，该编译过程使用Open64的前端，将C程序变为Whirl IR中间语言。如果自己`aarch64-linux-gnu-gcc`的版本是7的话，需要修改`whirl2mpl`这个脚本里的`FLAGS`如下所示。

```bash
FLAGS="-cc1 -emit-llvm -triple aarch64-linux-gnu -D__clang__ -D__BLOCKS__ -isystem /usr/aarch64-linux-gnu/include -isystem /usr/lib/gcc-cross/aarch64-linux-gnu/7/include"
```

运行结果如图所示，编译过程为`.c -> .B -> .bpl -> .s -> .out`。

![image-20210118215951069](https://i.loli.net/2021/01/26/hfGZSJHq8gm21iT.png)

现在我们完成了用方舟编译器编译C/C++项目的过程。

<img src="https://i.loli.net/2021/01/22/EWgLx7VaFQYSCO3.png" alt="image-20210122200756840" style="zoom:40%;" />

##### 3.3 Maple Engine for Java

https://gitee.com/openarkcompiler-incubator/maple_engine 

该项目也是一个孵化器项目，用来编译运行Java程序的项目，该项目会自动拉取编译上述mapleall项目。首先安装所需的软件包

```bash
sudo apt install -y build-essential clang cmake libffi-dev libelf-dev libunwind-dev libssl-dev openjdk8-jdk openjdk-8-jdk-headless unzip python-minimal python3 gdb bc
```

下载代码并设置Maple构建环境

```bash
git clone https://gitee.com/openarkcompiler-incubator/maple_engine.git
cd maple_engine
source ./envsetup.sh
```

构建Maple编译器和Maple Engine

```bash
./maple_build/tools/build-maple.sh
```


在另一台电脑构建定制的OpenJDK8，将构建Java核心库libcore.so和运行用户Java程序所需的如下jar文件拷贝到构建maple_engine的./maple_build/jar/目录下。[Official Document](https://gitee.com/openarkcompiler-incubator/maple_engine/blob/master/maple_build/doc/build_OpenJDK8.md)

```bash
# Java 核心库
rt.jar (customized)
charsets.jar
jce.jar
jsse.jar
```
其中一个组件 rt.jar 是方舟引擎定制版. 要生成方舟引擎定制版的 rt.jar 文件, 需要修改 OpenJDK-8 的 Object.java ，然后从源代码构建OpenJDK-8。首先安装以下依赖，

```bash
sudo apt install mercurial build-essential cpio zip libx11-dev libxext-dev libxrender-dev \
      libxtst-dev libxt-dev libcups2-dev libfreetype6-dev libasound2-dev libfontconfig1-dev
```

下载OpenJDK-8的源码，在运行maple engine的电脑上查看安装的OpenJDK-8-JRE的修订版本号

```bash
$ apt list openjdk-8-jre
Listing... Done
openjdk-8-jre/bionic-updates,bionic-security,now 8u275-b01-0ubuntu1~18.04 amd64 [installed]
N: There is 1 additional version. Please use the '-a' switch to see it
```
根据上述命令输出的版本号在构建定制OpenJDK8的电脑上执行下述命令，下载源码

```bash
hg clone http://hg.openjdk.java.net/jdk8u/jdk8u -r jdk8u275-b01 ~/my_openjdk8
cd ~/my_openjdk8
bash ./get_source.sh
```

修改` ~/my_openjdk8/jdk/src/share/classes/java/lang/Object.java`文件，插入如下字段声明：

```java
public class Object {
    long reserved_1; int reserved_2; // Add two extra fields here  在这添加两个额外字段
    private static native void registerNatives();
```

构建定制的OpenJDK-8

```bash
cd ~/my_openjdk8
bash ./configure
export DISABLE_HOTSPOT_OS_VERSION_CHECK=ok
make all
```

把如下的已经构建好的.jar文件复制到运行maple engine机器上的目录maple_build/jar/ 下：

```
build/linux-x86_64-normal-server-release/images/lib/rt.jar
build/linux-x86_64-normal-server-release/images/lib/jce.jar
build/linux-x86_64-normal-server-release/images/lib/jsse.jar
build/linux-x86_64-normal-server-release/images/lib/charsets.jar
```

修改`maple_build/tools/build-libcore.sh`中的`-bootclasspath`为` -sourcepath`，执行如下命令构建Java核心库

```bash
./maple_build/tools/build-libcore.sh
```

所有编译用户程序所需代码在目录maple_runtime/lib/x86_64目录下，主要就是`libcore.so`，另外还有几个工具用来编译运行java程序，在`maple_build/tools`目录下：

- java2asm.sh
  - javac: java to java bytecode
  - jbc2mpl: java bytecode to maple
  - maple: maple to assembly
- asm2so.sh
  - g++: .s -> .o -> .so
- run-app.sh

给定如下Java程序

```java
public class HelloWorld {

  public static void main(String[] args) {
    System.out.println("Hello World!");
  }
}
```


执行如下命令对其进行编译

```bash
# MAPLE_BUILD_TOOLS = maple_build/tools
cd maple_build/examples/HelloWorld
# .java -> .mpl -> .s
"$MAPLE_BUILD_TOOLS"/java2asm.sh HelloWorld.java
# .s -> .so
"$MAPLE_BUILD_TOOLS"/asm2so.sh HelloWorld.s
```

执行如下命令运行该程序

```bash
"$MAPLE_BUILD_TOOLS"/run-app.sh -classpath ./HelloWorld.so HelloWorld
```

<img src="https://i.loli.net/2021/01/26/QmrfZsvKB9TLFCX.png" style="zoom:87%;" />

调试应用程序

```bash
"$MAPLE_BUILD_TOOLS"/run-app.sh -gdb -classpath ./HelloWorld.so HelloWorld
```

Now, we are able to compile and run both Java and C/C++ programs. The compilation process for Java is shown below:

<img src="https://i.loli.net/2021/01/23/9fhxQqVCrjY8LmR.png" alt="image-20210123152622279" style="zoom: 43%;" />

The compilation process for C/C++ is shown below:

<img src="https://i.loli.net/2021/01/23/FHrMeEnm86cdbfi.png" alt="image-20210123152952757" style="zoom:43%;" />

#### 4. Phase介绍

官方Phase介绍 https://gitee.com/openarkcompiler/OpenArkCompiler/blob/master/doc/cn/CompilerPhaseDescription.md

方舟编译器引入了一个phase的概念，这个概念有点类似于LLVM的pass，用于管理方舟编译器的优化。方舟编译器实现三级管理机制，InterleavedManager负责PhaseManager的创建、管理和运行；PhaseManager负责Phase的创建、管理和运行。

<img src="https://i.loli.net/2021/01/20/gEvT3aWi8j1HVbq.png" alt="image-20210120164825674" style="zoom:40%;" />

##### 4.1 自定义Phase类

Phase的核心是重载Run函数，类似于LLVM Pass的runOnXXX函数。Phase中端主要包含两大类ModulePhase和MeFuncPhase，都继承自Phase类。ModulePhase的定义在`src/maple_ipa/include/module_phase.h`，MeFuncPhase的定义在`src/maple_me/include/me_phase.h`中。当添加一个新的phase的时候，必须要实现一个Run方法，并重写PhaseName方法返回名字，例子如下：

定义新的Function Phase

```c++
namespace maple { 
class MeDoExample : public MeFuncPhase { // 继承MeFuncPhase 
public:
    explicit MeDoExample(MePhaseID id) : MeFuncPhase(id) {};
    virtual ~MeDoExample() = default;
    // 需要重载的函数
    AnalysisResult *Run(MeFunction *func, MeFuncResultMgr *m, ModuleResultMgr *mrm) override;
    // 重写该函数的返回值
    std::string PhaseName() const override {  
        return "me_example";
    }
};
} // namespace maple
```

定义新的Module Phase

```C++
namespace maple { 
class DoExample : public ModulePhase { // 继承ModulePhase
public:
    explicit DoExample(ModulePhaseID id) : ModulePhase(id) {};
    ~DoExample() = default;
    // 需要重载的函数
    AnalysisResult *Run(MIRModule *module, ModuleResultMgr *mgr) override;
    // 重写该函数的返回值
    std::string PhaseName() const override {
        return "example";
    }
};
}  // namespace maple
```

The role that `Run` method plays is the same as `runOnXXX` method places in LLVM Pass. 

##### 4.2 PhaseManager

和LLVM Pass一样，Phase都是由Manager类来管理。PhaseManager负责phase的创建、管理和运行。ModulePhase和MeFuncPhase都有对应的Manager类，分别是ModulePhaseManager和MeFuncPhaseManager，他们都是PhaseManager类的子类。Phase使用了宏的机制来实现注册，便于管理需要注册的phase。

ModulePhase有一个对应的`module_phases.def`文件定义系统内部的module phase。ModulePhaseManager调用`RegisterModulePhases`函数注册定义在`src/maple_ipa/include/module_phases.def`中的phase，`module_phases.def`的内容如下：

```
MODAPHASE(MoPhase_CLONE, DoClone)
MODAPHASE(MoPhase_CHA, DoKlassHierarchy)
...
```

`MODAPHASE`第一个参数是id，第二个是phase类名，需要添加自定义的`DoExample`时，只需添加如下一行：

```
MODAPHASE(MoPhase_Example, DoExample)
```

MeFuncPhase有对应的`me_phases.def`文件。MeFuncPhaseManager调用`RegisterFuncPhases`函数注册定义在`src/maple_me/include/me_phases.def`中的phase，`me_phases.def`的内容如下：

```makefile
FUNCAPHASE(MeFuncPhase_DOMINANCE, MeDoDominance)
FUNCAPHASE(MeFuncPhase_SSATAB, MeDoSSATab)
...
```

`FUNCAPHASE`第一个参数是id，第二个是phase类名，需要自定义的`MeDoExample`时，只需添加如下一行：

```
FUNCTPHASE(MeFuncPhase_Example, MeDoExample)
```

注册Phase后，会调用基类PhaseManager的AddPhase函数添加自定义的phase。

##### 4.3  InterleavedManager && DriverRunner

除了使用上面的方式自行添加phase外，还需要借助InterleavedManager和DriverRunner组成的框架对添加自定义Phase。

InterleavedManager负责phase manager的创建、管理和运行。通过调用AddPhases接口，它将创建一个对应类型的phase manager并添加进MapleVector中, 同时该phase manager相应的phase注册、添加也会自动被触发。

DriverRunner包含了从一个mpl文件到优化结果文件的所有过程。

- ParseInput方法负责解析mpl文件，为后续mpl2mpl做准备工作，也为支持phase的运行

- ProcessMpl2mplAndMePhases方法通过InterleavedManager加载`phases.def`，实现phase的管理和运行，

DriverRunner也是通过宏的方式来集中管理phase，在`phases.def`文件里添加phase，然后通过InitPhases接口来遍历所有的phase并创建对应的phase manager。`phases.def`文件内容如下：

```
// Phase arguments are: name, condition. By default, all phases are required, so the condition value is 'true'.
// You can use condition to control these phases and your custom phases. E.g. ADD_PHASE("custom_phase", option1 == value1 [more conditions...])
ADD_PHASE("clone", true)
ADD_PHASE("vtableanalysis", true)
...
ADD_PHASE("CodeReLayout", MeOption::optLevel == 2)
```

第一个参数是phase名字，第二个参数是条件。现有的phase默认都是enable的，对于自定义的phase可以自行添加控制条件。

##### 4.4 Phase运行机制

maple指令中的运行的mpl2mpl2和maple这两个过程是通过执行ModulePhase和MeFuncPhase这两类phase来实现的。mpl2mpl的优化对应着ModulePhase这类的phase，mplme的优化对应着MeFuncPhase这类phase。

```bash
➜  helloworld git:(master) ✗ maple --run=me:mpl2mpl --option=" --O2 --quiet: --O2 --quiet --regnativefunc --no-nativeopt --maplelinker --emitVtableImpl" ./HelloWorld.mpl
Starting mpl2mpl&mplme
Starting:./maple --run=me:mpl2mpl --option=" --O2 --quiet: --O2 --quiet --regnativefunc --no-nativeopt --maplelinker --emitVtableImpl" ./HelloWorld.mpl
Starting parse input
Parse consumed 0s
Processing mpl2mpl&mplme
[mpl2mpl] Module phases cost 117ms
[me] Function phases cost 0ms
[mpl2mpl] Module phases cost 17ms
 Mpl2mpl&mplme consumed 0s
```

maple包含了多个compiler，包括jbc2mpl、me、mpl2mpl、mplcg，其参数列表之中的--run选项显示如下。

<img src="https://i.loli.net/2021/01/20/9JdCpVYWc2GDzS1.png" alt="image-20210120190522535" style="zoom:70%;" />

maple运行过程中会直接调用这几个compiler，但jbc2mpl还是用的bin目录下的。

![image-20210120190802474](https://i.loli.net/2021/01/20/P1KRtkcwfdImuZY.png)

1. (src/maple_driver/src/maple.cpp) main <= Entry point of maple

   - CompilerFactory: :GetInstance().Compile(mplOptions)

2. CompilerFactory构造函数：add the following compiler to supported compiler

   - ADD_COMPILER("jbc2mpl", Jbc2MplCompiler)
   - ADD_COMPILER("me", MapleCombCompiler)
   - ADD_COMPILER("mpl2mpl", MapleCombCompiler)
   - ADD_COMPILER("mplcg", MplcgCompiler)

3. CompilerFactory.Compiler

   - compiler = compilerSelector.Select
   - compiler.Compile

4. MapleCombCompiler.Compile

   - DriverRunner.Run

5. DriverRunner.Run

   - DriverRunner.ParseInput：解析mpl文件
   - DriverRunner.ProcessMpl2mplAndMePhases

6. DriverRunner.ProcessMpl2mplAndMePhases

   - DriverRunner.InitPhases：添加`phases.def`中的Phase，并根据其类型添加到各自的Phase Manager的数据结构中
     - InterleavedManager.AddPhases
   - InterleavedManager.run
     - ModulePhaseManager.run
     - MeFuncPhaseManager.run

7. InterleavedManager.AddPhases

   - ModulePhase
     - ModulePhaseManager.RegisterModulePhases `module_phases.def`
     - ModulePhaseManager.AddModulePhases

   - MeFuncPhase
     - MeFuncPhaseManager.RegisterFuncPhases ``me_phases.def``
     - MeFuncPhaseManager.AddPhasesNoDefault

#### 5. 自定义Phase

##### 5.1 自定义Module Phase

在`src/mapleall/mpl2mpl/`目录下写入自定义的ModulePhase，创建继承`ModulePhase`的类`DoExample`，头文件`example.h`和cpp文件`example.cpp`如下：

```C++
// src/mapleall/mpl2mpl/src/example.h

#include "module_phase.h"

namespace maple {
class DoExample : public ModulePhase {
public:
	explicit DoExample(ModulePhaseID id) : ModulePhase(id) { };
	~DoExample() = default;

	std::string PhaseName() const override {
		return "example";
	}

	AnalysisResult *Run(MIRModule *mod, ModuleResultMgr* mrm) override;
};
}
```

该Phase仅输出当前module的entry function名。

```C++
// src/mapleall/mpl2mpl/src/example.cpp

#include "example.h"
namespace maple {
AnalysisResult *DoExample::Run(MIRModule *module, ModuleResultMgr *mgr) {
	LogInfo::MapleLogger() << "Harper" << module->GetEntryFuncName();
	return nullptr;
}
}
```

在`src/mapleall/mpl2mpl/BUILD.gn`中将该类添加至被编译的对象中

```
# src/mapleall/mpl2mpl/BUILD.gn
src_libmpl2mpl = [
  "src/class_init.cpp",
  ...
  "src/example.cpp"
]
```

在Module Phase对应的文件中`src/mapleall/maple_ipa/include/module_phases.def`中加入自定义的Phase

```
MODAPHASE(MoPhase_Example, DoExample)
```

相应的，在`src/mapleall/maple_ipa/src/module_phase_manager.cpp`中加入头文件

```c++
#include "module_phase_manager.h"
...
#include "call_graph.h"
#include "example.h"       // <== example.h
```

在全局Phase文件`src/mapleall/maple_driver/defs/phases.def`中添加自定义的Phase

```bash
ADD_PHASE("example", true)
```

在OpenArk Compiler主目录执行如下命令，重新编译maple

```bash
make maple
```

进入`samples/helloworld`目录下，依次执行如下命令

```bash
# HelloWorld.java => HelloWorld.class => HelloWorld.jar
java2jar HelloWorld.jar /home/harper/Projects/OpenArkCompiler/output/aarch64-clang-release/libjava-core/java-core.jar "HelloWorld.java"
# HelloWorld.jar => HelloWorld.mpl, HelloWorld.mpltls 
jbc2mpl -mplt /home/harper/Projects/OpenArkCompiler/output/aarch64-clang-release/libjava-core/java-core.mplt  HelloWorld.jar
# HelloWorld.mpl => HelloWorld.VtableImpl.mpl
maple --run=me:mpl2mpl --option=" --O2 --quiet: --O2 --quiet --regnativefunc --no-nativeopt --maplelinker --emitVtableImpl" ./HelloWorld.mpl
```

运行情况如下，我们可以看到在最后一步，输出了我们自己编写Phase的信息`HarperLHelloWorld_3B_7Cmain_7C_28ALjava_2Flang_2FString_3B_29V`。

![image-20210121183226924](https://i.loli.net/2021/01/21/WwgG4Ntye2fzR9X.png)

##### 5.2 自定义Function Phase

在`src/mapleall/maple_me/`目录下写入自定义的MeFuncPhase，创建继承`MeFuncPhase`的`MeDoMeExample`类，头文件`me_example.h`和cpp文件`me_example.cpp`如下：

```C++
// src/mapleall/maple_me/include/me_example.h

#include "me_phase.h"

namespace maple {
class MeDoMeExample: public MeFuncPhase {
public:
	explicit MeDoMeExample(MePhaseID id) : MeFuncPhase(id) {};
	virtual ~MeDoMeExample() = default;

	AnalysisResult *Run(MeFunction *func, MeFuncResultMgr *m, ModuleResultMgr *mrm) override;
	std::string PhaseName() const override {
		return "me_example";
	}
};
}
```

当前只输出每个函数的名称。

```C++
// src/mapleall/maple_me/src/me_example.cpp

#include "me_example.h"
#include "me_function.h"

namespace maple {
AnalysisResult *MeDoMeExample::Run(MeFunction *func, MeFuncResultMgr *m, ModuleResultMgr *mrm) {
	LogInfo::MapleLogger() << "Harper " << func->GetName() << "\n";
	return nullptr;
}
}
```

在`src/mapleall/maple_me/BUILD.gn`文件中添加`me_example.cpp`到被编译的对象中，

```
src_libmplme = [
  "src/dse.cpp",
  ...
  "src/me_example.cpp" <== new phase
]
```

在定义Function Phase的文件`src/mapleall/maple_me/include/me_phases.def`中加入如下信息

```
FUNCAPHASE(MeFuncPhase_DOEXAMPLE, MeDoMeExample)
```

并在相应`src/mapleall/maple_me/src/me_phase_manager.cpp`中加入头文件

```c++
#include "me_example.h"
```

最后在全局Phase文件`src/mapleall/maple_driver/defs/phases.def`中加入该Phase

```
ADD_PHASE("me_example", true)
```

在OpenArk Compiler主目录执行如下命令，重新编译maple

```bash
make maple
```

进入`samples/helloworld`目录下，依次执行如下命令

```bash
# HelloWorld.java => HelloWorld.class => HelloWorld.jar
java2jar HelloWorld.jar /home/harper/Projects/OpenArkCompiler/output/aarch64-clang-release/libjava-core/java-core.jar "HelloWorld.java"
# HelloWorld.jar => HelloWorld.mpl, HelloWorld.mpltls 
jbc2mpl -mplt /home/harper/Projects/OpenArkCompiler/output/aarch64-clang-release/libjava-core/java-core.mplt  HelloWorld.jar
# HelloWorld.mpl => HelloWorld.VtableImpl.mpl
maple --run=me:mpl2mpl --option=" --O2 --quiet: --O2 --quiet --regnativefunc --no-nativeopt --maplelinker --emitVtableImpl" ./HelloWorld.mpl
```

运行情况如下，我们可以看到在最后一步，输出了我们自己编写Phase的信息。

![image-20210121193556088](https://i.loli.net/2021/01/21/9qe5yaCPNSxb2pV.png)

#### 7. 插桩示例

接下来，我们做一些插桩的工作，针对如下c文件，我们希望在main函数中添加第12行对函数f1的调用。

```C++
#include<stdio.h>
 
void f1(){
    printf("f1\n");
}
 
int f2(){
    printf("f2\n");
    return 0;
}
int main() {
    // f1(); <== to be added 
	f2();
	return 0;
}
```

我们先进入mapleall目录下，执行`ast2mpl`命令，先获得该文件对应的maple IR

```bash
./bin/ast2mpl test.c -I /usr/lib/gcc/x86_64-linux-gnu/8/include
```

该文件IR如下，我们需要在14行添加`call &f1()`

```
# ast2mpl test.c -I /usr/lib/gcc/x86_64-linux-gnu/8/include
func &main public () i32 {
  funcid 110
  funcinfo {
    @INFO_funcname "main",
    @INFO_signature "main|",
    @INFO_classname "",
    @INFO_fullname "main|()I"}

  var %retvar_12 i32
  var %retvar_13 i32

LOC 2 12
  #call &f1()  <== to be added
  #f2();
  callassigned &f2 () { dassign %retvar_13 0 }
LOC 2 13
  #return 0;
  return (constval i32 0)
}
```

我们定义如下`MeDoMeExample`类，继承自`MeFuncPhase`，该类每次操作一个函数. We create header file `me_example.h`and cpp file `me_example.cpp` in directory `src/mapleall/maple_me/include` and `src/mapleall/maple_me/src` respectively. This is the traditional directory in which Huawei developers put all exsiting function phases. The header file is shown as below

```c++
// src/mapleall/maple_me/include/me_example.h
#include "me_phase.h"

namespace maple {
class MeDoMeExample: public MeFuncPhase { // inherit from MeFuncPhase 
public:
	explicit MeDoMeExample(MePhaseID id) : MeFuncPhase(id) {};
	virtual ~MeDoMeExample() = default;
    // implement Run method
	AnalysisResult *Run(MeFunction *func, MeFuncResultMgr *m, ModuleResultMgr *mrm) override;
	std::string PhaseName() const override {  // override PhaseName method
		return "me_example"; 
	}
};

```

The cpp file is a little complex. Because this phase is a function phase, so the `Run` method will be executed for each function. The first step is to check if current function is main function.

```c++
#include "me_example.h"
#include "me_function.h"

namespace maple {
AnalysisResult *MeDoMeExample::Run(MeFunction *func, MeFuncResultMgr *m, ModuleResultMgr *mrm) {
	if (func->GetName() == "main") {
		LogInfo::MapleLogger() << "Harper " << func->GetName() <<  "\n";
        ... // instrumentation work
	}
	return nullptr;
}
}
```

Then, we need to get the statememt `callassigned &f2 () { dassign %retvar_13 0 }` that calls function f2, so that we can insert new call statement before it. We traverse every statement in every basic block using two loops. By checking if the opcode of a statement is `OP_call` or `OP_callassigned`, we can easily find the statement `callassigned &f2()`. Once the statement to be inserted before is found, we dump current basic block before and after instrumentation to check if we succeed.

```C++
for (auto &bb : func->GetAllBBs()) { // for each basic block
    for (auto &stmt : bb->GetStmtNodes()) { // for each statement
        if (stmt.GetOpCode() == OP_call || stmt.GetOpCode() == OP_callassigned) {
            bb->Dump(&func->GetMIRModule()); // dump the basic block before instrumentation
            ... // instumentation work
            bb->Dump(&func->GetMIRModule()); // dump the basic block before instrumentation
        }
    }
}
```

The core instrumentation logic is shown as below. Because `StmtNode` is the base class of all types of node, to access the methods of statement with specific type, we cast `stmt` to type `CallNode`.  Then we access the target function called by statement `callassigned &f2 () { dassign %retvar_13 0 }` using `PUIdx`. 

From line 4, we can see that each function is a program unit and are given a unique id to index. All functions are declared at global declaration part, therefore we can get a function by looking for the global function table using `Puidx`. Now we have function `f2`, the only question left is how to access function `f1` so that we can create a call statement to invoke it.

```C++
CallNode *callNode = static_cast<CallNode*>(&stmt); // cast stmt to callnode type

// get the target function called by statement `callassigned &f2 () { dassign %retvar_13 0 }`, which is f2
MIRFunction *fn = GlobalTables::GetFunctionTable().GetFunctionFromPuidx(callNode->GetPUIdx()); 
```

We achieve this by iterate all functions in this module, and check if current function is neither main function, nor f2. Once we get the variable `mirFunc`that corresponds to function `f1`, we create a callstmt with type `CallNode` at line 4. The opcode of this statement is set to be `OP_call`. This statement currently doesn't have any target. Therefore, we set its target using method `SetPUIdx` with parameter `mirFunc->GetPuidx()`, which is exacly f1. Finally, we insert the newly created statement `callStmt` before the statement that calls function f2 `stmt` at line 10. Now, all programming is done. 

```C++
for (auto &mirFunc: func->GetMIRModule().GetFunctionList()) { // iterate all functions in current mode
    if (mirFunc->GetName() != "main" && mirFunc->GetName() != fn->GetName()) { // to find function f1
        // create a empty call statement
        CallNode *callStmt = func->GetMIRModule().CurFuncCodeMemPool()->New<CallNode>(func->GetMIRModule(), OP_call);
        // set the target of call statement to be f1.
        callStmt->SetPUIdx(mirFunc->GetPuidx());							
        // insert function call f1 before function call f2
        // stmt: callassigned &f2 () { dassign %retvar_13 0 }
        // callStmt: call &f1()
        bb->InsertStmtBefore(&stmt, callStmt);
    }
}
```

To include this phase into the target to be compiled, we add the new phase `me_example.cpp`to the ninja build file `src/mapleall/maple_me/BUILD.gn`.

```java
// src/mapleall/maple_me/BUILD.gn
src_libmplme = [
  "src/dse.cpp",
  ...
  "src/me_example.cpp" <== new phase
]
```

As shown above, we need to register this phase by adding the following lines in corresponding `.def` files.

```java
// add this line to src/mapleall/maple_me/include/me_phases.def
FUNCAPHASE(MeFuncPhase_DOEXAMPLE, MeDoMeExample)

// add this line to src/mapleall/maple_driver/defs/phases.def
ADD_PHASE("me_example", true)
```

We further need to include the new header file `me_example.h` in function phase manager `src/mapleall/maple_me/src/me_phase_manager.cpp` to pass compilation.

```c++
#include "me_example.h"
```

The last step is executing `make maple` in the root directory of OpenArk Compiler to integrate this phase into executable `maple`.

To verify if the instrumentation succeed, we execute `maple` in the following way. The run option is specifed as `--run=me&mpl2mpl` to perform optimization in function level and module level.

```bash
$> maple --run=me:mpl2mpl -option="-O2 --quiet:-O2 -quiet" test.mpl
Starting mpl2mpl&mplme
Starting:./maple --run=me:mpl2mpl --option=" --O2 --quiet: --O2 --quiet" test.mpl
Starting parse input
Parse consumed 0s
Processing mpl2mpl&mplme
[mpl2mpl] Module phases cost 0ms
Harper main
# Before instrumentation
============BB id:2 return [ Entry  Exit ]===============
preds:
succs:
LOC 2 12
  #f2();
  callassigned &f2 () { dassign %retvar_13 0 }
LOC 2 13
  #return 0;
  return (constval i32 0)
callassigned
f2
LOC 2 12
  callassigned &f2 () { dassign %retvar_13 0 }
  
# After instrumentation
============BB id:2 return [ Entry  Exit ]===============
preds:
succs:
  #f2();
  call &f1 ()    # <== instrument successfully
  callassigned &f2 () { dassign %retvar_13 0 }
LOC 2 13
  #return 0;
  return (constval i32 0)
[me] Function phases cost 0ms
[mpl2mpl] Module phases cost 0ms
[me] Function phases cost 0ms
[mpl2mpl] Module phases cost 0ms
 Mpl2mpl&mplme consumed 0s
```

From the output log, we know that `maple` processes module phase 3 times (line 7, line 35, line 37) and processes function phase two times (line 34, line 36). Our instrumentation phase is invoked at the first time of processing funtion phase. Before processing our customized phase, there is only a function call at line 15, whereas, there are two function call at line 29, 30 after instrumention. 

To double check if we succeed, the maple IR of function main in the output maple file `test.Vtablempl.mpl` is shown below. We can see there is a new statement at line 12 to invoke function f1. 

```
func &main public () i32 {
  funcid 110
  funcinfo {
    @INFO_funcname "main",
    @INFO_signature "main|",
    @INFO_classname "",
    @INFO_fullname "main|()I"}


LOC 2 12
  #f2();
  call &f1 () # <== succeed!
  callassigned &f2 () {}
LOC 2 13
  #return 0;
  intrinsiccall MPL_CLEANUP_LOCALREFVARS ()
  return (constval i32 0)
}
```

Finally, we compile this maple file to assembly code using `maple` with option `--run=mplcg`, further to executable using `aarch64-linux-gnu-gcc`and check if it can output "f1f2 by running `test.out` in qemu.

<img src="https://i.loli.net/2021/01/23/kbasN7np3Ry4d8Y.png" alt="image-20210123135021782" style="zoom:50%;" />

The result shows that "f1f2" is successfully outputed, and we can do instrumentation using the framework of OpenArk Compiler.

#### Reference

1. 知乎专栏 https://zhuanlan.zhihu.com/openarkcompiler
2. https://zhuanlan.zhihu.com/p/80624361
3. 官方IR Maple的设计文档 https://gitee.com/openarkcompiler/OpenArkCompiler/blob/master/doc/en/MapleIRDesign.md
4. https://gitee.com/openarkcompiler-incubator/mapleall/blob/dev/doc/maple_ir_spec.md
5. Fred Chow的论文https://queue.acm.org/detail.cfm?id=2544374
6. 比较完整的知乎文章 https://zhuanlan.zhihu.com/p/137526426

