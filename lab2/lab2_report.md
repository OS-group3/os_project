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

1. **分区合并：** 在分配内存块后，检查相邻的空闲分区，如果它们相邻并且都是空闲的，可以将它们合并成一个更大的空闲分区，以容纳更大的进程。

2. **高效的数据结构**: 使用更高效的数据结构来存储空闲内存块，例如红黑树、跳表等，以便更快地查找和合并内存块。

3. **内存整理：** 定期执行内存整理操作，将内存中的分配块移动到一起，以创造更大的连续空闲空间。这可以减少外部碎片，但需要花费一些计算资源和时间。
  
3. **按需分配：** 不要一开始分配整个进程的内存需求，而是按照需要分配内存。这样可以减少内部碎片，因为只有真正需要的内存才会被分配。
  
4. **固定分区大小：** 将内存分成固定大小的分区，这样可以更容易找到适合大小的空闲分区，但可能会浪费一些内存。
  
5. **动态调整分区大小：** 允许动态调整分区大小，以更好地适应不同大小的进程。这可以减少内部碎片，但增加了管理复杂性。
  
6. **考虑首次适配的变体：** 可以修改首次适配算法，以考虑更合适的分配策略。例如，可以限制只在较大的空闲分区中分配，以减少外部碎片。


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
 min_size = p->property ;//更新 min_size 为 p 页面的值
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
 min_size = p->property ;//更新 min_size 为 p 页面的值
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
  - **更高效的数据结构**: 考虑使用更高效的数据结构，如二叉树来加速空闲内存块的搜索和分配过程。‘
 
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