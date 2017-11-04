# lab4
---

*(随便说两句，最近工作上的事情好多，导致放在业余学习的时间不是特别的多，终于碰见伪双休！)*

---
# 练习0
---
由于现在合入代码的量变得比较多，已经不适合用`diff`和`patch`这两个工具来打补丁了，直接使用meld图形化工具，方便快捷；毕竟人眼对可视化的工具更加适应。

---

# 练习1

本题主要是要求我们初始化一个进程数据结构，其实这个就是一个进程的**唯一标识**(这么说他不过分，毕竟一个进程的虚拟地址空间和寄存器，栈空间都是由这个数据结构进行管理的，kernel中就是由该数据结构负责)，下面来看看这个数据结构的组成：
```
struct proc_struct {                                                                                                                                                                         
    enum proc_state state;                      // Process state                    
    int pid;                                    // Process ID                       
    int runs;                                   // the running times of Proces   
    uintptr_t kstack;                           // Process kernel stack             
    volatile bool need_resched;                 // bool value: need to be rescheduled to release CPU?
    struct proc_struct *parent;                 // the parent process               
    struct mm_struct *mm;                       // Process's memory management field
    struct context context;                     // Switch here to run process       
    struct trapframe *tf;                       // Trap frame for current interrupt
    uintptr_t cr3;                              // CR3 register: the base addr of Page Directroy Table(PDT)
    uint32_t flags;                             // Process flag                     
    char name[PROC_NAME_LEN + 1];               // Process name                     
    list_entry_t list_link;                     // Process link list                
    list_entry_t hash_link;                     // Process hash list                
};                  
```

看了上面这个数据结构(其实它就是之前在操作系统课中常常听到的PCB，process control block 进程控制块)，其实你就已经对一个进程有了比较整体的理解了，而不是停留在“背书上的定义”的层次。

接下来我们解释一下各个数据成员：

* state: 进程当前的状态(uninit,runnable,sleeping,zombie)；我们知道一个进程最重要的三个状态分别是**运行**，**就绪**，**阻塞**；显然一个进程正在运行的时候是不需要进行状态标记的(因为有一个变量`curr_proc`来指向正在运行的程序)，因此这四个状态可以囊括了进程从创建到退出的所有状态；
* pid： process id；这个就不用解释了
* runs ：即进程占用的时间片个数，一般应用于进程调度中；
* need_resched : 当前正在运行的进程是否需要被调度来释放占用的CPU资源；
* parent ：父进程，这个也不需要多说；
* mm ： 这个就是每个进程的虚拟地址在空间(在实验三中我们已经学习到了)，有了这个数据成员之后，每个进程都可以认为自己独享了整个计算机的内存空间；这种思想非常好，它让一个进程不用去过多的关注内存分布相关信息，只需要关注我是运行在多少bit位的CPU及内存上就可以，**这种形成统一套层的作用正是操作系统的核心思想**；
* context ：上下文；作为在程序切换过程中起到至关重要作用的部分，我们要对他进行详细的讲解：

    ```
    struct context {                                                                    
        uint32_t eip;                                                                   
        uint32_t esp;                                                                   
        uint32_t ebx;                                                                   
        uint32_t ecx;                                                    
        uint32_t edx;                                                   
        uint32_t esi;                                                                   
        uint32_t edi;                                                                   
        uint32_t ebp;                                                                                                                                                                            
    };  
    ```
上下文主要时维护了通用寄存器(eax,ebx,ecx,edx等)及重要的esp(定位堆栈)和eip(定位指令)信息，这样我们就可以把当前程序现场保护下来，之所以不用维护ss,es,cs等段寄存器信息是因为他们根本不会变，不需要维护；
这是因为我们在进程切换回来时要通过trapframe和eip寄存器处的指令来恢复出进程在执行前的样子(这个我在后面的进程创建--切换--执行--退出中会再次给出讲解)；

* trapframe :中断帧；我们在理论课的学习中知道了线程切换需要**上下文**和**堆栈**，其中上下文是为了切换时可以恢复现场，堆栈是为了进程产生中断时存储trapframe所用的；

 *但是一个PCB中为什么还需要trapframe呢？*
 这是因为我们在进程切换的过程中，切换入口函数会将模拟一个中断返回(这里其实是很关键的一点，后续会讲到)，并将当前的esp定位在这个trapframe上，这样在处理完中断弹出后就可以直接从这个trapframe中恢复出进程真正的esp和eip，从而进程真正的程序运行；
 
* cr3:我们知道内核中的CR3寄存器存储的时`page directory table`的地址，这个也是这个作用；
* flags ： 标记位，eg该程序是否可中断；
* name ： 不多说，程序的名字；
* list_link ： 将进程穿成串；
* hash_link ：有的时候从list_link中进行遍历的话效率太低了，采用hash_link会好很多；


