---
title: CGroup Experiments
date: 2020-09-12 16:51:41
author: Wei CHEN
tags: 
  - CGroup
  - Container
categories: 
  - Container
description: CGroups Experiments including CPUSet, CPU, Memory usage limitation, etc.
---

URL: https://kernel.googlesource.com/pub/scm/linux/kernel/git/glommer/memcg/+/cpu_stat/Documentation/cgroups

## 1. CGroup Installation

The first step, on Ubuntu, is to install the cgroups packages.

```bash
sudo apt-get install cgroup-tools cgroup-bin cgroup-lite libcgroup1 cgroupfs-mount
# add the following in /etc/default/grub
GRUB_CMDLINE_LINUX_DEFAULT="quiet cgroup_enable=memory swapaccount=1"
sudo update-grub
```
<!--more-->

Several files are created at the same time.

- `/sys/fs/cgroup` has a bunch of folders in a sort of virtual filesystem that "represents" cgroup.
- `/etc/init/cgroup-lite.conf` creates the /sys/fs/cgroup directory
- `/proc/cgroups` specifies what groups cgroup-lite should create.

<img src="https://i.loli.net/2020/09/12/MkSH85IvOEonrV3.png" style="zoom:45%;" />

- By accessing the cgroup filesystem directly.
- Using the cgm client (part of the cgmanager).
- Via cgcreate, cgexec and cgclassify (part of cgroup-tools).
- Via cgconfig.conf and cgrules.conf (also part of cgroup-tools).

```bash
# /etc/init/cgroup-lite.conf
description "mount available cgroup filesystems"
author "Serge Hallyn <serge.hallyn@canonical.com>"

start on mounted MOUNTPOINT=/sys/fs/cgroup

pre-start script
	test -x /bin/cgroups-mount || { stop; exit 0; }
	test -d /sys/fs/cgroup || { stop; exit 0; }
	/bin/cgroups-mount
	cgconfigparser -l /etc/cgconfig.conf
			cgrulesengd
end script

post-stop script
	if [ -x /bin/cgroups-umount ]
	then
		/bin/cgroups-umount
	fi
end script
```

## 2. CPUSet Usage Limitation

Now the environment and tools are ready, we will define some roles in `/etc/cgconfig.conf`

```bash
group wchenbt {
    cpuset {
#       cat /proc/cpuinfo | grep "cpu cores" | uniq
        cpuset.cpus = "1,2";
        cpuset.mems = "0";
#       we need to specific memory node for cpuset 
    }
	...
}
```

We will associate these “roles” and the applications in `/etc/cgrules.conf`

```bash
# <user:process>    <subsystems>           <group>
harper:java         cpu,memory,cpuset      wchenbt
```
This will limit the process java of user harper to CPU Core 1, 2 and 1G of memory.

```bash
sudo vim /etc/cgconfig.conf
sudo vim /etc/cgrules.conf

sudo cgconfigparser -l /etc/cgconfig.conf
sudo cgrulesengd -d --logfile=/var/log/cgrulesengd.log

taskset -pc $(pidof java)
cat /proc/$(pidof java)/cgroup
sudo cgdelete cpuset:/wchenbt
```

Based on the roles, we can check the debug information of cgrulesengd and also the cgroup information of java. The output of taskset shows that we have successfully setup the roles.
<img src="https://i.loli.net/2020/09/12/F7UEaIXWp2bLgH8.png" style="zoom:45%;" />

<img src="https://i.loli.net/2020/09/12/QdXqS3PuTOHyiLR.png" style="zoom:45%;" />

## 3. CPU Usgae Limitation

```bash
group wchenbt {
	cpu {
		# cpu.shares = 300; # 30 %
		cpu.cfs_quota_us=10000; # 10 %
		cpu.cfs_period_us=100000; # default value
	}
	cpucct {
		
	}
	...
}
```

- cpu.shares: The weight of each group living in the same hierarchy, that translates into the amount of CPU it is expected to get. Upon cgroup creation, each group gets assigned a default of 1024. The percentage of CPU assigned to the cgroup is the value of shares divided by the sum of all shares in all cgroups in the same level.
- cpu.cfs_period_us: The duration in microseconds of each scheduler period, for bandwidth decisions. This defaults to 100000us or 100ms.
- cpu.cfs_quota_us: The maximum time in microseconds during each cfs_period_us in for the current group will be allowed to run. For instance, if it is set to half of cpu_period_us, the cgroup will only be able to peak run for 50 % of the time. One should note that this represents aggregate time over all CPUs in the system. Therefore, in order to allow full usage of two CPUs, for instance, one should set this value to twice the value of cfs_period_us.
<img src="https://i.loli.net/2020/09/12/1ZgbxkhHAXBLqet.png" style="zoom:45%;" />

We use htop to check the cpu usage which is lower than 10%.
<img src="https://i.loli.net/2020/09/12/nNPXxfRrTGKVgC9.png" style="zoom:45%;" />


## 4. Memory Usage Limitation

When not configure the memory limitation, we use stress process and check the memory usage is around 10%

```bash
# Stress https://www.cnblogs.com/sparkdev/p/10354947.html
stress --vm-bytes 800m --vm-keep -m 1
```
<img src="https://i.loli.net/2020/09/12/4cFrUnETQCkNtZl.png" style="zoom:45%;" />

```bash
# user su
mkdir /sys/fs/cgroup/memory/testmem -p
cd /sys/fs/cgroup/memory/testmem

echo $$ > tasks
echo 100m > memory.limit_in_bytes

# delete cgroup
cd /sys/fs/cgroup/memory/
echo $$ >> tasks
rmdir ./testm
```

## 5. CGCreate

```bash
cgcreate -a root -t harper -g cpu,memory:test
ls /sys/fs/cgroup/cpu/test
ls /sys/fs/cgroup/memory/test
head /sys/fs/cgroup/cpu/test/cpu.shares
head /sys/fs/cgroup/memory/test/memory.limit_in_bytes
echo 300 > /sys/fs/cgroup/cpu/test/cpu.shares
echo 100m > /sys/fs/cgroup/memory/test/memory.limit_in_bytes
cgexec -g cpu,memory:test cat /dev/urandom > /dev/null
```
<img src="https://i.loli.net/2020/09/12/jJRBuVcEov7QTts.png" style="zoom:45%;" />

You'll get 1024 for your cpu.shares (the maximum & default) and a huge number for your memory usage limit in bytes.
<img src="https://i.loli.net/2020/09/12/6K91YRy8HrdLExu.png" style="zoom:45%;" />

## 6. Data Synchronization

[https://medium.com/@asishrs/docker-limit-resource-utilization-using-cgroup-parent-72a646651f9d](https://medium.com/@asishrs/docker-limit-resource-utilization-using-cgroup-parent-72a646651f9d)
[https://andrestc.com/post/cgroups-io/](https://andrestc.com/post/cgroups-io/)

### 6.1 CGroupv1

The script `/etc/init/cgroup-lite.conf` will automatically mount cgroup filesystem when rebooting.

```bash
# /etc/init/cgroup-lite.conf
description "mount available cgroup filesystems"
author "Serge Hallyn <serge.hallyn@canonical.com>"

start on mounted MOUNTPOINT=/sys/fs/cgroup

pre-start script
	test -x /bin/cgroups-mount || { stop; exit 0; }
	test -d /sys/fs/cgroup || { stop; exit 0; }
	/bin/cgroups-mount
	cgconfigparser -l /etc/cgconfig.conf
		cgrulesengd
end script

post-stop script
	if [ -x /bin/cgroups-umount ]
	then
		/bin/cgroups-umount
	fi
end script
```

Also, we need add the following to `/etc/default/grub` and update

```bash
GRUB_CMDLINE_LINUX_DEFAULT="quiet cgroup_enable=memory swapaccount=1"
sudo update-grub
```

So let's start to limit I/O with cgroups v1. For I/O read, cgroups works, shown as follow.

```bash
# 消耗io
dd if=/dev/sda of=/dev/null
```

Before configuration, we can use iostat to check the I/O read that is close to 200M/s.
<img src="https://i.loli.net/2020/09/12/kBqDgGyROiXfjZF.png" style="zoom:45%;" />

To limit the I/O read, we need to create a cgroup `test` in the `blkio` controller. Then we are going to set our read limit using `blkio.throttle.read_bps_device` file. This requires us to specify limits by device, so we must find out our device major and minor version:
<img src="https://i.loli.net/2020/09/12/dXMcbVwFCutSzph.png" style="zoom:45%;" />

Let's limit the read bytes per second to 10485760 (10M/s) on the sda device (8: 0).

```bash
ls /sys/fs/cgroup/blkio/
mkdir /sys/fs/cgroup/blkio/test
echo '8:0 10485760' > /sys/fs/cgroup/blkio/test/blkio.throttle.read_bps_device
# process id
echo 2660 > /sys/fs/cgroup/blkio/test/tasks
```

Then we place the shell into cgroup test by writing its pid 2660 into `tasks` file and re-run the workload. The command we start in this shell will run in this cgroup, so the read bytes per second now become around 10M/s when watching the I/O workload using iostat.
<img src="https://i.loli.net/2020/09/12/VOPMfyw5ToxgAY3.png" style="zoom:45%;" />

For I/O write, this is not the case. We use the following command to generate I/O workload and monitor the I/O usage. The write bytes per second on the nvme0n1 device now is close to 150M/s.

```bash
dd if=/dev/zero of=/tmp/file1
```
<img src="https://i.loli.net/2020/09/12/V2ghwftFK7J9m5z.png" style="zoom:45%;" />

Then we limit the I/O usage using `blkio.throttle.write_bps_device` file, now the device major and minor version is 292: 0. 

```bash
echo '292:0 10485760' > blkio.throttle.write_bps_device
```

However, we are still able to write 128 MB/s, so the limitation doesn't work.
<img src="https://i.loli.net/2020/09/12/EUkRcStm3Vx9nja.png" style="zoom:45%;" />

If we try the same command but opening the file with `O_DIRECT` flag (passing `oflag=direct` to `dd`), the write bytes per second now is around 10M/s.
<img src="https://i.loli.net/2020/09/12/umYUjnaboCvRMEZ.png" style="zoom:45%;" />

Basically, when we write to a file (opened without any special flags), the data travels across a bunch of buffers and caches before it is effectively written to the disk. Opening a file with O_DIRECT (available since Linux 2.4.10), means file I/O is done directly to/from user-space buffers.

On traditional cgroup hierarchies, relationships between different controllers cannot be established making it impossible for writeback to operate accounting for cgroup resource restrictions and all writeback IOs are attributed to the root cgroup. 

It’s important to notice that this was added when cgroups v2 were already a reality (but still experimental). So the “traditional cgroup hierarchies” means cgroups v1. Since in cgroups v1, different resources/controllers (memory, blkio) live in different hierarchies on the filesystem, even when those cgroups have the same name, they are completely independent. So, when the memory page is finally being flushed to disk, there is no way that the memory controller can know what blkio cgroup wrote that page. That means it is going to use the root cgroup for the blkio controller.

### 6.2 CGroupv2

[https://www.kernel.org/doc/Documentation/cgroup-v2.txt](https://www.kernel.org/doc/Documentation/cgroup-v2.txt)

We need add the following to `/etc/default/grub` and update.

```bash
GRUB_CMDLINE_LINUX_DEFAULT="cgroup_no_v1=all"
sudo update-grub
```

Also, we need delete `/etc/init/cgroup-lite.conf` and reboot to unmount and disable cgroup v1.

<img src="https://i.loli.net/2021/01/08/SDMGnIzCkPEo8tU.png" alt="image-20210108151437090" style="zoom:67%;" />

First, we mount cgroup v2 filesystem in /mnt/cgroup2

<img src="https://i.loli.net/2021/01/08/CgWzjBvItwXyhrH.png" alt="image-20210108151457165" style="zoom:50%;" />

Now, we create a new cgroup called cg2 by creating a directory under the mounted file system. To be able to edit the I/O limits using the the I/O controller on the newly created cgroup, we need to write “+io” to the `cgroup.subtree_control` file in the parent (in this case, root) cgroup, and check the `cgroup.controllers` file for the cg2 cgroup, we see that the io controller is enabled.

<img src="https://i.loli.net/2021/01/08/dknTaDC7RhNQJ31.png" alt="image-20210108151520405" style="zoom:50%;" />


To limit I/O to 10MB/s, as done previously, we write into the io.max file and use `dd` to generate some IO workload.

<img src="https://i.loli.net/2021/01/08/LaSbo9ZpAGKihPR.png" alt="image-20210108151532020" style="zoom:50%;" />

The write bytes per second is around 700M/s. Let’s add our bash session to the cg2 cgroup, by writing its PID to `cgroup.procs` file. At the same time, we get this output from iostat (redacted).

<img src="https://i.loli.net/2021/01/08/xFiuS1sTLP27HpO.png" alt="image-20210108151542108" style="zoom:50%;" />

So, even relying on the writeback kernel cache we are able to limit the I/O on the disk with cgroup v2.
