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