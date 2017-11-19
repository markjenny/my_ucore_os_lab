# lab5
---
# 练习0
---
由于现在合入代码的量变得比较多，已经不适合用`diff`和`patch`这两个工具来打补丁了，直接使用meld图形化工具，方便快捷；毕竟人眼对可视化的工具更加适应。

---


---
# 附
---

这次的实验几个题都是比较简单的，但并不是说用户进程的切换是简单的，我们平时可以自己思考一下一个用户进程是如何切换到另外一个进程的并观察修改代码来巩固知识；实验只是通过一个简单的方法让我被操作系统"温柔以待"。

我在实验5中写完一下代码在运行之后出现了崩溃，这种情况在前几个实验中没有怎么出现，所以我挺珍惜这次的查Bug机会，把我的思路放上来(其实这个Bug后头来看还是挺简单的。。。。)

在写完lab5之后，我运行测试core之后出现了如下的错误:

```
Special kernel symbols:
  entry  0xc010002a (phys)
  etext  0xc010be7b (phys)
  edata  0xc019bf2a (phys)
  end    0xc019f0b8 (phys)
Kernel executable memory footprint: 637KB
ebp:0xc0129f38 eip:0xc0100af1 args: 0x00010094 0x00000000 0xc0129f68 0xc01000d3 
    kern/debug/kdebug.c:358: print_stackframe+28
ebp:0xc0129f48 eip:0xc0100e0f 
ebp:0xc0129f48 eip:0xc0100e0f args: 0x00000000 0x00000000 0x00000000 0xc0129fb8 
    kern/debug/kmonitor.c:129: mon_backtrace+10
ebp:0xc0129f68 eip:0xc01000d3 
ebp:0xc0129f68 eip:0xc01000d3 args: 0x00000000 0xc0129f90 0xffff0000 0xc0129f94 
    kern/init/init.c:58: grade_backtrace2+33
ebp:0xc0129f88 eip:0xc01000fc 
ebp:0xc0129f88 eip:0xc01000fc args: 0x00000000 0xffff0000 0xc0129fb4 0x0000002a 
    kern/init/init.c:63: grade_backtrace1+38
ebp:0xc0129fa8 eip:0xc010011a 
ebp:0xc0129fa8 eip:0xc010011a args: 0x00000000 0xc010002a 0xffff0000 0x0000001d 
    kern/init/init.c:68: grade_backtrace0+23
ebp:0xc0129fc8 eip:0xc010013f 
ebp:0xc0129fc8 eip:0xc010013f args: 0xc010be9c 0xc010be80 0x0000318e 0x00000000 
    kern/init/init.c:73: grade_backtrace+34
ebp:0xc0129ff8 eip:0xc010007f 
ebp:0xc0129ff8 eip:0xc010007f args: 0x00000000 0x00000000 0x0000ffff 0x40cf9a00 
    kern/init/init.c:33: kern_init+84
ebp:0x00000000 eip:0xc0100028 
ebp:0x00000000 eip:0xc0100028 args: 0x00000000 0x00000000 0x00000000 0x00000000 
    kern/init/entry.S:27: <unknown>+0
ebp:0x00000000 eip:0x00000000 
ebp:0x00000000 eip:0x00000000 args: 0x00000000 0x00000000 0x00000000 0x00000000 
    <unknow>: -- 0xffffffff --
ebp:0x00000000 eip:0x00000000 
ebp:0x00000000 eip:0x00000000 args: 0x00000000 0x00000000 0x00000000 0x00000000 
    <unknow>: -- 0xffffffff --
ebp:0x00000000 eip:0x00000000 
ebp:0x00000000 eip:0x00000000 args: 0x00000000 0x00000000 0x00000000 0x00000000 
    <unknow>: -- 0xffffffff --
ebp:0x00000000 eip:0x00000000 
ebp:0x00000000 eip:0x00000000 args: 0x00000000 0x00000000 0x00000000 0x00000000 
    <unknow>: -- 0xffffffff --
ebp:0x00000000 eip:0x00000000 
ebp:0x00000000 eip:0x00000000 args: 0x00000000 0x00000000 0x00000000 0x00000000 
    <unknow>: -- 0xffffffff --
ebp:0x00000000 eip:0x00000000 
ebp:0x00000000 eip:0x00000000 args: 0x00000000 0x00000000 0x00000000 0x00000000 
    <unknow>: -- 0xffffffff --
ebp:0x00000000 eip:0x00000000 
ebp:0x00000000 eip:0x00000000 args: 0x00000000 0x00000000 0x00000000 0x00000000 
    <unknow>: -- 0xffffffff --
ebp:0x00000000 eip:0x00000000 
ebp:0x00000000 eip:0x00000000 args: 0x00000000 0x00000000 0x00000000 0x00000000 
    <unknow>: -- 0xffffffff --
ebp:0x00000000 eip:0x00000000 
ebp:0x00000000 eip:0x00000000 args: 0x00000000 0x00000000 0x00000000 0x00000000 
    <unknow>: -- 0xffffffff --
ebp:0x00000000 eip:0x00000000 
ebp:0x00000000 eip:0x00000000 args: 0x00000000 0x00000000 0x00000000 0x00000000 
    <unknow>: -- 0xffffffff --
ebp:0x00000000 eip:0x00000000 
ebp:0x00000000 eip:0x00000000 args: 0x00000000 0x00000000 0x00000000 0x00000000 
    <unknow>: -- 0xffffffff --
ebp:0x00000000 eip:0x00000000 
ebp:0x00000000 eip:0x00000000 args: 0x00000000 0x00000000 0x00000000 0x00000000 
    <unknow>: -- 0xffffffff --
ebp:0x00000000 eip:0x00000000 
memory management: default_pmm_manager
e820map:
  memory: 0009fc00, [00000000, 0009fbff], type = 1.
  memory: 00000400, [0009fc00, 0009ffff], type = 2.
  memory: 00010000, [000f0000, 000fffff], type = 2.
  memory: 07efe000, [00100000, 07ffdfff], type = 1.
  memory: 00002000, [07ffe000, 07ffffff], type = 2.
  memory: 00040000, [fffc0000, ffffffff], type = 2.
check_alloc_page() succeeded!
Can not get the pte.
check_pgdir() succeeded!
check_boot_pgdir() succeeded!
-------------------- BEGIN --------------------
PDE(0e0) c0000000-f8000000 38000000 urw
  |-- PTE(38000) c0000000-f8000000 38000000 -rw
PDE(001) fac00000-fb000000 00400000 -rw
  |-- PTE(000e0) faf00000-fafe0000 000e0000 urw
  |-- PTE(00001) fafeb000-fafec000 00001000 -rw
--------------------- END ---------------------
use SLOB allocator
kmalloc_init() succeeded!
check_vma_struct() succeeded!
page fault at 0x00000100: K/W [no page found].
check_pgfault() succeeded!
check_vmm() succeeded.
not valid addr 9e, and  can not find it in vma
trapframe at 0xc0129e94
  edi  0x00000001
  esi  0x00000000
  ebp  0xc0129ef8
  oesp 0xc0129eb4
  ebx  0x00010094
  edx  0xc0382090
  ecx  0x00000016
  eax  0x0000002a
  ds   0x----0010
  es   0x----0010
  fs   0x----0023
  gs   0x----0023
  trap 0x0000000e Page Fault
  err  0x00000002
  eip  0xc010971a
  cs   0x----0008
  flag 0x00000002 IOPL=0
kernel panic at kern/trap/trap.c:222:
    handle pgfault failed in kernel mode. ret=-3
```

在上述的代码中我们可以发现`not valid addr 9e, and  can not find it in vma`这个日志信息，我初始的考虑是有可能我访问了vma之外的虚拟地址空间，所以我想在函数`do_pgfault`中的输出信息中再增加一些日志信息，例如我现在访问的逻辑地址是`0x11111`，但是正常的虚拟地址逻辑是`0x000000`~`0x10000`中，因此我将`do_pgfault`中的如下代码进行了修改：
```
   if (vma == NULL || vma->vm_start > addr) 
   {
        cprintf("not valid addr %x, and  can not find it in vma\n", addr);
   }
```

将上述的代码略微修改一下：
```
   if (vma == NULL || vma->vm_start > addr || vma->vm_end < addr) 
   {
        cprintf("not valid addr %x, and  can not find it in vma range[%x~%x]\n", 
                addr, vma->vm_start, vma->vm_end);
   }
```
当我使用上述的代码进行修改时发现并没有正常输出这句话，而是爆栈了，这就说明其实并不是addr有问题而是vma就是存在问题的，大概率说明整个PCB是存在问题的，可能是在切换的过程产生了错误(**此时大方向是确定了的~**)。

我们平时是使用qemu进行模拟，那么qemu提供了查看backtrace的功能，我用lab5_err.log存储下来了，具体的内容如下：
```
K> backtrace
ebp:0xc0129d48 eip:0xc0100af1 args: 0x00000000 0x00000001 0xc0129dc8 0xc0100d0d 
    kern/debug/kdebug.c:358: print_stackframe+28
ebp:0xc0129d58 eip:0xc0100e0f 
ebp:0xc0129d58 eip:0xc0100e0f args: 0x00000000 0xc0129d7c 0x00000000 0x00000000 
    kern/debug/kmonitor.c:129: mon_backtrace+10
ebp:0xc0129dc8 eip:0xc0100d0d 
ebp:0xc0129dc8 eip:0xc0100d0d args: 0xc019bf60 0x00000000 0xc010c576 0xc0129e40 
    kern/debug/kmonitor.c:75: runcmd+137
ebp:0xc0129df8 eip:0xc0100d8b 
ebp:0xc0129df8 eip:0xc0100d8b args: 0x00000000 0xc0129e3c 0x000000de 0xc010134a 
    kern/debug/kmonitor.c:96: kmonitor+85
ebp:0xc0129e28 eip:0xc0100e80 
ebp:0xc0129e28 eip:0xc0100e80 args: 0xc010c500 0x000000de 0xc010c548 0xfffffffd 
    kern/debug/panic.c:30: __panic+105
ebp:0xc0129e58 eip:0xc01028bd 
ebp:0xc0129e58 eip:0xc01028bd args: 0xc0129e94 0xc01a7084 0x00000001 0xc01a708c 
    kern/trap/trap.c:222: trap_dispatch+242
ebp:0xc0129e88 eip:0xc0102af0 
ebp:0xc0129e88 eip:0xc0102af0 args: 0xc0129e94 0x00000001 0x00000000 0xc0129ef8 
    kern/trap/trap.c:319: trap+74
ebp:0xc0129ef8 eip:0xc0102b45 
ebp:0xc0129ef8 eip:0xc0102b45 args: 0xc0382090 0x00000000 0xc0129f44 0xc012aa00 
    kern/trap/trapentry.S:24: <unknown>+0
ebp:0xc0129f28 eip:0xc0109ee8 
ebp:0xc0129f28 eip:0xc0109ee8 args: 0x00000100 0x00000000 0xc0129f44 0xc0382000 
    kern/process/proc.c:463: do_fork+241
ebp:0xc0129f98 eip:0xc0109ad1 
ebp:0xc0129f98 eip:0xc0109ad1 args: 0xc010ab2f 0x00000000 0x00000000 0x00007c7c 
    kern/process/proc.c:272: kernel_thread+111
ebp:0xc0129fc8 eip:0xc010adb5 
ebp:0xc0129fc8 eip:0xc010adb5 args: 0xc010be9c 0xc010be80 0x0000318e 0x00000000 
    kern/process/proc.c:909: proc_init+255
ebp:0xc0129ff8 eip:0xc0100098 
ebp:0xc0129ff8 eip:0xc0100098 args: 0x00000000 0x00000000 0x0000ffff 0x40cf9a00 
    kern/init/init.c:41: kern_init+109
```

可以看到`do_fork`中中存在了异常，而这个地方正是子进程和父进程建立连接关系时出的问题，我们可以通过GDB来定位在do_fork这里，因为这个时候页式内存管理已经建立起来了，所以不需要在物理地址上打断点了，可以直接在函数上打断点；GDB调试ucore的方法可以看我的lab1的report.md。

当定位到set_link之后，我观察了一下current_proc和proc的各个成员：
```
(gdb) p *current
$1 = {state = PROC_RUNNABLE, pid = 0, runs = 0, kstack = 3222437888, need_resched = 1, 
  parent = 0x0, mm = 0x0, context = {eip = 0, esp = 0, ebx = 0, ecx = 0, edx = 0, esi = 0, 
    edi = 0, ebp = 0}, tf = 0x0, cr3 = 2752512, flags = 0, name = "idle\000create ini", 
  list_link = {prev = 0xc0382008, next = 0xc0382040}, hash_link = {prev = 0x20, 
    next = 0xc0382ca8}, exit_code = -1070063608, wait_state = 40, cptr = 0x2a, yptr = 0x0, 
  optr = 0xc0382008}
(gdb) p *proc
$2 = {state = PROC_UNINIT, pid = 1, runs = 0, kstack = 3224907776, need_resched = 0, 
  parent = 0xc0382008, mm = 0x0, context = {eip = 3222313283, esp = 3224915892, ebx = 0, 
    ecx = 0, edx = 0, esi = 0, edi = 0, ebp = 0}, tf = 0xc0384fb4, cr3 = 2752512, flags =
0, 
  name = '\000' <repeats 15 times>, list_link = {prev = 0x10, next = 0xc0382ca8}, 
  hash_link = {prev = 0xc019e360 <hash_list+5056>, next = 0xc019e360 <hash_list+5056>}, 
  exit_code = 22, wait_state = 0, cptr = 0xc0382008, yptr = 0xc03820e0, optr = 0xc}
```

当我观察到`current`的数据成员`cptr`为`0x2a`时，我就知道问题所在了==，我忘记对struct proc中新增的数据成员忘记初始化了。

当对struct proc中新增的数据成员进行初始化之后，ucore就可以正常运行了，这就是我的一次调试ucore的普通操作。
