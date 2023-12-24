
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


