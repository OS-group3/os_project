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

![测试结果](https://markdown.liuchengtu.com/work/uploads/upload_8527609a1c7a232fafcd8afcb0d0ff30.png)

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
