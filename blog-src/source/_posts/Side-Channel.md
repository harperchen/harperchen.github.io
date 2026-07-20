---
title: Side Channel
date: 2021-03-22 14:20:55
tags:
---

#### Side channel

Steal Secret through side channels

side channels: timing; power; em emissions; sound; heat; cache

Infer secrets via secret-dependent physical information
<!--more-->
#### Example 

##### RSA Decryption Algorithm

```java
for bit in k:
    // compute square
    if bit == 1:
        // compute multiply
endfor
```

|  square | square  | square & multiply | square & multiply  | ...

|       0      |       0      |                   1               |                    1               | ...

##### Timing side channel

```C++
if (k == 1) then
    // slow branch
else
    // fast branch
endfor
```

##### Break RSA with Timing Side Channel

|  square |  square | square + multiply | square + multiply | ...

|       0      |       0      |                  1                |                  1                | ...

|     fast   |     fast    |              slow             |               slow            | ...

##### Break RSA with Power Side channel

<img src="https://i.loli.net/2021/03/22/4ShuJOAKLDZVrC5.png" alt="image-20210322145237378" style="zoom: 43%;" />

##### Break RSA with Power Side channel

<img src="https://i.loli.net/2021/03/22/bY3NiR8VJ17HeqZ.png" alt="image-20210322145348892" style="zoom:50%;" />

#### Cache-based side channel

Cache lines: minimal storage units of a cache 64 bytes

Cache sets: equal number of cache lines

```C++
// Table Lookup
x = A[idx]
```

idx is virtual address, for L1 and L2 cache, virtual address is used for indexing, however for L3 cache, physical address is used.

The upper part of a memory address maps a memory access to a cache line access

- Set index: locate the set in which the data may be stored. 

- Tag: confirm the data is present in one of its lines

<img src="https://i.loli.net/2021/03/22/9g463RPiF8rLUET.png" alt="image-20210322150113988" style="zoom:33%;" />

The System model for a multi-core processor, L1 and L2 cache is private to each core and LLC is shared across multiple cores;

<img src="https://i.loli.net/2021/03/22/qSvZraW2K5MneRP.png" alt="image-20210322145946903" style="zoom:30%;" />

Threat model

![image-20210322192746039](https://i.loli.net/2021/03/22/umxjnMIq9FlD3N4.png)

Support



#### Meltdown



##### Spectre



##### L1 and L2 Cache Side Channel

Prime-and-Probe



##### LLC Side Channel