---
title: Overview of Linux kernel
date: 2020-12-27 20:47:53
tags:
	- Kernel
categories: Surveys
---

Linux内核、驱动程序和硬件的关系，从中可以看出，内核的几个模块，相应的系统调用也可以分为这几类 http://seclab.cs.sunysb.edu/sekar/papers/syscallclassif.htm

1. 进程管理模块
2. 内存管理模块
3. 文件系统模块 file system
4. 设备控制模块 device driver
5. 网络模块 network

<!--more-->

<img src="https://i.loli.net/2020/12/27/mgGj6SIcwTAOnxk.png" alt="image-20201227204911819" style="zoom:60%;" />

Coq Formal Verification for kernel

### File Access

#### Setup

WriteOpen (path) - open and possibly create a file for write = { open(path, flags) | (flags & (O_WRONLY | O_APPEND | O_TRUNC)), open(path, flags, mode) | (flags & (O_WRONLY | O_APPEND | O_TRUNC)), creat(path, mode); }

ReadOpen(path) - open a file for read = { open(path,flags) | (flags & O_RONLY), open(path,flags,mode) | (flags & O_RONLY), }

open_2(path) - open a file = { ReadOpen(path), WriteOpen(path), }

truncate_2(path, len) - truncate a file to a specified length = { truncate(path, len), ftruncate(fd, len) | path = fdToName(fd) }

creat - create a file(3)
int creat(const char *pathname, mode_t mode);

open - open and possibly create a file or device
int open(const char *pathname, int flags);
int open(const char *pathname, int flags, mode_t mode);

truncate, ftruncate - truncate a file to a specified length(11)
int truncate(const char *path, size_t length);
int ftruncate(int fd, size_t length);

pipe - create pipe
int pipe(int filedes[2]);

#### File Attributes

filePermCheck(path) - check file permission = { stat(path,buf) fstat(fd, buf) | path = fdToName(fd) lstat(path, buf) access(path, mode) }

fileAttrCheck(path) - check any file attribute = { stat(path, buf) fstat(fd, buf) | path = fdToName(fd) lstat(path, buf) }

***filePermChange(path) - change file permissions = {
chmod_2(path, mode)
chown_2(path, owner, group)
}\***

***fileAttrChange(path) - change file attributes = {
filePermChange(path)
\***

stat_2(path, buf) - get file status = { stat(path, buf) fstat(fd, buf) | path = fdToName(fd) }

chmod_2(path, mode) - change permissions of a file = { chmod(path, mode), fchmod(fd, mode) | path = fdToName(fd); }

chown_2(path, owner, group) - change ownership of a file = { chown(path, owner, group), fchown(fd, owner, group) | path = fdToName(fd) }

link_2 (oldpath, newpath) - make a new name for a file = { link(oldpath, newpath), symlink(topath, frompath) }

access - check user's permissions for a file
int access(const char *pathname, int mode);

stat, fstat, lstat - get file status
int stat(const char *file_name, struct stat *buf);
int fstat(int filedes, struct stat *buf);
int lstat(const char *file_name, struct stat *buf);

umask - set file creation mask
int umask(int mask);

utime, utimes - change access and/or modification times of an inode(32)
int utime(const char *filename, struct utimbuf *buf);
int utimes(char *filename, struct timeval *tvp);

chmod, fchmod - change permissions of a file
int chmod(const char *path, mode_t mode);
int fchmod(int fildes, mode_t mode);

chown, fchown - change ownership of a file
int chown(const char *path, uid_t owner, gid_t group);
int fchown(int fd, uid_t owner, gid_t group);

link - make a new name for a file
int link(const char *oldpath, const char *newpath);

symlink - make a new name for a file
int symlink(const char *topath, const char *frompath);

rename - change the name or location of a file
int rename(const char *oldpath, const char *newpath);

unlink - delete a name and possibly the file it refers to
int unlink(const char *pathname);

#### Read/Write

_llseek,lseek - reposition read/write file offset
int _llseek(unsigned int fd, unsigned long offset_high, unsigned long offset_low, loff_t * result, unsigned int whence);
off_t lseek(int fildes, off_t offset, int whence);

lseek_2(fd, offset, whence) - reposition read/write file offset = { _llseek(fd, offset_high, offset_low, \* , whence) | offset = (offset_high<<32) | offset_low, lseek(fd, offset, whence) }

readlink - read value of a symbolic link
int readlink(const char *path, char *buf, size_t bufsiz);

#### Directory Operations

mkdir - create a directory
int mkdir(const char *pathname, mode_t mode);

mknod - create a directory
int mknod(const char *pathname, mode_t mode, dev_t dev);

mkdir_2(path, mode) - create a directory = { mkdir(path, mode), mknod(path, mode, \*) }

rmdir - delete a directory
int rmdir(const char *pathname);

getdents - get directory entries
int getdents(unsigned int fd, struct dirent *dirp, unsigned int count);

readdir - read directory entry
int readdir(unsigned int fd, struct dirent *dirp, unsigned int count);

#### Miscellaneous

fdatasync - synchronize a file's in-core data with that on disk
int fdatasync(int fd);

fsync - synchronize a file's complete in-core state with that on disk
int fsync(int fd);

msync - synchronize a file with a memory map
int msync(const void *start, size_t length, int flags);

chroot - change root directory
int chroot(const char *path);

chdir, fchdir - change working directory(2)
int chdir(const char *path);
int fchdir(int fd);

chdir_2(path)- change working directory = { chdir(path), fchdir(fd) | path = fdToName(fd) }

### Network Access

#### Setup

socket - create an endpoint for communication
int socket(int domain, int type, int protocol);

socketpair - create a pair of connected sockets
int socketpair(int d, int type, int protocol, int sv[2]);

getsockopt - get options on sockets
int getsockopt(int s, int level, int optname, void *optval, int *optlen);

setsockopt - set options on sockets
int setsockopt(int s, int level, int optname, const void *optval, int optlen);

bind - bind a name to a socket
int bind(int sockfd, struct sockaddr *my_addr, int addrlen);

getsockname - get socket name
int getsockname(int s , struct sockaddr * name , int * namelen )

listen - listen for connections on a socket
int listen(int s, int backlog);

accept - accept a connection on a socket
int accept(int s, struct sockaddr *addr, int *addrlen);

connect - initiate a connection on a socket
int connect(int sockfd, struct sockaddr *serv_addr, int addrlen );

shutdown - shut down part of a full-duplex connection
int shutdown(int s, int how);

#### Send/Receive

recv, recvfrom, recvmsg - receive a message from a socket
int recv(int s, void *buf, int len, unsigned int flags);
int recvfrom(int s, void *buf, int len, unsigned int flags, struct sockaddr *from, int *fromlen);
int recvmsg(int s, struct msghdr *msg, unsigned int flags);

recv_2 (s, buf, len, flag) - receive a message from a socket = { recv(s, buf, len, flag), recvfrom( s, buf, len, flag, \*), recvmsg(s, msg, flag) | buf = FUN get_buf(\*msg) len = FUN get_len(\*msg) } *

send, sendto, sendmsg - send a message from a socket(25)
int send(int s, const void *msg, int len, unsigned int flags);
int sendto(int s, const void *msg, int len, unsigned int flags, const struct sockaddr *to, int tolen);
int sendmsg(int s, const struct msghdr *msg, unsigned int flags);

send_2 (s, msg, len, flag) - send a message to a socket = { send(s, msg, len, flag), sendto( s, msg, len, flag, \*), sendmsg(s, msg, flag) | len = FUN get_len(\*msg) } *

#### Naming

getdomainname -- get domain name
int getdomainname(char *name, size_t len);

setdomainname - set domain name
int setdomainname(const char *name, size_t len);

gethostid - get the unique identifier of the current host
long int gethostid(void);

gethostname - get host name
int gethostname(char *name, size_t len);

gethostid_2() - get the unique identifier of the current host = { gethostid(void), gethostname(name, len) | return_value = NameToId(name) } *

sethostid - set the unique identifier of the current host
int sethostid(long int hostid);

sethostname - set host name(28)
int sethostname(const char *name, size_t len);

sethostid_2() - set the unique identifier of the current host = { sethostid(void), sethostname(name, len) | return_value = NameToId(name) } *

getpeername - get name of connected peer
int getpeername(int s, struct sockaddr *name, int *namelen)

### Message Queues

msgctl - message control operations
int msgctl(int msqid, int cmd, struct msqid_ds *buf )

msgget - get a message queue identifier
int msgget(key_t key, int msgflg)

msgsnd - send message
int msgsnd(int msqid, struct msgbuf *msgp, int msgsz, int msgflg )

msgrcv - receive messsage
int msgrcv(int msqid, struct msgbuf *msgp, int msgsz, long msgtyp, int msgflg )

### Shared Memory

shmctl - shared memory control
int shmctl(int shmid, int cmd, struct shmid_ds *buf);

shmat - shared memory operations
char *shmat(int shmid, char *shmaddr, int shmflg )

shmdt - shared memory operations
int shmdt(char *shmaddr)

shmget - allocates a shared memory segment
int shmget(key_t key, int size, int shmflg);

### File Descriptor Operations

#### Setup

close - close a file descriptor
int close(int fd);

mmap - map files or devices into memory
void * mmap(void *start, size_t length, int prot , int flags, int fd, off_t offset);

munmap - unmap files or devices into memory
int munmap(void *start, size_t length);

getdtablesize - get descriptor table size
int getdtablesize(void);

dup, dup2 - duplicate a file descriptor
int dup(int oldfd);
int dup2(int oldfd, int newfd);

dup_2(fd) - duplicate a file descriptor = { dup(fd), dup2(oldfd, newfd) | return_value = newfd, } *

#### Read/Write

read - read from a file descriptor
ssize_t read(int fd, void *buf, size_t count);

readv - read a vector
int readv(int fd, const struct iovec * vector, size_t count);

read_2(fd,buf,count) = { read(fd, buf,count), readv(fd, vector, count) |buf = FUN get_buf(vector) }

read_3(fd,buf, count) = { read_2(fd, buf,count), [recv_2 (fd, buf, count, \*)](http://seclab.cs.sunysb.edu/sekar/papers/classifbody.htm#recv2) }

write - write to a file descriptor
ssize_t write(int fd, const void *buf, size_t count);
int writev(int fd, const struct iovec * vector, size_t count);

write_2(fd,buf,len) = { write(fd, buf,count), writev(fd, vector, count) |buf = FUN get_buf(vector) }

write_3(fd,buf,len) = { write_2(fd, buf, len), [send_2(fd, buf, len, \*)](http://seclab.cs.sunysb.edu/sekar/papers/classifbody.htm#send2) }

#### File Descriptor Control

flock - apply or remove an advisory lock on an open file
int flock(int fd, int operation)

fcntl - manipulate file descriptor
int fcntl(int fd, int cmd);
int fcntl(int fd, int cmd, long arg);

fcntl_2(fd, cmd) - manipulate file descriptor = { fcntl(fd, cmd), fcntl(fd, cmd, arg) } *

ioctl - control device
int ioctl(int d, int request, ...)

### Time-Related

nanosleep - pause execution for a specified time
int nanosleep(const struct timespec *req, struct timespec *rem);

alarm - set an alarm clock for delivery of a signal
unsigned int alarm(unsigned int seconds);

getitimer - get value of an interval timer
int getitimer(int which, struct itimerval *value);

setitimer - set value of an interval timer
int setitimer(int which, const struct itimerval *value, struct itimerval *ovalue);

gettimeofday - get time
int gettimeofday(struct timeval *tv, struct timezone *tz);

settimeofday - set time
int settimeofday(const struct timeval *tv , const struct timezone *tz);

time - get time in seconds
time_t time(time_t *t);

times - get process times
clock_t times(struct tms *buf);

### Process Control

#### Process Creation and Termination

_exit - terminate the current process
void _exit(int status);

clone - create a child process
pid_t clone(void *sp, unsigned long flags)

execve - execute program
int execve(const char *filename, const char *argv [], const char *envp[]);

fork, vfork - create a child process
pid_t fork(void);
pid_t vfork(void);

 fork_2() - create a child process = { fork(void), vfork(void); } *

wait, waitpid - wait for process termination(34)
pid_t wait(int *status)
pid_t waitpid(pid_t pid, int *status, int options);

wait_2 (status) = { wait (status), waitpid(pid, status, \*) | pid = 0; } *

pid_t wait4(pid_t pid, int *status, int options,
struct rusage *rusage)

wait3, wait4 - wait for process termination, BSD style(35)
pid_t wait3(int *status, int options, struct rusage *rusage)

getpid - get current process identification
pid_t getpid(void);

getppid - get parent process identification
pid_t getppid(void);

#### Signals

kill - send signal to a process(16)
int kill(pid_t pid, int sig);

killpg - send signal to a process group
int killpg(int pgrp, int sig);

kill_2(pid,sig) - send signal to a process = { kill(pid, sig), killpg(pgrp, sig) | pid = pgrp } *

sigblock - manipulate the signal mask
int sigblock(int mask);

sigmask - manipulate the signal mask
int sigmask(int signum);

siggetmask - manipulate the signal mask
int siggetmask(void);

sigsetmask - manipulate the signal mask
int sigsetmask(int mask);

signal - ANSI C signal handling
void(*signal(int signum, void(*handler)(int)))(int);

sigvec - BSD software signal facilities
int sigvec(int sig, struct sigvec *vec, struct sigvec *ovec);

sigaction - POSIX signal handling functions.
int sigaction(int signum, const struct sigaction *act, struct sigaction *oldact);

sigprocmask - POSIX signal handling functions.
int sigprocmask(int how, const sigset_t *set, sigset_t *oldset);

sigpending - POSIX signal handling functions.
int sigpending(sigset_t *set);

sigsuspend - POSIX signal handling functions.
int sigsuspend(const sigset_t *mask);

sigpause - atomically release blocked signals and wait for interrupt
int sigpause(int sigmask);

pause - wait for signal
int pause(void);

sigreturn - return from signal handler and cleanup stack frame
int sigreturn(unsigned long __unused);

#### Synchronization

poll - wait for some event on a file descriptor
int poll(struct pollfd *ufds, unsigned int nfds, int timeout);

select - synchronous I/O multiplexing
int select(int n, fd_set *readfds, fd_set *writefds, fd_set *exceptfds, struct timeval *timeout);

semctl - semaphore control operations
int semctl(int semid, int semnun, int cmd, union semun arg )

semget - get a semaphore set identifier
int semget(key_t key, int nsems, int semflg )

semop - semaphore operations
int semop(int semid, struct sembuf *sops, unsigned nsops)

#### User/Group Id

getuid - get user real ID
uid_t getuid(void);

getgid - returns the real group ID of the current process.
gid_t getgid(void);

getegid - returns the effective group ID of the current process.
gid_t getegid(void);

geteuid - returns the effective user ID of the current process.
uid_t geteuid(void);

getresuid - get real, effective and saved user ID(14)
int getresuid(uid_t *ruid, uid_t *euid, uid_t *suid);

getuid_2() - get real user ID = { geteuid(void), getresuid(ruid, euid, suid) | return_value = ruid } 

geteuid_2() - get effective user ID = { geteuid(void), getresuid(ruid, euid, suid) | return_value = euid } 

getgid_2() - get real group ID = { getgid(), getresgid(rgid, egid, sgid) | return_value = rgid } 

getegid_2() - get effective group ID = { getegid(), getresgid(rgid, egid, sgid) | return_value = egid } 

getresgid - get real, effective and saved group ID(15)
int getresgid(gid_t *rgid, gid_t *egid, gid_t *sgid);

getsid - getsid - get session ID
pid_t getsid(void);

getpgid - get process group ID
pid_t getpgid(pid_t pid);

getpgrp -get process group ID
pid_t getpgrp(void);
getpgrp is equivalent to getpgid(0).

getpgid_2 (pid) - get process group ID = { getpgid(pid), getpgrp(void) | pid = 0 } 

getgroups - get group access list
int getgroups(int size, gid_t list[])

setegid - set effective group ID
int setegid(gid_t egid);

seteuid - set effective user ID
int seteuid(uid_t euid);

setfsgid - set group identity used for file system checks
int setfsgid(uid_t fsgid)

setfsuid - set user identity used for file system checks
int setfsuid(uid_t fsuid)

setgid - set group identity
int setgid(gid_t gid)

setregid - set real and / or effective group ID
int setregid(gid_t rgid, gid_t egid);

setreuid - set real and / or effective user ID
int setreuid(uid_t ruid, uid_t euid);

setresgid - set real, effective and saved group ID(30)
int setresgid(gid_t rgid, gid_t egid, gid_t sgid);

setresuid - set real, effective and saved user ID(29)
int setresuid(uid_t ruid, uid_t euid, uid_t suid);

setuid_2() - set real user ID ) = { seteuid(void), setresuid(ruid, euid, suid) | return_value = ruid } 

seteuid_2() - set effective user ID = { seteuid(void), setresuid(ruid, euid, suid) | return_value = euid } 

setgid_2() - set real group ID = { setgid(), setresgid(rgid, egid, sgid) | return_value = rgid } *

setegid_2() - set effective group ID = { setegid(), setresgid(rgid, egid, sgid) | return_value = egid } *

setgroups - set group access list
int setgroups(size_t size, const gid_t *list);

setsid - creates a session and sets the process group ID
pid_t setsid(void);

setuid - set user identity
int setuid(uid_t uid)

#### Resource Control

getrlimit - get resource limit
int getrlimit(int resource, struct rlimit *rlim)

setrlimit - set resource limits
int setrlimit(int resource, const struct rlimit *rlim);

getrusage - get resource usage
int getrusage(int who, struct rusage *usage);

getpriority - get program scheduling priority
int getpriority(int which, int who);

nice - change process priority
int nice(int inc);

setpriority - set program scheduling priority
int getpriority(int which, int who);

#### Virtual Memory

brk {,sbrk} - change data segment size
int brk(void *end_data_segment);
void *sbrk(ptrdiff_t increment);

mlock - disable paging for some parts of memory(20)
int mlock(const void *addr, size_t len);

mlockall - disable paging for calling process
int mlockall(int flags);

munlock - reenable paging for some parts of memory(21)
int munlock(const void *addr, size_t len);

munlockall - reenable paging for calling process
int munlockall(void);

mprotect - control allowable accesses to a region of memory
int mprotect(const void *addr, size_t len, int prot);

mremap - re-map a virtual memory address
void * mremap(void * old_address, size_t old_size , size_t
new_size, unsigned long flags);

modify_ldt - get or set local descriptor table, a per-process memory management table used by the i386 processor
int modify_ldt(int func, void *ptr, unsigned long bytecount);

#### Miscellaneous

uselib - select shared library
int uselib(const char *library);

profil - execution time profile
int profil(char *buf, int bufsiz, int offset, int scale);

ptrace - process trace
int ptrace(int request, int pid, int addr, int data);

### System-Wide

#### Unprivileged -- Filesystem

sync - commit buffer cache to disk.
int sync(void);

ustat - get file system statistics
int ustat(dev_t dev, struct ustat * ubuf);

statfs, fstatfs - get file system statistics(10)
int statfs(const char *path, struct statfs *buf);
int fstatfs(int fd, struct statfs *buf);

sysfs - get file system type information(31)
int sysfs(int option, const char * fsname);
int sysfs(int option, unsigned int fs_index, char * buf);
int sysfs(int option);

#### Unprivileged -- Miscellaneous

getpagesize - get system page size
size_t getpagesize(void);

sysinfo - returns information on overall system statistics
int sysinfo(struct sysinfo *info);

uname - get name and information about current kernel
int uname(struct utsname *buf);

#### Privileged -- Filesystem

setup - setup devices and file systems, mount root file system
int setup(void);

swapoff - stop swapping to file/device
int swapoff(const char *path);

swapon - start swapping to file/device
int swapon(const char *path, int swapflags);

nfsservctl - syscall interface to kernel nfs daemon
nfsservctl(int cmd, struct nfsctl_arg *argp, union nfsctl_res *resp);

mount - mount filesystem
int mount(const char *specialfile, const char * dir ,
const char * filesystemtype, unsigned long rwflag , const void * data);

umount - unmount filesystems.
int umount(const char *specialfile);
int umount(const char *dir);

#### Process Scheduling

sched_get_priority_max - get the max static priority
int sched_get_priority_max(int policy);

sched_get_priority_min - get the min static priority
int sched_get_priority_min(int policy);

sched_getparam - get scheduling parameters
int sched_getparam(pid_t pid, struct sched_param *p);

sched_setparam - set scheduling parameters
int sched_setparam(pid_t pid, const struct sched_param *p);

sched_getscheduler - get scheduling algorithm/parameters
int sched_getscheduler(pid_t pid);

sched_setscheduler - set scheduling algorithm/parameters
int sched_setscheduler(pid_t pid, int policy, const struct sched_param *p);

sched_rr_get_interval - get the SCHED_RR interval for the named process
int sched_rr_get_interval(pid_t pid, struct timespec *tp);

sched_yield - yield the processor
int sched_yield(void);

#### Privileged -- Time

stime - set time
int stime(time_t *t);

adjtimex - tune kernel clock
int adjtimex(struct timex *buf);

#### Loadable Modules

create_module - create a loadable module entry
caddr_t create_module(const char *name, size_t size);

delete_module - delete a loadable module entry
int delete_module(const char *name);

init_module - initialize a loadable module entry
int init_module(const char *name, struct module *image);

query_module - query the kernel for various bits pertaining to modules.
int query_module(const char *name, int which, void *buf, size_t bufsize, size_t *ret);

get_kernel_syms - retrieve exported kernel and module symbols
int get_kernel_syms(struct kernel_sym *table);

#### Accounting and Quota

acct - switch process accounting on or off
int acct(const char *filename);

quotactl - manipulate disk quotas
int quotactl(cmd, special, uid, addr)

#### Privileged -- Miscellaneous

sysctl - read/write system parameters
int _sysctl(struct __sysctl_args *args);

syslog - read and/or clear kernel message ring buffer
int syslog(int type, char *bufp, int len);

idle - make process 0 idle
void idle(void);

reboot - reboot or disable Ctrl-Alt-Del
int reboot(int magic, int magic_too, int flag);

ioperm - set port input/output permissions
int ioperm(unsigned long from, unsigned long num, int
turn_on);

iopl - change I/O privilege level
int iopl(int level);

bdflush - start, flush, or tune buffer-dirty-flush daemon(1)
int bdflush(int func, long *address);
int bdflush(int func, long data);

cacheflush - flush contents of instruction and/or data cache
int cacheflush(char *addr, int nbytes, int cache);

ipc - System V IPC system calls
int ipc(unsigned int call, int first, int second, int
third, void *ptr, long fifth);

socketcall - socket system calls
int socketcall(int call, unsigned long *args);

personality - set the process execution domain
int personality(unsigned long persona);

vhangup - virtually hangup the current tty
int vhangup(void);

vm86old, vm86 - enter virtual 8086 mode
int vm86old(struct vm86_struct * info);
int vm86(unsigned long fn, struct vm86plus_struct * v86);