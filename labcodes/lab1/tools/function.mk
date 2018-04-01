OBJPREFIX := __objs_

.SECONDEXPANSION:
# -------------------- function begin --------------------

#Li Jianlin注明：如果在这个function看他它的注释中在描述参数的部分是[, var1, var2]，
#表明这里面的参数是可以省略的，没有使用该参数的话也不会影响函数的执行

# brief 将某个文件夹下的所有的满足某个后缀的文件列出列表
# param1 $(1) 表示一个文件夹
# param2 $(2) 表示一个后缀名
# note 当$(1)文件夹下含有$(2)样式的后缀名时，这些后缀名的文件列出
# 如果没有显示标记出后缀名，那么将$(1)下所有的文件均列出来
# list all files in some directories: (#directories, #types)
listf = $(filter $(if $(2),$(addprefix %.,$(2)),%),\
		  $(wildcard $(addsuffix $(SLASH)*,$(1))))

# brief 构建目录OBJDIR/$(2),并通过$(1)的文件列表获取到其可重定向文件(即.o文件)列表
# 并构建出以OBJDIR/$(2)为目录，以获取到的可重定向文件为文件，制作出
# 这些文件的以工程目为跟的相对路径
# param1 $(1) 表示源文件的文件名（含后缀）
# param2 $(2) 表示最后形成的packet的文件夹名
# get .o obj files: (#files[, packet])
toobj = $(addprefix $(OBJDIR)$(SLASH)$(if $(2),$(2)$(SLASH)),\
		$(addsuffix .o,$(basename $(1))))

# brief 与上述是类似的，只不过该函数是获取依赖文件
# param1 $(1) 表示源文件的文件名（含后缀）
# param2 $(2) 表示最后形成的packet的文件夹名
# get .d dependency files: (#files[, packet])
todep = $(patsubst %.o,%.d,$(call toobj,$(1),$(2)))

# brief target的路径名
# param1 $(1) target的文件夹名字
totarget = $(addprefix $(BINDIR)$(SLASH),$(1))

# packet前缀？
# change $(name) to $(OBJPREFIX)$(name): (#names)
packetname = $(if $(1),$(addprefix $(OBJPREFIX),$(1)),$(OBJPREFIX))

# cc compile template, generate rule for dep, obj: (file, cc[, flags, dir])
define cc_template
$$(call todep,$(1),$(4)): $(1) | $$$$(dir $$$$@)
	@$(2) -I$$(dir $(1)) $(3) -MM $$< -MT "$$(patsubst %.d,%.o,$$@) $$@"> $$@
$$(call toobj,$(1),$(4)): $(1) | $$$$(dir $$$$@)
	@echo + cc $$<
	$(V)$(2) -I$$(dir $(1)) $(3) -c $$< -o $$@
ALLOBJS += $$(call toobj,$(1),$(4))
endef

# 注意这个$$不是为了二次扩展进行使用的，而是为了保证之后被eval函数调用的使用便于makefile将其解读成单纯的literal $
# compile file: (#files, cc[, flags, dir])
define do_cc_compile
$$(foreach f,$(1),$$(eval $$(call cc_template,$$(f),$(2),$(3),$(4))))
endef

# add files to packet: (#files, cc[, flags, packet, dir])
define do_add_files_to_packet
__temp_packet__ := $(call packetname,$(4))
ifeq ($$(origin $$(__temp_packet__)),undefined)
$$(__temp_packet__) :=
endif
__temp_objs__ := $(call toobj,$(1),$(5))
$$(foreach f,$(1),$$(eval $$(call cc_template,$$(f),$(2),$(3),$(5))))
$$(__temp_packet__) += $$(__temp_objs__)
endef

# add objs to packet: (#objs, packet)
define do_add_objs_to_packet
__temp_packet__ := $(call packetname,$(2))
ifeq ($$(origin $$(__temp_packet__)),undefined)
$$(__temp_packet__) :=
endif
$$(__temp_packet__) += $(1)
endef

# add packets and objs to target (target, #packes, #objs[, cc, flags])
define do_create_target
__temp_target__ = $(call totarget,$(1))
__temp_objs__ = $$(foreach p,$(call packetname,$(2)),$$($$(p))) $(3)
TARGETS += $$(__temp_target__)
ifneq ($(4),)
$$(__temp_target__): $$(__temp_objs__) | $$$$(dir $$$$@)
	$(V)$(4) $(5) $$^ -o $$@
else
$$(__temp_target__): $$(__temp_objs__) | $$$$(dir $$$$@)
endif
endef

# finish all
define do_finish_all
ALLDEPS = $$(ALLOBJS:.o=.d)
$$(sort $$(dir $$(ALLOBJS)) $(BINDIR)$(SLASH) $(OBJDIR)$(SLASH)):
	@$(MKDIR) $$@
endef

# --------------------  function end  --------------------
# compile file: (#files, cc[, flags, dir])
cc_compile = $(eval $(call do_cc_compile,$(1),$(2),$(3),$(4)))

# 将某个路径下的待打包的源文件集合起来
# eg 将某个目录下的文件打包成库文件并放置到packet中
# add files to packet: (#files, cc[, flags, packet, dir])
add_files = $(eval $(call do_add_files_to_packet,$(1),$(2),$(3),$(4),$(5)))

# add objs to packet: (#objs, packet)
add_objs = $(eval $(call do_add_objs_to_packet,$(1),$(2)))

# add packets and objs to target (target, #packes, #objs, cc, [, flags])
create_target = $(eval $(call do_create_target,$(1),$(2),$(3),$(4),$(5)))

read_packet = $(foreach p,$(call packetname,$(1)),$($(p)))

add_dependency = $(eval $(1): $(2))

finish_all = $(eval $(call do_finish_all))
