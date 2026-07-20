---
title: Usages and problems of Taint Tools
date: 2020-09-15 23:18:16
tags: Taint Analysis
categories: Taint
---

#### 1. Tool Categories

Existing taint analysis tools can be divided into three categories. 

##### a. Dynamic Taint Analysis

The first category of tools track the information flow from taint source to taint sink at runtime following the execution trace. Most of these dynamic analysis tools are built on the top of dynamic binary instrumentation (DBI) framework such as Pin and Valgrind. These tools dynamically insert analysis code into the target executable while the executable is running. Some other tools like PolyTracker work as an LLVM Pass that instruments taint tracking logic into the programs during compilation to perform taint analysis with lower overhead. Such tools always ship with their own compiler, for example, `polybuild` and `polybuild++` of Tool PolyTracker. Given a specific input, the dynamic analysis tools will track how the taint is propagated along the executed path.

<!-- more -->

| Tools                                                        | Foundation             | Data Dependency       |
| :----------------------------------------------------------- | ---------------------- | --------------------- |
| Dytan                                                        | DBI Platform: Pin      | Explicit and Implicit |
| [Triton](https://github.com/JonathanSalwan/Triton)           | DBI Platform: Pin      | Explicit              |
| [LibDFT](https://www.cs.columbia.edu/~vpk/research/libdft/)  | DBI Platform: Pin      | Explicit              |
| [LibDFT64](https://github.com/AngoraFuzzer/libdft64)         | DBI Platform: Pin      | Explicit              |
| [Taintgrind](https://github.com/wmkhoo/taintgrind)           | DBI Platform: Valgrind | Explicit              |
| [DataFlow Sanitizer](https://clang.llvm.org/docs/DataFlowSanitizer.html) | LLVM Pass              |                       |
| [PolyTracker](https://github.com/trailofbits/polytracker)    | LLVM Pass              | Explicit and Implicit |
| [TaintInduce](https://taintinduce.github.io/)                |                        |                       |

##### b. Static Taint Analysis but Emulate the Execution

The second category of tools work as an interpreter or a CPU emulator, which means these tools do not execute the target program, but emulate the functionalities and collect the essential information for analysis. Usually, we need to set up the environment such as stack, heap, the content of memory, and program input before performing analysis. During analysis, these tools process machine code one by one and transform the code into their pre-defined intermediate language, then the memory and register will be manipulated based on the intermediate language, with the taint propagated at the same time. At each program point during execution, the value of registers and memory cells can be monitored to check if they are tainted or not. As we can see, tools in this category also maintain an execution trace and only take care of the data and instructions along this execution trace, which is the same as dynamic taint analysis.

| Tools                                              | Description                                    | Data Dependency |
| -------------------------------------------------- | ---------------------------------------------- | --------------- |
| [Bincat](https://github.com/airbus-seclab/bincat)  | Plugin for IDA                                 | Explicit        |
| [Triton](https://github.com/JonathanSalwan/Triton) | Convert instruction to IR to emulate execution | Explicit        |

##### c. Static Taint Analysis

The third category of tools analyze the target program statically and wholly. All paths are taken into consideration. The taint source and sink are specified using annotations. Generally speaking, the sources are the return value of user-controllable functions, like `input()`,  and the sinks are the parameters of functions that should be treated carefully or may lead to potential security issues,  like `os.command()`. The tracking granularity of tools in this category is quite larger compared with the two before mentioned. Except for the taint source and sink, the tools in this category also support for sanitizing functions. Especially, Psalm, a tool mainly aiming for security analysis of web applications, will automatically remove the taint from data when executing functions like `stripslashes`, which removes backslashes used to prevent cross-site-scripting attacks.

| Tools                                              | Description                                     | Data Dependency |
| -------------------------------------------------- | ----------------------------------------------- | --------------- |
| [Pysa](https://pyre-check.org/docs/pysa-basics)    | reasons about data flows in Python applications | Explicit        |
| [Psalm](https://psalm.dev/docs/security_analysis/) | find errors in PHP applications                 | Explicit        |

In the following sections, I will demonstrate the usage of several tools to illustrate the difference between these three kinds of tools. In the end, with the guidance of the idea that if the output changes with the different inputs, the output should be tainted once the input is tainted, I will show the potential difficulties in testing these analysis tools.

#### 2. Dynamic Analysis Tool: Taintgrind

This tool Taintgrind is built on the top of Valgrind. There are two ways to track taint. One is using `TNT_TAINT` client request to introduce taint into a variable or memory location in the program. Take the following program as an example, we taint variable `a`, then pass it to `get_sign` function. The return value of `get_sign` implicitly depends on the parameter. 

```C
#include "taintgrind.h"
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
    unsigned int t;
    int a = atoi(argv[1]);
    //Defines int as tainted
    TNT_TAINT(&a,sizeof(a));
    int s = get_sign(a);
    TNT_IS_TAINTED(t, &s, sizeof(s));

    if (t)
        printf("s is_tainted: %08x\n", t);
    else
        printf("s is not tainted\n");
    return 0;
}

```

Compile the above program and run it with input 1. We check if the return value of get_sign is tainted using the client request `TNT_IS_TAINT`. The output of dynamic analysis shows how taint flows in the execution path through instructions one by one in the following form.

```bash
Location | Assembly instruction | Instruction type | Runtime value(s) | Information flow
```

However, we can see that Taintgrind does not support to analyze the implicit information flow, even though the taint has flowed into the conditional expression.

<img src="https://i.loli.net/2020/09/16/Y9oqw1cV3UAasPS.png">

As to the explicit information flow like below, the return value of get_sign can be successfully tainted.

```C
int get_sign(int x){
    return x;
}
```

<img src="https://i.loli.net/2020/09/16/oH6Yqmh8RkAfgd2.png">

Another usage of Taintgrind is to taint the file input given an executable, such as gzip, and show how taint flows along the execution path.

```bash
./build/bin/taintgrind --file-filter=FAQ.txt gzip -c FAQ.txt
```

#### 3. Dynamic Analysis Tool: PolyTracker

Unlike Taintgrind, PolyTracker instruments the taint analysis logic into programs during compilation to track which bytes of an input file are operated by which functions. Therefore, compared with dynamic binary instrumentation, such tools impose negligible performance overhead for almost all inputs, and is capable of tracking every byte of input at once. PolyTracker is built on the top of the LLVM DataFlowSanitizer.

PolyTrack works as [LLVM Pass](https://llvm.org/docs/WritingAnLLVMPass.html). The generated shared object `.so` can be loaded either through `opt` tool to instrument the LLVM bitcode, or through `clang` when the source code is avaliable. 

```bash
# Through opt tool
opt -local -mypass.so -mypass code.bc
# Through clang
clang -Xclang -load -Xclang mypass.so code.c
```

PolyTracker provides compilers `polybuild` and `polybuild++`, which are wrappers around `gclang` and `gclang++`. When the source code is avaiable, we can instrument it by simply replacing the compiler with PolyTracker and passing `--instrument-target` option before the cflags during the normal build process.

```bash
# export CC=`which polybuild`
${CC} --instrument-target -g -o my_target my_target.c
# export CXX=`which polybuild++`
${CXX} --instrument-target -g -o my_target my_target.cpp
```

If only the binary executable is given, we can first extract the bitcode from the target, then instrument it by passing `--instrument-bitcode` option.

```bash
get-bc -b target
${CC}/{CXX} --instrument-bitcode target.bc -o target_track --libs <any libs go here> 
```

To run the instrumented program, `POLYPATH` environment variable is requited to specify which input file's bytes are meant to be tracked. Currently, polytracker only expose the capability to specify a single file as the tainted input. Assume we have the following C program. Given an input file, this program computes a key based on the first three strings, then compares the key with `0x80000000`, and finally outputs the result. 

```c
#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include <sys/utsname.h>
#include <sys/fcntl.h>
#include <fcntl.h>

struct user_info {
    char *company;
    char *dep;
    char *name;
    char *progname;
};

int custom_crc32(int len, char *buf) {
    unsigned int poly = 0x04C11DB7;
    unsigned int sr = ~0;
    int i, j, k;

    for (i = 0; i < len; i++) {
        for (j = 0; j < 8; j++) {
            k = sr >> 31;
            sr <<= 1;
            if ((k ^ *buf) & 1) {
                sr ^= poly;
            }
        }
        buf++;
    }
    return sr;
}

int compute_key(struct user_info *info) {
    unsigned int k_comp, k_dept, k_name, k_progname;

    k_comp = custom_crc32(strlen(info->company), info->company);
    k_dept = custom_crc32(strlen(info->dep), info->dep);
    k_name = custom_crc32(strlen(info->name), info->name);
    k_progname = custom_crc32(strlen(info->progname), info->progname);

    return k_comp*k_name;
}


int main(int argc, char *argv[]) {
    int fd, i = 0;
    unsigned int key;
    char *provided_lic, *ptr, *temp[5];
    char str[128], delim[] = " ";
    struct user_info info;

    info.company = info.name = info.dep = NULL;

    if(argc < 2) {
        printf("Usage: %s inputfile\n", argv[0]);
        return 1;
    }
    // if use fopen and fread, polytracker will fail
    fd = open(argv[1], O_RDONLY);  
    read(fd, str, 128);
    ptr = strtok(str, delim);

    // example file content:
    // company department name 419B0F77970C4AC453973A5D99B995C989EBF204
    //
    // spilt the file content on whitespace
    while (ptr != NULL) {
        temp[i] = malloc(strlen(ptr));
        memcpy(temp[i], ptr, strlen(ptr));
        printf("%s\n", temp[i]);
        ptr = strtok(NULL, delim);
        i++;
    }

    info.progname = argv[0];
    info.company = temp[0];
    info.dep = temp[1];
    info.name = temp[2];
    provided_lic = temp[3];

    // compute the key
    key = compute_key(&info);
    printf("Key=>[0x%x]\n", key);

    // output result
    if (key >= 0x8000000)
        printf("Invalid serial %s\n", provided_lic);
    else
        printf("Thank you for registering !\n");
}
```

We can find that the last string (provided_lic) is actually not used when computing the key. Further, the three strings are only used in the condition statement (line 25) at function custom_crc32. We compile it using `polybuild`, the output shows several functions are instrumented.

<img src="http://harperchen.qiniudn.com/image-20200926235948282.png" alt="image-20200926235948282" style="zoom: 75%;" />

With the instrumented binary `my_target`，run the binary with POLYPATH environment to taint the input file.

```bash
POLYPATH=inputfile ./my_target inputfile

# inputfile:
# company department name 419B0F77970C4AC453973A5D99B995C989EBF204
```

 The binary is executed as normal, also two artifacts `polytracker_process_set.json` and `polytracker_forest.bin` are created in current directory at the same time.

<img src="http://harperchen.qiniudn.com/image-20200927000434633.png" alt="image-20200927000434633" style="zoom:80%;" />

The analysis results are saved in`polytracker_process_set.json`, which contains the information of `taint_sources`,  `runtime_cfg`, `tainted_function`, etc. The json file generated by `my_target` is shown as below:

```json
{
    "canonical_mapping": { // mapping [taint label, original file offset]
        "inputfile": [     // Totoally 65 bytes in inputfile
            [65, 64],  
            [64, 63],  
            ...
            [2, 1],
            [1, 0],
        ]
    },
    "runtime_cfg": { // the control flow graph made of instrumented function
        "dfs$custom_crc32": [
            "dfs$compute_key" // caller
        ],
        "dfs$compute_key": [ 
            "main"            // caller
        ],
        "main": [
            ""  // no caller for main
        ]
    },
    "taint_sources": {  // taint source
        "inputfile": {   
            "end_byte": 64,
            "start_byte": 0
        },
        // stdin is the default taint source, 
        // however, without environment POLYPATH, the                      
        // program cannot be executed, which leaves 
        // no space for tracking the taint from stdin
        "stdin": {   
            "end_byte": 2147483646,  
            "start_byte": 0
        }
    },
    "tainted_functions": {  // how the tainted function process taint label
        "dfs$custom_crc32": {
            "cmp_bytes": [  // the taint label are used at condition statements (line 25)
                1,
                ...   // 1-7: company
                7,
                9,
                ...   // 9-18: department
                18,
                20,
                ...   // 20-23: name
                23
            ],
            "input_bytes": [  // the taint labels are the input of function
                1,
                ...   // 1-7: company 
                7,
                9,
                ...   // 9-18: department
                18,
                20,
                ...   // 20-23: name
                23
            ]
        },
        "main": {
            "input_bytes": [
                1,
                2,
                ...
                65
            ]
        }
    },
    "tainted_input_blocks": {
        "inputfile": [
            [0, 64]
        ]
    },
    "version": "2.2.0"
}
```

Polytrack outputs function-to-input-bytes mapping to indicate which bytes of an input file are operated on by which functions and how. If an input byte flows into a function as parameter but has never been read by the function, the function will not be counted as a tainted function. 

```C
void testfunc(int len, char *buf) { // not a tainted function
  for (int i = 0; i < len; i++) {
        *buf = 1; // only write into the memory location buf
        buf++;
    }
}
```

Besides, Polytracker can identify whether the input bytes are used in condition statements (listed under the key `tainted_functions/function/cmp_bytes` in JSON file). However, there are some exceptions. The following function uses the length of `buf` to decide the value of `a`, then returns `a` to its caller. Polytracker will not label this function as tainted, even if the value of `a` is implicitly depends on input `buf`.

```C
int testfunc(char *buf) { // not be labeled as tainted
    int a = 0;

    if (strlen(buf) > 5){
        a = 1;
    } else {
        a = 2;
    }
    return a;
}
```

In fact, Polytrack is designed to be used in conjunction with [PolyFile](https://github.com/trailofbits/polyfile) to automatically determine the semantic purpose of the functions in a parser. PolyFile is a file identification utility to parse the file structure and map each byte of the file into the corresponding semantic. Take PDF file as an example, PolyFile first identifies that the given file is in PDF format, then outputs the sematic of each byte in the file, such as PDFComment, PDFObject. 

Assume we want to reverse-engineer the PDF parser [MuPDF](https://mupdf.com/). PolyTracker is used to instrument the parser to output the associate each byte of PDF file with each function in that parser. With the file format parsed by PolyFile as ground truth, we can easily infer the sematic purpose of each function in MuPDF by merging the two mappings (function <-> input byte <-> semantic).  Based on this design consideration, it's straightforward to answer why Polytracker only use function as taint sink granularity to perform analysis.

#### 4. Static Analysis Tool but Emulate Execution: Bincat

The following keygen-me-style program takes a few arguments as command-line parameters, then generates a hash depending on these parameters, and compares it to an expected license value.

<img src="https://i.loli.net/2020/09/21/v25azExLrdseBJ8.png" style="zoom:45%;" >

Open executable `get_key_x86` in IDA Pro. We can see address `0x93B` is the start point of main function.

<img src="https://i.loli.net/2020/09/21/2eVtNhBX8jC9HAo.jpg"  style="zoom:65%;">

Focus on the **BinCAT Configuration** pane, set the start address as `0x93B` as the start address. Edit the configuration to initialize the stack, setup the content of command-line parameters, and corresponding memory.

```bash
mem[0xb8000000*4099] = |00|?0xFF # initialize the stack to unknown value
mem[0xb8001004] = 5         # argc = 5
mem[0xb8001008] = 0x200000  # argv = 0x200000

mem[0x200000] = 0x300100 # argv[0] 
mem[0x200004] = 0x300140 # argv[1]
mem[0x200008] = 0x300180 # argv[2]
mem[0x20000C] = 0x3001C0 # argv[3]
mem[0x200010] = 0x300200 # argv[4]

mem[0x300100] = |6c6f6c3300|       # argv[0] = "lol3"
mem[0x300140] = |636f6d70616e7900| # argv[1] = "company"
mem[0x300180] = |64657000|   # argv[2] = "dep"
mem[0x3001C0] = |6c6f6c3100| # argv[3] = "lol1"
mem[0x300200] = |6c6f6c2100| # argv[4] = "lol!"
```

<img src="https://i.loli.net/2020/09/21/YI4PwTR73UEqWSh.png" alt="image-20200921214609971" style="zoom:60%;" />

Click start to perform analysis. When analysis finishes, open the **BinCAT Memory** view, we can see the five parameters are located at the corresponding memory addresses.

<img src="https://i.loli.net/2020/09/21/fiCyMKr2sIEBSzn.png" alt="image-20200921220518093" style="zoom:45%;" />

Switch to the **IDA View-A** view, go to an arbitrary address such as `0x98C`,  we can check the value of each register. From the **BinCAT IL** view, the intermediate language of instruction `mov [ebp+var_22C], edi` is `(32)[ebp+0xfffffdd4]<-edi`.

<img src="https://i.loli.net/2020/09/21/ficbyROY3ntDUZV.png" alt="image-20200921222843992" style="zoom:45%;" />

Override the taint of every byte at addresses `0x300140`-`0x300147` which contains the null-terminated `company` string.

<img src="https://i.loli.net/2020/09/21/HPzSNKxCvVayBjU.png" alt="image-20200921220721353" style="zoom:37%;" />

Set it to `!|FF|` (this fully taints the byte, without changing its value). 

<img src="https://i.loli.net/2020/09/21/y4P6zwo8DcAB5R3.png" alt="image-20200921220823674" style="zoom:37%;" />

We can check that the user-defined taint overrides at **BinCAT Overrides** view. Re-run the analysis.

<img src="https://i.loli.net/2020/09/21/wfVJax3QIPOFNsr.png" alt="image-20200921221039291" style="zoom:37%;" />

Advance to the instruction at address `0x93F`, and observe that this memory range is indeed tainted: both the ASCII and hexadecimal representations of this string are displayed as green text.

<img src="https://i.loli.net/2020/09/21/VJC8tbmI9RxZN6r.png" alt="image-20200921221127514" style="zoom: 40%;" />

In the **IDA View-A** view, notice that some instructions are displayed against a non-gray background, since they manipulate tainted data. For example, the instruction at address `0x9E6` (`push eax`) is highlighted because `eax`is tainted.

<img src="https://i.loli.net/2020/09/21/IsV7lnCDGdjkeYf.png" alt="image-20200921221444701" style="zoom:43%;" />

In the **IDA View-A** view, we can see some instructions are displayed with a white background, since these instructions are not executed with the given parameters.

<img src="https://i.loli.net/2020/09/21/MQPI8vWODSmocf1.png" alt="image-20200921224200323" style="zoom:33%;" />

#### 5. Static Analysis Tool: Psalm

Psalm is a static analysis tool for PHP applications. Assume we plan to analyze the following `target.php` program using Psalm. `$_POST` is user-controlled input, which is defined as a taint source by default. `echo` is the place that we don't want untrusted user data to end up, which is also defined as taint sink by default. In this program, the data explicitly flows from `$_POST` to `echo $name` and implicitly from `$_POST` to `echo $a`.

```php
<?php
$a = 0;
$name = "";
$input = "";

if ($_SERVER["REQUEST_METHOD"] == "POST") {
    $input = $_POST["name"];
    $name = test_input($input);

    if (strlen($input) >= 2) {
        $a = 1;
    } else {
        $a = 2;
    }
    echo $a;
    echo $name;
}

function test_input($data) {
    $data = trim($data);
    $data = stripslashes($data);
    return $data;
}
?>
```

In the directory of the above program, run the following command to add a `psalm.xml` config file. 

```bash
./vendor/bin/psalm --init
```

Psalm will scan the project, set the project files to be analyzed and figure out an appropriate error level for the codebase.

```xml
<?xml version="1.0"?>
<psalm
    errorLevel="3"
    ...
>
    <projectFiles>
        <file name="target.php" />
        <ignoreFiles>
            <directory name="vendor" />
        </ignoreFiles>
    </projectFiles>
</psalm>

```

To perform taint analysis, run the `./vendor/bin/psalm` with flag `--taint-analysis`. However, the analysis shows that no errors found in the `target.php` program.

<img src="https://i.loli.net/2020/09/22/yzIhduSG5k7xw6i.png" alt="image-20200922144006760" style="zoom:50%;" />

There are two reasons. First, Psalm not support implicit data flow tracking. Second, operation `stripslashes` remove taints from data because this function removes backslashes in the string, which eliminates the risk of suffering cross-site-scripting attacks. In that case, there is no need to track how taint flows anymore. We can feel that Psalm is developed mainly for security analysis of web applications. However, this is not consistent with our idea: If the output changes with the different inputs, the output should be tainted once the input is tainted. 

If we put `echo $data` ahead of `stripslashes` function, the error can be detected.

<img src="https://i.loli.net/2020/09/22/XqsBbYnF7wihrv3.png" alt="image-20200922145913877" style="zoom:45%;" />

Except for the three default taint sources `$_POST/$_GET/$_COOKIE`, we can define our custom taint sources using annotations `@psalm-taint-source <taint-type>`, which are always the return value of user-controlled functions. The following example defines the return value of `getUser` function as a taint source whose type is `input`. When the taint flows into the taint sink `echo`, an error will be reported.

<img src="https://i.loli.net/2020/09/22/gehaNQpXklCjnbs.png" alt="image-20200922151007945" style="zoom: 43%;" />

Also, except for a number of default builtin taint sinks such as `echo`, we can define our custom taint sinks using annotation `@psalm-taint-sink <taint-type> <param-name>`, which are always the parameters of functions that should be carefully treated. The following example defines the parameter `$str` of `myExec` function as taint sink whose type is `shell`.

<img src="https://i.loli.net/2020/09/22/kbvLpgYRq6XPSfM.png" alt="image-20200922152410422" style="zoom:43%;" />

#### 6. Static Analysis Tool: Pysa

Pysa is a static analysis tool for python. We first define different types of taint sources and sink in `taint.config` file. In the following config, we define source type `UserControlled`, sink type `RemoteCodeExecution`, as well as a rule showing that we concern about the data flows from source `UserControlled` to sink `RemoteCodeExecution`.

```json
{
    "sources": [
        {
            "name": "UserControlled",
            "comment": "use to annotate user input"
        }
    ],

    "sinks": [
        {
            "name": "RemoteCodeExecution",
            "comment": "use to annotate execution of code"
        }
    ],
    "features": [],

    "rules": [
        {
            "name": "Possible shell injection",
            "code": 5001,
            "sources": [ "UserControlled" ],
            "sinks": [ "RemoteCodeExecution" ],
            "message_format": "Data from [{$sources}] source(s) may reach [{$sinks}] sink(s)"
        }
    ]
}
```

Then we need to link the source and sink type with target program. The following `.pysa` file using python annotation syntax indicates that the return value of `input` is taint source with type `UserControlled`, and the parameter of `print` is taint sink with type `RemoteCodeExecution`. Once there is a data flow path from `input` to `print`, Pysa will report the potential issue. 

```python
# taint/general.pysa

# model for raw_input
def input(__prompt = ...) -> TaintSource[UserControlled]: ...

# model for print
def print(values: TaintSink[ReturnSign], sep = ..., end = ..., file = ...) : ...
```

Therefore, for the target program, the `input` function is a taint source since it gets input directly from the user. The `print` function is a taint sink, since we do not want user-controlled values to flow into it.

```python
def func():
    a = input()
    print(a)
```

Execute command `pyre analyze` to perform taint analysis, here are the results. The information shows that the taint source `a` flows into sink at line 3, in which `a` is used as the parameter of print function. The message also shows that the detected issue points to function `source.func`. Note that Pysa only analyzes data flow in functions, which means if the following statement 2 and 3 are in `main` function or even not any function, then Pysa will say that there is no issue.

<img src="https://i.loli.net/2020/09/22/3lx1IHiL5VJfMKW.png" alt="image-20200922172253744" style="zoom:43%;" />

Pysa cannot track implicit information flow, currently, only conditional tests are supported. In the following case, the taint source `a` is used in conditional test expression in line 4. Pysa can report this problem, but cannot detect that the taint has implicitly flowed into sink `print` at line 5 and line 7.

<img src="https://i.loli.net/2020/09/22/CrF9YpiZR37jXeT.png" alt="image-20200922223740657" style="zoom:43%;" />

#### 7. Conclusion

We can feel that even though there are a bunch of taint analysis tools, they are developed for different purposes, which leads to different user interfaces, different taint granularity, different features. We may need to be careful to infer the taint "ground truth" based on the output of the program. Furthermore, these taint tools prefer to under-taint and even make efforts to reduce false positive. In details, the implicit dependence such as `if(x){ y = 2; }` are not supported by majority tools. Besides, for dynamic tools and those static tools that simulate execution, they only focus on one path that depends on the user input.  Mutations that don't affect the information flow of that path may not be useful to test the analysis tool. Therefore, test case construction is another aspect that should be treated seriously.