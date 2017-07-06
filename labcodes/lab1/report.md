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

话说有一个地方我不太懂，今天感冒是在太难受/(ㄒoㄒ)/~~，先暂时放到这里：
```
#创建bootblock时
objdump -S obj/bootblock.o > obj/bootblock.asm #应该时该可执行文件的汇编代码
objdump -t obj/bootblock.o | sed '1,/SYMBOL TABLE/d; s/ .* / /; /^$/d' > obj/bootblock.sym #符号表
objcopy -S -O binary obj/bootblock.o obj/bootblock.out
#创建kernel时
objdump -S bin/kernel > obj/kernel.asm #应该是该操作系统代码的汇编代码
objdump -t bin/kernel | sed '1,/SYMBOL TABLE/d; s/ .* / /; /^$/d' > obj/kernel.sym #符号表

```