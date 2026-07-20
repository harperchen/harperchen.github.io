---
title: Gdb Usage
date: 2020-09-23 19:37:42
tags:
---

I would like to debug the following C program using gdb to check how to set the memory content to run this program statically using BinCAT.
<!-- more -->
```C
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int get_sign(int x){
	if (x == 0){
		return 0;
	}
	if (x < 0){
		return -1;
	}
	return 1;
}

int main(int argc, char **argv){
	int a = atoi(argv[1]);
	int s = get_sign(a);
	return 0;
}
```

Basically, I'm trying to set up argc and argv in correct memory location. The machine code of below C program is shown as below.

<img src="https://i.loli.net/2020/09/23/F7yVHlqONRnjvfo.png" style="zoom: 85%;" />

First, we compile this code with `clang` and set the args as 1.

```bash
$ clang test.c -o test
$ gdb test
(gdb) set args 1
```

<img src="https://i.loli.net/2020/09/23/kPIyaBRxn4S6OFt.png" alt="image-20200923194924624" style="zoom:43%;" />

Second, we use `layout asm` command to show the disassembly of test and use `b main` to set break at the start address of main.

<img src="https://i.loli.net/2020/09/23/zrZ3WwRlQDEMYIB.png" alt="image-20200923195515733" style="zoom:33%;" />

Third, we run the program using command `r`, the program stops at the instruction in address `0x400534`.

<img src="https://i.loli.net/2020/09/23/BP3m19Z6DWupTQg.png" alt="image-20200923195704924" style="zoom:43%;" />

We can use p to show the value of register.

```bash
(gdb) p $rsp
$1 = (void *) 0x7fffffffe220
(gdb) p $rbp
$2 = (void *) 0x7fffffffe220
```

`ni` is used to execute instruction one by one. We stop at `0x400546` and check the value of `edi` and `rsi`.  

![image-20200923200911169](https://i.loli.net/2020/09/23/mXwTZjuxY139dbf.png)

The result shows that `edi=2`, which is exactly `argc`, cause there are two parameters. `rsi=0x0x7fffffffe308` which should be the value of `argv`. We check the memory content at address `$rsi`, then we can find that `argv[0]=0x7fffffffe581` and `argv[1] = 0x00007fffffffe594`. Further, we check the memory content of `argv[0]` and `argv[1]`, the two parameters are listed.

```bash
(gdb) p /x $rsi
$5 = 0x7fffffffe308
(gdb) x/4x $rsi
0x7fffffffe308: 0xffffe581      0x00007fff      0xffffe594      0x00007fff
(gdb) x/19c 0x00007fffffffe581
0x7fffffffe581: 47 '/'  104 'h' 111 'o' 109 'm' 101 'e' 47 '/'  119 'w' 99 'c'
0x7fffffffe589: 104 'h' 101 'e' 110 'n' 98 'b'  116 't' 47 '/'  116 't' 101 'e'
0x7fffffffe591: 115 's' 116 't' 0 '\000'
(gdb) x/2c 0x00007fffffffe594
0x7fffffffe594: 49 '1'  0 '\000'
(gdb)
```

Therefore, `mov rax, [rbp+var_10]` will move the value of argv to register `rax`, then `mov rdi, [rax+8]` will move the value of argv[1] to `rdi`, which is the paramter of atoi function. 

```bash
(gdb) p/x $rdi
$7 = 0x7fffffffe594
(gdb) p/x $rax
$8 = 0x7fffffffe308
(gdb)
```

Based on the observation, we configure BinCAT to perform taint analysis.

```
reg[rsi] = 0xb8001008 # argv
reg[rdi] = 0x2 # argc
reg[rsp] = 0xb8001000

mem[0xb8000000*4099] = |00|?0xFF
mem[0xb8001008] = 0x300100 # argv[0]
mem[0xb8001010] = 0x300200 # argv[1]
mem[0x300200] = |3300|
```

The same as concrete execution, `rsi` is argv, `argv[1]=0x300200`, and the input 1 is store at `argv[1]`.

![image-20200923203244031](https://i.loli.net/2020/09/23/wXNM7ngi49TY2hv.png)

