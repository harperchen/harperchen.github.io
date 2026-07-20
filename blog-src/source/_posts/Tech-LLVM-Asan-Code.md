---
title: LLVM Asan Code
date: 2021-04-10 21:18:29
tags:
---

#### asan.module_ctor

works the same as \__attribute__((constructor)), insert into section `.init_array`

#### asan.module_dtor

works the same as  \__attribute__ ((destructor)), insert into section `.fini_array`

```assembly
.section	.init_array.1,"aw",@init_array
.p2align	3
.quad	asan.module_ctor

.section	.init_array,"aw",@init_array
.p2align	3
.quad	test

.section	.fini_array.1,"aw",@fini_array
.p2align	3
.quad	asan.module_dtor
```
But openark compiler doesn't support constructor and destructor.