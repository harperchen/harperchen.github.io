---
title: '[Tool] SVF Static Analysis'
date: 2021-06-04 22:08:45
tags:
---

### Static Value-Flow Analysis Framework

A scalable, precise and on-demand interprocedural program dependence analysis framework for both sequential and multithreaded programs.

##### Value-Flow Analysis

- resolves both control and data dependence. 
  - Does the information generated at program point A flow to another program point B along some execution paths? 
  - Can function F be called either directly or indirectly from some other function F 0? 
  - Is there an unsafe memory access that may trigger a bug or security risk?

#### Key features of SVF 

- Sparse: compute and maintain the data-flow facts where necessary
- Selective : support mixed analyses for precision and efficiency trade-offs
- On-demand : reason about program parts based on user queries.
 
<!--more-->
 
#### Client applications 

- Static bug detection (e.g., memory leaks, null dereferences, use-after-frees and data-races) 
- Accelerate dynamic analysis (e.g., Google’s Sanitizers and AFL fuzzing)

#### Several terms in static analysis

-  Flow-sensitive
- Context-sensitive
- Heap-sensitive
- Field-sensitive

![image-20210607195801671](/Users/harper/Library/Application%20Support/typora-user-images/image-20210607195801671.png)

![image-20210607200429237](https://i.loli.net/2021/06/07/nIRUL8qgzKxOmXJ.png)

#### Graph Representation of Code

Representing a program’s control-flow (i.e., execution order) and/or data-flow (variable definition and use relations) using nodes and edges of a graph.

- Call graph: Program calling relations between methods
- Control flow graph: Program execution order between two instructions.
  - Intra-procedural control-flow graph: control-flow graph within a program method. 
  - Inter-procedural control-flow graph: control-flow graph across program methods. (ICFG)
- Constraint graph
- Program assignment graph

#### Pointer-to Analysis

**Andersen’s analysis**, a flow-insensitive, context-insensitive and path-insensitive Andersen’s analysis through analyzing the Constraint Graph of a program

![image-20210607212140340](https://i.loli.net/2021/06/07/CWpEsfQReHiLzbk.png)

### Tool Usage

https://github.com/obfuscator-llvm/obfuscator/wiki



![image-20210606215243456](https://i.loli.net/2021/06/06/XpNQozKEw1DdCRL.png)



#### SVF

##### Install

```bash
git clone https://github.com/SVF-tools/SVF.git
cd SVF
source ./build.sh
```

##### Usage





#### Infer

Install

```bash
VERSION=1.0.0; \
curl -sSL "https://github.com/facebook/infer/releases/download/v$VERSION/infer-linux64-v$VERSION.tar.xz" \
| sudo tar -C /opt -xJ && \
sudo ln -s "/opt/infer-linux64-v$VERSION/bin/infer" /usr/local/bin/infer
```

Usage

Here is a simple Java example to illustrate Infer at work.

```java
// Hello.java
class Hello {
  int test() {
    String s = null;
    return s.length();
  }
}
```

To run Infer, type the following in your terminal from the same directory as [`Hello.java`](https://github.com/facebook/infer/tree/master/examples/Hello.java).

```bash
infer run -- javac Hello.java
```

You should see the following error reported by Infer.

![image-20210607214530159](https://i.loli.net/2021/06/07/tmBrjayU6EQ23NI.png)

Here is a simple C example to illustrate Infer at work.

```c
// hello.c

#include <stdlib.h>
void test() {
    int *s = NULL;
    *s = 42;
}
```

To run Infer, type the following in your terminal from the same directory as [`hello.c`](https://github.com/facebook/infer/tree/master/examples/hello.c).

```bash
infer run -- gcc -c hello.c
```

You should see the following error reported by Infer.

![image-20210607214848546](https://i.loli.net/2021/06/07/qmXfM9OZxJkI5lE.png)

#### Clang Static Analyzer

```C
#include <stdio.h> 
#include <stdlib.h> 

int main() {  
  int *mem;  
  mem = malloc(sizeof(int));  
  if(mem) { 
      return 1; 
  }
  *mem = 0xdeadbeaf;  
  free(mem);  
  return 0;  
} 
```

![image-20210607220047699](https://i.loli.net/2021/06/07/X2UZhFBRkyLJNYm.png)





```html
<tr>
  <td class="num"></td>
  <td class="line">
    <div id="Path1" class="msg msgEvent" style="margin-left:9ex">
      <table class="msgT">
        <tr>
          <td valign="top"><div class="PathIndex PathIndexEvent">1</div></td>
          <td>'twoIntsStructPointer' initialized to a null pointer value</td>
          <td><div class="PathNav"><a href="#EndPath" title="Next event (2)">&#x2192;</a></div></td>
        </tr>
      </table>
    </div>
  </td>
</tr>
```

```html
<tr>
  <td class="num"></td>
  <td class="line">
    <div id="EndPath" class="msg msgEvent" style="margin-left:47ex">
      <table class="msgT">
        <tr>
          <td valign="top"><div class="PathIndex PathIndexEvent">2</div></td>
          <td><div class="PathNav"><a href="#Path1" title="Previous event (1)">&#x2190;</a></div></td>
          <td>Access to field 'intOne' results in a dereference of a null pointer (loaded from variable 'twoIntsStructPointer')</td>
        </tr>
      </table>
    </div>
  </td>
</tr>
```

