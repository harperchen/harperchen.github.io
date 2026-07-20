---
title: '[Tech] Joern Usage & MVP & APHP'
date: 2024-03-28 14:03:43
tags:
   - Static Analysis
   - Linux kernel
categories: 
---

#### 1. Joern Background

https://docs.joern.io/cpgql/reference-card/

#### 2. Joern Generate DDG

Method 1: generate in joern console

```c++
joern> importCode.c.fromString("""
     | static void virtio_pci_remove(struct pci_dev *pci_dev)
     | {
     |  struct virtio_pci_device *vp_dev = pci_get_drvdata(pci_dev);
     |  struct device *dev = get_device(&vp_dev->vdev.dev);
     |
     |  pci_disable_sriov(pci_dev);
     |
     |  unregister_virtio_device(&vp_dev->vdev);
     |
     |  if (vp_dev->ioaddr)
     |      virtio_pci_legacy_remove(vp_dev);
     |  else
     |      virtio_pci_modern_remove(vp_dev);
     |
     |  pci_disable_device(pci_dev);
     |  put_device(dev);
     | }
     | """)
```

<!--more-->

Method 2: run the following command

```bash
# source files are located under current directory
➜  workspace joern-parse ./
Parsing code at: ./ - language: `NEWC`
[+] Running language frontend
=======================================================================================================
Invoking CPG generator in a separate process. Note that the new process will consume additional memory.
If you are importing a large codebase (and/or running into memory issues), please try the following:
1) exit joern
2) invoke the frontend: /opt/joern/joern-cli/c2cpg.sh -J-Xmx30208m ./ --output cpg.bin
3) start joern, import the cpg: `importCpg("path/to/cpg")`
=======================================================================================================

[+] Applying default overlays
Successfully wrote graph to: /home/weichen/workspace/cpg.bin
```

The above would generate a file named `cpg.bin`, then, we generate dog file to visualize the dog 

```bash
# generate ddg
➜  workspace joern-export --out out-ddg --repr ddg /home/weichen/workspace/cpg.bin
# generate pdg
➜  workspace joern-export --out out-pdg --repr pdg /home/weichen/workspace/cpg.bin
```

The generated dot files are under directory `out-ddg`, we check it and found `out-ddg/1-ddg.dot` is the one we want. 

```bash
dot -Tpng -o test.png out-ddg/1-ddg.dot
```

#### 2. Analyze DDG 

There is a null ptr dereference inside the function to be analyzed.

```c++
static int mvebu_uart_probe(struct platform_device *pdev) {
	const struct of_device_id *match = of_match_device(mvebu_uart_of_match,
							   &pdev->dev);
	...
  mvuart->data = (struct mvebu_uart_driver_data *)match->data;
  ...
}
```

In line 2, `match` is returned from function `of_match_device`, without verifying whether `match` is NULL, and instead directly dereference it in line 5 would cause NPD.

##### 2.1 MVP Algorithm

The input of MVP is a security patches. For instance, to fix the above NPD, the [patch](https://github.com/torvalds/linux/commit/32f47179833b63de72427131169809065db6745e) adds the check from line 14 to line 15.

```c++
static int mvebu_uart_probe(struct platform_device *pdev)
{
	struct resource *reg = platform_get_resource(pdev, IORESOURCE_MEM, 0);
	const struct of_device_id *match = of_match_device(mvebu_uart_of_match,
							   &pdev->dev);
	struct uart_port *port;
	struct mvebu_uart *mvuart;
	int ret, id, irq;

	if (!reg) {
		dev_err(&pdev->dev, "no registers defined\n");
		return -EINVAL;
	}
+ if (!match)
+   return -ENODEV;  
  
	/* Assume that all UART ports have a DT alias or none has */
	id = of_alias_get_id(pdev->dev.of_node, "serial");
	if (!pdev->dev.of_node || id < 0)
		pdev->id = uart_num_counter++;
	else
		pdev->id = id;

	if (pdev->id >= MVEBU_NR_UARTS) {
		dev_err(&pdev->dev, "cannot have more than %d UART ports\n",
			MVEBU_NR_UARTS);
		return -EINVAL;
	}

	port = &mvebu_uart_ports[pdev->id];

	spin_lock_init(&port->lock);

	port->dev        = &pdev->dev;
	port->type       = PORT_MVEBU;
	port->ops        = &mvebu_uart_ops;
	port->regshift   = 0;

	port->fifosize   = 32;
	port->iotype     = UPIO_MEM32;
	port->flags      = UPF_FIXED_PORT;
	port->line       = pdev->id;

	/*
	 * IRQ number is not stored in this structure because we may have two of
	 * them per port (RX and TX). Instead, use the driver UART structure
	 * array so called ->irq[].
	 */
	port->irq        = 0;
	port->irqflags   = 0;
	port->mapbase    = reg->start;

	port->membase = devm_ioremap_resource(&pdev->dev, reg);
	if (IS_ERR(port->membase))
		return -PTR_ERR(port->membase);

	mvuart = devm_kzalloc(&pdev->dev, sizeof(struct mvebu_uart),
			      GFP_KERNEL);
	if (!mvuart)
		return -ENOMEM;

	/* Get controller data depending on the compatible string */
	mvuart->data = (struct mvebu_uart_driver_data *)match->data;
	mvuart->port = port;

	port->private_data = mvuart;
	platform_set_drvdata(pdev, mvuart);

	/* Get fixed clock frequency */
	mvuart->clk = devm_clk_get(&pdev->dev, NULL);
	if (IS_ERR(mvuart->clk)) {
		if (PTR_ERR(mvuart->clk) == -EPROBE_DEFER)
			return PTR_ERR(mvuart->clk);

		if (IS_EXTENDED(port)) {
			dev_err(&pdev->dev, "unable to get UART clock\n");
			return PTR_ERR(mvuart->clk);
		}
	} else {
		if (!clk_prepare_enable(mvuart->clk))
			port->uartclk = clk_get_rate(mvuart->clk);
	}

	/* Manage interrupts */
	if (platform_irq_count(pdev) == 1) {
		/* Old bindings: no name on the single unamed UART0 IRQ */
		irq = platform_get_irq(pdev, 0);
		if (irq < 0) {
			dev_err(&pdev->dev, "unable to get UART IRQ\n");
			return irq;
		}

		mvuart->irq[UART_IRQ_SUM] = irq;
	} else {
		/*
		 * New bindings: named interrupts (RX, TX) for both UARTS,
		 * only make use of uart-rx and uart-tx interrupts, do not use
		 * uart-sum of UART0 port.
		 */
		irq = platform_get_irq_byname(pdev, "uart-rx");
		if (irq < 0) {
			dev_err(&pdev->dev, "unable to get 'uart-rx' IRQ\n");
			return irq;
		}

		mvuart->irq[UART_RX_IRQ] = irq;

		irq = platform_get_irq_byname(pdev, "uart-tx");
		if (irq < 0) {
			dev_err(&pdev->dev, "unable to get 'uart-tx' IRQ\n");
			return irq;
		}

		mvuart->irq[UART_TX_IRQ] = irq;
	}

	/* UART Soft Reset*/
	writel(CTRL_SOFT_RST, port->membase + UART_CTRL(port));
	udelay(1);
	writel(0, port->membase + UART_CTRL(port));

	ret = uart_add_one_port(&mvebu_uart_driver, port);
	if (ret)
		return ret;
	return 0;
}
```

**Step 1:** MVP first analyzes the patch and extracts four variables as shown below and $f_{v}$ and $p_v$ are vulnerable and patched function.
$$
S_{del}:& \texttt{set of deleted statements} \\
S_{add}:& \texttt{set of added statements} \\
S_{vul}:& \texttt{all statements in vulnerable functions} \\
S_{pat}:& \texttt{all statements in patched functions}
$$

Thus, for the patch above, $S_{add} = \{s_{14}, s_{15}\}$, $S_{del} = \{\}$.

**Step 2**: MVP takes statements in $S_{add}$ and $S_{del}$ as slicing criterion and perform forward and backward slicing of PDF of patched function $p_{v}$ and vulnerable function $f_v$ to capture the **data and control dependencies.** 

1. Backward slicing is normal, just includes all data dependence and control dependence

**Example.** By taking $s_{15}$ as slicing criterion, the result of backward slicing is {$s_{3}$ (ctrl), $s_4$ (data), $s_{10}$​ (ctrl)}

2. Forward slicing is customized, otherwise too many statements would be involved if the added statements are `if` conditions.
   1. Assignment is included
   2. Return statements will not be forward sliced 
   3. For function call and conditional statement, first backward on data dependence then forward

**Example.** First, $s_{15}$ is return statement. Thus we do not perform forward slicing. Second, to handle the conditional statement in $s_{14}$, we first conduct backward slicing on data dependencies and obtain $s_4$. Then we set $s_4$ as slicing criterion, and conduct forward slicing on data dependence. The results include $\{s_{63}, s_{66}, s_{67}, s_{75}, s_{118}, s_{120}, s_{122}, s_{123}\}$​.

For reference, this is the selected PDG for function after patch.

![graphviz (10)](/Users/harperchen/Downloads/graphviz (10).svg)



For reference, this is the selected PDG for function before patch.

<img src="/Users/harperchen/Downloads/graphviz (11).svg" height="75%" width="75%">



> [!IMPORTANT]
>
> - Joern does not distinguish `a` and `a->b`, any statement that may be affected will be considered as data dependence related one.

**Step 3:** MVP puts the slicing results into $S^{sem}_{del}$ and $S_{add}^{sem}$, making it as semantically-related statements of all changed statements in changed function of security patch.

**Example.** Since no deleted statements in the current patch. $S_{del}^{sem}$ is $\{\}$ while $S^{sem}_{add} = \{s_3, s_4, s_{10}, s_{14}, s_{63}, s_{66}, s_{67}, s_{75}, s_{118}, s_{120}, s_{122}, s_{123}\}$ contains so many noises incurred during forward slicing.

**Step 4:** MVP computes the vulnerability signature and patch signature is generated below:

- $V_{syn} = S^{sem}_{del} \cup (S_{vul} \cap S_{add}^{sem})$: vulnerability syntax signature 
- $V_{sem} = \{(s_1, s_2, \texttt{type}) | s_1, s_2 \in V_{syn}\}$

- $P_{syn} = S^{sem}_{add} \setminus S_{vul}$  statements that only exist in patched function $p_{v}$
- $P_{sem} = \{(s_1, s_2, \texttt{type}) | s_1, s_2 \in S^{sem}_{add}\} \setminus \{(s_1, s_2, \texttt{type}) | s_1, s_2 \in S_{vul}\} $ data or control dependencies between two statements that only exist in patched function

Although the above formula looks quite complicate, but you should notice that

- $V_{syn} \cup P_{syn} = S^{sem}_{del} \cup S_{add}^{sem}$​

To more noise in case $V_{syn}$ is too large, MVP iteratively remove from $V_{syn}$ which are farthest from the slicing criterion on PDG.

**Example.** 

- $V_{syn} = \{s_3, s_4, s_{10}, s_{63}, s_{66}, s_{67}, s_{75}, s_{118}, s_{120}, s_{122}, s_{123}\}$​ 
- $V_{sem} = \{(s_3, s_{10}, \texttt{data}), (s_{10}, s_{63}, \texttt{ctrl}), (s_4, s_{63}, \texttt{data}), ...\}$
- $P_{syn} = {s_{14}} $​
- $P_{sem} = \{\}$

**Step 5**: Apply abstraction, normalization and hashing procedure

- Formal parameters => PARAM
- Local variables => VARIABLE
- String => STRING

**Step 6**: Determine whether a target function is vulnerable based on the principle that its signature matches the vulnerability signature but does not match patch signature. 



#### Reference

1. https://docs.joern.io/export/

