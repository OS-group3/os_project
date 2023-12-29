# lab0.5

## 练习1: 使用GDB验证启动流程
为了熟悉使用qemu和gdb进行调试工作,使用gdb调试QEMU模拟的RISC-V计算机加电开始运行到执行应用程序的第一条指令（即跳转到0x80200000）这个阶段的执行过程，说明RISC-V硬件加电后的几条指令在哪里？完成了哪些功能？要求在报告中简要写出练习过程和回答。

复位地址指的是CPU在上电或按下复位键时将PC赋的初始值。复位代码主要是将计算机系统的各个组件置于初始状态，以确保系统处于可控状态，并且准备好加载和执行操作系统。

在QEMU模拟的RISC-V处理器中，复位地址被初始化为0x1000即PC被初始化为0x1000，故处理器加电后从0x1000开始执行复位代码。在此处复位代码将计算机系统初始化后，由于QEMU的复位代码指定加载Bootloader的位置为0x80000000，故将启动Bootloader，之后Bootloader将加载操作系统内核并启动操作系统的执行。这里使用的是QEMU自带的 bootloader: OpenSBI固件。在Qemu开始执行指令之前，作为bootloader的OpenSBI.bin会被加载到物理内存以物理地址0x80000000开头的区域上，内核镜像os.bin被加载到以物理地址0x80200000开头的区域上。

1. 启动：在Makefile文件的目录下，创建两个终端，分别输入：
```
make debug   # 终端1，启动qemu
make gdb     # 终端2，启动gdb
```

2. 由于CPU加电后执行的第一条指令存放于地址`0x1000`中也就是当前pc位置，故执行命令`x/10i  $pc`显示即将执行的10条汇编指令。发现硬件加电后的几条指令所在的位置：0x1000、0x10004、0x10008、0x1000c、0x10010。这前五条指令用于初始化处理器的一些配置，读取了mhartid CSR并执行跳转操作，最后跳转到0x80000000启动Bootloader。
![加电后的即将执行的十条指令](https://markdown.liuchengtu.com/work/uploads/upload_fc72a96a34493f403d30750f7d0d32c0.png)

3. 之后执行命令`b *0x80200000`在0x80200000地址设置断点并执行命令`c`来让程序从0x80000000运行到0x80200000。可以看到此处命令为la sp,bootstacktop，对应到了作为整个内核的入口点的kern/init/entry.S文件中的入口点kern_entry，其作用就是分配好内核栈。之后就是通过命令`j 0x8020000c <kern_init>`跳转到函数kern_init。所以kern_init是真正的入口点。
![跳转到0x80200000](https://markdown.liuchengtu.com/work/uploads/upload_36c670c31fc36c71deb165bf4bfcc89a.png)

4. 其余分析
    在最小可执行内核里，主要完成了内核的内存布局和入口点设置以及通过sbi封装输入输出函数这两个部分。
    内存布局和入口点设置是在第三条中所说的部分实现的。
    通过sbi封装输入输出函数是在kern/init/init.c中实现的。OpenSBI提供了输入一个字符和输出一个字符的接口，通过把接口一层层封装起来，从而让stdio.h里的格式化输出函数cprintf()来使用。通过内联汇编调用ecall指令，从而调用OpenSBI。如此就可以通过sbi_console_putchar()函数来输出一个字符。之后使用console.c文件实现简单的封装，并在libs/printfmt.c实现复杂的格式化输入输出函数。
# lab1

## 练习1：理解内核启动中的程序入口操作
阅读 kern/init/entry.S内容代码，结合操作系统内核启动流程，说明指令 la sp, bootstacktop 完成了什么操作，目的是什么？ tail kern_init 完成了什么操作，目的是什么？

kern/init/entry.S文件中的汇编代码, 作为整个内核的入口点。

在这个入口点中——指令 la sp, bootstacktop的作用就是分配好内核栈，将 bootstacktop 的地址加载到 sp 寄存器中。这个指令的目的是将内核栈的顶部地址设置为 bootstacktop，即将栈指针 sp 设置为内核栈的顶部。这样，在内核初始化过程中，可以使用栈来保存函数调用的返回地址、局部变量等信息。

然后通过指令tail kern_init跳转到kern_init,。它的作用是将程序的控制权转移到标记为 kern_init 的代码段。使用 "tail" 关键字可以实现函数调用的尾递归优化，即在跳转

它的目的是在跳转到 kern_init 之前，清空当前函数的调用栈，以便在 kern_init 函数中使用新的栈帧。这样可以确保在内核初始化过程中，使用的是一个干净的栈空间，避免出现不可预料的错误，比如函数调用时的堆栈溢出。


## 练习2：完善中断处理 （需要编程）
请编程完善trap.c中的中断处理函数trap，在对时钟中断进行处理的部分填写kern/trap/trap.c函数中处理时钟中断的部分，使操作系统每遇到100次时钟中断后，调用print_ticks子程序，向屏幕上打印一行文字”100
 ticks”，在打印完10行后调用sbi.h中的shut_down()函数关机。

实验代码如下：
```Plain
clock_set_next_event()//发生这次时钟中断的时候，我们要设置下一次时钟中断
if（num==10）{//判断打印了十次
sbi_shutdown();//设置关机函数
}
if (++ticks % TICK_NUM == 0) { //宏定义TICK_NUM=100   
    print_ticks();       
    num++;
}
```
clock_set_next_event()函数位于/lab/lab1/kern/driver/clock.c文件中，代码为：
```
void clock_set_next_event(void) 
{
sbi_set_timer(get_cycles() + timebase); 
}
```
整个函数的作用是通过获取当前 CPU 周期数，加上一个时间间隔，来计算出下一个时钟事件的时刻，并将该时刻传递给 `sbi_set_timer` 函数进行设置。这样可以实现在指定时间间隔后触发下一个时钟事件的功能。

即每次时钟中断时都要设置一次时钟中断，便于下一次再次触发。累计到100s的时候调用一次`print_ticks()`，打印一次100 ticks，信号计数num+1，随后进入下一轮计数。结果如下

![](https://markdown.liuchengtu.com/work/uploads/upload_9038315d009dadb19341ec3d3b62c96f.png)


## 扩展练习 Challenge1：描述与理解中断流程
回答：描述ucore中处理中断异常的流程（从异常的产生开始），其中mov a0，sp的目的是什么？SAVE_ALL中寄存器保存在栈中的位置是什么确定的？对于任何中断，__alltraps 中都需要保存所有寄存器吗？请说明理由。

在 ucore 中，处理中断异常的流程如下：
 1. 异常产生：当处理器执行指令时，如果发生了异常（如中断、故障或陷阱），处理器会根据异常类型和优先级触发相应的异常处理流程。
 2. 中断向量表：处理器会根据异常类型，从中断向量表中找到对应的异常处理程序的入口地址。
3. 保存上下文：处理器会在触发异常之前，将当前的上下文（包括寄存器的值、程序状态等）保存到内核栈中，以便在异常处理完成后能够恢复执行。
4. 跳转到异常处理程序：处理器会根据中断向量表中找到的入口地址，跳转到对应的异常处理程序。
5. 异常处理程序：异常处理程序会根据具体的异常类型，执行相应的处理逻辑。例如，对于时钟中断，可能会进行时间片轮转调度；对于硬件中断，可能会处理设备的输入输出等。
6. 恢复上下文：在异常处理程序执行完毕后，处理器会从内核栈中恢复之前保存的上下文，包括寄存器的值、程序状态等。
7. 返回原程序：处理器会根据恢复的上下文，继续执行触发异常的指令后面的指令，使程序从异常处继续执行。


"mov a0, sp" 的目的是将栈指针 sp 的值传递给寄存器 a0，作为参数传递给接下来要调用的函数 "trap"，以便中断处理程序能够访问和操作栈上的数据。通过将栈指针作为参数传递给中断处理程序，可以在中断处理程序中获取到触发中断时的栈状态，从而进行相应的处理。例如，可以保存或恢复栈上的数据，或者进行栈的调整等操作。
       
在kern/trap/trapentry.S中，我们定义一个汇编宏 SAVE_ALL, 用来保存所有寄存器到栈顶（实际上把一个trapFrame结构体放到了栈顶）。寄存器保存在栈中的位置是由栈指针 sp 决定的。在保存寄存器时，可以选择将寄存器的值按照一定的顺序依次压入栈中，也可以选择将寄存器的值按照一定的顺序依次存放在栈中的不同位置。
       
在一些情况下，__alltraps可能并不需要保存所有的寄存器。具体需要保存哪些寄存器，取决于中断处理程序的需求和编译器的实现。在具体的实现中，需要查看编译器的文档或具体的调用约定来确定需要保存哪些寄存器。

一种情况是，如果中断处理程序不需要使用到所有的寄存器，那么可以选择只保存和恢复需要使用的寄存器，而不是保存所有的寄存器。这样可以减少保存和恢复寄存器的开销，提高中断处理程序的执行效率。

另一种情况是，如果编译器能够进行寄存器分配优化，并且确定某些寄存器在中断处理程序中不会被使用到，那么编译器可能会选择不保存这些寄存器的值。这样可以进一步减少保存和恢复寄存器的开销。

## 扩展练习 Challenge2：理解上下文切换机制
回答：在trapentry.S中汇编代码 csrw sscratch, sp；csrrw s0, sscratch, x0实现了什么操作，目的是什么？save all里面保存了stval scause这些csr，而在restore all里面却不还原它们？那这样store的意义何在呢？

`csrw sscratch, sp` 和 `csrrw s0, sscratch, x0` 是用于操作特殊寄存器的指令。

- `csrw sscratch, sp` 将 `sp` 寄存器的值存储到 `sscratch` 寄存器中。这个操作的目的是将当前的栈指针（`sp`）保存到 `sscratch` 寄存器中，以便稍后在异常处理过程中使用。
  
- `csrrw s0, sscratch, x0` 将 `sscratch` 寄存器的值存储到寄存器 `s0` 中，并将 `x0` 的值写入 `sscratch` 寄存器。这个操作的目的是在异常处理程序之前将 `sscratch` 寄存器的值设置为0。在异常处理程序中，如果发生递归异常，即异常又引发了新的异常，通过检查 `sscratch` 寄存器的值为0，可以知道异常来自内核，从而避免无限递归。
  `SAVE_ALL` 保存了诸如 `scause` 和 `stval` 等控制状态寄存器（CSR）的值，以备将来使用。在之后的`restore all`中便于恢复之前保存的所有状态寄存器，可以恢复到发生异常之前的状态，但是不能将 `scause` 和 `stval` 这些CSR恢复，因为他们之中可能包括导致异常的代码，因此不会还原。

这些操作是为了在保存寄存器状态和处理异常时正确地管理与栈相关的寄存器和特殊寄存器，可以在中断处理例程中获取相关的系统状态信息，了解导致异常的原因，并进行相应的处理或记录。

## 扩展练习Challenge3：完善异常中断

编程完善在触发一条非法指令异常 mret，在kern/trap/trap.c的异常处理函数中捕获，并对其进行处理，简单输出异常类型和异常指令触发地址，即“Illegal instruction caught at 0x(地址)”，“ebreak caught at 0x（地址）”与“Exception type:Illegal instruction"，“Exception type: breakpoint”。

实验代码如下：
```
#define T_ILLEGAL_INSTRUCTION    12      // 非法指令异常
#define T_EBREAK                15      // 软件断点异常

// 非法指令异常处理
/* LAB1 CHALLENGE3   YOUR CODE :2111673  */
/*(1)输出指令异常类型（ Illegal instruction）
*(2)输出异常指令地址
*(3)更新 tf->epc寄存器
*/
            cprintf("Exception type:Illegal instruction\n");
            cprintf("Illegal instruction caught at 0x%x\n", tf->epc);
            
//断点异常处理
/* LAB1 CHALLLENGE3   YOUR CODE : 2111673 */
/*(1)输出指令异常类型（ breakpoint）
*(2)输出异常指令地址
*(3)更新 tf->epc寄存器
*/
            cprintf("Exception type: breakpoint\n");
            cprintf("breakpoint caught at 0x%x\n", tf->epc);

```
在trap_dispatch()函数中添加对非法指令异常（T_ILLEGAL_INSTRUCTION）和软件断点异常（T_EBREAK）的处理分支。然后在init.c文件中添加触发语句
```
uint32_t src, ret;
__asm__ __volatile__("mret"); // 触发非法伪指命异常
//__asm__ __volatile__("ebreak"); //触发断点异常
```
触发违法伪指令异常显示如下：

![](https://markdown.liuchengtu.com/work/uploads/upload_fba872cf95c57efd429f9dde1d82e57f.png)


触发断点异常显示如下：

![](https://markdown.liuchengtu.com/work/uploads/upload_c3ada6fd1d8e49e4b2ef3cd2863daa0a.png)

# lab2
## 练习1：理解first-fit 连续物理内存分配算法（思考题）
first-fit 连续物理内存分配算法作为物理内存分配一个很基础的方法，需要同学们理解它的实现过程。请大家仔细阅读实验手册的教程并结合`kern/mm/default_pmm.c`中的相关代码，认真分析default_init，default_init_memmap，default_alloc_pages， default_free_pages等相关函数，并描述程序在进行物理内存分配的过程以及各个函数的作用。
请在实验报告中简要说明你的设计实现过程。请回答如下问题：

- 你的first fit算法是否有进一步的改进空间？

最先匹配法 (first-fit) ：当需要分配页面时，它会从空闲页块链表中找到第一个适合大小的空闲页块，然后进行分配。当释放页面时，它会将释放的页面添加回链表，并在必要时合并相邻的空闲页块，以最大限度地减少内存碎片。但随着低端分区不断划分而产生较多小分区，每次分配时查找时间开销会增大。

物理内存分配的基本过程：
1. 遍历物理内存空闲链表，找到第一个大小大于等于请求的页面数量n的空闲页面。
  
2. 如果找到了符合要求的空闲页面，将该页面从空闲链表中删除，并将其标记为已分配状态。
  
3. 如果找不到符合要求的空闲页面，则分配失败，返回NULL。
  
4. 如果找到的空闲页面大小大于请求的页面数量n，将该页面分成两部分，一部分大小为n，另一部分大小为剩余的空闲页面数量。将前一部分标记为已分配状态，并将其返回给调用者，将后一部分重新插入到空闲链表中。
  
5. 返回已分配的页面的Page结构指针。

### 1.算法实现

default_init函数：
初始化物理内存管理器，在系统启动时调用。通过调用list_init函数初始化空闲链表，并将可用的物理页面数初始化为0，为后续的物理内存分配做准备。
```
static void
default_init(void) {
    //初始化物理内存空闲链表free_list
    list_init(&free_list);
    nr_free = 0;//nr_free可以理解为在这里可以使用的一个全局变量，记录可用的物理页面数
}
```

default_init_memmap函数：
将一段连续的物理页面初始化为保留页面，并将其加入到空闲链表中。
```
static void
default_init_memmap(struct Page *base, size_t n) {
    assert(n > 0);//判断传入的页面数量n是否大于0
    struct Page *p = base;
    for (; p != base + n; p ++) {
        assert(PageReserved(p));//使用assert宏来断言该页面是保留页面
        //将其标志位和属性清零，将引用计数设置为0
        p->flags = p->property = 0;
        set_page_ref(p, 0);
    }
    //将base页面的属性设置为n，表示该连续页面的数量为n，将该页面标记为保留页面
    base->property = n;
    SetPageProperty(base);
    nr_free += n;//增加n个可用的物理内存页
    //根据空闲链表的情况，将base页面插入到空闲链表中的合适位置
    if (list_empty(&free_list)) {
        //如果空闲链表为空，则直接将base插入到链表头部
        list_add(&free_list, &(base->page_link));
    } else {//遍历空闲链表，找到合适的位置将base插入
        list_entry_t* le = &free_list;
        while ((le = list_next(le)) != &free_list) {
            struct Page* page = le2page(le, page_link);
            if (base < page) {
            // 如果base小于当前页面，将base插入到当前页面之前
                list_add_before(le, &(base->page_link));
                break;
            } else if (list_next(le) == &free_list) {
            // 如果已经到达链表尾部，将base插入到链表尾部
                list_add(le, &(base->page_link));
            }
        }
    }
}
```
default_alloc_pages函数：
从空闲链表中分配n个物理页面。从空闲链表中找到第一个满足要求的页面。如果找到了可用的页面，则将其分配出去，并更新空闲链表和可用页面数量。如果找不到可用的页面，则返回NULL
```
static struct Page *
default_alloc_pages(size_t n) {
    assert(n > 0);////判断传入的页面大小n是否大于0
    if (n > nr_free) {
    //判断可用的物理页面nr_free是否足够分配大小为n页面，如果不足则返回NULL
        return NULL;
    }
    //使用一个指针le遍历空闲链表free_list
    struct Page *page = NULL;
    list_entry_t *le = &free_list;
    while ((le = list_next(le)) != &free_list) {
        struct Page *p = le2page(le, page_link);
        if (p->property >= n) {//找到第一个property大于等于n的页面
            page = p;//将其赋值给page，并跳出循环
            break;
        }
    }
    if (page != NULL) {
        //使用指针prev指向page的前一个页面
        list_entry_t* prev = list_prev(&(page->page_link));
        list_del(&(page->page_link));//从空闲链表中删除page
        if (page->property > n) {
        //如果page的剩余空闲页面数量大于n，将剩余的页面分成两部分。其中一部分大小为n，另一部分大小为剩余的页面数量。
            struct Page *p = page + n;
            p->property = page->property - n;
            //将剩余的页面标记为保留页面，并将其插入到prev指向的页面之后
            SetPageProperty(p);
            list_add(prev, &(p->page_link));
        }
        nr_free -= n;//将nr_free减去n，表示分配了n个页面
        ClearPageProperty(page);//清除page的保留页面标志
    }
    return page;
}
```
default_free_pages函数：
释放一段连续的物理页面，并将其加入到空闲链表中
```
static void
default_free_pages(struct Page *base, size_t n) {
    assert(n > 0); // 确保页面数量大于0
    struct Page *p = base;
    for (; p != base + n; p ++) {
        // 确保页面既不是保留页面也不是属性页面
        assert(!PageReserved(p) && !PageProperty(p)); 
        p->flags = 0; // 清除页面标志位
        set_page_ref(p, 0); // 清除页面的引用计数
    }
    base->property = n; // 设置base页面的属性为n，表示连续页面的数量为n
    SetPageProperty(base); // 将base页面标记为属性页面
    nr_free += n; // 增加可用页面的数量

    if (list_empty(&free_list)) { // 如果空闲链表为空
        list_add(&free_list, &(base->page_link)); // 将base插入到链表头部
    } else {
        list_entry_t* le = &free_list;
        // 遍历空闲链表，找到合适的位置将base插入
        while ((le = list_next(le)) != &free_list) {
            struct Page* page = le2page(le, page_link);
            if (base < page) {
            // 如果base小于当前页面，将base插入到当前页面之前
                list_add_before(le, &(base->page_link));
                break;
            } else if (list_next(le) == &free_list) { 
            // 如果已经到达链表尾部，将base插入到链表尾部
                list_add(le, &(base->page_link));
            }
        }
    }

    // 检查base页面的前一个页面是否是空闲页面，如果是则合并
    list_entry_t* le = list_prev(&(base->page_link));
    if (le != &free_list) {
        p = le2page(le, page_link);
        if (p + p->property == base) { // 如果前一个页面与base页面相邻
            p->property += base->property; // 合并页面数量
            ClearPageProperty(base); // 清除base的属性页面标志
            list_del(&(base->page_link)); // 从链表中删除base
            base = p; // 更新base为合并后的页面
        }
    }

    // 检查base页面的后一个页面是否是空闲页面，如果是则合并
    le = list_next(&(base->page_link));
    if (le != &free_list) {
        p = le2page(le, page_link);
        if (base + base->property == p) { // 如果后一个页面与base页面相邻
            base->property += p->property; // 合并页面数量
            ClearPageProperty(p); // 清除p的属性页面标志
            list_del(&(p->page_link)); // 从链表中删除p
        }
    }
}
```

### 2.改进空间

1. **高效的数据结构**: 使用更高效的数据结构来存储空闲内存块，例如红黑树、跳表等，以便更快地查找和合并内存块。
  
2. **固定分区大小：** 将内存分成固定大小的分区，这样可以更容易找到适合大小的空闲分区，但可能会浪费一些内存。
  
3. **动态调整分区大小：** 允许动态调整分区大小，以更好地适应不同大小的进程。这可以减少内部碎片，但增加了管理复杂性。
  
4. **考虑首次适配的变体：** 可以修改首次适配算法，以考虑更合适的分配策略。例如，可以限制只在较大的空闲分区中分配，以减少外部碎片。


## 练习2：实现 Best-Fit 连续物理内存分配算法（需要编程）
在完成练习一后，参考kern/mm/default_pmm.c对First Fit算法的实现，编程实现Best Fit页面分配算法，算法的时空复杂度不做要求，能通过测试即可。
请在实验报告中简要说明你的设计实现过程，阐述代码是如何对物理内存进行分配和释放，并回答如下问题：
- 你的 Best-Fit 算法是否有进一步的改进空间？

最佳适应算法（Best Fit）：从全部空闲区中找出能满足作业要求的、且大小最小的空闲分区，这种方法能使碎片尽量小。为适应此算法，空闲分区表（空闲区链）中的空闲分区要按从小到大进行排序，自表头开始查找到第一个满足要求的自由分区分配。该算法保留大的空闲区，但造成许多小的空闲区。
### 1.修改代码
首先对kern/mm/best_fit_pmm.c文件中的代码进行完善
修改的几处代码如下：

函数best_fit_init_memmap内：
```
 /*LAB2 EXERCISE 2:2111673*/
 // 清空当前页框的标志和属性信息，并将页框的引用计数设置为0
 p->flags = p->property = 0; // 清空标志和属性信息
 set_page_ref(p, 0);// 将引用计数设置为0

 /*LAB2 EXERCISE 2: 2111673*/
 // 编写代码
 // 1、当base < page时，找到第一个大于base的页，将base插入到它前面，并退出循环
 // 2、当list_next(le) == &free_list时，若已经到达链表结尾，将base插入到链表尾部
  
 // 插入base到链表中
 if (base < page) {
 list_add_before(le, &(base->page_link));//插入到page前
 break;
 } else  if (list_next(le) == &free_list) {
 list_add(le, &(base->page_link));//插入到链表尾
 }
```
函数best_fit_alloc_pages内：
```
 /*LAB2 EXERCISE 2: 2111673*/
 // 下面的代码是first-fit的部分代码，请修改下面的代码改为best-fit
 // 遍历空闲链表，查找满足需求的空闲页框
 // 如果找到满足需求的页面，记录该页面以及当前找到的最小连续空闲页框数量
  
 // 遍历空闲链表，查找满足需求的空闲页框中最小的一个，即属性大于等于 n 且最接  近 n 的页面

 while ((le = list_next(le)) != &free_list) {//le 不等于链表头
 struct  Page *p = le2page(le, page_link);//将链表节点 le 转换为对应的 Page 结构体p
 if (p->property >= n && p->property - n < min_size) {//确保页面 p 大于或等于n 且p 的大小减去 n 后的大小小于 min_size
 page = p;//指针 page 指向当前找到的页面 p
 min_size = p->property-n ;//更新 min_size 为 p 页面的值
        }
  
    }
 // 如果找到了满足需求的页面
 if (page != NULL) {
 list_entry_t* prev = list_prev(&(page->page_link));// 获取 page 页面的前一个页面的链表节点
 list_del(&(page->page_link));//从可用页面链表中删除 page 页面
 if (page->property > n) {//如果 page 的属性大于要分配的页面数量
 struct  Page *p = page + n;//计算出剩余部分的页面地址
 p->property = page->property - n;//设置剩余部分的页面属性
 SetPageProperty(p);// 将剩余部分的页面标记为"Property"
 list_add(prev, &(p->page_link));//将剩余部分的页面添加到可用页面链表中
        }
 nr_free -= n;//减少系统中的空闲页面的数量
 ClearPageProperty(page);//将已分配的页面标记的"Property"清除
    }
```
函数best_fit_free_pages内：
```
 /*LAB2 EXERCISE 2: 2111673*/
 // 编写代码
 // 具体来说就是设置当前页块的属性为释放的页块数、并将当前页块标记为已分配状态、最后增加nr_free的值
  
 base->property = n;
 SetPageProperty(base);
 nr_free += n;
  
 if (list_empty(&free_list)) {//检查链表 free_list 是否为空。如果为空，将 base 页面添加到链表的开头
 list_add(&free_list, &(base->page_link));
 } else {//不为空，进入一个循环，查找适当的位置将 base 页面插入到链表中
 list_entry_t* le = &free_list;
 while ((le = list_next(le)) != &free_list) {
 struct  Page* page = le2page(le, page_link);
 if (base < page) {
 list_add_before(le, &(base->page_link));//插入到page前
 break;
 } else  if (list_next(le) == &free_list) {
 list_add(le, &(base->page_link));//插入到链表尾
 break;
        }
    }
 }

 /*LAB2 EXERCISE 2: 2111673*/
 // 编写代码
 // 1、判断前面的空闲页块是否与当前页块是连续的，如果是连续的，则将当前页块合并到前面的空闲页块中
 // 2、首先更新前一个空闲页块的大小，加上当前页块的大小
 // 3、清除当前页块的属性标记，表示不再是空闲页块
 // 4、从链表中删除当前页块
 // 5、将指针指向前一个空闲页块，以便继续检查合并后的连续空闲页块
 if (p + p->property == base) { // 1. 判断前面的空闲页块是否与当前页块是连续的，如果连续就合并
 p->property += base->property; // 2. 更新前一个空闲页块的大小，加上当前页块的大小
 ClearPageProperty(base); // 3. 清除当前页块的属性标记
 list_del(&(base->page_link));// 4. 从链表中删除当前页块          
 base = p; // 5. 将指针指向前一个空闲页块
 }
```

### 2.全部代码及阐述：
```
#include  <pmm.h>
#include  <list.h>
#include  <string.h>
#include  <best_fit_pmm.h>
#include  <stdio.h>
  
free_area_t  free_area;
  
#define  free_list (free_area.free_list)
#define  nr_free (free_area.nr_free)
  
static  void
best_fit_init(void) {
 list_init(&free_list);
 nr_free = 0;//nr_free可以理解为在这里可以使用的一个全局变量，记录可用的物理页面数
}
  
static  void
best_fit_init_memmap(struct  Page *base, size_t  n) {
 assert(n > 0);//检查n是否大于0，保证初始化页面的数量是有效的
 struct  Page *p = base;
 for (; p != base + n; p ++) {
 assert(PageReserved(p));//检查p的标志位，检查页面是否被标记为“保留”
        /*LAB2 EXERCISE 2:2111673*/
 // 清空当前页框的标志和属性信息，并将页框的引用计数设置为0
 p->flags = p->property = 0; // 清空标志和属性信息
 set_page_ref(p, 0);// 将引用计数设置为0
    }
 base->property = n;
 SetPageProperty(base);//将该页面标记为"Property"
 nr_free += n;//可用的空闲页面数量增加了n
 if (list_empty(&free_list)) {// 如果空闲链表为空，直接将base插入
 list_add(&free_list, &(base->page_link));
} else {
 list_entry_t* le = &free_list;
 while ((le = list_next(le)) != &free_list) {
 struct  Page* page = le2page(le, page_link);
             /*LAB2 EXERCISE 2: 2111673*/
 // 编写代码
 // 1、当base < page时，找到第一个大于base的页，将base插入到它前面，并退出循环
 // 2、当list_next(le) == &free_list时，若已经到达链表结尾，将base插入到链表尾部
  
 // 插入base到链表中
if (base < page) {
 list_add_before(le, &(base->page_link));
 break;
} else  if (list_next(le) == &free_list) {
 list_add(le, &(base->page_link));
            }
        }
    }
}
  
static  struct  Page *
best_fit_alloc_pages(size_t  n) {//用于从一个可用页面的链表中分配一组页面
 assert(n > 0);
 if (n > nr_free) {//如果要分配的n已经比总空闲页面数大，则退出
 return  NULL;
    }
 struct  Page *page = NULL;//用于存储找到的可用页面
 list_entry_t *le = &free_list;//指向表示可用页面链表头的指针 le
 size_t  min_size = nr_free + 1;
     /*LAB2 EXERCISE 2: 2111673*/
 // 下面的代码是first-fit的部分代码，请修改下面的代码改为best-fit
 // 遍历空闲链表，查找满足需求的空闲页框
 // 如果找到满足需求的页面，记录该页面以及当前找到的最小连续空闲页框数量
  
 // 遍历空闲链表，查找满足需求的空闲页框中最小的一个，即属性大于等于 n 且最接近 n 的页面

 while ((le = list_next(le)) != &free_list) {//le 不等于链表头
 struct  Page *p = le2page(le, page_link);//将链表节点 le 转换为对应的 Page 结构体p
 if (p->property >= n && p->property - n < min_size) {//确保页面 p 大于或等于n 且p 的大小减去 n 后的大小小于 min_size
 page = p;//指针 page 指向当前找到的页面 p
 min_size = p->property-n ;//更新 min_size 为 空闲页面最小的值
        }
  
    }

 // 如果找到了满足需求的页面
 if (page != NULL) {
 list_entry_t* prev = list_prev(&(page->page_link));// 获取 page 页面的前一个页面的链表节点
 list_del(&(page->page_link));//从可用页面链表中删除 page 页面
 if (page->property > n) {//如果 page 的属性大于要分配的页面数量
 struct  Page *p = page + n;//计算出剩余部分的页面地址
 p->property = page->property - n;//设置剩余部分的页面属性
 SetPageProperty(p);// 将剩余部分的页面标记为"Property"
 list_add(prev, &(p->page_link));//将剩余部分的页面添加到可用页面链表中
        }
 nr_free -= n;//减少系统中的空闲页面的数量
 ClearPageProperty(page);//将已分配的页面标记的"Property"清除
    }

 return  page;
}
  
static  void
best_fit_free_pages(struct  Page *base, size_t  n) {
 assert(n > 0);
 struct  Page *p = base;
 for (; p != base + n; p ++) {
 assert(!PageReserved(p) && !PageProperty(p));//确保当前页面 p 不是保留页面并且不是属性页面
 p->flags = 0;//将当前页块的属性标志清零
 set_page_ref(p, 0);//将引用计数设置为0
    }
  
    /*LAB2 EXERCISE 2: 2111673*/
 // 编写代码
 // 具体来说就是设置当前页块的属性为释放的页块数、并将当前页块标记为已分配状态、最后增加nr_free的值
  
 base->property = n;
 SetPageProperty(base);
 nr_free += n;
  
 if (list_empty(&free_list)) {//检查链表 free_list 是否为空。如果为空，将 base 页面添加到链表的开头
 list_add(&free_list, &(base->page_link));
} else {//不为空，进入一个循环，查找适当的位置将 base 页面插入到链表中
 list_entry_t* le = &free_list;
 while ((le = list_next(le)) != &free_list) {
 struct  Page* page = le2page(le, page_link);
 if (base < page) {
 list_add_before(le, &(base->page_link));
 break;
} else  if (list_next(le) == &free_list) {
 list_add(le, &(base->page_link));
 break;
            }
        }
    }
  
 list_entry_t* le = list_prev(&(base->page_link));//获取 base 页面的前一个页面元素的指针
 if (le != &free_list) {
 p = le2page(le, page_link);
        /*LAB2 EXERCISE 2: 2111673*/
// 编写代码

 // 1、判断前面的空闲页块是否与当前页块是连续的，如果是连续的，则将当前页块合并到前面的空闲页块中
 // 2、首先更新前一个空闲页块的大小，加上当前页块的大小
 // 3、清除当前页块的属性标记，表示不再是空闲页块
 // 4、从链表中删除当前页块
 // 5、将指针指向前一个空闲页块，以便继续检查合并后的连续空闲页块
 if (p + p->property == base) { // 1. 判断前面的空闲页块是否与当前页块是连续的，如果连续就合并
 p->property += base->property; // 2. 更新前一个空闲页块的大小，加上当前页块的大小
 ClearPageProperty(base); // 3. 清除当前页块的属性标记
 list_del(&(base->page_link));// 4. 从链表中删除当前页块          
 base = p; // 5. 将指针指向前一个空闲页块
        }
}
  
  
 le = list_next(&(base->page_link));
 if (le != &free_list) {
 p = le2page(le, page_link);
 if (base + base->property == p) {//检查 base 页面和后一个页面 p 是否相邻
 base->property += p->property;
 ClearPageProperty(p);
 list_del(&(p->page_link));
        }
    }
}
  
static  size_t
best_fit_nr_free_pages(void) {
 return  nr_free;
}

```
### 3.实验结果
`make`
![](https://markdown.liuchengtu.com/work/uploads/upload_a70d64dafbd431cfbf1cc99453b0bce7.png)

` make qemu`
![](https://markdown.liuchengtu.com/work/uploads/upload_e2eedf769744a112aece5bbbda5ce8f1.png)
![](https://markdown.liuchengtu.com/work/uploads/upload_02a224689135485f6ca6f9b7b186dfa9.png)

` make grade`
![](https://markdown.liuchengtu.com/work/uploads/upload_51d0f2d07ac9cf599afe1a0e149f361b.png)

### 4.Best-Fit 算法进一步的改进空间
1.**碎片化问题处理**:
 - **合并邻近的空闲块**: 在分配和释放内存时，尝试合并相邻的空闲块，以减少碎片化问题。
 - **拆分大块**: 如果分配的空闲块比请求的大，可以考虑将多余的部分拆分成更小的块，以提高内存利用率。
  
2.**数据结构优化**:
  - **更高效的数据结构**: 考虑使用更高效的数据结构，如二叉树来加速空闲内存块的搜索和分配过程。
 
3.**空闲块管理策略**:
  - **分级管理**: 将内存块按大小进行分级管理，以便更快地找到合适大小的空闲块。
  
4.**分配策略优化**:
  - **首次适应和循环首次适应**: 考虑在特定场景下使用First_fit算法，以避免频繁的内存移动。

 
5.**自动内存释放**:
  - **实现内存释放机制**: 考虑实现自动释放不再使用的内存块，减少碎片化

## 扩展练习 Challenge3：硬件的可用物理内存范围的获取方法（思考题）
如果 OS 无法提前知道当前硬件的可用物理内存范围，请问你有何办法让 OS 获取可用物理内存范围？

1.操作系统可以利用计算机的BIOS或UEFI接口来获取硬件信息，包括物理内存的大小和布局。这些接口提供了系统信息的访问权限，包括内存映射表，允许操作系统确定可用内存的位置和大小。通过调用适当的BIOS/UEFI功能或访问相关数据结构，操作系统就可以获取内存信息。
 - **中断 `0x15` 子功能 `0xe820`**： 这个子功能能够获取系统的内存布局，由于系统内存各部分的类型属性不同，BIOS就按照类型属性来划分这片系统内存，所以这种查询呈迭代式，每次BIOS只返回一种类型的内存信息，直到将所有内存类型返回完毕。
 - **中断 `0x15` 子功能 `0xe801`**：这个方法虽然获取内存的方式较为简单，但是功能不强大，只能识别最大4GB内存
 - **中断 `0x15` 子功能 `0x88`**：这个方法最简单，得到的结果也最简单，简单到只能识别最大64MB的内存
 
2.物理内存映射：可以通过创建一个物理内存映射来访问和探测物理内存的范围。这通常涉及到使用特定的内核模式代码来访问系统的物理内存映射表。通过扫描这个映射表，操作系统可以确定可用物理内存的范围和大小。

3.使用一些管理工具，可以用于查看和管理系统的硬件信息，包括物理内存。这些工具通常提供了可视化的界面，可以用于查询可用的物理内存范围，再给操作系统进行分配


# lab3
## 练习1：理解基于FIFO的页面替换算法（思考题）
描述FIFO页面置换算法下，一个页面从被换入到被换出的过程中，会经过代码里哪些函数/宏的处理（或者说，需要调用哪些函数/宏），并用简单的一两句话描述每个函数在过程中做了什么？（为了方便同学们完成练习，所以实际上我们的项目代码和实验指导的还是略有不同，例如我们将FIFO页面置换算法头文件的大部分代码放在了`kern/mm/swap_fifo.c`文件中，这点请同学们注意）

- 至少正确指出10个不同的函数分别做了什么？如果少于10个将酌情给分。我们认为只要函数原型不同，就算两个不同的函数。要求指出对执行过程有实际影响,删去后会导致输出结果不同的函数（例如assert）而不是cprintf这样的函数。如果你选择的函数不能完整地体现”从换入到换出“的过程，比如10个函数都是页面换入的时候调用的，或者解释功能的时候只解释了这10个函数在页面换入时的功能，那么也会扣除一定的分数

FIFO(First in, First out)页面置换算法，就是把所有页面排在一个队列里，每次换入页面的时候，把队列里最靠前（最早被换入）的页面置换出去。

我们目前的框架支持消极的替换策略，即只有当试图得到空闲页时，发现当前没有空闲的物理页可供分配，这时才开始查找“不常用”页面，并把一个或多个这样的页换出到硬盘上。

在FIFO页面置换算法下，一个页面从被换入到被换出的过程中，需要调用以下的函数/宏：

1. `alloc_pages`（`kern/mm/pmm.c`）:
用于分配一个物理页面。在FIFO算法中，这个函数用于分配一个新的物理页面，以便将其换入内存。当我们试图得到空闲页且没有空闲的物理页时，调用 `swap_out` 函数将一些页面交换到磁盘上以释放内存。
2. `swap_in`（`kern/mm/swap.c`）：
将一个页面从磁盘中换入到内存中。在FIFO算法中，这个函数用于将被置换出的页面从磁盘中换入到内存中。在这个过程中需要找到一个物理页面和对应的页表项，并将数据从硬盘读取到内存中。
3. `swap_out`（`kern/mm/swap.c`）：
将一个页面从内存换出到磁盘中。在FIFO算法中，这个函数用于将被置换出的页面换出到磁盘中的交换分区，释放内存空间以便为新页面腾出空间。这个过程需要找到写入磁盘中的页面并写入磁盘，最后更新TLB。
4. `swap_init()`（`kern/mm/swap.c`）：
初始化交换系统，包括调用 `swapfs_init` 函数初始化交换文件系统、检查最大交换偏移量是否在合理范围内以及初始化交换管理器等。
5. `swap_init_mm`（`kern/mm/swap.c`）：
初始化交换系统的内存管理器，将 `mm` 参数传递给交换管理器的 `init_mm` 函数。
6. `swap_tick_event`（`kern/mm/swap.c`）：
处理时钟中断事件，将 `mm` 参数传递给交换管理器的`tick_event` 函数。
7. `swap_map_swappable`（`kern/mm/swap.c`）：
将一个页面映射为可交换的页面，将 `mm`、`addr`、`page` 和 `swap_in` 参数传递给交换管理器的 `map_swappable` 函数。
8. `swap_set_unswappable`（`kern/mm/swap.c`）：
将一个页面设置为不可交换的页面，将 `mm` 和 `addr` 参数传递给交换管理器的 `set_unswappable` 函数。
9. `_fifo_map_swappable`（`kern/mm/swap_fifo.c`）：
将一个页面映射为可交换的页面，并将该页面添加到先进先出（FIFO）页面置换算法的页面队列中。在获取链表头指针和链表节点指针后，将节点指针添加到链表的末尾。
10. `_fifo_swap_out_victim`（`kern/mm/swap_fifo.c`）:
选择一个页面作为牺牲品，将其交换到磁盘上，并将该页面的信息存储在 `ptr_page` 指针中。从页面队列的开头（即最早到达的页面）中选择一个页面作为牺牲品，并将其从队列中删除。如果队列为空，则将 `ptr_page` 指针设置为 NULL。
11. `page_insert`（`kern/mm/pmm.c`）:
将一个物理页面映射到一个虚拟地址上，并设置相应的访问权限。
函数首先调用 `get_pte` 函数获取虚拟地址 `la` 对应的页表项指针 `ptep`。将页表项 `ptep` 设置为要映射的物理页面，并设置相应的访问权限。然后，调用 `tlb_invalidate` 函数使 TLB 缓存失效，以确保新的映射关系能够立即生效。
12. `tlb_invalidate`（`kern/mm/pmm.c`）:
当页表映射关系改变时，使 TLB 缓存失效，以确保新的页表映射关系能够立即生效。由于 TLB 缓存是硬件实现的，无法直接访问，因此需要调用 `flush_tlb` 函数来刷新 TLB 缓存。
13. `assert` ：
C语言中的一个宏定义，用于在程序中进行调试和错误处理。它的作用是判断一个条件是否为真，如果为假，则输出错误信息并终止程序运行。

## 练习2：深入理解不同分页模式的工作原理（思考题）

get_pte()函数（位于`kern/mm/pmm.c`）用于在页表中查找或创建页表项，从而实现对指定线性地址对应的物理页的访问和映射操作。这在操作系统中的分页机制下，是实现虚拟内存与物理内存之间映射关系非常重要的内容。

### 1.get_pte()函数中有两段形式类似的代码， 结合sv32，sv39，sv48的异同，解释这两段代码为什么如此相像。

首先进行sv32、sv39和sv48的了解：
（1）sv32：使用RISC-V的32位版本，支持32位的整数寄存器和操作，有一个双层页表树，支持4个MiB超级页面。其支持基本的虚拟内存管理，包括分页机制，允许计算机在虚拟内存上运行多个应用程序。
（2）sv39：是RISC-V64位架构的一个变种，支持64位整数寄存器，对应三级页表。其使用39位的虚拟地址，允许计算机管理更大的物理内存空间。
（3）sv48：是RISC-V64位架构的一个变种，类似于 "SV39"，支持64位整数寄存器，对应四级页表。其使用48位的虚拟地址，允许更大的虚拟地址空间，提供更大的物理内存寻址范围。

故sv32、sv39和sv48的主要区别为：
（1）位宽差异：sv32是一个32位的RISC-V架构，而sv39和sv48是64位架构的变种，其中sv39使用39位虚拟地址，而sv48使用48位虚拟地址。
（2）虚拟内存扩展：sv32支持基本的虚拟内存，而sv39和sv48扩展了虚拟内存系统，以支持更大的虚拟地址空间，允许管理更大的物理内存。

get_pte()函数代码如下所示：
```
pte_t  *get_pte(pde_t  *pgdir, uintptr_t  la, bool  create) {
 //下面的代码：尝试访问一级页表项（pdep1），这是在一级页表中查找的。若一级页表项无效（PTE_V标志位未设置），则尝试分配一个新的物理页（struct Page *page），并将其清零。这一级的页表项存储的是二级页表的基地址，因此需要创建一个新的二级页表。
 pde_t  *pdep1  =  &pgdir[PDX1(la)];
 if (!(*pdep1  &  PTE_V)) {
     struct  Page  *page;
     if (!create  || (page  =  alloc_page()) ==  NULL) {
         return  NULL;
     }
     set_page_ref(page, 1);
     uintptr_t  pa  =  page2pa(page);
     memset(KADDR(pa), 0, PGSIZE);
     *pdep1  =  pte_create(page2ppn(page), PTE_U  |  PTE_V);
 }
 //下面的代码：访问二级页表项（pdep0），这是在二级页表中查找的。若二级页表项无效，分配一个新的物理页并清零。这一级的页表项最终会指向实际的物理页帧。
 pde_t  *pdep0  =  &((pde_t  *)KADDR(PDE_ADDR(*pdep1)))[PDX0(la)];
 if (!(*pdep0  &  PTE_V)) {
     struct  Page  *page;
     if (!create  || (page  =  alloc_page()) ==  NULL) {
         return  NULL;
     }
     set_page_ref(page, 1);
     uintptr_t  pa  =  page2pa(page);
     memset(KADDR(pa), 0, PGSIZE);
     *pdep0  =  pte_create(page2ppn(page), PTE_U  |  PTE_V);
 }
 //返回指向相应页表项的内核虚拟地址。
 return  &((pte_t  *)KADDR(PDE_ADDR(*pdep0)))[PTX(la)];
}
```

可以知道这个函数是用于管理虚拟内存和页表的，具体为获取或创建一个页表项并返回该页表的内核虚拟地址，以正确映射线性地址到物理地址，这是操作系统内核的重要功能之一。

（1）相似性：这两段代码十分相似，因为其都执行了以下操作： 
  - 根据`PTE_V`标志位检查页表项是否有效。
  - 若无效，则通过 `alloc_page()` 函数分配一个新的物理页框，并更新页表项，使其指向新的物理页框。
  - 最后返回相应的页表项。
  
（2）原因： 这个函数中的代码是基于RISC-V架构的页表模型编写的，同时考虑了不同的页表级别，即sv32、sv39和sv48。
我们已经了解到sv32、sv39和sv48是分别通过两级页表、三级页表和四级页表来进行分层组织的。虽然他们在内部结构上有些许差异，但这段代码的逻辑是通用的，可以应用于不同的模型。无论是sv32、sv39还是sv48，它们都有一级页表和二级页表。故不同级别的页表具有相似的结构和操作，因此代码是相似的。
故综上所述，这两段代码的相似性主要是因为它们都涉及页表管理，并且不同的页表模型在结构和操作上有一定的共性，因此代码中的通用逻辑在不同模型之间重复使用，以提高代码的可维护性和可移植性。

### 2.目前get_pte()函数将页表项的查找和页表项的分配合并在一个函数里，你认为这种写法好吗？有没有必要把两个功能拆开？

本小组认为这个写法是可以的，没有必要将两个功能拆开。

将页表项的查找和分配合并在一个函数中有一些优点和缺点，但其写法具体是否好取决于上下文和设计的考虑因素。

优点：
（1）简化接口： 合并查找和分配操作可以简化函数的接口。如此在需要调用的时候就只需调用一个函数，而不需要在多个函数之间来回切换。这样可以让代码更容易被使用，减少了外部调用方的工作量。
（2）原子性： 合并查找和分配操作可以确保这两个步骤之间是原子的，从而避免了竞态条件。这可以增加代码的稳定性和可靠性。
（3）性能优化： 合并起来的函数可以避免不必要的操作，如不用多次访问相同的页表项，故能提高性能。

缺点：
（1）功能不明确： 合并的函数使其有两个功能，故不能够完全明确其功能。在良好的软件工程实践中，函数应该专注于单一任务。将查找和分配合并在一起可能会导致函数变得复杂，难以理解和维护。
（2）可读性和可维护性： 若将查找和分配拆分成两个单独的函数，代码的可读性和可维护性可能会提高，使得代码更容易理解和调试。
（3）复用性： 拆分成两个函数后，查找和分配操作可以在不同的上下文中更容易地被复用。而不像是在合并到一起时，复用会受到限制。

故判断将查找和分配合并在一个函数中是否好坏取决于项目的需求和设计。当性能和原子性是关键因素时，这种合并是合理的。但在一些其他情况下，拆分这两个功能可能会更有益于代码的可读性和可维护性。

## 练习3：给未被映射的地址映射上物理页（需要编程）
补充完成do_pgfault（mm/vmm.c）函数，给未被映射的地址映射上物理页。设置访问权限 的时候需要参考页面所在 VMA 的权限，同时需要注意映射物理页时需要操作内存控制 结构所指定的页表，而不是内核的页表。

请在实验报告中简要说明你的设计实现过程。请回答如下问题：
- 请描述页目录项（Page Directory Entry）和页表项（Page Table Entry）中组成部分对ucore实现页替换算法的潜在用处。
- 如果ucore的缺页服务例程在执行过程中访问内存，出现了页访问异常，请问硬件要做哪些事情？
  - 数据结构Page的全局变量（其实是一个数组）的每一项与页表中的页目录项和页表项有无对应关系？如果有，其对应关系是啥？

### 1.修改代码
给未被映射的地址映射上物理页，对vmm.c文件中的代码修改如下：
```
if (*ptep == 0) {
 if (pgdir_alloc_page(mm->pgdir, addr, perm) == NULL) {
 cprintf("pgdir_alloc_page in do_pgfault failed\n");
 goto  failed;
        }
} else {
        /*LAB3 EXERCISE 3: 2111673
        * 请你根据以下信息提示，补充函数
        * 现在我们认为pte是一个交换条目，那我们应该从磁盘加载数据并放到带有phy addr的页面，
        * 并将phy addr与逻辑addr映射，触发交换管理器记录该页面的访问情况
        *
        *  一些有用的宏和定义，可能会对你接下来代码的编写产生帮助(显然是有帮助的)
        *  宏或函数:
        *    swap_in(mm, addr, &page) : 分配一个内存页，然后根据
        *    PTE中的swap条目的addr，找到磁盘页的地址，将磁盘页的内容读入这个内存页
        *    page_insert ： 建立一个Page的phy addr与线性addr la的映射
        *    swap_map_swappable ： 设置页面可交换
        */
 if (swap_init_ok) {
 struct  Page *page = NULL;
 // 你要编写的内容在这里，请基于上文说明以及下文的英文注释完成代码编写
 //(1) 根据 mm 和 addr，尝试将正确的磁盘页内容加载到内存页中
 if ((ret = swap_in(mm, addr, &page)) != 0) { // 加载失败
 cprintf("swap page in do_pgfault failed\n");
 goto  failed;
            }
 //(2) 根据 mm、addr 和 page，设置物理地址（phy addr）与逻辑地址（logical addr）之间的映射
 if (page_insert(mm, page, addr, perm) != 0) { // 插入失败
 cprintf("page_insert failed\n");
 goto  failed;
            }
 //(3) 标记页面为可交换
 if (swap_map_swappable(mm, addr, page, 1) != 0) {//标记失败
 cprintf("swap_map_swappable failed\n");
goto  failed;
            }
 // 交换成功，则建立物理地址<--->虚拟地址映射，并将页设置为可交换的
 page_insert(mm->pgdir,page,addr,perm);
 swap_map_swappable(mm,addr,page,1);          
 page->pra_vaddr = addr;
} else {// 没开启交换功能
 cprintf("no swap_init_ok but ptep is %x, failed\n", *ptep);
 goto  failed;
        }
   }
```
### 2.描述页目录项和页表项中组成部分对ucore实现页替换算法的潜在用处
**页目录项的组成**
  -  前20位表示该PDE对应的页表起始位置
  -  第9-11位保留给OS使用
  -  第8位可忽略
  -  第7位用于设置Page大小，0表示4KB
  -  第6位为0
  -  第5位表示该页是否被引用过
  -  第4位表示是否需要进行缓存
  -  第3位表示CPU是否可直接写回内存
  -  第2位表示该页是否可被任何特权级访问
  -  第1位表示是否允许读写
  -  第0位为该PDE的存在位
    
**页表项的组成**
- 前20位表示该PTE指向的物理页的物理地址
- 第9-11位保留给OS使用
- 第8位表示在 CR3 寄存器更新时无需刷新 TLB 中关于该页的地址
- 第7位恒为0
- 第6位表示该页是否被写过
- 第5位表示是否被引用过
- 第4位表示是否需要进行缓存
- 第0-3位与页目录项的0-3位相同

1. **标志位**：页表项中通常包括一些标志位，如存在位、读/写位、用户模式位，访问位和修改位等。这些标志位可以用于控制页面的访问权限，跟踪页面的访问和修改历史等，对页替换算法的实现很有用。如果页面权限和操作权限冲突时，操作系统可以在访问冲突时拒绝写入，并触发页替换策略来释放可写入的页面。
标志位定义在mm/mmu.h：
![](https://markdown.liuchengtu.com/work/uploads/upload_f9472cf001658686e11d86350a90ad4f.png)
  
2. **物理地址和虚拟地址映射**：页目录项和页表项包括虚拟地址到物理地址的映射。实现了操作系统将虚拟地址转换为物理地址的功能，从而正确加载和管理页面。在页替换算法中，这些映射关系用于确定哪个物理页面被替换或释放。

页目录项主要是用于找到页表项，在页访问异常处理时，找到页表项后可以判断虚拟地址对应的物理页是否存在，如果不存在需要建立虚拟地址到物理页的映射，存在则说明该页被换出，需要换入。而页表项在页未被换出时，一些位可以用于页替换算法中页的选择，如访问位和修改位在时钟替换算法中会用到，如果页被换出，页表项可以用于保存页被换入硬盘的扇区位置，以便换入。

### 3.如果ucore的缺页服务例程在执行过程中访问内存，出现了页访问异常，请问硬件要做哪些事情？

在这种情况下发生页访问异常和其他情况下发生页访问异常的处理是相同的。硬件首先保存上下文信息，随后跳转到内核的缺页服务例程（Page Fault Handler），进行页面替换等操作，随后硬件恢复上下文信息，继续执行代码。

### 4.数据结构Page的全局变量（其实是一个数组）的每一项与页表中的页目录项和页表项有无对应关系？如果有，其对应关系是啥？
page结构体如下所示：
```
struct  Page {
 int  ref; // 页面的引用计数器
 uint64_t  flags; // 标志位
 unsigned  int  property; // 表示空闲块的数量
 list_entry_t  page_link; // 是一个链表节点，维护了空闲页面之间的连接关系。
 list_entry_t  pra_page_link; // 是一个链表节点，用于维护页面替换算法中的页面顺序。
 uintptr_t  pra_vaddr; // 表示页面在虚拟地址空间中的地址
};
```
`Page`数据结构是一个描述物理内存页面的结构体，包含了页面的状态、页号、页面内容等信息。页表项中的指针或索引可以与`Page`数据结构建立对应关系。这样，操作系统可以通过页表项找到对应的`Page`数据结构，以获取页面的状态信息。

## 练习4：请在我们给出的框架上填写代码，实现 Clock页替换算法（mm/swap_clock.c）

请在实验报告中简要说明你的设计实现过程。请回答如下问题：

- 比较Clock页替换算法和FIFO算法的不同。

### 1.修改代码
```
static  int
_clock_init_mm(struct  mm_struct *mm)
{    
     /*LAB3 EXERCISE 4: 2111673*/
// 初始化pra_list_head为空链表
list_init(&pra_list_head);
  
// 初始化当前指针curr_ptr指向pra_list_head，表示当前页面替换位置为链表头
curr_ptr = &pra_list_head;
  
// 将mm的私有成员指针指向pra_list_head，用于后续的页面替换算法操作
mm->sm_priv = &pra_list_head;
//cprintf(" mm->sm_priv %x in fifo_init_mm\n",mm->sm_priv);

return  0;
}
```

```
static  int
_clock_map_swappable(struct  mm_struct *mm, uintptr_t  addr, struct  Page *page, int  swap_in)
{

 list_entry_t *entry=&(page->pra_page_link);
 assert(entry != NULL && curr_ptr != NULL);
 //record the page access situlation
    /*LAB3 EXERCISE 4: 2111673*/
 // link the most recent arrival page at the back of the pra_list_head qeueue.
// 获取链表头
 curr_ptr=(list_entry_t*) mm->sm_priv;
 // 将页面page插入到页面链表pra_list_head的末尾
 list_add(curr_ptr, entry);
 // 将页面的visit标志置为1，表示该页面已被访问
 struct  Page *ptr = le2page(entry, pra_page_link);
 pte_t *ptep = get_pte(mm  -> pgdir, ptr  -> pra_vaddr, 0);
    *ptep=*ptep & (~PTE_A);
  
 return  0;
}    
```

```
static  int
_clock_swap_out_victim(struct  mm_struct *mm, struct  Page ** ptr_page, int  in_tick)
{
list_entry_t *head=(list_entry_t*) mm->sm_priv;//将head指向链表头
assert(head != NULL);
assert(in_tick==0);
    /* Select the victim */
 //  //(1)  unlink the  earliest arrival page in front of pra_list_head qeueue
 //  //(2)  set the addr of addr of this page to ptr_page
  
    /*LAB3 EXERCISE 4: 2111673*/
 // 编写代码
 // 遍历页面链表pra_list_head，查找最早未被访问的页面
struct  Page *victim; //定义一个准备换出的页面
for(int  i=0;i<2;i++){//两次循环，第一次寻找访问位为0且修改位为0的，没找到就将所有的页面的访问位置为0，
//第二次循环就把访问位为0且修改位为0的第一个页面换出，若依旧没有，就最后换出链表尾的页面，相当于换出最早插入的页面
 curr_ptr=list_next(head);//将指针指向头结点的下一个，表示第一个页面的指针
 assert(curr_ptr!=head);
 while(curr_ptr!=head){
 victim=le2page(curr_ptr,pra_page_link);//将链表指针转换为页面指针
 pte_t *ptep=get_pte(mm->pgdir,victim->pra_vaddr,0);//根据给定的虚拟地址（pra_vaddr）在给定的页目录（mm->pgdir）中查找对应的页表项，并返回指向该页表项的指针
 //前两次循环
 if(!(*ptep & PTE_A) && !(*ptep & PTE_D)){ // 如果当前页面未被访问，则将该页面从页面链表中删除，并将该页面指针赋值给ptr_page作为换出页面
 assert(victim!=NULL);

                *ptr_page=victim;// 将该页面从页面链表中删除，并将该页面指针赋值给ptr_page作为换出页面
list_del(curr_ptr);
 return  0;
            }
 if(*ptep & PTE_A) {// 如果当前页面已被访问，则将visited标志置为0，表示该页面已被重新访问
                *ptep=*ptep & (~PTE_A);//置为0
 cprintf("curr_ptr %p\n",curr_ptr);//输出curr_ptr
            }
 //修改了标志位，更新TLB
 tlb_invalidate(mm->pgdir, victim->pra_vaddr);
 curr_ptr=list_next(curr_ptr);//将指针后移，继续遍历链表
        }
     }
//最后直接进行选择,考虑到换入时插入链表的顺序，仍然选择链尾的页
curr_ptr=head->prev;
victim=le2page(curr_ptr,pra_page_link);        
assert(victim!=NULL);
list_del(curr_ptr);
     *ptr_page=victim;
return  0;
}
```

### 2.比较Clock页替换算法和FIFO算法的不同
Clock（时钟）和FIFO（先进先出）算法的区别如下所示：
1. **置换策略**：
  - **FIFO算法**：它选择最早进入内存的页面进行置换。即最早进入内存的页面将最早被淘汰，而最后进入内存的页面将最后被淘汰。
  - **Clock算法**：通过模拟环形链表的方式，保持一个类似时钟的数据结构。它基于一种“访问位和修改位”结合的方式来确定哪些页面被置换。它避免了FIFO可能出现的顺序引起的不合理置换问题。
2. **数据结构**：
  - **FIFO算法**：只需维护一个队列，将页面按照它们进入内存的先后顺序排列。当需要置换页面时，直接选择队列中最早进入的页面进行置换。
  - **Clock算法**：需要维护一个环形链表或类似的数据结构，以模拟一个时钟。该时钟用于确定哪些页面可以被置换，避免了FIFO中不合理的置换问题。
3. **性能影响**：
  - **FIFO算法**：增加物理页面数可能会导致缺页率升高的异常情况。
  - **Clock算法**：能更好地应对异常，它综合考虑了页面的占用情况，尽可能选择长时间未被访问的页面进行置换，从而提高性能。

### 3.实验结果
`make`
![](https://markdown.liuchengtu.com/work/uploads/upload_5590364a808717935f5157bc3c0d6b57.png)

`make qemu`
![](https://markdown.liuchengtu.com/work/uploads/upload_8e710391aac0e425af1c37d834c60e8c.png)
![](https://markdown.liuchengtu.com/work/uploads/upload_9236c8692a8369f071aa25eec2fc05d6.png)
![](https://markdown.liuchengtu.com/work/uploads/upload_4f53958264ee49b4da5076f281560a5d.png)

`make grade`
![](https://markdown.liuchengtu.com/work/uploads/upload_5244fb38d6c36571df0ac238b9a9369c.png)

## 练习5：阅读代码和实现手册，理解页表映射方式相关知识（思考题）
如果我们采用”一个大页“ 的页表映射方式，相比分级页表，有什么好处、优势，有什么坏处、风险？

采用“一个大页”的页表映射方式相对于分级页表有一些优势和劣势，这些取决于具体的应用场景和需求。

优势：
1. 较小的页表：大页可以减小页表的大小，因为一个大页可以映射更多的虚拟地址空间。这有助于减少页表的内存占用和管理开销，尤其是在具有大内存需求的系统中。
2. 降低TLB缓存失效的概率：在一个大页中，相同的页表条目可以映射更多的虚拟地址，这意味着只有较少的页表条目需要在TLB中缓存。这可以降低TLB缓存失效的概率，提高内存访问性能。
3. 更快的地址转换：因为需要查找的页表级别较少，硬件可以更快地定位到正确的页表条目，所以地址转换会更快。
4. 适用于特定工作负载：大页通常适用于具有连续内存访问模式的工作负载，如科学计算或多媒体应用。在这些情况下，大页可以显著提高性能。

劣势：
1. 内存碎片：大页可能导致内存碎片问题，因为操作系统需要分配连续的物理内存来满足大页的需求。这可能会导致内存资源浪费和不规则的内存分配。
2. 不适用于小型数据结构：大页不适用于小型数据结构或散乱的内存访问模式，因为这可能会浪费内存或导致不必要的数据移动。
3. 不适用于多任务系统：在多任务操作系统中，不同进程可能具有不同的内存访问需求。因此它们通常需要更大的内存块，而大页可能会限制内存的动态分配和共享，故无法适用于多任务系统。
4. 管理复杂性：大页的管理会比分级页表需要更多的操作系统支持和硬件复杂性，包括处理页错误和页面交换。

故综上所述，采用大页的页表映射方式可以提供性能和管理上的优势，尤其适用于特定的工作负载。然而其还会引入一些风险和限制，因此在选择页表映射方式时，需要根据具体的应用需求和系统特点进行权衡和决策。在许多情况下，分级页表结构仍然是更通用和灵活的选择，因为它可以适应各种应用场景。

# lab4
## 练习1：分配并初始化一个进程控制块（需要编码）
alloc_proc函数（位于kern/process/proc.c中）负责分配并返回一个新的struct proc_struct结构，用于存储新建立的内核线程的管理信息。ucore需要对这个结构进行最基本的初始化，你需要完成这个初始化过程。
  - 【提示】在alloc_proc函数的实现中，需要初始化的proc_struct结构中的成员变量至少包括：state/pid/runs/kstack/need_resched/parent/mm/context/tf/cr3/flags/name。

请在实验报告中简要说明你的设计实现过程。请回答如下问题：
- 请说明proc_struct中`struct context context`和`struct trapframe *tf`成员变量含义和在本实验中的作用是啥？（提示通过看代码和编程调试可以判断出来）

### 1.修改代码
将结构中的变量进行初始化
```
 // 初始化各个成员变量
 static  struct  proc_struct *
 alloc_proc(void) {
 struct  proc_struct *proc = kmalloc(sizeof(struct  proc_struct));
 if (proc != NULL) {
 //LAB4:EXERCISE1 2111673  
 // 初始化各个成员变量
 proc->state = PROC_UNINIT; // 设置进程状态为未初始化
 proc->pid = -1; // 初始化进程ID
 proc->runs = 0; // 初始化运行次数
 proc->kstack = 0; // 初始化内核栈地址
 proc->need_resched = 0; // 初始化不需要重新调度
 proc->parent = NULL; // 父进程暂时为空
 proc->mm = NULL; // 内存管理结构为空
 memset(&(proc->context), 0, sizeof(struct  context)); // 初始化上下文
 proc->tf = NULL; // 中断帧指针暂时为空
 proc->cr3 = boot_cr3; // 默认页目录为内核页目录表的基地址
 proc->flags = 0; // 初始化进程标志
 memset(proc->name, 0, PROC_NAME_LEN); // 清空进程名称
    }
 return  proc;
 }
```
### 2.回答问题

 `struct context` 和 `struct trapframe` 分别用于保存进程的上下文信息和中断帧信息。以下是它们的含义和在本实验中的作用：

（1）**`struct context context` ：**
  
  - **含义：** 保存了进程的上下文信息，包括寄存器值、程序计数器（`ra`）、栈指针（`sp`）等。
  - **作用：** 在进程切换时，需要保存当前执行上下文的状态，以便在切换回来时能够继续执行，即恢复。 `struct context` 中的成员用于保存这些信息。
  
（2）**`struct trapframe *tf`:**
  
  - **含义：** 保存了进程在发生中断或异常时的寄存器状态，以及一些其他的控制信息。 它是中断帧的结构，用于保存中断时的现场信息。
  - **作用：** 在中断或异常发生时，操作系统需要保存当前进程的状态到 `tf` 指向的中断帧中，以便在中断处理完成后能够正确地恢复进程的执行。
  
故在代码中， `struct trapframe` 主要用于保存中断发生时的寄存器状态，包括（`gpr`）、程序计数器（`epc`）、状态寄存器（`status`）等。在创建新的进程时，`copy_thread` 函数会将父进程的 `trapframe` 复制到子进程中，以确保子进程创建后能够从父进程的状态继续执行。

总体而言， `struct context` 和 `struct trapframe` 是在操作系统中用于保存进程或线程执行状态的关键数据结构，在进程切换和中断处理等场景中起到重要的作用。

## 练习2：为新创建的内核线程分配资源（需要编码）

创建一个内核线程需要分配和设置好很多资源。kernel_thread函数通过调用**do_fork**函数完成具体内核线程的创建工作。do_kernel函数会调用alloc_proc函数来分配并初始化一个进程控制块，但alloc_proc只是找到了一小块内存用以记录进程的必要信息，并没有实际分配这些资源。ucore一般通过do_fork实际创建新的内核线程。do_fork的作用是，创建当前内核线程的一个副本，它们的执行上下文、代码、数据都一样，但是存储位置不同。因此，我们**实际需要"fork"的东西就是stack和trapframe**。在这个过程中，需要给新内核线程分配资源，并且复制原进程的状态。你需要完成在kern/process/proc.c中的do_fork函数中的处理过程。它的大致执行步骤包括：

- 调用alloc_proc，首先获得一块用户信息块。
- 为进程分配一个内核栈。
- 复制原进程的内存管理信息到新进程（但内核线程不必做此事）
- 复制原进程上下文到新进程
- 将新进程添加到进程列表
- 唤醒新进程
- 返回新进程号

请在实验报告中简要说明你的设计实现过程。请回答如下问题：

- 请说明ucore是否做到给每个新fork的线程一个唯一的id？请说明你的分析和理由。

### 1.修改代码
```
do_fork(uint32_t  clone_flags, uintptr_t  stack, struct  trapframe *tf) {
int  ret = -E_NO_FREE_PROC;
struct  proc_struct *proc;
if (nr_process >= MAX_PROCESS) {
goto  fork_out;
}
ret = -E_NO_MEM;
//LAB4:EXERCISE2 2111673
if((proc = alloc_proc()) == NULL){//    分配并初始化一个新的进程控制块pcb
goto  fork_out;
}
proc->parent = current; // 设置父进程为current，表示当前进程是新进程的父进程
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
list_add(&proc_list , &proc->list_link); //  将新进程添加到进程链表
nr_process++;//进程数加1
}
local_intr_restore(intr_flag);//恢复中断状态
wakeup_proc(proc);//    唤醒新进程
ret =proc->pid;//    返回新进程的PID，表示成功创建新进程
```
### 2.回答问题
ucore确实为每个新fork的线程分配了一个唯一的ID。

这是通过`get_pid`函数实现的，该函数的目的就是为新的进程或线程分配一个唯一的进程ID（PID）。在`get_pid`函数中，有一个静态变量`last_pid`，它记录了最后一次分配的PID。每次调用`get_pid`时，`last_pid`都会增加1，然后检查是否达到了PID的最大值`MAX_PID`。如果达到了最大值，`last_pid`会被重置为1，然后开始从进程列表中寻找一个未被使用的PID。

在寻找过程中，如果发现有进程的PID等于`last_pid`，那么`last_pid`会再次增加1，然后继续寻找。如果发现有进程的PID大于`last_pid`且小于`next_safe`（`next_safe`是下一个安全的PID，即在当前进程列表中没有进程使用的PID），那么`next_safe`会被设置为该进程的PID。

这个过程会一直重复，直到找到一个未被使用的PID，然后返回这个PID。因此，每个新fork的线程都会得到一个唯一的PID。
## 练习3：编写proc_run 函数（需要编码）

proc_run用于将指定的进程切换到CPU上运行。它的大致执行步骤包括：

- 检查要切换的进程是否与当前正在运行的进程相同，如果相同则不需要切换。
- 禁用中断。你可以使用`/kern/sync/sync.h`中定义好的宏`local_intr_save(x)`和`local_intr_restore(x)`来实现关、开中断。
- 切换当前进程为要运行的进程。
- 切换页表，以便使用新进程的地址空间。`/libs/riscv.h`中提供了`lcr3(unsigned int cr3)`函数，可实现修改CR3寄存器值的功能。
- 实现上下文切换。`/kern/process`中已经预先编写好了`switch.S`，其中定义了`switch_to()`函数。可实现两个进程的context切换。
- 允许中断。

请回答如下问题：

- 在本实验的执行过程中，创建且运行了几个内核线程？

### 1.修改代码

```
void
proc_run(struct  proc_struct *proc) {
if (proc != current) {
// LAB4:EXERCISE3 2111673
bool  intr_flag;
struct  proc_struct *prev = current, *next = proc;
local_intr_save(intr_flag);//保存中断开关状态,禁用中断
    {
    current = proc;//设置当前进程为proc
    lcr3(next->cr3);//更新CR3为新进程页目录表物理地址,完成进程间页表切换
    switch_to(&(prev->context), &(next->context));//切换当前进程和新进程的上下文
    }
local_intr_restore(intr_flag);//恢复中断开关状态,允许中断
    }
}
```
### 2.回答问题
在本实验的执行过程中，创建且运行了第 0 个内核线程 idleproc和第 1 个内核线程 initproc。

在kern_init函数中，当完成虚拟内存的初始化工作后，就调用了proc_init函数，这个函数完成了idleproc内核线程和initproc内核线程的创建或复制工作。其中idleproc内核线程（空闲进程）的工作就是完成内核中各个子系统的初始化，然后通过执行cpu_idle函数不停地查询，看是否有其他内核线程可以执行了，如果有，马上让调度器选择那个内核线程执行。

接着就是调用kernel_thread函数来创建initproc内核线程。initproc内核线程的工作就是显示“Hello World”，表明自己存在且能正常工作了。
### 3.实验结果
`make`

![](https://markdown.liuchengtu.com/work/uploads/upload_29e47c66023664b714cd8c6b43f30df4.png)

`make qemu`

![](https://markdown.liuchengtu.com/work/uploads/upload_0f288e18127f58484d3219feab81bf53.png)
![](https://markdown.liuchengtu.com/work/uploads/upload_b33a09339888cc568e602733e25aab6d.png)

`make grade`

![](https://markdown.liuchengtu.com/work/uploads/upload_f86301252fb2881ffedb49d4d42dbd36.png)

## 扩展练习
说明语句`local_intr_save(intr_flag);....local_intr_restore(intr_flag);`是如何实现开关中断的？
__intr_save定义如下：

```
static  inline  bool  __intr_save(void) {
 if (read_csr(sstatus) & SSTATUS_SIE) {
 //read_csr(sstatus)指从控制寄存器CSR的sstatus中读取当前状态
 //通过按位与操作检查中断使能位SIE是否被设置。如果中断使能位被设置，说明当前中断是允许的。
 intr_disable();//调用函数禁用中断
 return  1;//如果中断使能位被设置且成功禁用了中断，函数返回 1
    }
 return  0;//如果中断使能位未被设置，说明中断之前就是关闭的，函数返回 0
}
```
其中intr_disable()函数定义如下，通过清除控制寄存器 `sstatus` 中的中断使能位SIE来禁用中断
```
void  intr_disable(void) {
clear_csr(sstatus, SSTATUS_SIE); 
}
```
__intr_restore定义如下:
```
static  inline  void  __intr_restore(bool  flag) {//如果 flag为真，即之前中断被禁用，现在需要恢复中断，则调用 intr_enable()函数，该函数可能会设置控制寄存器，以允许中断发生。
 if (flag) {
 intr_enable();
    }
}
```
其中intr_enable()函数定义如下，通过设置控制寄存器 `sstatus` 中的中断使能位SIE置为 1，以允许中断产生。
```
void  intr_enable(void) { 
set_csr(sstatus, SSTATUS_SIE); 
}
```
这两个语句作用分别是屏蔽中断和打开中断，保护进程切换不会被中断，以免进程切换时其他进程再进行调度，相当于互斥锁。在临界区使用这两个函数暂时屏蔽中断，避免进程调度，从而提供互斥。在proc_run中完成了上下文切换等重要工作，如果没有互斥，当前进程被设置为要切换运行的进程，但还没有完成上下文的切换，如果在此时发生了进程调度，就可能产生错误。

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

# lab8
## 练习1: 完成读文件操作的实现（需要编码）
首先了解打开文件的处理流程，然后参考本实验后续的文件读写操作的过程分析，填写在 kern/fs/sfs/sfs_inode.c中 的sfs_io_nolock()函数，实现读文件中数据的代码。
### 1.填写代码
```
// 对齐偏移。如果偏移没有对齐第一个基础块，则多读取/写入第一个基础块的末尾数据
 if ((blkoff = offset % SFS_BLKSIZE) != 0) { // blkoff为第一块数据块中进行操作的偏移量
 size = (nblks != 0) ? (SFS_BLKSIZE - blkoff) : (endpos - offset); // 第一块数据块中进行操作的数据长度
 // 获取第一个基础块所对应的block的编号ino
 if ((ret = sfs_bmap_load_nolock(sfs, sin, blkno, &ino)) != 0) {
 goto  out; // 找到内存文件索引对应的 block 的编号 ino
        }
 // 通过上一步取出的ino，读取/写入一部分第一个基础块的末尾数据
 if ((ret = sfs_buf_op(sfs, buf, size, ino, blkoff)) != 0) {
 goto  out;
        }
 // 已经完成读写的数据长度
 alen += size;
 if (nblks == 0) {
 goto  out;
        }
 buf += size, blkno ++, nblks --;
    }
 // 以块为单位循环处理中间的部分，循环读取/写入对齐好的数据
 size = SFS_BLKSIZE;
 while (nblks != 0) {
 // 获取inode对应的基础块编号
 if ((ret = sfs_bmap_load_nolock(sfs, sin, blkno, &ino)) != 0) {
 goto  out;
        }
 // 单次读取/写入一基础块的数据
 if ((ret = sfs_block_op(sfs, buf, ino, 1)) != 0) {
 goto  out;
        }
 alen += size, buf += size, blkno ++, nblks --;
    }
 // 如果末尾位置没有与最后一个基础块对齐，则多读取/写入一点末尾基础块的数据
 if ((size = endpos % SFS_BLKSIZE) != 0) {
 if ((ret = sfs_bmap_load_nolock(sfs, sin, blkno, &ino)) != 0) {
 goto  out;
        }
 if ((ret = sfs_buf_op(sfs, buf, size, ino, 0)) != 0) {
 goto  out;
        }
 alen += size;
    }
```
### 2.回答问题
打开文件的处理流程
首先有五个文件系统抽象概念：超级块(superblock)、文件(file)、目录项(dentry)、索引节点(inode)和安装点(mount point)。

- 超级块：存储整个文件系统的相关信息。对于磁盘上的文件系统，对应磁盘里的文件系统

- 文件：文件中的内容可理解为是一有序字节buffer，文件都有一个方便应用程序识别的文件名称或文件路径名。典型的文件操作有读、写、创建和删除等。

- 目录项：目录项不是目录，而是目录的组成部分。目录被看作一种特定的文件，而目录项是文件路径中的一部分。一般而言，目录项包含目录项的名字和目录项的索引节点位置。

- 索引节点：文件的相关元数据信息（如访问控制权限、大小、拥有者、创建时间、数据内容等等信息）存储在一个单独的数据结构中，该结构被称为索引节点。

- 安装点：文件系统被安装在一个特定的文件路径位置，这个位置就是安装点。所有的已安装文件系统都作为根文件系统树中的叶子出现在系统中。
- 
ucore的文件系统架构主要由四部分组成：

- 通用文件系统访问接口层：该层提供了一个从用户空间到文件系统的标准访问接口。这一层访问接口让应用程序能够通过一个简单的接口获得ucore内核的文件系统服务。

- 文件系统抽象层：向上提供一个一致的接口给内核的文件系统相关的系统调用实现模块或其他内核功能模块访问。向下提供一个同样的抽象函数指针列表和数据结构屏蔽不同文件系统的实现细节。

- Simple FS文件系统层：一个基于索引方式的简单文件系统实例。向上通过各种具体函数实现以对应文件系统抽象层提出的抽象函数。向下访问外设接口

- 外设接口层：向上提供设备访问接口屏蔽不同硬件细节。向下实现访问各种具体设备驱动的接口。

假如应用程序操作文件打开/创建/删除/读写，首先需要通过文件系统的通用文件系统访问接口层给用户空间提供的访问接口进入文件系统内部，接着由文件系统抽象层把访问请求转发给某一具体文件系统（比如SFS文件系统），具体文件系统（Simple FS文件系统层）把应用程序的访问请求转化为对磁盘上的block的处理请求，并通过外设接口层交给磁盘驱动例程来完成具体的磁盘操作。
![](https://markdown.liuchengtu.com/work/uploads/upload_c72224a212817709f5383b327a861c6d.png)

打开文件时首先进入通用文件访问接口层的处理流程，即进一步调用如下用户态函数： open->sys_open->syscall，从而引起系统调用进入到内核态。到了内核态后，通过中断处理例程，会调用到sys_open内核函数，并进一步调用sysfile_open内核函数。到了这里，需要把位于用户空间的字符串"/test/testfile"拷贝到内核空间中的字符串path中，并进入到文件系统抽象层的处理流程完成进一步的打开文件操作中。
再分配一个空闲的file数据结构变量file，调用vfs_open函数来找到path指出的文件所对应的基于inode数据结构的VFS索引节点node，在找到根目录对应的inode后，通过调用vop_lookup函数来查找“/”和“test”这两层目录下的文件“testfile”所对应的索引节点，如果找到就返回此索引节点，最终把file和node建立联系
## 练习2: 完成基于文件系统的执行程序机制的实现（需要编码）
改写proc.c中的load_icode函数和其他相关函数，实现基于文件系统的执行程序机制。执行：make qemu。如果能看看到sh用户程序的执行界面，则基本成功了。如果在sh用户界面上可以执行”ls”,”hello”等其他放置在sfs文件系统中的其他执行程序，则可以认为本实验基本成功。
### 1.填写代码
在proc.c的alloc_proc函数中：
```
void
alloc_proc(void) {
 struct  proc_struct *proc = kmalloc(sizeof(struct  proc_struct));
 if (proc != NULL) {
 memset(proc, 0, sizeof(struct  proc_struct));
 proc->state = PROC_UNINIT;
 proc->pid = -1;
 proc->cr3 = boot_cr3;
 list_init(&(proc->run_link));
  }
 return  proc;
}
```
在proc_run函数中：
```
void
proc_run(struct  proc_struct *proc) {
 if (proc != current) {
 bool  intr_flag;
struct  proc_struct *prev = current, *next = proc;
local_intr_save(intr_flag);//保存中断开关状态
         {
current = proc;//设置当前进程为proc
lcr3(proc->cr3);//更新CR3为新进程页目录表物理地址,完成进程间页表切换
flush_tlb();
switch_to(&(prev->context), &(next->context));//切换当前进程和新进程的上下文
         }
local_intr_restore(intr_flag);//恢复中断开关状态
    }
}
```
在load_icode函数中：该函数把LAB5那部分的load_icode部分复制过来再修改即可，不必全都重新编写
```
static  int
load_icode(int  fd, int  argc, char **kargv) {
 assert(argc >= 0 && argc <= EXEC_MAX_ARG_NUM);
 if (current->mm != NULL) {
 panic("load_icode: current->mm must be empty.\n");
    }
  
 int  ret = -E_NO_MEM;
 struct  mm_struct *mm;
 //(1)建立内存管理器
 if ((mm = mm_create()) == NULL) {
 goto  bad_mm;
    }
 //(2)建立页目录
 if (setup_pgdir(mm) != 0) {
 goto  bad_pgdir_cleanup_mm;
    }
 struct  Page *page;
 //LAB8 这里要从文件中读取ELF header
 struct  elfhdr  __elf, *elf = &__elf;
 if ((ret = load_icode_read(fd, elf, sizeof(struct  elfhdr), 0)) != 0) {
 goto  bad_elf_cleanup_pgdir;
    }
 // 判断读取入的elf header是否正确
 if (elf->e_magic != ELF_MAGIC) {
 ret = -E_INVAL_ELF;
 goto  bad_elf_cleanup_pgdir;
    }
 //(3)从文件加载程序到内存
 // 根据每一段的大小和基地址来分配不同的内存空间
 struct  proghdr  __ph, *ph = &__ph;
 uint32_t  vm_flags, perm,phnum=0;
 struct  proghdr *ph_end = ph + elf->e_phnum;
 for (; phnum < elf->e_phnum; phnum ++) {
 //(3.4) find every program section headers
if ((ret = load_icode_read(fd, ph, sizeof(struct  proghdr), elf->e_phoff + sizeof(struct  proghdr) * phnum)) != 0) {
 goto  bad_cleanup_mmap;
        }
 if (ph->p_type != ELF_PT_LOAD) {
 continue ;
        }
 if (ph->p_filesz > ph->p_memsz) {
 ret = -E_INVAL_ELF;
 goto  bad_cleanup_mmap;
        }
 if (ph->p_filesz == 0) {
 // continue ;
        }
 //(3.5) call mm_map fun to setup the new vma ( ph->p_va, ph->p_memsz)
 vm_flags = 0, perm = PTE_U | PTE_V;
 if (ph->p_flags & ELF_PF_X) vm_flags |= VM_EXEC;
 if (ph->p_flags & ELF_PF_W) vm_flags |= VM_WRITE;
 if (ph->p_flags & ELF_PF_R) vm_flags |= VM_READ;
 // modify the perm bits here for RISC-V
 if (vm_flags & VM_READ) perm |= PTE_R;
 if (vm_flags & VM_WRITE) perm |= (PTE_W | PTE_R);
 if (vm_flags & VM_EXEC) perm |= PTE_X;
 if ((ret = mm_map(mm, ph->p_va, ph->p_memsz, vm_flags, NULL)) != 0) {
 goto  bad_cleanup_mmap;
        }
 //LAB8 从文件特定偏移处读取每个段的详细信息（包括大小、基地址等等）
 off_t  offset = ph->p_offset;
 size_t  off, size;
 uintptr_t  start = ph->p_va, end, la = ROUNDDOWN(start, PGSIZE);
  
 ret = -E_NO_MEM;
  
//(3.6) alloc memory, and  copy the contents of every program section (from, from+end) to process's memory (la, la+end)
 end = ph->p_va + ph->p_filesz;
//(3.6.1) copy TEXT/DATA section of bianry program
 while (start < end) {
 if ((page = pgdir_alloc_page(mm->pgdir, la, perm)) == NULL) {
 goto  bad_cleanup_mmap;
            }
 off = start - la, size = PGSIZE - off, la += PGSIZE;
 if (end < la) {
 size -= la - end;
            }
 if ((ret = load_icode_read(fd, page2kva(page) + off, size, offset)) != 0) {
 goto  bad_cleanup_mmap;
            }
 start += size, offset += size;
        }
  
 // 对于段中当前页中剩余的空间（复制elf数据后剩下的空间），将其置为0
 end = ph->p_va + ph->p_memsz;
 if (start < la) {
            /* ph->p_memsz == ph->p_filesz */
 if (start == end) {
 continue ;
            }
 off = start + PGSIZE - la, size = PGSIZE - off;
 if (end < la) {
 size -= la - end;
            }
 memset(page2kva(page) + off, 0, size);
 start += size;
 assert((end < la && start == end) || (end >= la && start == la));
        }
 // 对于段中剩余页中的空间（复制elf数据后的多余页面），将其置为0
 while (start < end) {
 if ((page = pgdir_alloc_page(mm->pgdir, la, perm)) == NULL) {
 ret = -E_NO_MEM;
 goto  bad_cleanup_mmap;
            }
 off = start - la, size = PGSIZE - off, la += PGSIZE;
 if (end < la) {
 size -= la - end;
            }
 memset(page2kva(page) + off, 0, size);
 start += size;
        }
    }
 // 关闭读取的ELF
 sysfile_close(fd);
 //(4)建立相应的虚拟内存映射表
 // 设置栈内存
 vm_flags = VM_READ | VM_WRITE | VM_STACK;
 if ((ret = mm_map(mm, USTACKTOP - USTACKSIZE, USTACKSIZE, vm_flags, NULL)) != 0) {
 goto  bad_cleanup_mmap;
    }
 assert(pgdir_alloc_page(mm->pgdir, USTACKTOP-PGSIZE , PTE_USER) != NULL);
 assert(pgdir_alloc_page(mm->pgdir, USTACKTOP-2*PGSIZE , PTE_USER) != NULL);
 assert(pgdir_alloc_page(mm->pgdir, USTACKTOP-3*PGSIZE , PTE_USER) != NULL);
 assert(pgdir_alloc_page(mm->pgdir, USTACKTOP-4*PGSIZE , PTE_USER) != NULL);

 //(5)设置用户栈
 mm_count_inc(mm);
 current->mm = mm;
// 设置CR3页表相关寄存器
 current->cr3 = PADDR(mm->pgdir);
 lcr3(PADDR(mm->pgdir));
 //(6)处理用户栈中传入的参数，其中argc对应参数个数，uargv[]对应参数的具体内容的地址
 //LAB8 设置execve所启动的程序参数
 uint32_t  argv_size=0, i;
 for (i = 0; i < argc; i ++) {
 argv_size += strnlen(kargv[i],EXEC_MAX_ARG_LEN + 1)+1;
    }
 uintptr_t  stacktop = USTACKTOP - (argv_size/sizeof(long)+1)*sizeof(long);
// 直接将传入的参数压入至新栈的底部
 char** uargv=(char **)(stacktop - argc * sizeof(char *));

 argv_size = 0;
 for (i = 0; i < argc; i ++) {
 uargv[i] = strcpy((char *)(stacktop + argv_size ), kargv[i]);
 argv_size +=strnlen(kargv[i],EXEC_MAX_ARG_LEN + 1)+1;
    }
 stacktop = (uintptr_t)uargv - sizeof(int);
    *(int *)stacktop = argc;
 //(6) setup trapframe for user environment
 struct  trapframe *tf = current->tf;
 // Keep sstatus
 uintptr_t  sstatus = tf->status;
 //(7)设置进程的中断帧  
 memset(tf, 0, sizeof(struct  trapframe));
 tf->gpr.sp = USTACKTOP; // 将用户栈指针设置为用户栈的顶部
 // 设置用户程序入口地址
 tf->epc = elf->e_entry;
 // 设置 SPP为0 以指示用户模式
 tf->status = (sstatus & ~ SSTATUS_SPP) | SSTATUS_SPIE;
 ret = 0;
//(8)错误处理部分

out:
 return  ret;
bad_cleanup_mmap:
 exit_mmap(mm);
bad_elf_cleanup_pgdir:
 put_pgdir(mm);
bad_pgdir_cleanup_mm:
 mm_destroy(mm);
bad_mm:
 goto  out;
}
```
### 2.实验结果
``make``
![](https://markdown.liuchengtu.com/work/uploads/upload_6e7473fce157931abe212d8a63c80844.png)


``make qemu``
![](https://markdown.liuchengtu.com/work/uploads/upload_5d15ef7d66ffd09f38054fdad2ffd20b.png)


``make grade``
![](https://markdown.liuchengtu.com/work/uploads/upload_385eb2aecab481935b443b4bb2a6082e.png)
![](https://markdown.liuchengtu.com/work/uploads/upload_5ebad12b176ee0af79575e18a552f299.png)


