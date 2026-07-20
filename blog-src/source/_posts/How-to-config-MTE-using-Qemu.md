---
title: How to config MTE using Qemu
date: 2020-09-12 12:20:20
author: Wei CHEN
tags: 
  - ARM
  - MTE
categories: 
  - ARM
description: Configure memory tagging extension (MTE) using Qemu
---

#### 1. Qemu 5.1.0

```bash
# download qemu-5.1.0
wget https://download.qemu.org/qemu-5.1.0.tar.xz
tar xvJf qemu-5.1.0.tar.xz
cd qemu-5.1.0

# build & install qemu-5.1.0
./configure --target-list=arm-softmmu,aarch64-softmmu
make
sudo make install

# check version (v5.1 is required)
qemu-system-aarch64 --version
```

<!--more-->

<img src="https://i.loli.net/2020/09/12/yQLkDFaYEnsS4Jq.png" alt="image-20200817144007620" style="zoom:45%;" />

#### 2. GNU ToolChain 9.2

```bash
wget https://developer.arm.com/-/media/Files/downloads/gnu-a/9.2-2019.12/binrel/gcc-arm-9.2-2019.12-x86_64-aarch64-none-linux-gnu.tar.xz
mkdir toolchains
tar -xJf gcc-arm-9.2-2019.12-x86_64-aarch64-none-linux-gnu.tar.xz -C toolchains

# set path
vim ~/.zshrc
PATH=$PATH:/home/wchenbt/toolchains/gcc-arm-9.2-2019.12-x86_64-aarch64-none-linux-gnu/bin
source ~/.zshrc

# check version (v9.2 is required)
aarch64-none-linux-gnu-gcc --version
```

<img src="https://i.loli.net/2020/09/12/4HF2c8R9wSQbhjd.png" style="zoom:45%;"/>

#### 3. Compile Linux Kernel

```bash
git clone https://git.kernel.org/pub/scm/linux/kernel/git/arm64/linux.git Linux_Arm
cd Linux_Arm

# check out to the branch that add memory tagging extension
git checkout for-next/mte
```

<img src="https://i.loli.net/2020/09/12/3aiepfYyMNgqmhX.png" style="zoom:45%;"/>

```bash
# compile linux kernel using gnu toolchain 9.2
# we can find option CONFIG_ARM64_MTE=y in .config
ARCH=arm64 CROSS_COMPILE=aarch64-none-linux-gnu- make defconfig 

ARCH=arm64 CROSS_COMPILE=aarch64-none-linux-gnu- make -j64  
```

<img src="https://i.loli.net/2020/09/12/OTtcKUh4u9Qi6Jy.png" style="zoom:45%;" />

#### 4. Make Rootfs

```bash
sudo apt-get install qemu-user-static binfmt-support
wget http://cdimage.ubuntu.com/ubuntu-base/releases/20.04/release/ubuntu-base-20.04-base-arm64.tar.gz

mkdir rootfs
dd if=/dev/zero of=ubuntu-20.04-rootfs_ext4.img bs=1M count=4096 oflag=direct
mkfs.ext4 ubuntu-20.04-rootfs_ext4.img
sudo mount -t ext4 ubuntu-20.04-rootfs_ext4.img rootfs/
sudo tar -xzf ubuntu-base-20.04-base-arm64.tar.gz -C rootfs/

sudo cp /usr/bin/qemu-aarch64-static rootfs/usr/bin/
sudo cp /etc/resolv.conf rootfs/etc/resolv.conf
sudo mount -t proc /proc rootfs/proc
sudo mount -t sysfs /sys rootfs/sys
sudo mount -o bind /dev rootfs/dev
sudo mount -o bind /dev/pts rootfs/dev/pts

# install kernel modules
cd Linux_Arm
ARCH=arm64 CROSS_COMPILE=aarch64-none-linux-gnu- make modules -j8
sudo ARCH=arm64 CROSS_COMPILE=aarch64-none-linux-gnu- make modules_install INSTALL_MOD_PATH=../rootfs 

sudo chroot rootfs
# install essential packages
apt-get update
apt-get install sudo vim bash-completion -y
apt-get install net-tools ethtool ifupdown network-manager iputils-ping -y
apt-get install rsyslog resolvconf udev -y

apt-get install systemd -y

# add user wchenbt
adduser wchenbt
adduser wchenbt sudo
echo "Ubuntu" >/etc/hostname
echo "127.0.0.1 localhost" >/etc/hosts
echo "127.0.0.1 Ubuntu">>/etc/hosts
dpkg-reconfigure resolvconf
dpkg-reconfigure tzdata
exit

sudo umount rootfs/proc
sudo umount rootfs/sys
sudo umount rootfs/dev/pts
sudo umount rootfs/dev
sudo umount rootfs
```

#### 5. Launch Qemu

```bash
# -m the type of machine (virt,mte=on is required)
# -cpu the type of virtual cpu (max is required, other cpus don't support mte)

qemu-system-aarch64 \
  -machine virt,mte=on \
  -smp 4 \
  -cpu max \
  -m 2048M \
  -nographic \
  -kernel /home/wchenbt/Projects/Linux_Arm/arch/arm64/boot/Image \
  -append "console=ttyAMA0 root=/dev/vda rw" \
  -drive if=none,file=ubuntu-20.04-rootfs_ext4.img,id=hd0,format=raw \
  -device virtio-blk-device,drive=hd0 \
  -net user,hostfwd=tcp::10023-:22 -net nic
```

<img src="https://i.loli.net/2020/09/12/eMhN3yEVsDwvaYW.png" style="zoom:45%;" />

#### 6. Test MTE

The following test file comes from 
https://kernel.googlesource.com/pub/scm/linux/kernel/git/arm64/linux/+/refs/heads/for-next/mte/Documentation/arm64/memory-tagging-extension.rst

```C
/*
 * To be compiled with -march=armv8.5-a+memtag
 */
#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/auxv.h>
#include <sys/mman.h>
#include <sys/prctl.h>

/*
 * From arch/arm64/include/uapi/asm/hwcap.h
 */
#define HWCAP2_MTE              (1 << 18)

/*
 * From arch/arm64/include/uapi/asm/mman.h
 */
#define PROT_MTE                 0x20

/*
 * From include/uapi/linux/prctl.h
 */
# define PR_SET_TAGGED_ADDR_CTRL 55
# define PR_GET_TAGGED_ADDR_CTRL 56
# define PR_TAGGED_ADDR_ENABLE  (1UL << 0)
# define PR_MTE_TCF_SHIFT       1
# define PR_MTE_TCF_NONE        (0UL << PR_MTE_TCF_SHIFT)
# define PR_MTE_TCF_SYNC        (1UL << PR_MTE_TCF_SHIFT)
# define PR_MTE_TCF_ASYNC       (2UL << PR_MTE_TCF_SHIFT)
# define PR_MTE_TCF_MASK        (3UL << PR_MTE_TCF_SHIFT)
# define PR_MTE_TAG_SHIFT       3
# define PR_MTE_TAG_MASK        (0xffffUL << PR_MTE_TAG_SHIFT)

/*
 * Insert a random logical tag into the given pointer.
 */
#define insert_random_tag(ptr) ({                 \
	uint64_t __val;                                 \
  asm("irg %0, %1" : "=r" (__val) : "r" (ptr));   \
  __val;                                          \
})

/*
 * Set the allocation tag on the destination address.
 */
#define set_tag(tagged_addr) do {                                \
	asm volatile("stg %0, [%0]" : : "r" (tagged_addr) : "memory"); \
} while (0)

int main()
{
  unsigned char *a;
  unsigned long page_sz = sysconf(_SC_PAGESIZE);
  unsigned long hwcap2 = getauxval(AT_HWCAP2);

  /* check if MTE is present */
  if (!(hwcap2 & HWCAP2_MTE))
    return EXIT_FAILURE;

  /*
   * Enable the tagged address ABI, synchronous MTE tag check faults and
   * allow all non-zero tags in the randomly generated set.
   */
  if (prctl(PR_SET_TAGGED_ADDR_CTRL, PR_TAGGED_ADDR_ENABLE | 
            PR_MTE_TCF_SYNC | (0xfffe << PR_MTE_TAG_SHIFT),
            0, 0, 0)) {
    perror("prctl() failed");
    return EXIT_FAILURE;
  }

  a = mmap(0, page_sz, PROT_READ | PROT_WRITE,
           MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
  if (a == MAP_FAILED) {
    perror("mmap() failed");
    return EXIT_FAILURE;
  }

  /*
   * Enable MTE on the above anonymous mmap. The flag could be passed
   * directly to mmap() and skip this step.
   */
  if (mprotect(a, page_sz, PROT_READ | PROT_WRITE | PROT_MTE)) {
    perror("mprotect() failed");
    return EXIT_FAILURE;
  }

  /* access with the default tag (0) */
  a[0] = 1;
  a[1] = 2;

  printf("a[0] = %hhu a[1] = %hhu\n", a[0], a[1]);

  /* set the logical and allocation tags */
  a = (unsigned char *)insert_random_tag(a);
  set_tag(a);

  printf("%p\n", a);

  /* non-zero tag access */
  a[0] = 3;
  printf("a[0] = %hhu a[1] = %hhu\n", a[0], a[1]);

  /*
   * If MTE is enabled correctly the next instruction will generate an    
   * exception.
   */
  printf("Expecting SIGSEGV...\n");
  a[16] = 0xdd;

  /* this should not be printed in the PR_MTE_TCF_SYNC mode */
  printf("...haven't got one\n");

  return EXIT_FAILURE;
}
```

Compiled the above test file with -march=armv8.5-a+memtag.

```shell
gcc test.c -march=armv8.5-a+memtag
./a.out
```

This executable generates an exception due to the invalid memory access a[16] . 

<img src="https://i.loli.net/2020/09/12/7mRS9BaEUoncg8H.png" alt="image-20200817204848121" style="zoom:45%;" />


