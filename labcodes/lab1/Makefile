PROJ := challenge
EMPTY :=
SPACE := $(EMPTY) $(EMPTY)
SLASH := /

V := @
#need llvm/cang-3.5+
#USELLVM := 1
# try to infer the correct GCCPREFX
ifndef GCCPREFIX
GCCPREFIX := $(shell if i386-elf-objdump -i 2>&1 | grep '^elf32-i386$$' >/dev/null 2>&1; \
then echo 'i386-elf-'; \
elif objdump -i 2>&1 | grep 'elf32-i386' >/dev/null 2>&1; \
then echo ''; \
else echo "***" 1>&2; \
echo "*** Error: Couldn't find an i386-elf version of GCC/binutils." 1>&2; \
echo "*** Is the directory with i386-elf-gcc in your PATH?" 1>&2; \
echo "*** If your i386-elf toolchain is installed with a command" 1>&2; \
echo "*** prefix other than 'i386-elf-', set your GCCPREFIX" 1>&2; \
echo "*** environment variable to that prefix and run 'make' again." 1>&2; \
echo "*** To turn off this error, run 'gmake GCCPREFIX= ...'." 1>&2; \
echo "***" 1>&2; exit 1; fi)
endif

# try to infer the correct QEMU
ifndef QEMU
QEMU := $(shell if which qemu-system-i386 > /dev/null; \
then echo 'qemu-system-i386'; exit; \
elif which i386-elf-qemu > /dev/null; \
then echo 'i386-elf-qemu'; exit; \
elif which qemu > /dev/null; \
then echo 'qemu'; exit; \
else \
echo "***" 1>&2; \
echo "*** Error: Couldn't find a working QEMU executable." 1>&2; \
echo "*** Is the directory containing the qemu binary in your PATH" 1>&2; \
echo "***" 1>&2; exit 1; fi)
endif

# eliminate default suffix rules
.SUFFIXES: .c .S .h

# delete target files if there is an error (or make is interrupted)
.DELETE_ON_ERROR:

# define compiler and flags
ifndef USELLVM
HOSTCC := gcc
HOSTCFLAGS := -g -Wall -O2
CC := $(GCCPREFIX)gcc
CFLAGS := -fno-builtin -Wall -ggdb -m32 -gstabs -nostdinc $(DEFS)
CFLAGS += $(shell $(CC) -fno-stack-protector -E -x c /dev/null >/dev/null 2>&1 && echo -fno-stack-protector)
else
HOSTCC := clang
HOSTCFLAGS := -g -Wall -O2
CC := clang
CFLAGS := -fno-builtin -Wall -g -m32 -mno-sse -nostdinc $(DEFS)
CFLAGS += $(shell $(CC) -fno-stack-protector -E -x c /dev/null >/dev/null 2>&1 && echo -fno-stack-protector)
endif

CTYPE := c S

LD := $(GCCPREFIX)ld
LDFLAGS := -m $(shell $(LD) -V | grep elf_i386 2>/dev/null)
LDFLAGS += -nostdlib

OBJCOPY := $(GCCPREFIX)objcopy
OBJDUMP := $(GCCPREFIX)objdump

COPY := cp
MKDIR := mkdir -p
MV := mv
RM := rm -f
AWK := awk
SED := sed
SH := sh
TR := tr
TOUCH := touch -c

OBJDIR := obj
BINDIR := bin

ALLOBJS :=
ALLDEPS :=
TARGETS :=

include tools/function.mk

listf_cc = $(call listf,$(1),$(CTYPE))


# add_files文件送用作于临时打包用的，主要将libs下的
# 待打包的源文件集合起来
# for cc
add_files_cc = $(call add_files,$(1),$(CC),$(CFLAGS) $(3),$(2),$(4))
create_target_cc = $(call create_target,$(1),$(2),$(3),$(CC),$(CFLAGS))

# for hostcc
add_files_host = $(call add_files,$(1),$(HOSTCC),$(HOSTCFLAGS),$(2),$(3))
create_target_host = $(call create_target,$(1),$(2),$(3),$(HOSTCC),$(HOSTCFLAGS))
# cg的意思是change么==
cgtype = $(patsubst %.$(2),%.$(3),$(1))
# 重定向文件列表
objfile = $(call toobj,$(1))
# [汇编文件]列表(.o后缀换成.asm后缀)
asmfile = $(call cgtype,$(call toobj,$(1)),o,asm)
# [输出文件]列表(.o后缀换成.out后缀)
outfile = $(call cgtype,$(call toobj,$(1)),o,out)
# [系统文件]列表(.o后缀换成.sym)
symfile = $(call cgtype,$(call toobj,$(1)),o,sym)

# for match pattern
match = $(shell echo $(2) | $(AWK) '{for(i=1;i<=NF;i++){if(match("$(1)","^"$$(i)"$$")){exit 1;}}}'; echo $$?)

# >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
# include kernel/user

INCLUDE += libs/
# C编译器参数
CFLAGS += $(addprefix -I,$(INCLUDE))

LIBDIR += libs

# libs就是add_files函数中待打包的打包名（便于理解packet的意思）
$(call add_files_cc,$(call listf_cc,$(LIBDIR)),libs,)

# -------------------------------------------------------------------
# kernel

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

# 编译kernel中的每个源文件，并将每个重定向文件(.o)放置到kernel文件夹
$(call add_files_cc,$(call listf_cc,$(KSRCDIR)),kernel,$(KCFLAGS))

# 将function中之前被add_files_cc调用产生的libs和kernel下的重定向文件
# 都被存放在了临时变量__objs_libs和__objs_kernel这两个临时变量中
# 所以KBOJ是都是kernel需要的所有重定向文件
KOBJS = $(call read_packet,kernel libs)

# create kernel target
# 构建kernel的目标路径，/bin/kernel，kernel就是一个文件了
kernel = $(call totarget,kernel)

# kernel.ld是链接脚本
# 可以看到关于这个kernel其实是有多个rules的。那么这些
# prerequisites就是append到一个list中，其实就相当于
# $(kernel) : tools/kernel.ld $(KOBJS)
$(kernel): tools/kernel.ld

# LD解析出来之后是gcc中自带的
# 需要说明一下这个地方，因为我之前稍微有一点点蒙
# 对于make这种脚本语言（可以认为是语言么==）需要将中的variable
# 全部理解成字符串，比如在第一行的命令中，kernel就是一个文件
# 但是第二行中由于调用了asmfile函数，
# objdump -S 这个参数是用于intermix code with assembly，其实就是
# 在code的下面加入一些这些代码对应的汇编代码
# objdump -t 的意思是输出kernel文件的符号表内容
$(kernel): $(KOBJS)
	@echo + ld $@
	# 执行链接脚本利用kobjs生成kernel对象
	$(V)$(LD) $(LDFLAGS) -T tools/kernel.ld -o $@ $(KOBJS)
	@$(OBJDUMP) -S $@ > $(call asmfile,kernel)
	@$(OBJDUMP) -t $@ | $(SED) '1,/SYMBOL TABLE/d; s/ .* / /; /^$$/d' > $(call symfile,kernel)

# 创建可执行目标kernel
$(call create_target,kernel)

# -------------------------------------------------------------------

# create bootblock
# 获取boot文件夹下的所有源文件，并进行编译生成重定向文件和依赖文件
# 编译参数 -Os 和 -nostdinc是编译参数，相关具体作用可自行查找
bootfiles = $(call listf_cc,boot)
$(foreach f,$(bootfiles),$(call cc_compile,$(f),$(CC),$(CFLAGS) -Os -nostdinc))

# 创建目录bootblock，即最后生成的这个文件叫做bootblock，是加载引导区么O(∩_∩)O
bootblock = $(call totarget,bootblock)

# sign文件夹这里是典型的order-by-prerequisites
$(bootblock): $(call toobj,$(bootfiles)) | $(call totarget,sign)
@echo + ld $@
$(V)$(LD) $(LDFLAGS) -N -e start -Ttext 0x7C00 $^ -o $(call toobj,bootblock)
@$(OBJDUMP) -S $(call objfile,bootblock) > $(call asmfile,bootblock)
# 将bootblock中的可执行文件写成bootblock下的.out文件
@$(OBJCOPY) -S -O binary $(call objfile,bootblock) $(call outfile,bootblock)
# 执行sign程序，将.out的可执行文件生成bootblock这个可执行文件
@$(call totarget,sign) $(call outfile,bootblock) $(bootblock)

#创建可执行目标bootblock
$(call create_target,bootblock)

# -------------------------------------------------------------------

# 创建sign可执行程序
# create 'sign' tools
$(call add_files_host,tools/sign.c,sign,sign)
$(call create_target_host,sign,sign)

# -------------------------------------------------------------------

# create ucore.img
UCOREIMG := $(call totarget,ucore.img)

$(UCOREIMG): $(kernel) $(bootblock)
$(V)dd if=/dev/zero of=$@ count=10000
$(V)dd if=$(bootblock) of=$@ conv=notrunc
$(V)dd if=$(kernel) of=$@ seek=1 conv=notrunc

$(call create_target,ucore.img)

# >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

$(call finish_all)

IGNORE_ALLDEPS = clean \
dist-clean \
grade \
touch \
print-.+ \
handin

ifeq ($(call match,$(MAKECMDGOALS),$(IGNORE_ALLDEPS)),0)
-include $(ALLDEPS)
endif

# files for grade script

TARGETS: $(TARGETS)

.DEFAULT_GOAL := TARGETS

.PHONY: qemu qemu-nox debug debug-nox
qemu-mon: $(UCOREIMG)
$(V)$(QEMU) -no-reboot -monitor stdio -hda $< -serial null
qemu: $(UCOREIMG)
$(V)$(QEMU) -no-reboot -parallel stdio -hda $< -serial null
log: $(UCOREIMG)
$(V)$(QEMU) -no-reboot -d int,cpu_reset -D q.log -parallel stdio -hda $< -serial null
qemu-nox: $(UCOREIMG)
$(V)$(QEMU) -no-reboot -serial mon:stdio -hda $< -nographic
TERMINAL :=gnome-terminal
debug: $(UCOREIMG)
$(V)$(QEMU) -S -s -parallel stdio -hda $< -serial null &
$(V)sleep 2
$(V)$(TERMINAL) -e "gdb -q -tui -x tools/gdbinit"

debug-nox: $(UCOREIMG)
$(V)$(QEMU) -S -s -serial mon:stdio -hda $< -nographic &
$(V)sleep 2
$(V)$(TERMINAL) -e "gdb -q -x tools/gdbinit"

.PHONY: grade touch

GRADE_GDB_IN := .gdb.in
GRADE_QEMU_OUT := .qemu.out
HANDIN := proj$(PROJ)-handin.tar.gz

TOUCH_FILES := kern/trap/trap.c

MAKEOPTS := --quiet --no-print-directory

grade:
$(V)$(MAKE) $(MAKEOPTS) clean
$(V)$(SH) tools/grade.sh

touch:
$(V)$(foreach f,$(TOUCH_FILES),$(TOUCH) $(f))

print-%:
@echo $($(shell echo $(patsubst print-%,%,$@) | $(TR) [a-z] [A-Z]))

.PHONY: clean dist-clean handin packall tags
clean:
$(V)$(RM) $(GRADE_GDB_IN) $(GRADE_QEMU_OUT) cscope* tags
-$(RM) -r $(OBJDIR) $(BINDIR)

dist-clean: clean
-$(RM) $(HANDIN)

handin: packall
@echo Please visit http://learn.tsinghua.edu.cn and upload $(HANDIN). Thanks!

packall: clean
@$(RM) -f $(HANDIN)
@tar -czf $(HANDIN) `find . -type f -o -type d | grep -v '^\.*$$' | grep -vF '$(HANDIN)'`

tags:
@echo TAGS ALL
$(V)rm -f cscope.files cscope.in.out cscope.out cscope.po.out tags
$(V)find . -type f -name "*.[chS]" >cscope.files
$(V)cscope -bq 
$(V)ctags -L cscope.files
