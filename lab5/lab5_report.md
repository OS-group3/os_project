# lab5
## 练习1：加载应用程序并执行（需要编码）
**do_execv**函数调用`load_icode`（位于kern/process/proc.c中）来加载并解析一个处于内存中的ELF执行文件格式的应用程序。你需要补充`load_icode`的第6步，建立相应的用户内存空间来放置应用程序的代码段、数据段等，且要设置好`proc_struct`结构中的成员变量trapframe中的内容，确保在执行此进程后，能够从应用程序设定的起始执行地址开始执行。需设置正确的trapframe内容。

请在实验报告中简要说明你的设计实现过程。

- 请简要描述这个用户态进程被ucore选择占用CPU执行（RUNNING态）到具体执行应用程序第一条指令的整个经过。
### 1.修改代码
在proc.c中修改alloc_proc的变量初始化
```
//LAB5 YOUR CODE : 2111673(update LAB4 steps)
     /*
     * below fields(add in LAB5) in proc_struct need to be initialized  
     *       uint32_t wait_state;                        // waiting state
     *       struct proc_struct *cptr, *yptr, *optr;     // relations between processes
     */
 proc->state = PROC_UNINIT; // 设置进程状态为未初始化
 proc->pid = -1; // 初始化进程ID
 proc->runs = 0; // 初始化运行次数
 proc->kstack = 0; // 初始化内核栈地址
 proc->need_resched = 0; // 初始化不需要重新调度
 proc->parent = NULL; // 父进程暂时为空
 proc->mm = NULL; // 内存管理结构为空
 //memset(&(proc->context), 0, sizeof(struct context));  
 // 初始化上下文
 memset(proc, 0, sizeof(struct  proc_struct));//初始化结构体实例
 proc->tf = NULL; // 中断帧指针暂时为空
 proc->cr3 = boot_cr3; // 默认页目录为内核页目录表的基地址
 proc->flags = 0; // 初始化进程标志
 memset(proc->name, 0, PROC_NAME_LEN); // 清空进程名称
  
 proc->wait_state=0;//将等待状态设为0
 proc->cptr = proc->optr = proc->yptr = NULL;//链表节点设为null
 ```
 dofork函数中`assert(current->wait_state == 0);` 确保进程在等待、`set_links(proc);` 设置进程链接
 
 ```
  //LAB5 YOUR CODE :2111673(update LAB4 steps)
 //TIPS: you should modify your written code in lab4(step1 and step5), not add more code.
   /* Some Functions
    *    set_links:  set the relation links of process.  ALSO SEE: remove_links:  lean the relation links of process
    *    -------------------
    *    update step 1: set child proc's parent to current process, make sure current process's wait_state is 0
    *    update step 5: insert proc_struct into hash_list && proc_list, set the relation links of process
    */
if((proc = alloc_proc()) == NULL){//    分配并初始化一个新的进程控制块pcb
goto  fork_out;
     }
proc->parent = current; // 设置父进程为current，表示当前进程是新进程的父进程
assert(current->wait_state == 0); //确保进程在等待
if(setup_kstack(proc) != 0 ){// 调用setup_kstack分配内核栈
goto  bad_fork_cleanup_proc;
     }
if(copy_mm(clone_flags , proc) != 0 ){//调用copy_mm 复制父进程内存信息（也可能是共享）
goto  bad_fork_cleanup_kstack;
     }
copy_thread(proc , stack ,tf); // 调用copy_thread 复制上下文和中断帧

bool  intr_flag;
local_intr_save(intr_flag);// 禁用中断
     {
proc->pid = get_pid();//分配id
hash_proc(proc);//放入哈希链表
//  list_add(&proc_list , &proc->list_link); //  将新进程添加到进程链表
//  nr_process++;//进程数加1
set_links(proc); //设置进程链接
     }
local_intr_restore(intr_flag);//恢复中断状态

wakeup_proc(proc);//    唤醒新进程
ret =proc->pid;//    返回新进程的PID，表示成功创建新进程
```
load_icode函数中设置用户栈指针、程序入口地址和状态标志位等
```
/*   LAB5:EXERCISE1 2111673
     * should set tf->gpr.sp, tf->epc, tf->status
     * NOTICE: If we set trapframe correctly, then the user level process can return to USER MODE from kernel. So
     *          tf->gpr.sp should be user stack top (the value of sp)
     *          tf->epc should be entry point of user program (the value of sepc)
     *          tf->status should be appropriate for user program (the value of sstatus)
     *          hint: check meaning of SPP, SPIE in SSTATUS, use them by SSTATUS_SPP, SSTATUS_SPIE(defined in risv.h)
*/

 tf->gpr.sp = USTACKTOP; // 将用户栈指针设置为用户栈的顶部
 // 设置用户程序入口地址
 tf->epc = elf->e_entry;
 // 设置 SPP为0 以指示用户模式
 tf->status = (sstatus & ~SSTATUS_SPP) | SSTATUS_SPIE;
```
### 2.回答问题
在proc_init中，会建立第1个内核线程idle_proc，这个线程总是调度运行其他线程。然后proc_init会调用kernel_thread建立init_main线程，接着在init_main中将调用kernel_thread建立user_main线程。user_main仍然是一个内核线程，但其任务是创建用户进程。在user_main中将调用kernel_execve来把某一具体程序的执行内容放入内存，覆盖user_main线程，此后就可以调度执行程序，该程序在用户态运行，此时也就完成了用户进程的创建。系统调用将通过do_execve完成用户程序的加载。

首先看到do_execve函数主要做的工作就是先回收自身所占用户空间，然后调用load_icode，用新的程序覆盖内存空间，形成一个执行新程序的新进程。
load_icode函数功能如下：
- 为新进程创建mm结构
- 创建新的页目录，并把内核页表复制到新创建的页目录，这样新进程能够正确映射内核空间
- 分配内存，从elf文件中复制代码和数据，初始化.bss段
- 建立用户栈空间
- 将新进程的mm结构设置为刚刚创建的mm
- 构造中断帧，使用户进程最终能够正确在用户态运行

通过上述do_execve中的操作，原来的user_main已经被用户进程所替换掉了。此时处于RUNNABLE状态的是已经创建完成了的用户进程，系统调用已经完成，将按照调用的顺序一路返回到__trapret，从中断帧中恢复寄存器的值，通过iret回到用户进程exit的第一条语句开始执行。
综上所述，一个用户进程创建到执行第一条指令的完整过程如下：
```
父进程通过fork系统调用创建子进程。通过do_fork进行进程资源的分配，创建出新的进程
fork返回0，子进程创建完成，等待调度。fork中将进程设置为RUNNABLE，该进程可以运行schedule函数进行调度，调用proc_run运行该进程
该进程调用kernel_execve，产生中断并进行exec系统调用
do_execve将当前进程替换为需要运行的用户进程，加载程序并设置好中断帧
从中断帧返回到用户态，根据中断帧中设置的eip，跳转执行用户程序的第一条指令
```
## 练习2：父进程复制自己的内存空间给子进程（需要编码）
创建子进程的函数`do_fork`在执行中将拷贝当前进程（即父进程）的用户内存地址空间中的合法内容到新进程中（子进程），完成内存资源的复制。具体是通过`copy_range`函数（位于kern/mm/pmm.c中）实现的，请补充`copy_range`的实现，确保能够正确执行。

请在实验报告中简要说明你的设计实现过程。

- 如何设计实现`Copy on Write`机制？给出概要设计，鼓励给出详细设计。
### 1.修改代码
在pmm.c的copy_range函数中复制进程并建立物理地址与页地址的映射关系
```
            /* LAB5:EXERCISE2 2111673
             * replicate content of page to npage, build the map of phy addr of
             * nage with the linear addr start
             *
             * Some Useful MACROs and DEFINEs, you can use them in below
             * implementation.
             * MACROs or Functions:
             *    page2kva(struct Page *page): return the kernel vritual addr of
             * memory which page managed (SEE pmm.h)
             *    page_insert: build the map of phy addr of an Page with the
             * linear addr la
             *    memcpy: typical memory copy function
             *
             * (1) find src_kvaddr: the kernel virtual address of page
             * (2) find dst_kvaddr: the kernel virtual address of npage
             * (3) memory copy from src_kvaddr to dst_kvaddr, size is PGSIZE
             * (4) build the map of phy addr of  nage with the linear addr start
             */
  
 //1.找寻父进程的内核虚拟页地址
 void * src_kvaddr = page2kva(page);
 //2.找寻子进程的内核虚拟页地址  
 void * dst_kvaddr = page2kva(npage);
 //3.复制父进程内容到子进程
 memcpy(dst_kvaddr, src_kvaddr, PGSIZE);
 //4.建立物理地址与子进程的页地址起始位置的映射关系
 ret = page_insert(to, npage, start, perm);
  
 assert(ret == 0);
```
### 2.回答问题
Copy on Write 是读时共享，写时复制机制。多个进程可以读同一部分数据，需要对数据进行写时再复制一份到自己的内存空间。具体的实现为，在fork时，直接将父进程的地址空间即虚拟地址复制给子进程，不分配实际的物理页给子进程，并将父进程所有的页都设置为只读。父子进程都可以读取该页，当父子进程写该页时，就会触发页访问异常，发生中断，调用中断服务例程，在中断服务例程中，将触发异常的虚拟地址所在的页复制，分配新的一页存放数据，这样父子进程写该部分数据时就各自可以拥有一份自己的数据。
所以设计思路如下：
1.设置一个标记位，用来标记某块内存是否共享，实际上dup_mmap函数中有对share的设置，因此首先需要将share设为1,表示可以共享。
2.在pmm.c中为copy_range添加对共享页的处理，如果share为1，那么将子进程的页面映射到父进程的页面即可。子进程和父进程对于这个共享页面都保持只读权限，这样可以保证不会影响另外一个页面，。
3.当程序尝试修改只读的内存页面的时候，将触发Page Fault中断，这时候我们可以检测出是超出权限访问导致的中断，说明进程访问了共享的页面且要进行修改，因此内核此时需要重新为进程分配页面、拷贝页面内容、建立映射关系（修改do_pgfault）

### 3.实验结果
`make`
![](https://markdown.liuchengtu.com/work/uploads/upload_a00ea59b149fd4269d3d3e1461ab5369.png)

`make qemu`
![](https://markdown.liuchengtu.com/work/uploads/upload_2e3c8c3963df1bdffb6113692cc5d265.png)
![](https://markdown.liuchengtu.com/work/uploads/upload_c44a86224eca621eb18a4e6203595430.png)

`make grade`
![](https://markdown.liuchengtu.com/work/uploads/upload_b2ee700300254143a725d82c024bbc8e.png)


## 练习3：阅读分析源代码，理解进程执行 fork/exec/wait/exit 的实现，以及系统调用的实现（不需要编码）
请在实验报告中简要说明你对 fork/exec/wait/exit函数的分析。并回答如下问题：

- 请分析fork/exec/wait/exit的执行流程。重点关注哪些操作是在用户态完成，哪些是在内核态完成？内核态与用户态程序是如何交错执行的？内核态执行结果是如何返回给用户程序的？
- 请给出ucore中一个用户态进程的执行状态生命周期图（包执行状态，执行状态之间的变换关系，以及产生变换的事件或函数调用）。（字符方式画即可）

 - fork：进程执行了fork系统调用后，进入正常的中断处理流程，最终将控制权转移给syscall。在syscall函数中，根据系统调用执行sys_fork函数，该函数进一步执行do_fork函数，完成新的进程的进程控制块的初始化、设置、以及将父进程内存中的内容到子进程的内存的复制工作。然后将新创建的进程放入可执行队列，状态标记为RUNNABLE，这样之后调度器就有可能将子进程运行起来；
  - exec：在执行exec系统调用之后，经过一系列中断处理流程和函数调用，最终执行了do_execve函数。在该函数中，会对用户态内存空间进行清空，然后将新的要执行的程序加载到内存中，然后设置好中断帧，使得最终中断返回之后可以跳转到指定的应用程序的入口处，保证程序的正确执行；
  - wait：wait系统调用的主要实现部分同样也在do_wait函数。在这个函数中，首先检查保存返回码的指针地址是否在合理范围内，然后搜索指定进程是否存在着处于ZOMBIE状态的子进程，如果有，直接将其占用的资源释放掉即可；如果找不到这种子进程，则将当前进程的状态改成SLEEPING，然后调用schedule函数将其当前线程从CPU占用中切换出去，并且重复寻找ZOMBIE状态的子进程，直到有对应的子进程结束来唤醒这个进程为止；
  - exit：进程执行了exit系统调用之后，进入正常的中断处理流程，然后将控制权转移给syscall，之后根据系统调用执行sys_exit函数，最后执行do_exit函数。该函数首先将释放当前进程的大多数资源，然后将其标记为ZOMBIE状态。如果父进程处于等待当前进程退出的状态，即SLEEPING状态，则调用wakeup_proc函数将父进程唤醒；如果当前进程还有子进程，则完成处于ZOMBIE状态子进程的最后回收工作。最终调用schedule函数，让出CPU资源执行新的进程，等待父进程进一步完成其所有资源的回收；


- 分析fork/exec/wait/exit的执行流程：
  - 当用户态程序需要操作系统提供的服务时，它会执行一个系统调用`syscall`。通过内联汇编进行`ecall`环境调用。这将产生一个中断, 进入内核态进行异常处理，并开始执行与系统调用关联的内核代码。在内核态中，syscall函数主要完成系统调用的转发，交由具体的函数进行处理。 
  - 用户态主要完成系统调用函数的调用和传递参数，并等待系统调用的返回结果。内核态的系统调用函数执行具体的操作，如创建新进程（fork）、加载新程序（exec）、等待子进程结束（wait）和终止进程（exit）。内核态访问和修改进程的数据结构和状态并进行资源分配和管理。当系统调用完成后，内核态将执行结果返回给用户程序，并将控制权切换回用户态，用户程序继续执行。
  - fork：sys_fork函数，用于创建新的进程。在函数中调用`do_fork`函数负责实际进程的复制。函数会把当前的进程复制一份，创建一个子进程，原先的进程是父进程。接下来两个进程都会收到`sys_fork()`的返回值，如果返回0说明当前位于子进程中，返回一个非0的值（子进程的PID）说明当前位于父进程中。然后就可以根据返回值的不同，在两个进程里进行不同的处理。
  - exec：sys_exec函数，用于运行一个新的进程。在当前的进程下，停止原先正在运行的程序，开始执行一个新程序。PID不变，但是内存空间要重新分配，执行的机器代码发生了改变。我们可以用`fork()`和`exec()`配合，在当前程序不停止的情况下，开始执行另一个程序。
  - wait：sys_wait函数，用于使父进程暂停，直到一个子进程结束。函数指定一个pid并调用`do_wait`挂起当前的进程，等到特定条件满足的时候再继续执行,最后返回已经结束子进程的ID。
  - exit：sys_exit函数，用于结束当前进程的执行。在函数中调`do_exit`函数负责实际的进程结束操作，包括释放进程的所有资源，并将退出状态返回给父进程。
  - 当用户程序调用系统调用函数时，会触发从用户态切换到内核态的过程。在内核态执行系统调用函数期间，用户程序会被阻塞，等待系统调用完成。完成后，内核态将执行结果返回给用户程序，并将控制权切换回用户态，用户程序继续执行。
  - 内核态执行结果返回给用户程序的方式通常是通过系统调用函数的返回值或者通过参数传递。例如，在fork系统调用中，内核态会返回子进程的进程ID给用户程序；在wait系统调用中，内核态会将子进程的退出状态存储在用户程序提供的存储区域中。用户程序可以通过检查返回值或读取存储区域来获取内核态的执行结果。
  

- 请给出ucore中一个用户态进程的执行状态生命周期图
![](https://markdown.liuchengtu.com/work/uploads/upload_a8558ffc0cbf347b9b5a72359b95e278.png)

执行：make grade。如果所显示的应用程序检测都输出ok，则基本正确。（使用的是qemu-1.0.1）