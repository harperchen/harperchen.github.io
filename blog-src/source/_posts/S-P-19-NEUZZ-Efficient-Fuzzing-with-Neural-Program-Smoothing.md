---
title: '[S&P''19] NEUZZ: Efficient Fuzzing with Neural Program Smoothing'
date: 2021-03-04 14:50:28
tags:
    - Fuzz Testing
categories: Papers
---
One of the main limitations of evolutionary optimization algorithms is that they cannot leverage the structure (*i.e.*, gradients or other higher-order derivatives) of the underlying optimization problem. In this paper, we introduce a novel, efficient, and scalable program smoothing technique using feed-forward Neural Networks (NNs) that can incrementally learn smooth approximations of complex, real-world program branching behaviors, *i.e.*, predicting the control flow edges of the target program exercised by a particular given input. 

<!--more-->

The key challenge in incremental training is that if an NN is only trained on new data, it might completely forget the rules it learned from old data [57]. We avoid this problem by designing a new coverage-based filtration scheme that creates a condensed summary of both old and new data, allowing the NN to be trained efficiently on them.

<img src="https://i.loli.net/2021/03/04/fELcX8lCpg5rGt9.png" alt="image-20210304152019208" style="zoom: 33%;" />