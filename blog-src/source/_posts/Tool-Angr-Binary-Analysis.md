---
title: '[Tool] Angr Binary Analysis'
date: 2021-05-31 17:42:33
tags:
---

### Workflow

- Binary Lifting ***libVEX*** : Binary Code  to VEX IR
- Binary Loading ***CLE*** : load binary with differernt formats
  - Resolve dynamic symbol
  - Perform relocation
  - Initialize program state
- Program State Representation: ***SimuVEX***
  - Program state (***SimState***) is a snapshot of values in registers and memory, open files, etc.

    

