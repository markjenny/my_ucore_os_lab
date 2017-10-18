# 练习0
---
练习0的代码合成方法还是采用最基本的diff和patch的方法，但是现在来看是比较复杂了；而且越到后期越不好处理；
一般如果是有可视化界面的linux系统的话还是推荐使用meld，效率要高一些；但是对于无法使用的可视化的工具的情况，还是可以使用一下淳朴的`diff`和`patch`工具应对一下。

---

# 练习1

这个练习题主要是为了测试在用户进程中出现页错误中断时应如何进行处理(但是现在都是在内核中进行模拟的)；
由于`do_pgfault`函数稍微优点长，直接摆出来会影响阅读效果，我将边阐述边对代码进行分析；

当产生页错误时，证明进程想访问的物理页是不存在的，也就是page table中的page table entry中的值并不能推断出一个物理页的存在，此时的pte的内容有两种情况：
* `uintptr_t` pte = 0，即page table entry中是没有内容的；那么就说明**虚拟内存页**还没有载入过代码或是数据(如果之前载入过代码那么这个pte就是一个swap entry);此时的操作就直接申请一个物理内存页并构建pte及快表即可。代码如下：
```
if (0 == *ptep) {                                                            
        if (NULL == pgdir_alloc_page(mm->pgdir, addr, perm))                     
        {                                                                        
           cprintf("call pgdir_alloc_page failed in do_pgfault.\n");             
           goto failed;                                                          
        }                                                                        
    }
```

* `uintptr_t` pte != 0,即page table entry中有内容，但是不是物理页的物理地址;**那么这个pte中存储的是什么值呢？**，答存储的是swap entry中的内容，用来映射交换分区中存储的指令或者数据。代码如下：
```
    else {                                                                       
        if (swap_init_ok) {                                                      
            struct Page *page = NULL;                                            
            //uintptr_t phy_addr;                                                
            ret = swap_in(mm, addr, &page);                                      
            if (0 != ret)                                                        
            {                                                                    
                cprintf("call swap_in failed in do_pgfault.\n");                 
                goto failed;                                                     
            }                                                                    
                                                                                 
            //now the page table entry is converted to real page table entry from
            //swap_entry                                                         
            //phy_addr = page2pa(page);                                          
            page_insert(mm->pgdir, page, addr, perm);                            
            //*ptep = phy_addr | PTE_P | perm;                                   
                                                                                 
            swap_map_swappable(mm, addr, page, 0);                               
        }                                                                        
        else {                                                                   
            cprintf("no swap_init_ok but ptep is %x, failed\n, *ptep");          
        }                                                                        
    }       
```

通过每个进程建立一个page directory来维护一个虚拟地址空间，如果某个虚拟地址初次访问的时产生`page fault`，那么就直接创建一个物理页并填充pte及相应的快表即可；如果某个虚拟地址访问出现`page fault`但是其linear address对应的pte其实是有值的，那么这个值就是**swap entry**，这是因为我们采用虚拟内存管理，就需要及时地将某些暂时不使用的物理内存页还给操作系统，但是为了后期还能继续使用这个物理页上的数据(毕竟一个程序的指令或者数据都是可以并可能重复使用的)，我们就将这个物理页上的数据暂时存放在磁盘空间上。

但是放置到磁盘上了之后，怎么才能在下次可以快速地找到这个页的所有数据呢，这个时候就**要重复利用一个pte了**,为了下次这个linear address产生`page fault`时可以继续读取原来的数据（这里我们假定这个数据当时时存储在了交换分区的`n~n+7`个sector上，因为一个页为4KB，一个sector为512B，因此一个页相当于8个sector），我们在pte中存储交换分区中这个`n`值，下次再缺页时通过这个pte上的offset值就可以直接准确地将数据从磁盘上写回物理内存上；

本题中还有一个问题：
> 如果ucore的缺页服务例程在执行过程中访问内存，出现了页访问异常，请问硬件要做哪些事情？

首先出现了页异常，即CPU读取物理内存时出现错误；这个时候中断控制器会向总线上发送中断信号；CPU在执行完一个指令后开始读取中断信号，获取到中断index及相应的error code信息等；接下来，CPU会将相应的error code及寄存器状态等存储在trapframe中，并根据异常对应向量值去IDT中寻找中断描述符；中断描述符中存储着中断例程对应的selector和offset，通过这两个值将CS：EIP定位到中断服务例程上，也就是我们的`do_pgfault`上进行后续处理。

其实这道题和之前我们讲的中断知识有关；
---
# 
challenge 

挑战题还是先放置在此，当全部基础题完成后在全部一一攻破；

---
# 说明

该说明主要是针对在完成实验1和实验2之后出现的问题说明及其相关的解决办法；

首先列出在完成了实验1和实验2之后，利用`make qemu`模拟操作系统启动过程时出现如下问题：

```
ide 0:      10000(sectors), 'QEMU HARDDISK'.
ide 1:     262144(sectors), 'QEMU HARDDISK'.
SWAP: manager = fifo swap manager
BEGIN check_swap: count 31994, total 31994
setup Page Table for vaddr 0X1000, so alloc a page
setup Page Table vaddr 0~4MB OVER!
set up init env for check_swap begin!
page fault at 0x00001000: K/W [no page found].
page fault at 0x00002000: K/W [no page found].
page fault at 0x00003000: K/W [no page found].
page fault at 0x00004000: K/W [no page found].
set up init env for check_swap over!
write Virt Page c in fifo_check_swap
write Virt Page a in fifo_check_swap
write Virt Page d in fifo_check_swap
write Virt Page b in fifo_check_swap
write Virt Page e in fifo_check_swap
page fault at 0x00005000: K/W [no page found].
swap_out: i 0, store page in vaddr 0x1000 to disk swap entry 2
write Virt Page b in fifo_check_swap
write Virt Page a in fifo_check_swap
page fault at 0x00001000: K/W [no page found].
swap_out: i 0, store page in vaddr 0x2000 to disk swap entry 3
swap_in: load disk swap entry 2 with swap_page in vadr 0x1000
write Virt Page b in fifo_check_swap
page fault at 0x00002000: K/W [no page found].
swap_out: i 0, store page in vaddr 0x3000 to disk swap entry 4
swap_in: load disk swap entry 3 with swap_page in vadr 0x2000
write Virt Page c in fifo_check_swap
page fault at 0x00003000: K/W [no page found].
swap_out: i 0, store page in vaddr 0x4000 to disk swap entry 5
swap_in: load disk swap entry 4 with swap_page in vadr 0x3000
write Virt Page d in fifo_check_swap
page fault at 0x00004000: K/W [no page found].
swap_out: i 0, store page in vaddr 0x5000 to disk swap entry 6
swap_in: load disk swap entry 5 with swap_page in vadr 0x4000
count is 7, total is 7
check_swap() succeeded!
++ setup timer interrupts
0: @ring 0
0:  cs = 8
0:  ds = 10
0:  es = 10
0:  ss = 10
+++ switch to  user  mode +++
trap in T_SWITCH_TOU.the value of tf_eip is c010020c
page fault at 0xc010020c: U/R [protection fault].
not valid addr c010020c, and  can not find it in vma
trapframe at 0xc011ffb4
  edi  0x00000001
  esi  0x00000000
  ebp  0xc011ffa8
  oesp 0xc011ffd4
  ebx  0x00010094
  edx  0xc0108de7
  ecx  0x00000000
  eax  0x0000001e
  ds   0x----0023
  es   0x----0023
  fs   0x----0023
  gs   0x----0023
  trap 0x0000000e Page Fault
  err  0x00000005
  eip  0xc010020c
  cs   0x----001b
  flag 0x00003286 PF,SF,IF,IOPL=3
  esp  0xc011ffa0
  ss   0x----0023
kernel panic at kern/trap/trap.c:197:
    handle pgfault failed. invalid parameter

Welcome to the kernel debug monitor!!
Type 'help' for a list of commands.
```

从上述实验结果中我们可以看到测试`check_swap`函数已经成功了，但是最后操作系统还是产生了`panic`错误，这是为什么呢？
当我们的程序和我们预想的不一样时，初始的调试技巧我认为是要依靠**日志信息**和**简单的代码逻辑推理**，因为我们在排除bug的过程中要由浅入深，很有可能一个bug就是通过简单的代码逻辑推断或者是系统日志就完全可以观察出来，如果每次都用GDB等调试工具进行调试的话过程麻烦不说，而且和该bug相关的逻辑很多的话你要从哪里开始打断点观察调试呢？所以我们调试的方式一定要由浅入深，不要上来就使用各种调试工具(当然出core dump的话就另说了)

回到本文描述的现象中，首先我们可以看到是在`switch to user mode`的过程中产生了panic，我们清楚`switch to user mode`就是我们在lab1中所写的`lab1_switch_test`函数的部分功能；那么我们现在可以对其进行着重分析了；

我们首先看到了`not valid addr c010020c, and  can not find it in vma`，这函数表明进程访问的虚拟地址空间有问题；我们知道对于一个用户态的进程来说，每个进程都有其自己的虚拟地址空间。这个地址空间在操作系统中是使用一个`mm_struct`的结构体进行管理的，其中`mm_struct`结构体上还挂者相关虚拟地址所需要使用的`vma_struct`，表明用户态进程执行时需要的连续的虚拟地址空间块；有了这两个管理结构，一旦用户态进程想访问其他的非法虚拟地址的话，就会由于没有那个相应的`vma_struct`而产生如上述代码中的`not valid addr c010020c, and  can not find it in vma`.

那么为什么`switch to user mode`之后就会出现这个问题呢？这是因为我们在写`lab1_switch_test`的时候是为了理解trackframe而强行改变其内陷栈数据，这样的话trapframe中存储的EIP寄存器的值其实还是内核时的EIP值(因为trap发生在内核态中，所以不存在栈切换)；但是这个时候由于CS和EIP都已经从trapframe中弹出了，那么CS:IP就是现在的逻辑空间；而由于我们现在仍然在模拟虚拟地址空间，EIP中的值一定不在`mm_struct`中进而产生的上述`not valid addr c010020c, and  can not find it in vma`;

上面都是我的推断，然后我特意在ucore源代码中打印了一下EIP的值，如上面的`the value of tf_eip is c010020c`所显示的，果然和想访问的`valid addr`相同，因此推断合理。