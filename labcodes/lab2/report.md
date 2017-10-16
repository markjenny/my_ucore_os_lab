# 练习0
---
以前都没用过这个diff和patch的工具，都是直接使用svn或者是git的相关客户端工具，今天使用了一下，发现用起来也是很不错的，但是因为我之前不了解，所以只是使用了一下基本的功能来处理；但是感觉重复工作还是做了比较的多的；
后期再查看用更便捷的参数或者脚本来批量处理，现在大部分是手工处理的，所以后期有好的方法我再进行迭代。

那么就先说一下我的做法；

首先，我是直接比较了kern文件夹下所有不同的文件，因为在lab1中我主要修改的就是kern下的代码；因为文件夹下还有子文件夹，所以我们要采用递归的方式来进行调用，所以需要加上-r参数，具体如下：
```
prompt# diff -r lab2/kern/ lab1/kern/ > changelist
```
其中，需要注意的是上述命令是分析数/lab2/kern/和lab1/kern/下**所有文件的具体内容差别**，如果只是想获取到这两个文件夹下哪些文件有差别，那么需要添加`--brief`参数，即简明扼要地表达出这两个文件夹下哪些文件不同，具体参数如下：
```
prompt# diff -r --brief lab2/kern/ lab1/kern/ > changelist
```

这样就会将kern文件夹下的所有不同的文件都输出出来，我是将这些不同的文件都进行了一个输出，并把他们都放置到changelist中；具体的差别如下
```
Files lab1/kern/debug/kdebug.c and lab2/kern/debug/kdebug.c differ
Only in lab2/kern/debug: kdebug.c.orig
Only in lab2/kern/debug: kdebug.c.rej
Files lab1/kern/debug/kdebug.h and lab2/kern/debug/kdebug.h differ
Files lab1/kern/debug/kmonitor.c and lab2/kern/debug/kmonitor.c differ
Files lab1/kern/debug/kmonitor.h and lab2/kern/debug/kmonitor.h differ
Files lab1/kern/driver/console.c and lab2/kern/driver/console.c differ
Only in lab2/kern/init: entry.S
Files lab1/kern/init/init.c and lab2/kern/init/init.c differ
Files lab1/kern/libs/readline.c and lab2/kern/libs/readline.c differ
Only in lab2/kern/mm: default_pmm.c
Only in lab2/kern/mm: default_pmm.h
Files lab1/kern/mm/memlayout.h and lab2/kern/mm/memlayout.h differ
Files lab1/kern/mm/mmu.h and lab2/kern/mm/mmu.h differ
Files lab1/kern/mm/pmm.c and lab2/kern/mm/pmm.c differ
Files lab1/kern/mm/pmm.h and lab2/kern/mm/pmm.h differ
Only in lab2/kern/: sync
Files lab1/kern/trap/trap.c and lab2/kern/trap/trap.c differ
Files lab1/kern/trap/trap.h and lab2/kern/trap/trap.h differ
```
那我我们就可以通过上述的文本看到哪些文件是不同的；首先理解我们自己的需求：我们是需要将lab1中新添加的代码合入到lab2中；因此像那些只存在lab2中的不同我们就不用关心了；如上面的文本所示，我们可以发现kdebug.c这个文件二者是不同的，那么我们可以diff一下这两个文件看看具体有什么不同：
```
6,9d5
< #include <sync.h>
< #include <sync.h>
< #include <kmonitor.h>
< #include <assert.h>
11,12d6
< #include <kmonitor.h>
< #include <assert.h>
310a305,341
> 	//print the important info of register ebp and esp
> 	uint32_t ebp_value;	//the value is the address of ebp register
> 	uint32_t eip_value;
> 	uint32_t argu_count = 4;
> 
> 	ebp_value = read_ebp();
> 	eip_value = read_eip(); 
> 	
> 	uint32_t i, j;
> 
> 	for (i = 0; i < STACKFRAME_DEPTH; i++)
> 	{
> 		cprintf("ebp:0x%08x eip:0x%08x ", ebp_value, eip_value);
> 		//using the uint32_t in order to simulated the addres of 32-bit
> 		//after the ebp register is [return address], and then calling function's arguments
> 		cprintf("args: ");
> 		uint32_t *argu_addr = (uint32_t*)ebp_value + 2;
> 		for (j = 0; j < argu_count; j++)	
> 		{
> 			cprintf("0x%08x ", argu_addr[j]);	
> 		}
> 		cprintf("\n");
> 		print_debuginfo(eip_value - 1);
> 		
> 		//to resolve the [error: invalid type argument of unary ‘*’] problem: convert the type of eip_value/ebp_value to [uint32_t*]
> 		eip_value = *((uint32_t*)ebp_value + 1);//when the eip points to the return address, [pop arguments] will exec;
> 		ebp_value = *(uint32_t*)ebp_value; 
> 		//eip_value = ((uint32_t*)ebp_value)[1];		//because the value of ebp_value is address, so we can use uin32_t* to convert
> 		//ebp_value = ((uint32_t*)ebp_value)[0];
> 
> 
> 		cprintf("ebp:0x%08x ", ebp_value);
> 		cprintf("eip:0x%08x \n", eip_value);
> 	}
> 
> 
> 	return;

```
这里需要插嘴一句的是，我们在使用diff命令的时候，如果你像通过patch来让a变成b，那么在diff的时候就使用`diff a b > delta`，这样delta中就回存储两个文件的不同，之后再使用`patch a delta`时就可以让a通过补丁delta变成b；了解了这个diff和patch中参数位置带来的具体效果后，我们就可以通过这种方法来填补上lab1中含有的但是lab2中不含有的代码了；

因为我们想让lab2中含有lab1拥有的代码，那么其实就可以理解成我们想让部分代码变成lab1中的样子，因为我们就需要将上文中讲到的`diff a b`中`a`的位置替换成`lab2/kern/debug/kdebug.c`，将`b`中的位置替换成`lab1/kern/debug/kdebug.c`，并将不同输出到delta文件中；delta文件中存放的就是上一个代码段中显示的内容；

仔细观察我们可以发现，lab1下的这个文件并不是完全比lan2下的这个文件多的，kdebug-lab2中包含了更多的头文件信息，所以我们并不能将这个delta用作恢复的完整文件，因为那样的话patch了之后就是一个单纯的kdebug-lab1了，而lab2新增的很多代码就没有了，这样的patch没有意义；因为我们将delta文件中，kdebug-lab2自身拥有的那部分去掉，即上文的`6,9d5`和`11,12d6`后面对应的代码去掉，这样剩下的就是kdebug-lab1中比kdebug-lab2中完全新增的东西，这个时候执行如下命令：
```
prompt# patch lab2/kern/debug/kdebug.c delta
```
就可以将kdebug-lab1中新增的代码都patch到kdebug-lab2上；
剩下的新增文件都采用这种方法（感觉还是稍微有点笨拙）。

----
# 练习一

(*由于有的时候需要进行总结性的思考，而我的印象笔记有的篇幅有些杂乱，因此我会把这个report当成一个blog来书写，主要记录一下在学习过程中的一些思路*)

首先我们可以先熟悉几个词汇，一个free block其实就是一个连续的内存块；每个连续的内存的block其实是有多个pages的；
那么我们在分配内存时主要是以一个block进行的，一个block中含有若干page；

在操作系统初始化的过程中，是经历了下面几个函数调用管理`kern_init()-->pmm_init()-->init_pmm_manager`，也就是在初始化的过程中我们首先要初始化物理内存管理，然后再初始化段式内存管理/页式内存管理/段页式内存管理；因为我们在使用页式内存管理时虽然一次只要求操作系统分配一个page大小的内存，那它也是一块连续的内存区域也就需要进行物理内存管理；

在连续内存管理方法中，我们学习的有first fit，best fit，worst fit和buddy system，试验中也采用了较为简单的first fit的分配方法；我们在理论课上知道first fit中block是按照地址由大到小进行排序；但是由于lab2中已经有了部分代码信息，所以我在查看代码的时候产生了相关的错误理解，我之前理解的block是如下图所示进行维护的：


但是其实它是如下图进行维护的，这让我迷糊了一阵，后期也采用了第二种方法；


因为这个算法还是比较简单的，没有特别要说的东西，所以具体细节可以查看我的提交的代码:)

但是lab1中有一个问题：
> 你的first fit算法是否有进一步的改进空间

我觉得我的算法没有什么改进的了，唯一有一点**可能**需要改进的地方就是我的`default_free_pages`这个函数中对要回收的block的所有pages进行了一次loop来恢复每个page之前没有被分配出去时的状态；可能这里在分配出去之后只有head page的相关属性被修改了，其他page的属性没有被修改；这里因为我不知道分配出去之后的情况，所以保险起见我就loop了一次；后来我查看了一下labcodes_answer中的相关代码，发现那个代码没有我写的**高效**，在分配空间时总是一个page一个page的去遍历；

   这种一个一个page遍历的方法就会造成每次分配连续内存空间时都会存在O(n)的时间复杂度，但是其实这里时不需要进行单个page的loop，因为每个block的head page中的property属性都是有值的，我们可以首先遍历这些head page，一旦head page中的property字段比要求分配的空间大时，我们就可以将该block中的pages进行拆分；反之，如果head page中的property比要求分配的空间小时，就直接跳到下一个head page上了(*利用head_page + head_page->property的方法直接跳到下一个head_page上*)，这要我们就不用再这些head page后的common page上面再进行判断了，完全没有必要，这是我认为labcodes_answer可以改善的地方；
   
---
# 练习二

首先阐述练习二中我遇到的几个困难点：

1.get_pte函数的调用关系可以通过练习指导书中查看到，此时获取到的物理内存都是在近0x00000000处，因为也就在内核占用的物理内存区域，因为获取到了物理内存之后可以直接通过`page2kva(pg_tbl)`来获取到它的linear address；
2.我们知道在page table entry中存储的是`physical address | flags`，其实page directory entry中存储的也是`physical address | flags`只不过page directory entry中的physical address是某一个page table的physical address;
3.对于page table来说，由于这些page table不仅内核会访问，而且用户态也会访问；因此我们就需要将page directory中的page directory entry中添加标志位添加PTE_U字段；

总体来说这个题目还是比较简单的，主要就是先从page directory中找到virtual address对应的page directory entry，如果这个page directory entry并不存在(即其PTE_P位没有使能，当前page directory entry不存在)那么我们就需要从物理内存中拿出一个page来当page table，并将这个page table与page directory entry相关联(关联的方法即使page directory entry中存储该**page table的物理地址及相应的标志位**)；
一旦获取到了这个page table，那么我们就可以通过virtual address与page directory+page table的关系来获取到该virtual address与page directory+page table之间的关系(**其实这种对应关系是很简单的，一个virtual address的前10位对应page directory entry index，中间10位对应page table entry index，最后12位对应0-4096的单个page偏移，这样就可以保证了一个物理page偏移对应一个逻辑page偏移**)；

改题的总体思路就这样(其实这题早就写完了，只是迟迟没有更新笔记，笔记有益于日后更深入的思考及回忆，所以今天补上,XD)

下面对页式内存管理中的内存映射及段式/页式内存管理生效机制进行一个比较详细的说明与讲解，并于自己日后回忆及更深入的思考(如果有同学看到此报告并能对你产生帮助那就更好不过了，同时如有错误欢迎指出)：

* 首先，在bootloader阶段，首先进行相应的寄存器初始化，使能A20，load GDT，探测物理内存；需要说明一点的是在load GDT之后virutal address和linear address之间是一一映射的关系，具体可以看到bootstrap GDT代码：


```
.data                                                                                                                                                                                        
# Bootstrap GDT                                                                  
.p2align 2                                          # force 4 byte alignment     
gdt:                                                                             
    SEG_NULLASM                                     # null seg                   
    SEG_ASM(STA_X|STA_R, 0x0, 0xffffffff)           # code seg for bootloader and kernel
    SEG_ASM(STA_W, 0x0, 0xffffffff)                 # data seg for bootloader and kernel
                                                                                 
gdtdesc:                                                                         
    .word 0x17                                      # sizeof(gdt) - 1            
    .long gdt                                       # address gdt  
```

此时我们只是设定了一个gdt表，并对表项的内存进行书写，此时表项和各个段寄存器其实是没有关系的，有些人会认为只要有了这个gdt并且进行了`lgdt`就完成了段映射(**其实这句话是说给我自己听的==**)；bootloader在设立了gdt之后，还要设置段寄存器的值让其值指向gdt的某个表项才是完成了全部的段式内存管理，如下的代码就是分别将代码段寄存器和数据段寄存器分别设置数值让其指向之前loaded的gdt，这样才是完成了全部的段式内存管理：

```
    ljmp $PROT_MODE_CSEG, $protcseg                 # 利用ljmp来将PROT_MODE_CSEG赋值给代码段寄存器CS                                                                                             
    
.code32                                             # Assemble for 32-bit mode   
protcseg:                                                                        
    # Set up the protected-mode data segment registers
    # 将PROT_MODE_DSEG赋值给数据段寄存器
    movw $PROT_MODE_DSEG, %ax                       # Our data segment selector  
    movw %ax, %ds                                   # -> DS: Data Segment        
    movw %ax, %es                                   # -> ES: Extra Segment       
    movw %ax, %fs                                   # -> FS                      
    movw %ax, %gs                                   # -> GS                      
    movw %ax, %ss                                   # -> SS: Stack Segment  
```
通过将具体的index值付给数据段和代码段寄存器之后，就完成了完整的页式内存管理，CD:IP就可以通过CS的值当做gdt的index来读取base address（此阶段是0x0），然后和IP的offset相加作为最后的virtual address；数据段的值同理；

* 接下来是第二阶段，即`call bootmain`之后将扇区上的数据读取到内存上之后，并执行代码段上的entry函数(即kern_entry函数)；
    
这个地方其实比较有意思，如果能准确地在kern_entry上面打到断点并且程序运行时可以停止在这里就说明你清晰地知道之前段式内存管理的bases address为`0x00000000`，下面我们一起来尝试一下；
首先利用qemu来模拟操作系统启动过程，可以去我的lab1的report中查找该方法；我们可以在kern_entry上面打一个断点，然后再在另外一个地方打一个断点，如下所示：

```
The target architecture is assumed to be i8086                                               
(gdb) target remote 127.0.0.1:1234                                                  
Remote debugging using 127.0.0.1:1234                                               
0x0000fff0 in ?? ()                                                                 
(gdb) file ./bin/kernel                                                             
A program is being debugged already.                                                
Are you sure you want to change the file? (y or n) y                                
Reading symbols from ./bin/kernel...done.                                           
(gdb) b kern_entry                                                                  
Breakpoint 1 at 0xc0100000: file kern/init/entry.S, line 11.                        
(gdb) b *0x00100000                                                                 
Breakpoint 2 at 0x100000                                                            
(gdb) continue                                                                      
Continuing.                                                                         
                                                                                    
Breakpoint 2, 0x00100000 in ?? ()                                                   
(gdb) x /10i $pc                                                                    
=> 0x100000:    lgdtw  (%di)                                                        
   0x100003:    sbb    %dh,0x11(%bx,%si)                                            
   0x100006:    add    %bh,0x10(%bx,%si)                                            
   0x10000a:    add    %al,(%bx,%si)                                                
   0x10000c:    mov    %ax,%ds                                                      
   0x10000e:    mov    %ax,%es                                                      
   0x100010:    mov    %ax,%ss                                                      
   0x100012:    ljmp   $0xc010,$0x19                                                
   0x100017:    or     %al,(%bx,%si)                                                
   0x100019:    mov    $0x0,%bp                                                     
(gdb)
```
如上我们可以看到，gdb竟然在2号断点上停止了，而2号断点和1号断点的逻辑地址位置就是相差了`0xc0000000`，这是为什么呢？

**主要时因为此时的段式内存管理采用的base address仍然时0x00000000，并且bootloader在放置代码段和数据段的时候的基础起始物理地址是0x00000000而不是0xc0000000，所以我们在virtual address的0x00100000上打断点时，就相当于在物理地址的0x00100000上打上了断点因此在congtinue时就会停止，而之所以没有在0xc0100000上停止时因为代码段并没有在物理内存0xc0100000上有任何代码，也就不会停止**

在进入kern_entry后，有一次进行了和步骤1中一样的load global descriptor table的动作，只不过gdt变成了如下的样子：

```
.align 4                                                                            
__gdt:                                                                              
    SEG_NULL                                                                        
    SEG_ASM(STA_X | STA_R, - KERNBASE, 0xFFFFFFFF)      # code segment              
    SEG_ASM(STA_W, - KERNBASE, 0xFFFFFFFF)              # data segment              
__gdtdesc:                                                                          
    .word 0x17                                          # sizeof(__gdt) - 1         
    .long REALLOC(__gdt) 
```
可以看到他们的base address都变成了`-0xc0000000`了，在完成全部的页式内存管理之后，再通过virtual address来打断点的话就可以准确地停止了；此时各个地址之间的映射关系为`vitrual address - 0xc0000000 == linear address == pyhsical address`了；

* 第三阶段即是设置页映射关系并生效；

首先先创建一个page directory，然后进行linear address到physical address之间的映射，具体的代码如下：
```
    boot_map_segment(boot_pgdir, KERNBASE, KMEMSIZE, 0, PTE_W);
```
上述函数主要是构建`KERNBASE~KMEMSIZE`之间的虚拟地址到物理地址之间的映射，映射的物理地址为:`0~KERNMEMSIZE-KERNBASE`，之所以这样映射其实是为了当执行第三次的段式更新时(第三次段式更新之后base address为0，那么virtual address和inear address中内核其实地址都是0xc0000000),页式内存管理就可以通过这次的页式管理映射从linear address直接映射到physical address上；

但是需要说明的是，此时如果不做其他处理并且直接生效页式内存管理的话，那么第二是段式内存管理的结果还是存在的，即virtual address需要`-0xc0000000`之后才会变成linear address,然后此时并没有有效的页式映射(有效的页式映射是KERNBASE~KERNMEMSIZE，而linear address在0x00000000~0x10000000之间)，那么页式映射就会出错，所以才需要一个临时的页式内存映射，如下：
```
    boot_pgdir[0] = boot_pgdir[PDX(KERNBASE)]; 
```
这个临时的页式内存映射可以保证在页式管理生效后到第三次段式管理生效前，可以将linear address准确地映射到physical address上(因为当前的代码段的linear address就是在0~4M之间)，这一步的思想是十分重要的；
完成了页式映射及临时映射之后就可以生效页式内存管理了，具体就是让CR0寄存器的相应标志位生效：
··
* 最后的一步就是生效第三次页式内存管理，对应的函数是`gdt_init`，并将步骤3中临时的页式映射销毁，即是`boot_pgdir[0] = 0;`，至此段页式内存管理全部完成，保证了`virtual address == linear address == physical address + 0xc0000000`，在段式内存管理没有办法丢弃的情况下，将其影响减到最小；

---
# 练习三

练习三没什么好说的，主要就是如果一个pte不想使用的话，需要清空该pte中的数据；该pte关联的page如果其reference位0，则说明该page没有人使用，那么应该还回去，同时将快表中某个linear address对应的pte表项清除掉，留给其他的linear使用；

当时回顾该题目的时候有一个东西想不起来了，导致思考出现错误，现将该观点描述一下，我们在解决该题目时使用了一个宏，如下：
```
    #define PTE_ADDR(pte)   ((uintptr_t)(pte) & ~0xFFF)
```

为什么将后12bit都置为0就可以获取到该pte中存储的物理页的地址值了呢？
答：**这是因为存储在pte中到的物理地址页的后12bit其实都是为0的，因为我们存储的时候是根据一个页一个页去存储的，那么每个页的起始地址肯定是4096的整数倍，这样每个页的起始地址的后12bit肯定就是都为0的，因此就可以通过`& ~0xfff`的方法获取到一个pte中存储的物理地址页的起始地址。**

---
# challenge

这里的challege看起来还是很有意思的，但是我想先将所有的实验都做完再来做这个challenge部分，所以这里先放置一下；