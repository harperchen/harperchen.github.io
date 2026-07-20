---
title: Linux Program Startup
date: 2021-04-10 18:02:20
tags:
    - Kernel
categories: Techniques
---
原文链接 https://luomuxiaoxiao.com/?p=516

本文介绍main函数如何被执行，并理解如何通过debug了解main函数启动前发生的事情

<!--more-->

#### 1. main函数的调用

我们将编译一个最简单的C程序——空的`main`函数，然后，查看其反汇编代码以理解程序是如何从启动开始调用到main函数。

```c++
int main()
{
}
```

将上述代码保存为`prog1.c`，首先要做的是使用下面的命令编译这个文件：

```bash
gcc -ggdb -o prog1 prog1.c
```

我们首先查看其反汇编代码，通过这个程序来查看关于程序启动的一些过程，然后再用GDB去调试比这个版本稍微复杂一点的程序`prog2`。使用命令`objdump -d prog1 > prog1.dump`，就能保存objdump的输出，从反汇编代码中，我们发现程序是由一个`_start`函数最终调用`main`函数执行的。

```assembly

prog1:     file format elf64-x86-64


Disassembly of section .init:

00000000000004b8 <_init>:
 4b8:	48 83 ec 08          	sub    $0x8,%rsp
 4bc:	48 8b 05 25 0b 20 00 	mov    0x200b25(%rip),%rax        # 200fe8 <__gmon_start__>
 4c3:	48 85 c0             	test   %rax,%rax
 4c6:	74 02                	je     4ca <_init+0x12>
 4c8:	ff d0                	callq  *%rax
 4ca:	48 83 c4 08          	add    $0x8,%rsp
 4ce:	c3                   	retq   

Disassembly of section .plt:

00000000000004d0 <.plt>:
 4d0:	ff 35 f2 0a 20 00    	pushq  0x200af2(%rip)         # 200fc8 <_GLOBAL_OFFSET_TABLE_+0x8>
 4d6:	ff 25 f4 0a 20 00    	jmpq   *0x200af4(%rip)        # 200fd0 <_GLOBAL_OFFSET_TABLE_+0x10>
 4dc:	0f 1f 40 00          	nopl   0x0(%rax)

Disassembly of section .plt.got:

00000000000004e0 <__cxa_finalize@plt>:
 4e0:	ff 25 12 0b 20 00    	jmpq   *0x200b12(%rip)        # 200ff8 <__cxa_finalize@GLIBC_2.2.5>
 4e6:	66 90                	xchg   %ax,%ax

Disassembly of section .text:

00000000000004f0 <_start>:
 4f0:	31 ed                	xor    %ebp,%ebp
 4f2:	49 89 d1             	mov    %rdx,%r9
 4f5:	5e                   	pop    %rsi
 4f6:	48 89 e2             	mov    %rsp,%rdx
 4f9:	48 83 e4 f0          	and    $0xfffffffffffffff0,%rsp
 4fd:	50                   	push   %rax
 4fe:	54                   	push   %rsp
 4ff:	4c 8d 05 7a 01 00 00 	lea    0x17a(%rip),%r8        # 680 <__libc_csu_fini>
 506:	48 8d 0d 03 01 00 00 	lea    0x103(%rip),%rcx       # 610 <__libc_csu_init>
 50d:	48 8d 3d e6 00 00 00 	lea    0xe6(%rip),%rdi        # 5fa <main>
 514:	ff 15 c6 0a 20 00    	callq  *0x200ac6(%rip)        # 200fe0 <__libc_start_main@GLIBC_2.2.5>
 51a:	f4                   	hlt    
 51b:	0f 1f 44 00 00       	nopl   0x0(%rax,%rax,1)

0000000000000520 <deregister_tm_clones>:
 520:	48 8d 3d e9 0a 20 00 	lea    0x200ae9(%rip),%rdi        # 201010 <__TMC_END__>
 ...
 55d:	00 00 00 

0000000000000560 <register_tm_clones>:
 560:	48 8d 3d a9 0a 20 00 	lea    0x200aa9(%rip),%rdi        # 201010 <__TMC_END__>
 ...
 5ad:	00 00 00 

00000000000005b0 <__do_global_dtors_aux>:
 5b0:	80 3d 59 0a 20 00 00 	cmpb   $0x0,0x200a59(%rip)        # 201010 <__TMC_END__>
 5b7:	75 2f                	jne    5e8 <__do_global_dtors_aux+0x38>
 5b9:	48 83 3d 37 0a 20 00 	cmpq   $0x0,0x200a37(%rip)        # 200ff8 <__cxa_finalize@GLIBC_2.2.5>
 5c0:	00 
 5c1:	55                   	push   %rbp
 5c2:	48 89 e5             	mov    %rsp,%rbp
 5c5:	74 0c                	je     5d3 <__do_global_dtors_aux+0x23>
 5c7:	48 8b 3d 3a 0a 20 00 	mov    0x200a3a(%rip),%rdi        # 201008 <__dso_handle>
 5ce:	e8 0d ff ff ff       	callq  4e0 <__cxa_finalize@plt>
 5d3:	e8 48 ff ff ff       	callq  520 <deregister_tm_clones>
 5d8:	c6 05 31 0a 20 00 01 	movb   $0x1,0x200a31(%rip)        # 201010 <__TMC_END__>
 5df:	5d                   	pop    %rbp
 5e0:	c3                   	retq   
 5e1:	0f 1f 80 00 00 00 00 	nopl   0x0(%rax)
 5e8:	f3 c3                	repz retq 
 5ea:	66 0f 1f 44 00 00    	nopw   0x0(%rax,%rax,1)

00000000000005f0 <frame_dummy>:
 5f0:	55                   	push   %rbp
 5f1:	48 89 e5             	mov    %rsp,%rbp
 5f4:	5d                   	pop    %rbp
 5f5:	e9 66 ff ff ff       	jmpq   560 <register_tm_clones>

00000000000005fa <main>:
 5fa:	55                   	push   %rbp
 5fb:	48 89 e5             	mov    %rsp,%rbp
 5fe:	b8 00 00 00 00       	mov    $0x0,%eax
 603:	5d                   	pop    %rbp
 604:	c3                   	retq   
 605:	66 2e 0f 1f 84 00 00 	nopw   %cs:0x0(%rax,%rax,1)
 60c:	00 00 00 
 60f:	90                   	nop

0000000000000610 <__libc_csu_init>:
 610:	41 57                	push   %r15
 612:	41 56                	push   %r14
 614:	49 89 d7             	mov    %rdx,%r15
 617:	41 55                	push   %r13
 619:	41 54                	push   %r12
 61b:	4c 8d 25 ce 07 20 00 	lea    0x2007ce(%rip),%r12        # 200df0 <__frame_dummy_init_array_entry>
 622:	55                   	push   %rbp
 623:	48 8d 2d ce 07 20 00 	lea    0x2007ce(%rip),%rbp        # 200df8 <__init_array_end>
 62a:	53                   	push   %rbx
 62b:	41 89 fd             	mov    %edi,%r13d
 62e:	49 89 f6             	mov    %rsi,%r14
 631:	4c 29 e5             	sub    %r12,%rbp
 634:	48 83 ec 08          	sub    $0x8,%rsp
 638:	48 c1 fd 03          	sar    $0x3,%rbp
 63c:	e8 77 fe ff ff       	callq  4b8 <_init>
 641:	48 85 ed             	test   %rbp,%rbp
 644:	74 20                	je     666 <__libc_csu_init+0x56>
 646:	31 db                	xor    %ebx,%ebx
 648:	0f 1f 84 00 00 00 00 	nopl   0x0(%rax,%rax,1)
 64f:	00 
 650:	4c 89 fa             	mov    %r15,%rdx
 653:	4c 89 f6             	mov    %r14,%rsi
 656:	44 89 ef             	mov    %r13d,%edi
 659:	41 ff 14 dc          	callq  *(%r12,%rbx,8)
 65d:	48 83 c3 01          	add    $0x1,%rbx
 661:	48 39 dd             	cmp    %rbx,%rbp
 664:	75 ea                	jne    650 <__libc_csu_init+0x40>
 666:	48 83 c4 08          	add    $0x8,%rsp
 66a:	5b                   	pop    %rbx
 66b:	5d                   	pop    %rbp
 66c:	41 5c                	pop    %r12
 66e:	41 5d                	pop    %r13
 670:	41 5e                	pop    %r14
 672:	41 5f                	pop    %r15
 674:	c3                   	retq   
 675:	90                   	nop
 676:	66 2e 0f 1f 84 00 00 	nopw   %cs:0x0(%rax,%rax,1)
 67d:	00 00 00 

0000000000000680 <__libc_csu_fini>:
 680:	f3 c3                	repz retq 

Disassembly of section .fini:

0000000000000684 <_fini>:
 684:	48 83 ec 08          	sub    $0x8,%rsp
 688:	48 83 c4 08          	add    $0x8,%rsp
 68c:	c3                   	retq   

```

#### 2. _start函数分析

当你执行一个程序的时候，shell或者GUI会调用execve()，它会执行linux系统调用execve()。系统会为你设置栈，并且将`argc`，`argv`和`envp`压入栈中。文件描述符0，1和2（stdin, stdout和stderr）保留shell之前的设置。加载器会帮你完成重定位，调用你设置的预初始化函数。当所有搞定之后，控制权会传递给`_start()`，下面是使用`objdump -d prog1`输出的_start函数的内容：

```assembly
080482e0 <_start>:
80482e0:       31 ed                   xor    %ebp,%ebp
80482e2:       5e                      pop    %esi
80482e3:       89 e1                   mov    %esp,%ecx
80482e5:       83 e4 f0                and    $0xfffffff0,%esp
80482e8:       50                      push   %eax
80482e9:       54                      push   %esp
80482ea:       52                      push   %edx
80482eb:       68 00 84 04 08          push   $0x8048400
80482f0:       68 a0 83 04 08          push   $0x80483a0
80482f5:       51                      push   %ecx
80482f6:       56                      push   %esi
80482f7:       68 94 83 04 08          push   $0x8048394
80482fc:       e8 c3 ff ff ff          call   80482c4 <__libc_start_main@plt>
8048301:       f4
```

任何值`xor`自身得到的结果都是0。所以`xor %ebp,%ebp`语句会把`%ebp`设置为0。ABI（Application Binary Interface specification）推荐这么做，目的是为了标记最外层函数的页帧（frame）。

接下来，从栈中弹出栈顶的值保存到`%esi`。在最开始的时候我们把`argc`，`argv`和`envp`放到了栈里，所以现在的`pop`语句会把`argc`放到`%esi`中。这里只是临时保存一下，稍后我们会把它再次压回栈中。因为我们弹出了`argc`，所以`%ebp`现在指向的是`argv`。`mov`指令把`argv`放到了`%ecx`中，但是并没有移动栈指针。

然后，将栈指针和一个可以清除后四位的掩码做`and`操作。根据当前栈指针的位置不同，栈指针将会向下移动0到15个字节。这么做，保证了任何情况下，栈指针都是16字节的偶数倍对齐的。对齐的目的是保证栈上所有的变量都能够被内存和cache快速的访问。要求这么做的是SSE，就是指令都能在单精度浮点数组上工作的那个（扩展指令集）。比如，某次运行时，`_start`函数刚被调用的时候，`%esp`处于`0xbffff770`。在我们从栈上弹出`argc`后，`%esp`指向`0xbffff774`。它向高地址移动了（往栈里存放数据，栈指针地址向下增长；从栈中取出数据，栈指针地址向上增长）。当对栈指针执行了`and`操作后，栈指针回到了`0xbffff770`。

#### 3. __libc_start_main函数

现在，我们把`__libc_start_main`函数的参数压入栈中。第一个参数`%rax`被压入栈中，里面保存了无效信息，原因是稍后会有七个参数将被压入栈中，但是为了保证16字节对齐，所以需要第八个参数。这个值也并不会被用到。`__libc_start_main`是在链接的时候从glibc复制过来的。在glibc的代码中，它位于`csu/libc-start.c`文件里。`__libc_start_main`的定义如下：

```c++
int __libc_start_main(  int (*main) (int, char * *, char * *),
                int argc, char * * ubp_av,
                void (*init) (void),
                void (*fini) (void),
                void (*rtld_fini) (void),
                void (* stack_end));
```

所以，我们期望`_start`函数能够将`__libc_start_main`需要的参数按照逆序压入栈中。

![image-20210410183824866](https://i.loli.net/2021/04/10/jC3Sv6cDNEAU8na.png)

`__libc_csu_fini`函数也是从glibc被链接进我们代码的，它的源代码位于`csu/elf-init.c`中。稍后我们会看到它。

你是否注意到我们并没有获取envp（栈里指向我们环境变量的指针）？它并不是`__libc_start_main`函数的参数。但是我们知道main函数的原型其实是`int main(int argc, char** argv, char** envp)`。所以，到底怎么回事？

其实，`__libc_start_main`函数会调用`__libc_init_first`，这个函数会使用内部信息去找到环境变量（实际上环境变量就位于`argv`的终止字符null的后面），然后设置一个全局变量`__environ`，这个全局变量可以被`__libc_start_main`函数内部任何地方使用，包括调用main函数时。当`envp`建立了之后，`__libc_start_main`函数会使用相同的小技巧，越过envp数组之后的`NULL`字符，获取另一个向量——ELF辅助向量（加载器使用它给进程传递一些信息）。

稍后本文会详细介绍__libc_start_main函数，但是，它的主要功能如下：

1. 处理关于setuid、setgid程序的安全问题
2. 启动线程
3. 把`fini`函数和`rtld_fini`函数作为参数传递给`at_exit`调用，使它们在`at_exit`里被调用，从而完成用户程序和加载器的调用结束之后的清理工作
4. 调用其`init`参数
5. 调用`main`函数，并把`argc`和`argv`参数、环境变量传递给它
6. 调用`exit`函数，并将main函数的返回值传递给它

`__libc_start_main`函数的`init`参数被设置成了`__libc_csu_init`函数，它也是被链接进我们代码的。它来源于glibc源代码中的csu/elf-init.c。

#### 4. __libc_csu_init函数

`__libc_csu_init`函数相当重要，因为它是我们可执行程序的构造函数。“等等！，我们的程序不是C++程序啊！”。是的，不是C++程序，但是构造函数和析构函数的概念并非属于C++，因为它的诞生早于C++。对于任意的可执行程序都可以有一个C函数的构造函数`__libc_csu_init`和C函数的析构函数`__libc_csu_fini`。在构造函数内部，你将会看到，可执行程序会找到全局C函数组成的构造函数集，并且调用它们。任何一个C程序都是可以有的构造函数集的。下面是`__libc_csu_init`函数的反汇编代码：

```assembly
080483a0 <__libc_csu_init>:
 80483a0:       55                      push   %ebp
 80483a1:       89 e5                   mov    %esp,%ebp
 80483a3:       57                      push   %edi
 80483a4:       56                      push   %esi
 80483a5:       53                      push   %ebx
 80483a6:       e8 5a 00 00 00          call   8048405 <__i686.get_pc_thunk.bx>
 80483ab:       81 c3 49 1c 00 00       add    $0x1c49,%ebx
 80483b1:       83 ec 1c                sub    $0x1c,%esp
 80483b4:       e8 bb fe ff ff          call   8048274 <_init>
 80483b9:       8d bb 20 ff ff ff       lea    -0xe0(%ebx),%edi
 80483bf:       8d 83 20 ff ff ff       lea    -0xe0(%ebx),%eax
 80483c5:       29 c7                   sub    %eax,%edi
 80483c7:       c1 ff 02                sar    $0x2,%edi
 80483ca:       85 ff                   test   %edi,%edi
 80483cc:       74 24                   je     80483f2 <__libc_csu_init+0x52>
 80483ce:       31 f6                   xor    %esi,%esi
 80483d0:       8b 45 10                mov    0x10(%ebp),%eax
 80483d3:       89 44 24 08             mov    %eax,0x8(%esp)
 80483d7:       8b 45 0c                mov    0xc(%ebp),%eax
 80483da:       89 44 24 04             mov    %eax,0x4(%esp)
 80483de:       8b 45 08                mov    0x8(%ebp),%eax
 80483e1:       89 04 24                mov    %eax,(%esp)
 80483e4:       ff 94 b3 20 ff ff ff    call   *-0xe0(%ebx,%esi,4)
 80483eb:       83 c6 01                add    $0x1,%esi
 80483ee:       39 fe                   cmp    %edi,%esi
 80483f0:       72 de                   jb     80483d0 <__libc_csu_init+0x30>
 80483f2:       83 c4 1c                add    $0x1c,%esp
 80483f5:       5b                      pop    %ebx
 80483f6:       5e                      pop    %esi
 80483f7:       5f                      pop    %edi
 80483f8:       5d                      pop    %ebp
 80483f9:       c3                      ret
```

#### 5. _init函数分析

当加载器将控制权交给`_start`函数之后，`_start`函数将会调用`__libc_start_main`函数，`__libc_start_main`函数会调用`__libc_csu_init`函数, `__libc_csu_init`函数会调用`_init`函数。

```assembly
08048274 <_init>:
 8048274:       55                      push   %ebp
 8048275:       89 e5                   mov    %esp,%ebp
 8048277:       53                      push   %ebx
 8048278:       83 ec 04                sub    $0x4,%esp
 804827b:       e8 00 00 00 00          call   8048280 <_init+0xc>
 8048280:       5b                      pop    %ebx
 8048281:       81 c3 74 1d 00 00       add    $0x1d74,%ebx        (.got.plt)
 8048287:       8b 93 fc ff ff ff       mov    -0x4(%ebx),%edx
 804828d:       85 d2                   test   %edx,%edx
 804828f:       74 05                   je     8048296 <_init+0x22>
 8048291:       e8 1e 00 00 00          call   80482b4 <__gmon_start__@plt>
 8048296:       e8 d5 00 00 00          call   8048370 <frame_dummy>
 804829b:       e8 70 01 00 00          call   8048410 <__do_global_ctors_aux>
 80482a0:       58                      pop    %eax
 80482a1:       5b                      pop    %ebx
 80482a2:       c9                      leave
 80482a3:       c3                      ret
```

我们来看`gmon_start`函数。如果它是空的，我们跳过它，不调用它。否则，调用它来设置profiling。该函数调用一个例程开始profiling，并且调用`at_exit`去调用另一个程序运行,并且在运行结束的时候生成gmon.out。

完成上述两者之一的某个函数之后，接下来`frame_dummy`函数会被调用。其目的是调用`__register_frame_info`函数，但是，调用`frame_dummy`是为了给上述函数设置参数。这么做的目的是为了在出错时设置unwinding stack frames。

#### 6. _do_global_ctors_aux函数分析

终于调用到`_do_global_ctors_aux`函数了。如果在调用main函数之前，你的程序出了问题，你很可能需要看看这个函数。当然，这里存放了全局C++对象的构造函数，但是，这里也能存放其他东西。

来看个例子，我们修改程序prog1，并把它叫做prog2。令人兴奋的部分是`__attribute__ ((constructor))`，它告诉GCC：链接器应该在`__do_global_ctors_aux`使用的表里创建一个指针指向这里。

```c++
#include <stdio.h>

void __attribute__ ((constructor)) a_constructor() {
    printf("%s\n", __FUNCTION__);
}

int main() {
    printf("%s\n",__FUNCTION__);
}
```

如你所见，我们编写的构造函数确实运行了（__FUNCTION__被编译器替换成了当前函数的名字，这就是GCC魅力所在）。

<img src="https://i.loli.net/2021/04/10/84hiSDVnIFjs2Jy.png" alt="image-20210410194109450" style="zoom: 43%;" />

稍后我们将使用GDB看看到底发生了什么。我们将进入prog2的_init函数。

```assembly
08048290 <_init>:
 8048290:       55                      push   %ebp
 8048291:       89 e5                   mov    %esp,%ebp
 8048293:       53                      push   %ebx
 8048294:       83 ec 04                sub    $0x4,%esp
 8048297:       e8 00 00 00 00          call   804829c <_init+0xc>
 804829c:       5b                      pop    %ebx
 804829d:       81 c3 58 1d 00 00       add    $0x1d58,%ebx
 80482a3:       8b 93 fc ff ff ff       mov    -0x4(%ebx),%edx
 80482a9:       85 d2                   test   %edx,%edx
 80482ab:       74 05                   je     80482b2 <_init+0x22>
 80482ad:       e8 1e 00 00 00          call   80482d0 <__gmon_start__@plt>
 80482b2:       e8 d9 00 00 00          call   8048390 <frame_dummy>
 80482b7:       e8 94 01 00 00          call   8048450 <__do_global_ctors_aux>
 80482bc:       58                      pop    %eax
 80482bd:       5b                      pop    %ebx
 80482be:       c9                      leave
 80482bf:       c3                      ret
```

我们可以看到，上述的地址和prog1的地址略微有所不同。这些有差异的地址似乎相对于prog1移动了28个字节。这里，有两个函数：`"a_constructor"`（加上结束符一共14个字节）、`"main"`（加上结束符一共5个字节）和两个格式化字符串`"%s\n"`（2*4个字节，加上一个1字节的换行符和终止符），所以14 + 5 + 4 + 4 = 27？ 似乎还差一个。不管怎样，这只是个猜想，我就不仔细研究了。然后我们就要跳入到`__do_global_ctors_aux`函数中去，我们列举出`__do_global_ctors_aux`函数的C代码，它位于GCC源码中的gcc/crtstuff.c里。

```c++
__do_global_ctors_aux (void)
{
  func_ptr *p;
  for (p = __CTOR_END__ - 1; *p != (func_ptr) -1; p--)
    (*p) ();
}
```

如上所示，p的值被初始化成`__CTOR_END__`减去一个字节。这是一种指针算法，如果指针指向一个函数，在这种情况下，-1表示向上移动一个指针或者说4个字节。我们也能从汇编里面看出来。当指针不等于-1时，调用这个指针指向的函数，并且再次将指针上移。很明显，这个指针数组起始于-1，并且包含若干个函数指针。

下面是使用`objdump -d`得到的`__do_global_ctors_aux`函数对应的汇编语言。我们将仔细的查看它的每条指令，以便你就能够在我们使用debugger之前完全了解它。

```assembly
08048450 <__do_global_ctors_aux>:
 8048450:       55                      push   %ebp
 8048451:       89 e5                   mov    %esp,%ebp
 8048453:       53                      push   %ebx
 8048454:       83 ec 04                sub    $0x4,%esp
 8048457:       a1 14 9f 04 08          mov    0x8049f14,%eax
 804845c:       83 f8 ff                cmp    $0xffffffff,%eax
 804845f:       74 13                   je     8048474 <__do_global_ctors_aux+0x24>
 8048461:       bb 14 9f 04 08          mov    $0x8049f14,%ebx
 8048466:       66 90                   xchg   %ax,%ax
 8048468:       83 eb 04                sub    $0x4,%ebx
 804846b:       ff d0                   call   *%eax
 804846d:       8b 03                   mov    (%ebx),%eax
 804846f:       83 f8 ff                cmp    $0xffffffff,%eax
 8048472:       75 f4                   jne    8048468 <__do_global_ctors_aux+0x18>
 8048474:       83 c4 04                add    $0x4,%esp
 8048477:       5b                      pop    %ebx
 8048478:       5d                      pop    %ebp
 8048479:       c3                      ret
```

函数最开始的部分依然遵从了C函数正常的调用惯例（保存调用者的栈基址寄存器，设置当前函数的栈基址寄存器），本函数中还增加了一点：额外把`%ebx`保存到了栈中，因为这个函数后面会使用到它。同时，我们也为（C代码中的）指针p保留了空间。你可能注意到了，即使我们在栈上为其开辟了空间，但是从未使用这部分空间。取而代之的是，`p`将会保存到`%ebx`中，`*p`会保存到`%eax`中。

看起来编译器做了一些优化，编译器并没有直接“加载`__CTOR_END__`，然后将其值减去1，再查找它指向的内容”，而是直接加载`*(__CTOR_END__ - 1)`，这是一个立即数`0x8049f14`（注意，`$0x8049f14`意思是一个立即数，而不带`$`，只写`0x8049f14`的意思是这个地址指向的内容）。这个数里面的内容被直接放到了%eax中，然后立刻比较%eax和-1，如果相等，则跳转到地址0x8048474，回收栈，弹出我们保存在栈里的内容，函数调用结束，返回。

假设在函数表中至少有一个值，立即数`0x8049f14`被存放到`%ebx`，也就是函数指针`p`，然后执行指令`xchg %ax,%ax`，这是什么鬼？原来这是X86 16或者32位里的一个nop（No Operation）语句。它什么也不做，只是占据了一个指令周期，起一个占位符作用而已。在这种情况下，使循环开始于`8048468`，而不是`8048466`。这么做的好处是使循环开始的地方以4字节对齐，这样整个循环将会极大可能的被保存到一个cache line里，而不会被分成两段，从而起到加速执行的作用。

接下来，将`%ebx`减去4，从而为下一次循环做好准备，调用`%eax`里保存的地址对应的函数，然后将下一个函数指针移至`%eax`中，并且和-1比较，如果不等于-1，再次调回到上述循环。

此时，已经运行到函数的最后，然后返回到`_init`中，然后又运行到`_init`函数的最后，并返回`__libc_csu_init__`中。你肯定已经忘了吧！此时仍然在循环处理中呢！但是首先我们完成之前的承诺。

开始吧！需要记住一点的是：**GDB总是显示你将要执行的下一行或者下一条指令**。

```
$ gdb prog2
Reading symbols from /home/patrick/src/asm/prog2...done.
(gdb) set disassemble-next-line on
(gdb) b *0x80482b7
Breakpoint 1 at 0x80482b7
```

运行调试器，打开`disassemble-next-line`，这样它就会总是显示下一条将要执行的指令的汇编代码，然后我们在`_init`函数将要调用`__do_global_ctors_aux`函数的地方设置一个断点。

```bash
(gdb) r
Starting program: /home/patrick/src/asm/prog2 

Breakpoint 1, 0x080482b7 in _init ()
=> 0x080482b7 <_init+39>:    e8 94 01 00 00 call   0x8048450 <__do_global_ctors_aux>
(gdb) si
0x08048450 in __do_global_ctors_aux ()
=> 0x08048450 <__do_global_ctors_aux+0>:     55 push   %ebp
```

输入`r`继续运行程序，到达断点处。再输入`si`单步执行指令，现在我们进入了`__do_global_ctors_aux`函数内部。后面你会看到若干次我并没输入任何指令，但是GDB却继续执行，这是因为我只是按了回车而已，GDB默认会重复上条指令。所以，如果我按下回车，GDB将会按照输入`si`继续执行。

```
(gdb)
0x08048451 in __do_global_ctors_aux ()
=> 0x08048451 <__do_global_ctors_aux+1>:     89 e5  mov    %esp,%ebp
(gdb) 
0x08048453 in __do_global_ctors_aux ()
=> 0x08048453 <__do_global_ctors_aux+3>:     53 push   %ebx
(gdb) 
0x08048454 in __do_global_ctors_aux ()
=> 0x08048454 <__do_global_ctors_aux+4>:     83 ec 04   sub    $0x4,%esp
(gdb) 
0x08048457 in __do_global_ctors_aux ()
```

好的，现在我们已经执行完程序最开始的部分，接下来将要执行真正的代码了。

```
(gdb)
=> 0x08048457 <__do_global_ctors_aux+7>:     a1 14 9f 04 08 mov    0x8049f14,%eax
(gdb) 
0x0804845c in __do_global_ctors_aux ()
=> 0x0804845c <__do_global_ctors_aux+12>:    83 f8 ff   cmp    $0xffffffff,%eax
(gdb) p/x $eax
$1 = 0x80483b4
```

我想知道加载完指针之后会是什么样，所以输入了`p/x $eax`，意思是以十六进制的形式打印寄存器`%eax`的内容。它不等于-1，所以我们假定程序将继续执行循环。现在由于我的最后一条指令是print指令，所以我不能按回车继续执行了，下次我就得输入`si`了。

```
(gdb) si
0x0804845f in __do_global_ctors_aux ()
=> 0x0804845f <__do_global_ctors_aux+15>:    74 13  je     0x8048474 <__do_global_ctors_aux+36>
(gdb) 
0x08048461 in __do_global_ctors_aux ()
=> 0x08048461 <__do_global_ctors_aux+17>:    bb 14 9f 04 08 mov    $0x8049f14,%ebx
(gdb) 
0x08048466 in __do_global_ctors_aux ()
=> 0x08048466 <__do_global_ctors_aux+22>:    66 90  xchg   %ax,%ax
(gdb) 
0x08048468 in __do_global_ctors_aux ()
=> 0x08048468 <__do_global_ctors_aux+24>:    83 eb 04   sub    $0x4,%ebx
(gdb) 
0x0804846b in __do_global_ctors_aux ()
=> 0x0804846b <__do_global_ctors_aux+27>:    ff d0  call   *%eax
(gdb) 
a_constructor () at prog2.c:3
3   void __attribute__ ((constructor)) a_constructor() {
=> 0x080483b4 <a_constructor+0>:     55 push   %ebp
   0x080483b5 <a_constructor+1>:     89 e5  mov    %esp,%ebp
   0x080483b7 <a_constructor+3>:     83 ec 18   sub    $0x18,%esp
```

这部分代码很有意思。我们一步步调用来看看。现在我们已经进入了我们自己写的函数`a_constructor`。因为GDB是能看到我们的源代码的，所以它在下一行给出了我们源码。又因为我打开了`disassemble-next-line`，所以它也会给出对应的汇编代码。这个例子中输出了函数最开始的部分，对应了函数的声明，现在，我输入`n`命令，这个时候我们写的`prinf`就会被调用了。第一个n跳过了程序最开始的部分，第二个n执行prinf，第三个n执行了函数的结尾部分。如果你想知道为什么你需要在函数最开始和结束部分做些处理的话，现在，你使用GDB的单步调试应该能知道答案了吧。

```
(gdb) n
4       printf("%s\n", __FUNCTION__);
=> 0x080483ba <a_constructor+6>:     c7 04 24 a5 84 04 08   movl   $0x80484a5,(%esp)
   0x080483c1 <a_constructor+13>:    e8 2a ff ff ff call   0x80482f0 <puts@plt>
```

之前，我们已经把`a_constructor`字符串的地址作为`printf`的参数保存到了栈里，因为编译器足够的智能，发现实际上`puts`函数才是我们想要的，所以它调用了`puts`函数。

```
(gdb) n
a_constructor
5   }
=> 0x080483c6 <a_constructor+18>:    c9 leave  
   0x080483c7 <a_constructor+19>:    c3 ret   
```

因为我们正在运行中来调试程序，所以我们看到了`a_constructor`打印出了上面的内容。后括号`}`对应了函数的结尾部分，被显示出来了。提示一下，如果你不清楚`leave`指令的话，实际上它做了一下操作：

```
    movl %ebp, %esp
    popl %ebp
```

继续执行，我们就退出了函数，并返回了调用函数。这里我又不得不输入`si`了：

```
(gdb) n
0x0804846d in __do_global_ctors_aux ()
=> 0x0804846d <__do_global_ctors_aux+29>:    8b 03  mov    (%ebx),%eax
(gdb) si
0x0804846f in __do_global_ctors_aux ()
=> 0x0804846f <__do_global_ctors_aux+31>:    83 f8 ff   cmp    $0xffffffff,%eax
(gdb) 
0x08048472 in __do_global_ctors_aux ()
=> 0x08048472 <__do_global_ctors_aux+34>:    75 f4  jne    0x8048468 <__do_global_ctors_aux+24>
(gdb) p/x $eax
$2 = 0xffffffff
```

我比较好奇，并且再次看了一下：这次，我们的函数指针指向了-1，所以，程序退出了循环。

```
(gdb) si
0x08048474 in __do_global_ctors_aux ()
=> 0x08048474 <__do_global_ctors_aux+36>:    83 c4 04   add    $0x4,%esp
(gdb) 
0x08048477 in __do_global_ctors_aux ()
=> 0x08048477 <__do_global_ctors_aux+39>:    5b pop    %ebx
(gdb) 
0x08048478 in __do_global_ctors_aux ()
=> 0x08048478 <__do_global_ctors_aux+40>:    5d pop    %ebp
(gdb) 
0x08048479 in __do_global_ctors_aux ()
=> 0x08048479 <__do_global_ctors_aux+41>:    c3 ret    
(gdb) 
0x080482bc in _init ()
=> 0x080482bc <_init+44>:    58 pop    %eax
```

注意，我们现在退回到了`_init`。

```bash
(gdb) 
0x080482bd in _init ()
=> 0x080482bd <_init+45>:    5b pop    %ebx
(gdb) 
0x080482be in _init ()
=> 0x080482be <_init+46>:    c9 leave  
(gdb) 
0x080482bf in _init ()
=> 0x080482bf <_init+47>:    c3 ret    
(gdb) 
0x080483f9 in __libc_csu_init ()
=> 0x080483f9 <__libc_csu_init+25>:  8d bb 1c ff ff ff  lea    -0xe4(%ebx),%edi
(gdb) q
A debugging session is active.

    Inferior 1 [process 17368] will be killed.

Quit anyway? (y or n) y
```

现在，程序跳转回`__libc_csu_init`函数，然后我们输入`q`退出了调试器。以上是我之前说的调试过程。现在我们回到`__libc_csu_init__`函数，这里还有另外一个循环要处理，我就不再进入循环单步分析了。我们刚刚经历了冗长的时间来分析一个汇编语言写的循环，这个用汇编写的循环要比上一个更加复杂。所以我留给读者自行分析。这里我贴出对应的C代码：

```C++
void __libc_csu_init (int argc, char **argv, char **envp) {
  _init ();

  const size_t size = __init_array_end - __init_array_start;
  for (size_t i = 0; i < size; i++)
      (*__init_array_start [i]) (argc, argv, envp);
}
```

`__init__`数组里面是什么呢？你肯定不会想到。你也可以在这个阶段自定义代码。这时刚刚从运行我们自定义的构造函数的`_init`函数返回，这意味着，在这个数组里面的内容将会在构造函数完成之后运行。你能通过某种方式告诉编译器你想在这个阶段运行某个你自定义的函数。这个函数也会收到和main函数相同的参数。

```c++
void init(int argc, char **argv, char **envp) {
 	printf("%s\n", __FUNCTION__);
}
__attribute__((section(".init_array"))) typeof(init) *__init = init;
```

我们并不这么做，因为这和之前的动作基本差不多。现在，我们返回到`__lib_csu_init`函数中，你还记得会返回到哪里吗？程序将返回`__libc_start_main__`，它调用了我们的main函数，然后把main函数的返回值传递给exit()函数。exit()函数运行了更多的循环。exit()函数按照注册顺序依次运行了在at_exit()中注册的函数。然后会运行另外一个循环，这次的循环是在`__fini_`数组中定义的。在运行完这些函数之后，就会调用析构函数。

#### 7. Constructor

```assembly
	.text
	.file	"test.c"
	
	.globl	test                    # -- Begin function test
	.p2align	4, 0x90
	.type	test,@function
test:                                   # @test
	.cfi_startproc
# %bb.0:
	pushq	%rbp
	...
	retq
.Lfunc_end0:
	.size	test, .Lfunc_end0-test
	.cfi_endproc
                                        # -- End function
                                        
	.globl	main                    # -- Begin function main
	.p2align	4, 0x90
	.type	main,@function
main:                                   # @main
	.cfi_startproc
# %bb.0:
	pushq	%rbp
	...
	retq
.Lfunc_end1:
	.size	main, .Lfunc_end1-main
	.cfi_endproc
                                        # -- End function
	.type	c,@object               # @c
	
	.data
	.globl	c
	.p2align	2
c:
	.long	6                       # 0x6
	.size	c, 4

	.type	.L.str,@object          # @.str
	.section	.rodata.str1.1,"aMS",@progbits,1
.L.str:
	.asciz	"test for constructor\n"
	.size	.L.str, 22

	.type	.L.str.1,@object        # @.str.1
.L.str.1:
	.asciz	"%d\n"
	.size	.L.str.1, 4
	# __attribute((constructor))_ start
	.section	.init_array,"aw",@init_array
	.p2align	3
	.quad	test
	# __attribute((constructor))_ end
	.ident	"clang version 10.0.1 "
	.section	".note.GNU-stack","",@progbits
```

#### 8. Conclusion

这个程序，把上面所有的过程联系了起来

```c++
#include <stdio.h>

void preinit(int argc, char **argv, char **envp) {
 printf("%s\n", __FUNCTION__);
}

void init(int argc, char **argv, char **envp) {
 printf("%s\n", __FUNCTION__);
}

void fini() {
 printf("%s\n", __FUNCTION__);
}

__attribute__((section(".init_array"))) typeof(init) *__init = init;
__attribute__((section(".preinit_array"))) typeof(preinit) *__preinit = preinit;
__attribute__((section(".fini_array"))) typeof(fini) *__fini = fini;

void  __attribute__ ((constructor)) constructor() {
 printf("%s\n", __FUNCTION__);
}

void __attribute__ ((destructor)) destructor() {
 printf("%s\n", __FUNCTION__);
}

void my_atexit() {
 printf("%s\n", __FUNCTION__);
}

void my_atexit2() {
 printf("%s\n", __FUNCTION__);
}

int main() {
 atexit(my_atexit);
 atexit(my_atexit2);
}
```

编译并运行这个函数（这里我将其命名为hooks.c），输出如下：

```bash
$ ./hooks
preinit
init
constructor
my_atexit2
my_atexit
destructor
fini
```

现在我们再来回顾一下整个过程，这次你就不会对它感到陌生了吧。

![image-20210410200953737](https://i.loli.net/2021/04/10/TsSo8YD6VKBdMl1.png)