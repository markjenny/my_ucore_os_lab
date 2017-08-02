# 练习一

***

# 习题1

（太伤心了，写了一部分的东西竟然没有保存，再打开就没有了，看来以后要写完一个题就将他们进行上传）

首先先增加一些需要的makefile的基本知识：

* makefile可以进行像C语言那样的include包含的方式，如下：

    ```
    include foo.make a.mk b.mk
    ```
    其中上述的a.mk和foo.mk都是可以有相对当前Makefile的相对地址或者是绝对地址；
    
* Makfile中也是含有一系列的内置函数，如addsuffix,basename,join等等；

对于在编译操纵系统的过程中需要的Makefile和tools/function.mk的相关注释我都写好了，可以直接去观看。



下面来看制作整个镜像文件的过程（流水账），这个流程可以直接通过make来观察，具体的过程是:
```
make clean;make --just-print #相关的参数如果不熟悉的话可以看《跟我一起写Makefile》
```

**注**：我是从根节点开始说的，真正的执行顺序反过来就可以了；

**首先是镜像文件**

1. 首先创建块文件，使用的方法是dd命令，首先创建一块[512*10000]的文件；从设备文件/dev/zero进行拷贝；默认的一块block为512Bytes；
2. 这个镜像文件中将[引导扇区]的文件内容拷贝到第一块block中，正好是512个字节；
3. 然后将内核文件从镜像文件的第二块区域开始进行拷贝，所以需要使用seek来跳过第一块block；

(注：上面的dd用于copy & convert 文件，例如相关的conv=notruc这些参数可以具体查看man手册)

那么制作这个镜像文件就需要[引导扇区]和[内核文件]

**其次是引导扇区**

以下是创建引导扇区（加载程序）的代码：
```
# create bootblock
bootfiles = $(call listf_cc,boot)
$(foreach f,$(bootfiles),$(call cc_compile,$(f),$(CC),$(CFLAGS) -Os -nostdinc))

bootblock = $(call totarget,bootblock)

$(bootblock): $(call toobj,$(bootfiles)) | $(call totarget,sign)
	@echo + ld $@
	$(V)$(LD) $(LDFLAGS) -N -e start -Ttext 0x7C00 $^ -o $(call toobj,bootblock)
	@$(OBJDUMP) -S $(call objfile,bootblock) > $(call asmfile,bootblock)
	@$(OBJDUMP) -t $(call objfile,bootblock) | $(SED) '1,/SYMBOL TABLE/d; s/ .* / /; /^$$/d' > $(call symfile,bootblock)
	@$(OBJCOPY) -S -O binary $(call objfile,bootblock) $(call outfile,bootblock)
	@$(call totarget,sign) $(call outfile,bootblock) $(bootblock)

$(call create_target,bootblock)
```

这里涉及到太多的makefile的用法，不了解makefile的用法就无法读懂，所以这里还是顺便学习一下比较复杂的makefile的用法，无论以后修改makefile还是使用cmake都会有一些帮助，关于这篇文章所需要的makefile知识我后期会放到我的[blog](https://markjenny.github.com)上，感兴趣的可以去看看，如果有错误的地方欢迎提出！

总结一下创建引导扇区的过程：

首先获取到boot下所有的源码文件，以.c(c语言)文件和.S（汇编语言）文件为准
```
$(call listf_cc,boot)
```

接下来我们定义一个最后要形成的目标的名字，定为bootblock；
```
bootblock = $(call totarget,bootblock)
```

接下来就是一个标准的makefile中存在的`target : prerequisites; command`的形式了，代码如下：
```
$(bootblock): $(call toobj,$(bootfiles)) | $(call totarget,sign)
	@echo + ld $@
	$(V)$(LD) $(LDFLAGS) -N -e start -Ttext 0x7C00 $^ -o $(call toobj,bootblock)
	@$(OBJDUMP) -S $(call objfile,bootblock) > $(call asmfile,bootblock)
	@$(OBJDUMP) -t $(call objfile,bootblock) | $(SED) '1,/SYMBOL TABLE/d; s/ .* / /; /^$$/d' > $(call symfile,bootblock)
	@$(OBJCOPY) -S -O binary $(call objfile,bootblock) $(call outfile,bootblock)
	@$(call totarget,sign) $(call outfile,bootblock) $(bootblock)
```

这个过程主要是将bootasm.S和bootmain.c编译成重定向文件，并将重定向文件进行链接生成obj/bootblock.o可执行文件，并利用`objdump -S -O `（这里暂时没有懂，放下）生成bootblock.out这个可执行文件，在利用sign工具重写，将其重写成满足规定的主引导扇区的形式：
1. 主引导扇区的长度为512个字节长；
2. 结尾的两个自己是0x55AA;

最后利用`dd if=bin/bootblock of=bin/ucore.img conv=notrunc`将主引导扇区的代码写入到磁盘镜像中。

**最后是操作系统内核**

首先，获取到编译内核代码需要的头文件目录和源文件目录，及编译时需要的编译参数，代码如下所示；

```
# kernel中包含头文件的所有include目录
KINCLUDE += kern/debug/ \
kern/driver/ \
kern/trap/ \
kern/mm/

# kernel中包含源文件的所有source目录
KSRCDIR += kern/init \
kern/libs \
kern/debug \
kern/driver \
kern/trap \
kern/mm

# 编译kernel需要的编译器参数
KCFLAGS += $(addprefix -I,$(KINCLUDE))
```

然后，将取出来的keinel下的源文件进行编译；
```
$(call add_files_cc,$(call listf_cc,$(KSRCDIR)),kernel,$(KCFLAGS))
```

然后在对libs下的源文件进行编译，代码如下：
```
$(call add_files_cc,$(call listf_cc,$(LIBDIR)),libs,)
```

读取libs目录下，kern目录下的源文件，并获取他们的集合：
```
KOBJS = $(call read_packet,kernel libs)
```

最后进行编译链接，并将生成的可执行文件命名为kernel：
```
$(kernel): $(KOBJS)
	@echo + ld $@
	# 执行链接脚本利用kobjs生成kernel对象
	$(V)$(LD) $(LDFLAGS) -T tools/kernel.ld -o $@ $(KOBJS)
	@$(OBJDUMP) -S $@ > $(call asmfile,kernel)
	@$(OBJDUMP) -t $@ | $(SED) '1,/SYMBOL TABLE/d; s/ .* / /; /^$$/d' > $(call symfile,kernel)
```

最后将kernel这个可执行文件写入到ucore.img镜像的第二块区，代码如下：
```
$(V)dd if=$(kernel) of=$@ seek=1 conv=notrunc
```

以上就是编译链接一个操作系统的整个过程；

*感冒差不多好啦O(∩_∩)O，现在继续更新*
```
#创建bootblock时
objdump -S obj/bootblock.o > obj/bootblock.asm #应该时该可执行文件的汇编代码
objdump -t obj/bootblock.o | sed '1,/SYMBOL TABLE/d; s/ .* / /; /^$/d' > obj/bootblock.sym #符号表
objcopy -S -O binary obj/bootblock.o obj/bootblock.out
#创建kernel时
objdump -S bin/kernel > obj/kernel.asm #应该是该操作系统代码的汇编代码
objdump -t bin/kernel | sed '1,/SYMBOL TABLE/d; s/ .* / /; /^$/d' > obj/kernel.sym #符号表

```

上面的代码其实与创建一个操作系统的镜像文件已经没有太大的关系了，此时ucore.img已经创建成功了；而且objdump一般是用于分析编译/链接时更多的使用（至少我是在这种情况下使用，但是话说我已经将编译链接的一个大致过程忘却了，抽空再学习巩固一下~）

**jobjdump**这个工具通过名字就很容易理解，它是用于展示可执行文件的相关属性信息的；下面我们主要说一下所用到的两个参数的意义：
* -S 主要是以“源代码”+“汇编代码”的混合方式用来更来地说明哪段源代码对应哪些汇编代码；
* -t 主要是展示出该可执行文件的符号表；
上述这些都是为了后期学习时巩固用的。

---

# 练习二
***
为了调试ucore的第一条指令，当然是让它先接电起来啦！但是又要保证不执行任何一条指令，这种蛋疼的要求只有使用qemu来模拟了，模拟的命令为,：
```
qemu -s -S -hda ./bin/ucore.img -monitor stdio
```
上面这条命令使用了monitor是为了在调试过程中(即出现`(qemu)`字样的情况下，来使用monitor的相关参数来控制)，方便

因为我们需要测试操作系统启动时执行的第一条指令（运行第一条指令时，内存为实模式8086架构的特点），所以这个时候从本机上是无法使用gdb的（连基本的进程空间都还没有建立，gdb也是一个用户态进程，当然无法使用拉~）；这样我们就需要使用远程gdb：
```
set architecture i8086
target remote 127.0.0.1:1234
file ./bin/kernel     #为了让gdb在调试的过程中获取到符号信息
b *0x7c00            #对地址进行断点设置的方法
continue            #c 可以进行简写为c
x /2i $pc #查看反汇编代码，这里的"2"表示一次现实几行反汇编代码
stepi                #以机器代码的形式单步调试，可以简写为si
```

通过上面的代码你就可以进入一个单步调试ucore启动第一条机器指令的功能；但是如果你突然冒出一个想法要退出gdb模式，然后再进入gdb进行调试时你又一次需要输入这么多相关的参数，有木有很烦，程序员的时间很宝贵的好不好还有留着时间去宅呢；所以一个偷懒的方法就是将这些功能写成一个类似脚本的文件，这种功能在gdb中时存在的，你只要在`gdb -x gdbscripting`这种模式，gdbscripting中的相关语句就会在gdb的模式下依次执行，其实就是将gdb中需要执行的语句批量执行；

> 从标准答案的报告中学习到了相关qemu的其他使用方式：`-d: item1:enable logging of specified item`即让特定相关信息进行日志形式的输出，默认情况下他会在qemu的命令行下进行直接输出，这些时无法保存并不方便查看；我们可以使用`-D logfile`来将logging输出的东西指定到该logfile的日志文件中，以便观察对比；

（ *赞！两个很有用的参数知识* ）

通过在gdb中查看也观察出主引导扇区中得bootload在调用bootmain之前得汇编代码(记得要要在gdb调试中加上`x /10i $pc`来将当前得机器代码强制反汇编哦)与bootasm.S和bootblock.asm中的代码是相同的；

随便找一个memset的内核代码，直接使用如下信息设置断点：

```
break memset #话说我一般都直接使用b来表示break，但是都建了一个代码块了，写太少的代码貌似不好，23333
```
`continue`之后就会在memest那里break住。

---

# 练习三

---

由于intel芯片的向下兼容的原因，他们特意构造出了A20 gate，通过它来控制是否进行“ *回绕* ”，当使用了80386这个cpu时，无论是实模式还是保护模式，我们都需要将A20使能，保证其可以正常使用从而不产生回绕；所以bootloader进行的过程主要有以下几个主要的过程：
* 使能A20;
* 初始化全局描述符表，保证可以确定出数据/代码等相关数据的位置；
* 使能[保护模式]；
* 最后将ucore的代码，数据等加载到内存中；

这只是一个大致的过程，实际上根据bootasm.S的描述（没办法，有一些cpu指令高级语言是没有办法来进行描述的，必须使用汇编语言），还是有很多的细节的；

首先我们先要进行一些初始化的工作
```
cli #clear interrupt flag,这个是X86架构中Flag寄存器上的一个标志位，将其clear表明该标识位不再起作用了，也就禁止接收中断了
cld #clear direction flag,这个也是一个标志位，将其置为空就是保证代码和数据是在每次执行之后可以向高地址去继续执行，可以参考[该连接](https://stackoverflow.com/questions/9636691/whats-the-difference-between-cld-and-std-instructions-in-assembly-language)

# 以下主要是将重要的涉及到重要的数据段寄存器置空，这个汇编语言中使用的是movw，而不是mov这是因为现在还是实模式，w指明我们操作的是一个“字”（可以看《cs：app》或王爽的《汇编语言》）
xorw %ax, %ax #异或保证该寄存器的值为空
movw %ax, %ds #置空下列三个段寄存器的值
movw %ax, %es
movw %ax, %ss
```

接下来我们就是要将A20 Gate开启，保证当读取超过1MB的内控空间是不会发生相关的“ *回绕* ”从而可以在保护模式下使用整个32bit的4GB空间，简单来说就是将8042单片机的一个引脚置为高电平，具体可以看gitbook形式的指导书，下面这部分代码不再进行引用，直接看代码吧，太简单了没有描述的必要了，反正老师不会评我的实验报告，我只要做到简要明白准确即可（代码位置boot/bootasm.S中的29~43行）

接下来我们就初始化GDT(global description table)，即将全局描述符表加载到内存中，并初始化[GDTR](https://en.wikibooks.org/wiki/X86_Assembly/Global_Descriptor_Table)
```
lgst gdtdesc
```
多说一句，我们在学习理论课的时候知道了GDTR的作用：标记GDT；并且理论课中得知GDTR中不仅保存了GDT的地址，还保存了GDT的长度，我们从代码中都可以看出：
```
gdtdesc:
.word 0x17                                      # sizeof(gdt) - 1
.long gdt                                       # address gdt
```

初始化段寄存器，A20及全局描述符表之后，我们就可以使能保护模式了，这就涉及到要修改CR0控制寄存器的第0bit，将该bit位置为1就使能了`保护模式`，具体的汇编代码如下所示：
```
movl %cr0, %eax
orl $CR0_PE_ON, %eax
movl %eax, %cr0
```

将现有的内存模式设置成保护模式后，需要将设置CS寄存器及EIP寄存器的值，在bootssm.S中使用了长跳转指令来设定CS寄存器和EIP寄存器的值，我目前认为跳转指令`jmp`是在段内进行进行跳转，`ljmp`是在段间进行跳转，可以看一个[例子](https://docs.oracle.com/cd/E19455-01/806-3773/instructionset-73/index.html);
```
ljmp $PROT_MODE_CSEG, $protcseg
```
通过bootasm.S代码中的变量`PROT_MODE_CSEG`为内核的代码段选择子，及CS寄存器的值；`protcseg`为所执行的代码，此事我们已经将CS和EIP全部设置好了，可以正常第执行代码段的代码了；

在call bootmain之前还需要将数据段相关的寄存器进行初始化设置，如下:
```
# Set up the protected-mode data segment registers
    movw $PROT_MODE_DSEG, %ax                       # Our data segment selector
    movw %ax, %ds                                   # -> DS: Data Segment
    movw %ax, %es                                   # -> ES: Extra Segment
    movw %ax, %fs                                   # -> FS
    movw %ax, %gs                                   # -> GS
    movw %ax, %ss                                   # -> SS: Stack Segment
```
初始化完数据段相关寄存器后，初始化堆栈相关的寄存器：
```
movl $0x0, %ebp
movl $start, %esp
```
ebp寄存器是保持最新的栈顶信息，而esp保存的是某一时刻的栈顶信息，是为了函数调用可以进行调用与恢复而使用的；

最后，`call bootmain`

---

# 练习四

---
首先需要引用一段实验指导书中的相关概述：
> bootloader访问硬盘的是方式是LBA模式的PIO（Program IO）方式，即访问硬盘的方式是通过CPU访问硬盘的**IO地址寄存器**来完成的；

即计算机中存在IO地址寄存器，我们通过对IO地址寄存器进行赋值，从而完成CPU对硬盘的控制及数据读取；IO地址寄存器分别为0x1f0-0x1f7,0x170-0x17f,通过对这些IO地址寄存器的设定，可以保证CPU对硬盘进行相关的访问；

相关IO地址寄存器的值及相关功能如下：

|IO地址|功能|
|---|:---|
|0x1f0|读数据，当0x1f7不为忙状态时，可以读。|
|0x1f2|要读写的扇区数，每次读写前，你需要表明你要读写几个扇区。最小是1个扇区|
|0x1f3|如果是LBA模式，就是LBA参数的0-7位|
|0x1f4|如果是LBA模式，就是LBA参数的8-15位|
|0x1f5|如果是LBA模式，就是LBA参数的16-23位|
|0x1f6|第0~3位：如果是LBA模式就是24-27位 第4位：为0主盘；为1从盘|
|0x1f7|状态和命令寄存器。操作时先给命令，再读取，如果不是忙状态就从0x1f0端口读数据|

通过控制这些IO地址寄存器，从而控制CPU访问硬盘的相关行为；

CPU在读取硬盘的内容时要先等待硬盘空闲了之后才能向硬盘发出读取扇区的命令，并且也需要等到硬盘空闲时，才能将硬盘的内容读取到内存中来，所以在读取硬盘内容的步骤就可以分成如下步骤：

* 等待硬盘空闲；
* 发出读取硬盘的命令；
* 等待硬盘空闲；
* 将硬盘扇区的数据读取到内存中；

（ *由于我惊奇的脑回路，导致我一直以为时在kernel.ld中的0x10000和bootmain.S中的0x1000是一个值，只是他们可能写错了的问题导致看起来不一样==，但是正在我为自己的脑回路找借口的时候，发现我的脑回路有问题，那么就将正确的写下来吧，但是我觉得可以对0x1000多嘴几句，以免我的同类也搞不懂0x10000和0x1000有什么区别，23333。话说我在网上查找了一下，几乎都是对代码相同的解释，我想说，都是抄的咩？* ）

首先bootmain函数中，首先进行的是将镜像文件的第二个扇区开始的数据进行读取；

```
void
bootmain(void) {
    // read the 1st page off disk
    readseg((uintptr_t)ELFHDR, SECTSIZE * 8, 0);

    //...
}
```
上面代码中的readseg函数是从硬盘中读取`SECTSIZE * 8`长度的数据放置到`ELFHDR`这个虚拟地址中，这个时候我就有点搞不清这个`0x10000`的作用了，我的潜意识竟然将它和kernel.ld中的`0x100000`等效成一个东西了，其实这里是不一样，他们的作用是不同的，虾米那我较为详细地阐述一下为什么要使用`0x10000`和`0x100000`；
首先`0x1000`是一个暂存的地址，即我们将从硬盘中读取到的磁盘数据先放置在这个地方，之后再将这些数据和程序加载到他们需要加载的地方(我们知道，在boot的起始阶段中机器代码会从0x7c00处开始执行，而0x7c00向上取个整就是0x10000，并且0x10000-0x7c00之间完全可以放置了一个扇区的数据，这就是我的解释23333)；

在这里马上再解释一下`0x100000`这个数据的作用，这个数据是kernel程序加载程序段的虚拟地址的地方（ 注：程序的加载过程，我觉得《程序员的自我修养》这本书讲的挺仔细的，虚拟地址可以参考一下我的[博客](https://markjenny.github.io/difference_between_virtualaddress_logicaddress_and_linearaddres/) ），我们通过读取kernel文件也可以看出来：

```
Elf file type is EXEC (Executable file)
Entry point 0x100000
There are 3 program headers, starting at offset 52

Program Headers:
  Type           Offset   VirtAddr   PhysAddr   FileSiz MemSiz  Flg Align
  LOAD           0x001000 0x00100000 0x00100000 0x0d6a9 0x0d6a9 R E 0x1000
  LOAD           0x00f000 0x0010e000 0x0010e000 0x00a16 0x01d80 RW  0x1000
  GNU_STACK      0x000000 0x00000000 0x00000000 0x00000 0x00000 RWE 0x10

 Section to Segment mapping:
  Segment Sections...
   00     .text .rodata .stab .stabstr 
   01     .data .bss 
   02 
```
通过上文可以看到，代码段（Flg为R E）是要加载到虚拟地址`0x100000`上，而数据段(Flg为RW)是加载到虚拟地址`0x0010e000`上，这些信息通过kernel.ld上也可以清晰地看出来；

我们接下来往下走，读取bootmain首先读取了一个page的数据，但是它是分扇区来进行读取的，即一个扇区一个扇区地读取，如下代码所示：

```
static void
readseg(uintptr_t va, uint32_t count, uint32_t offset) {
    uintptr_t end_va = va + count;

    // round down to sector boundary
    va -= offset % SECTSIZE;

    // translate from bytes to sectors; kernel starts at sector 1
    uint32_t secno = (offset / SECTSIZE) + 1;

    // If this is too slow, we could read lots of sectors at a time.
    // We'd write more to memory than asked, but it doesn't matter --
    // we load in increasing order.
    for (; va < end_va; va += SECTSIZE, secno ++) {
        readsect((void *)va, secno);
    }
}
```

上面的代码都比较好理解，即一个扇区一个扇区地读取，读取成功之后就更新虚拟地址以便下一个扇区要放置的虚拟地址的地方紧随上一个扇区；

上述代码中的函数`readsect`的作用就是我们前面讲的，通过给IO地址寄存器赋值来控制CPU读硬盘数据的读取，自己可以进行对，我就不赘述了。

对于代码段或者数据段来说，每个段都存在一个段表section header,用来表明代码段或者数据段放置的虚拟地址的位置，放置数据的长度，通过`readsect`函数将这些数据从之前内存的暂存位置放置到它要求的位置上，段表的结构可以查看elf.h文件，如下：

```
/* program section header */
struct proghdr {
    uint32_t p_type;   // loadable code or data, dynamic linking info,etc.
    uint32_t p_offset; // file offset of segment
    uint32_t p_va;     // virtual address to map segment
    uint32_t p_pa;     // physical address, not used
    uint32_t p_filesz; // size of segment in file
    uint32_t p_memsz;  // size of segment in memory (bigger if contains bss）
    uint32_t p_flags;  // read/write/execute bits
    uint32_t p_align;  // required alignment, invariably hardware page size
};
```
最后，通过kernel程序的file header中的`e_entry`指示处程序入口，将控制权交给了kernel，关键代码如下

```
    // call the entry point from the ELF header
    // note: does not return
    ((void (*)(void))(ELFHDR->e_entry & 0xFFFFFF))();
```

至此，整个kernel的加载并将控制权转移的过程结束。

----
# 练习五
----

练习五主要是针对调用栈进行理解及相关的简单实践；但是对于我们理解堆栈的调用还是很有帮助的，后续我还是会在我的blog中贴出一个简单的堆栈调用的讲解；

看了一下实验答案，发现答案还针对最初始的状态对ebp进行了解释，那么我也利用这个思路进行一下解释；不过没有按照实验答案的思路来走，感兴趣的可以看一下；

我们指导在执行被调用函数体时，会执行如下的汇编指令：
```
push ebp
mov esp ebp
```
这样新的ebp的指向的堆栈内存中保存的时原来的ebp的值(该内存位置向栈顶方向则是函数体的执行，该内存位置向栈底方向则是该被调用函数的return address及各个实参值（也可能不含有参数）),当函数体执行完毕时，又会执行一次如下汇编指令：
```
pop ebp
```
又将原ebp的值进行了恢复；这样通过更新ebp的值并存储原来ebp的值，就会将调用的函数形成一个**调用堆栈链**，从而正确地执行函数调用；

我们可以通过该实验的一个调用输出来阐述一下：
```
moocos-> cat tmp
 make qemu
(THU.CST) os is loading ...

Special kernel symbols:
  entry  0x00100000 (phys)
  etext  0x001032f9 (phys)
  edata  0x0010ea16 (phys)
  end    0x0010fd20 (phys)
Kernel executable memory footprint: 64KB
ebp:0x00007b08 eip:0x001009ad args: 0x00010094 0x00000000 0x00007b38 0x00100092 
    kern/debug/kdebug.c:311: print_stackframe+28
ebp:0x00007b18 eip:0x00100ccb 
ebp:0x00007b18 eip:0x00100ccb args: 0x00000000 0x00000000 0x00000000 0x00007b88 
    kern/debug/kmonitor.c:125: mon_backtrace+10
ebp:0x00007b38 eip:0x00100092 
ebp:0x00007b38 eip:0x00100092 args: 0x00000000 0x00007b60 0xffff0000 0x00007b64 
    kern/init/init.c:48: grade_backtrace2+33
ebp:0x00007b58 eip:0x001000bb 
ebp:0x00007b58 eip:0x001000bb args: 0x00000000 0xffff0000 0x00007b84 0x00000029 
    kern/init/init.c:53: grade_backtrace1+38
ebp:0x00007b78 eip:0x001000d9 
ebp:0x00007b78 eip:0x001000d9 args: 0x00000000 0x00100000 0xffff0000 0x0000001d 
    kern/init/init.c:58: grade_backtrace0+23
ebp:0x00007b98 eip:0x001000fe 
ebp:0x00007b98 eip:0x001000fe args: 0x0010331c 0x00103300 0x0000130a 0x00000000 
    kern/init/init.c:63: grade_backtrace+34
ebp:0x00007bc8 eip:0x00100055 
ebp:0x00007bc8 eip:0x00100055 args: 0x00000000 0x00000000 0x00000000 0x00010094 
    kern/init/init.c:28: kern_init+84
ebp:0x00007bf8 eip:0x00007d68 
ebp:0x00007bf8 eip:0x00007d68 args: 0xc031fcfa 0xc08ed88e 0x64e4d08e 0xfa7502a8 
    <unknow>: -- 0x00007d67 --
ebp:0x00000000 eip:0x00007c4f 
ebp:0x00000000 eip:0x00007c4f args: 0xf000e2c3 0xf000ff53 0xf000ff53 0xf000ff53
```
我们可以看到ebp的值是如下变化的：
`0x00000000`，'0x00007bf8'，'0x00007bc8'，`0x00007b98`，`0x00007b98`，`0x00007b78`，`0x00007b58`，`0x00007b38`，`0x00007b18`，`0x00007b08`；

对于上述的变化有两点要说一下：

1. 为什么我要逆序来写呢？因为我从初始调用状态开始的，首先在操作系统的bootloader会初始化相关的寄存器/A20/全局描述符表及堆栈信息（即让ebp为0x00000000，esp为0x00007c00）；所以初始状态的ebp就是0x00000000；
2. 为什么之后ebp的值是一直在变小的，因为堆栈的增长是向虚拟地址空间小的方向进行的；

---