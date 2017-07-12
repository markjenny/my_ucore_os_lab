#练习一

***

#习题1

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

#练习二
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


*赞！两个很有用的参数知识*