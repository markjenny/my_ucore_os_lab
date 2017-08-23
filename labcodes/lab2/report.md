# 练习0
---
以前都没用过这个diff和patch的工具，都是直接使用svn或者是git的相关客户端工具，今天使用了一下，发现用起来也是很不错的，但是因为我之前不了解，所以只是使用了一下基本的功能来处理；但是感觉重复工作还是做了比较的多的；
后期再查看用更便捷的参数或者脚本来批量处理，现在大部分是手工处理的，所以后期有好的方法我再进行迭代。

那么就先说一下我的做法；

首先，我是直接比较了kern文件夹下所有不同的文件，因为在lab1中我主要修改的就是kern下的代码；因为文件夹下还有子文件夹，所以我们要采用递归的方式来进行调用，所以需要加上-r --brief参数，具体如下：
```
prompt# diff -r lab2/kern/ lab1/kern/ > changelist
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
那我我们就口蹄疫通过上述的文本看到哪些文件是不同的；首先理解我们自己的需求：我们是需要将lab1中新添加的代码合入到lab2中；因此像那些只存在lab2中的不同我们就不用关心了；如上面的文本所示，我们可以发现kdebug.c这个文件二者是不同的，那么我们可以diff一下这两个文件看看具体有什么不同：
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
这里需要插嘴一句的是，我们在使用diff命令的时候，如果你像通过patch来让a变成b，那么在diff的时候就使用`diff a b > delta`，这样delta中就回存储两个文件的不同，之后再使用`patch a c`时就可以让a通过补丁c变成b；了解了这个diff和patch中参数位置带来的具体效果后，我们就可以通过这种方法来填补上lab1中含有的但是lab2中不含有的代码了；

因为我们想让lab2中含有lab1拥有的代码，那么其实就可以理解成我们想让部分代码变成lab1中的样子，因为我们就需要将上文中讲到的`diff a b`中`a`的位置替换成`lab2/kern/debug/kdebug.c`，将`b`中的位置替换成`lab1/kern/debug/kdebug.c`，并将不同输出到delta文件中；delta文件中存放的就是上一个代码段中显示的内容；

仔细观察我们可以发现，lab1下的这个文件并不是完全比lan2下的这个文件多的，kdebug-lab2中包含了更多的头文件信息，所以我们并不能将这个delta用作回复的完整文件，因为那样的话patch了之后就是一个单纯的kdebug-lab1了，而lab2新增的很多代码就没有了，这样的patch没有意义；因为我们将delta文件中，kdebug-lab2自身拥有的那部分去掉，即上文的`6,9d5`和`11,12d6`后面对应的代码去掉，这样剩下的就是kdebug-lab1中比kdebug-lab2中完全新增的东西，这个时候执行如下命令：
```
prompt# patch lab2/kern/debug/kdebug.c delta
```
就可以将kdebug-lab1中新增的代码都patch到kdebug-lab2上；
剩下的新增文件都采用这种方法（感觉还是稍微有点笨拙）。