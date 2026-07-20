---
title: Rebuttal
date: 2021-04-04 01:53:50
tags:
    - Ph.D.
categories: Ph.D.
---
I read this paper before (in about 5 mins or less). And like I mentioned to you, although I don't remember the technical details, but I remember 1) key idea is to ensemble multiple fuzzers together and boost the performance, that's new and should be appreciated, although, well, I wonder if we shall trust their reported results (we should believe unless we have concrete evidence), 2) it's very important to remember who published this paper, although it might be difficult to remember the "name", you at least need to remember the institute.

<!--more-->

What's important is to let people know they are worse, by either:

1. after manually checking their findings, that's not as signaficant as us, say, if that's not a real vulnerability or so.

2. if that's infeasible, we have to report their findings, although it's as well vulnerabilities, have been reported already or so.

##### Rebuttal 1

On Review 1,


On the concern about incorrect classification of multi-package libraries (say "from the same developer", using "the same prefix"), it is possible that our tool will identify each combination as a different library. However, we believe this is essentially a problem shared by all library identification methods. LibD might be able to identify different "versions have different structures". If LibD cannot detect the relation, they will be classified as different libraries. We will consider this in our future work.


On Review 2,


The number of identified libraries reported over the whole sample set (1.4 million apps) is indeed not the ground truth. We lack the manpower to verify all positives and negatives manually. However, to validate the credibility of our results, we did manually verify the results over a subset of the samples (1000 apps). Since this set is large and randomly selected, the false positive and false negative rates should be approximately applicable to the overall results.


We report the number of packages in a library because some previous work only consider single-package libraries. Our results indicate that failing to consider cross-package dependencies can lead to significant mis-classifications.


Google has published multiple Android security white papers [1][2] and explicitly states that apps will be analyzed both statically and dynamically before publication. There are also unofficial technical reports [3][4] reveling the details of the vetting process.


We didn't run WuKong because LibRadar is essentially the improved version of WuKong's library identification part.


Reporting the number of obfuscated libraries is a clear indication of the improvement made by our tool comparing to previous work, for they cannot correctly cluster these obfuscated libraries with other unobfuscated versions.


We do not claim LibD can directly identify vulnerable or malicious libraries. Instead, we identify different instances of the same library such that when one of the instances is considered vulnerable or malicious, the other instances can be quickly identified.


We did compare LibD with LibRadar, one of the state-of-the-art Android library detectors (Table IV). There are other similar tools, but we cannot get access to them. Our false positive rate seems high, but it is already significant improvement compared with LibRadar.


On Review 3,


We would like to emphasize that our experiments are not subjective. It is true that every library detection method has its advantages and disadvantages over certain obfuscation techniques. However, our experiment results are **manually** validated, with all obfuscations known to us considered. Therefore, the experiments will not offer us unfair advantages over other tools. The results suggest that focusing on library name obfuscation significantly boosts the overall performance. A possible reason may be that library name obfuscation is one of the most widely used obfuscation techniques.


Per our investigation, most of "ghost calls" are calling functions from customized Android frameworks. For example, there is a call invoking com.samsung.android.SsdkInterface.getVersionCode which exists only on Samsung Android phones. The decompiler failed to consider these cases, leading to dangling function targets.


[1]https://goo.gl/50HCk2

[2]https://goo.gl/JwmAvZ

[3]https://goo.gl/fUPQZ

[4]https://goo.gl/5O6c5T



##### Rebuttal 2


Our submitted vulnerability reports are still waiting for confirmation from the Linux developers. Generally speaking, it takes XXX to confirm each reported defects and we are anticipating to hear from them later this year. 

On the other hand, we have conducted further analysis of those `unknown` vulnerabilities reported by our tool and comprehend each cases. 

We report that for the first case, it indicates a XXXX (e.g., use-after-free) bug in the *XXX module* of the Linux kernel. Generally speaking, this bug can jeopardize heap code pointers, and likely to enable remote code control and heap memory overread, violating the confidentiality and integrity of Linux kernel.

We report that for the second case, it indicates a XXXX (e.g., use-after-free) bug in the *XXX module* of the Linux kernel. Generally speaking, this bug can jeopardize heap code pointers, and likely to enable remote code control and heap memory overread, violating the confidentiality and integrity of Linux kernel.

We confirm that by searching such code pattern cannot online, we cannot find any relavent bug reports. Therefore, to our best knowledge, XXX outperforms Moonshine and YYY by findings these new issues.

We note that it usually takes a while for the open source community to confirm bugs or vulnerabilities. However, manual study have shown promising findings, adding confidence and significance of our research. Also, the findings can be treated as "vulnerabilities", since we not only find critical memory abusing bugs (use-after-free), and also know  what user-input can indeed trigger that bug. 

