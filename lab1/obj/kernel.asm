
bin/kernel：     文件格式 elf64-littleriscv


Disassembly of section .text:

0000000080200000 <kern_entry>:
#include <memlayout.h>

    .section .text,"ax",%progbits
    .globl kern_entry
kern_entry:
    la sp, bootstacktop
    80200000:	00004117          	auipc	sp,0x4
    80200004:	00010113          	mv	sp,sp

    tail kern_init
    80200008:	0040006f          	j	8020000c <kern_init>

000000008020000c <kern_init>:
int kern_init(void) __attribute__((noreturn));
void grade_backtrace(void);

int kern_init(void) {
    extern char edata[], end[];
    memset(edata, 0, end - edata);
    8020000c:	00004517          	auipc	a0,0x4
    80200010:	00450513          	addi	a0,a0,4 # 80204010 <edata>
    80200014:	00004617          	auipc	a2,0x4
    80200018:	01460613          	addi	a2,a2,20 # 80204028 <end>
int kern_init(void) {
    8020001c:	1141                	addi	sp,sp,-16
    memset(edata, 0, end - edata);
    8020001e:	8e09                	sub	a2,a2,a0
    80200020:	4581                	li	a1,0
int kern_init(void) {
    80200022:	e406                	sd	ra,8(sp)
    memset(edata, 0, end - edata);
    80200024:	1e9000ef          	jal	ra,80200a0c <memset>

    cons_init();  // init the console
    80200028:	14c000ef          	jal	ra,80200174 <cons_init>

    const char *message = "(THU.CST) os is loading ...\n";
    cprintf("%s\n\n", message);
    8020002c:	00001597          	auipc	a1,0x1
    80200030:	9f458593          	addi	a1,a1,-1548 # 80200a20 <etext+0x2>
    80200034:	00001517          	auipc	a0,0x1
    80200038:	a0c50513          	addi	a0,a0,-1524 # 80200a40 <etext+0x22>
    8020003c:	030000ef          	jal	ra,8020006c <cprintf>

    print_kerninfo();
    80200040:	060000ef          	jal	ra,802000a0 <print_kerninfo>

    // grade_backtrace();

    idt_init();  // init interrupt descriptor table
    80200044:	140000ef          	jal	ra,80200184 <idt_init>

    // rdtime in mbare mode crashes
    clock_init();  // init clock interrupt
    80200048:	0e8000ef          	jal	ra,80200130 <clock_init>

    intr_enable();  // enable irq interrupt
    8020004c:	132000ef          	jal	ra,8020017e <intr_enable>
    
    while (1)
        ;
    80200050:	a001                	j	80200050 <kern_init+0x44>

0000000080200052 <cputch>:

/* *
 * cputch - writes a single character @c to stdout, and it will
 * increace the value of counter pointed by @cnt.
 * */
static void cputch(int c, int *cnt) {
    80200052:	1141                	addi	sp,sp,-16
    80200054:	e022                	sd	s0,0(sp)
    80200056:	e406                	sd	ra,8(sp)
    80200058:	842e                	mv	s0,a1
    cons_putc(c);
    8020005a:	11c000ef          	jal	ra,80200176 <cons_putc>
    (*cnt)++;
    8020005e:	401c                	lw	a5,0(s0)
}
    80200060:	60a2                	ld	ra,8(sp)
    (*cnt)++;
    80200062:	2785                	addiw	a5,a5,1
    80200064:	c01c                	sw	a5,0(s0)
}
    80200066:	6402                	ld	s0,0(sp)
    80200068:	0141                	addi	sp,sp,16
    8020006a:	8082                	ret

000000008020006c <cprintf>:
 * cprintf - formats a string and writes it to stdout
 *
 * The return value is the number of characters which would be
 * written to stdout.
 * */
int cprintf(const char *fmt, ...) {
    8020006c:	711d                	addi	sp,sp,-96
    va_list ap;
    int cnt;
    va_start(ap, fmt);
    8020006e:	02810313          	addi	t1,sp,40 # 80204028 <end>
int cprintf(const char *fmt, ...) {
    80200072:	f42e                	sd	a1,40(sp)
    80200074:	f832                	sd	a2,48(sp)
    80200076:	fc36                	sd	a3,56(sp)
    vprintfmt((void *)cputch, &cnt, fmt, ap);
    80200078:	862a                	mv	a2,a0
    8020007a:	004c                	addi	a1,sp,4
    8020007c:	00000517          	auipc	a0,0x0
    80200080:	fd650513          	addi	a0,a0,-42 # 80200052 <cputch>
    80200084:	869a                	mv	a3,t1
int cprintf(const char *fmt, ...) {
    80200086:	ec06                	sd	ra,24(sp)
    80200088:	e0ba                	sd	a4,64(sp)
    8020008a:	e4be                	sd	a5,72(sp)
    8020008c:	e8c2                	sd	a6,80(sp)
    8020008e:	ecc6                	sd	a7,88(sp)
    va_start(ap, fmt);
    80200090:	e41a                	sd	t1,8(sp)
    int cnt = 0;
    80200092:	c202                	sw	zero,4(sp)
    vprintfmt((void *)cputch, &cnt, fmt, ap);
    80200094:	572000ef          	jal	ra,80200606 <vprintfmt>
    cnt = vcprintf(fmt, ap);
    va_end(ap);
    return cnt;
}
    80200098:	60e2                	ld	ra,24(sp)
    8020009a:	4512                	lw	a0,4(sp)
    8020009c:	6125                	addi	sp,sp,96
    8020009e:	8082                	ret

00000000802000a0 <print_kerninfo>:
/* *
 * print_kerninfo - print the information about kernel, including the location
 * of kernel entry, the start addresses of data and text segements, the start
 * address of free memory and how many memory that kernel has used.
 * */
void print_kerninfo(void) {
    802000a0:	1141                	addi	sp,sp,-16
    extern char etext[], edata[], end[], kern_init[];
    cprintf("Special kernel symbols:\n");
    802000a2:	00001517          	auipc	a0,0x1
    802000a6:	9a650513          	addi	a0,a0,-1626 # 80200a48 <etext+0x2a>
void print_kerninfo(void) {
    802000aa:	e406                	sd	ra,8(sp)
    cprintf("Special kernel symbols:\n");
    802000ac:	fc1ff0ef          	jal	ra,8020006c <cprintf>
    cprintf("  entry  0x%016x (virtual)\n", kern_init);
    802000b0:	00000597          	auipc	a1,0x0
    802000b4:	f5c58593          	addi	a1,a1,-164 # 8020000c <kern_init>
    802000b8:	00001517          	auipc	a0,0x1
    802000bc:	9b050513          	addi	a0,a0,-1616 # 80200a68 <etext+0x4a>
    802000c0:	fadff0ef          	jal	ra,8020006c <cprintf>
    cprintf("  etext  0x%016x (virtual)\n", etext);
    802000c4:	00001597          	auipc	a1,0x1
    802000c8:	95a58593          	addi	a1,a1,-1702 # 80200a1e <etext>
    802000cc:	00001517          	auipc	a0,0x1
    802000d0:	9bc50513          	addi	a0,a0,-1604 # 80200a88 <etext+0x6a>
    802000d4:	f99ff0ef          	jal	ra,8020006c <cprintf>
    cprintf("  edata  0x%016x (virtual)\n", edata);
    802000d8:	00004597          	auipc	a1,0x4
    802000dc:	f3858593          	addi	a1,a1,-200 # 80204010 <edata>
    802000e0:	00001517          	auipc	a0,0x1
    802000e4:	9c850513          	addi	a0,a0,-1592 # 80200aa8 <etext+0x8a>
    802000e8:	f85ff0ef          	jal	ra,8020006c <cprintf>
    cprintf("  end    0x%016x (virtual)\n", end);
    802000ec:	00004597          	auipc	a1,0x4
    802000f0:	f3c58593          	addi	a1,a1,-196 # 80204028 <end>
    802000f4:	00001517          	auipc	a0,0x1
    802000f8:	9d450513          	addi	a0,a0,-1580 # 80200ac8 <etext+0xaa>
    802000fc:	f71ff0ef          	jal	ra,8020006c <cprintf>
    cprintf("Kernel executable memory footprint: %dKB\n",
            (end - kern_init + 1023) / 1024);
    80200100:	00004597          	auipc	a1,0x4
    80200104:	32758593          	addi	a1,a1,807 # 80204427 <end+0x3ff>
    80200108:	00000797          	auipc	a5,0x0
    8020010c:	f0478793          	addi	a5,a5,-252 # 8020000c <kern_init>
    80200110:	40f587b3          	sub	a5,a1,a5
    cprintf("Kernel executable memory footprint: %dKB\n",
    80200114:	43f7d593          	srai	a1,a5,0x3f
}
    80200118:	60a2                	ld	ra,8(sp)
    cprintf("Kernel executable memory footprint: %dKB\n",
    8020011a:	3ff5f593          	andi	a1,a1,1023
    8020011e:	95be                	add	a1,a1,a5
    80200120:	85a9                	srai	a1,a1,0xa
    80200122:	00001517          	auipc	a0,0x1
    80200126:	9c650513          	addi	a0,a0,-1594 # 80200ae8 <etext+0xca>
}
    8020012a:	0141                	addi	sp,sp,16
    cprintf("Kernel executable memory footprint: %dKB\n",
    8020012c:	f41ff06f          	j	8020006c <cprintf>

0000000080200130 <clock_init>:

/* *
 * clock_init - initialize 8253 clock to interrupt 100 times per second,
 * and then enable IRQ_TIMER.
 * */
void clock_init(void) {
    80200130:	1141                	addi	sp,sp,-16
    80200132:	e406                	sd	ra,8(sp)
    // enable timer interrupt in sie
    set_csr(sie, MIP_STIP);
    80200134:	02000793          	li	a5,32
    80200138:	1047a7f3          	csrrs	a5,sie,a5
    __asm__ __volatile__("rdtime %0" : "=r"(n));
    8020013c:	c0102573          	rdtime	a0
    ticks = 0;

    cprintf("++ setup timer interrupts\n");
}

void clock_set_next_event(void) { sbi_set_timer(get_cycles() + timebase); }
    80200140:	67e1                	lui	a5,0x18
    80200142:	6a078793          	addi	a5,a5,1696 # 186a0 <BASE_ADDRESS-0x801e7960>
    80200146:	953e                	add	a0,a0,a5
    80200148:	067000ef          	jal	ra,802009ae <sbi_set_timer>
}
    8020014c:	60a2                	ld	ra,8(sp)
    ticks = 0;
    8020014e:	00004797          	auipc	a5,0x4
    80200152:	ec07b923          	sd	zero,-302(a5) # 80204020 <ticks>
    cprintf("++ setup timer interrupts\n");
    80200156:	00001517          	auipc	a0,0x1
    8020015a:	9c250513          	addi	a0,a0,-1598 # 80200b18 <etext+0xfa>
}
    8020015e:	0141                	addi	sp,sp,16
    cprintf("++ setup timer interrupts\n");
    80200160:	f0dff06f          	j	8020006c <cprintf>

0000000080200164 <clock_set_next_event>:
    __asm__ __volatile__("rdtime %0" : "=r"(n));
    80200164:	c0102573          	rdtime	a0
void clock_set_next_event(void) { sbi_set_timer(get_cycles() + timebase); }
    80200168:	67e1                	lui	a5,0x18
    8020016a:	6a078793          	addi	a5,a5,1696 # 186a0 <BASE_ADDRESS-0x801e7960>
    8020016e:	953e                	add	a0,a0,a5
    80200170:	03f0006f          	j	802009ae <sbi_set_timer>

0000000080200174 <cons_init>:

/* serial_intr - try to feed input characters from serial port */
void serial_intr(void) {}

/* cons_init - initializes the console devices */
void cons_init(void) {}
    80200174:	8082                	ret

0000000080200176 <cons_putc>:

/* cons_putc - print a single character @c to console devices */
void cons_putc(int c) { sbi_console_putchar((unsigned char)c); }
    80200176:	0ff57513          	andi	a0,a0,255
    8020017a:	0190006f          	j	80200992 <sbi_console_putchar>

000000008020017e <intr_enable>:
#include <intr.h>
#include <riscv.h>

/* intr_enable - enable irq interrupt */
void intr_enable(void) { set_csr(sstatus, SSTATUS_SIE); }
    8020017e:	100167f3          	csrrsi	a5,sstatus,2
    80200182:	8082                	ret

0000000080200184 <idt_init>:
 */
void idt_init(void) {
    extern void __alltraps(void);
    /* Set sscratch register to 0, indicating to exception vector that we are
     * presently executing in the kernel */
    write_csr(sscratch, 0);
    80200184:	14005073          	csrwi	sscratch,0
    /* Set the exception vector address */
    write_csr(stvec, &__alltraps);
    80200188:	00000797          	auipc	a5,0x0
    8020018c:	35c78793          	addi	a5,a5,860 # 802004e4 <__alltraps>
    80200190:	10579073          	csrw	stvec,a5
}
    80200194:	8082                	ret

0000000080200196 <print_regs>:
    cprintf("  badvaddr 0x%08x\n", tf->badvaddr);
    cprintf("  cause    0x%08x\n", tf->cause);
}

void print_regs(struct pushregs *gpr) {
    cprintf("  zero     0x%08x\n", gpr->zero);
    80200196:	610c                	ld	a1,0(a0)
void print_regs(struct pushregs *gpr) {
    80200198:	1141                	addi	sp,sp,-16
    8020019a:	e022                	sd	s0,0(sp)
    8020019c:	842a                	mv	s0,a0
    cprintf("  zero     0x%08x\n", gpr->zero);
    8020019e:	00001517          	auipc	a0,0x1
    802001a2:	aba50513          	addi	a0,a0,-1350 # 80200c58 <etext+0x23a>
void print_regs(struct pushregs *gpr) {
    802001a6:	e406                	sd	ra,8(sp)
    cprintf("  zero     0x%08x\n", gpr->zero);
    802001a8:	ec5ff0ef          	jal	ra,8020006c <cprintf>
    cprintf("  ra       0x%08x\n", gpr->ra);
    802001ac:	640c                	ld	a1,8(s0)
    802001ae:	00001517          	auipc	a0,0x1
    802001b2:	ac250513          	addi	a0,a0,-1342 # 80200c70 <etext+0x252>
    802001b6:	eb7ff0ef          	jal	ra,8020006c <cprintf>
    cprintf("  sp       0x%08x\n", gpr->sp);
    802001ba:	680c                	ld	a1,16(s0)
    802001bc:	00001517          	auipc	a0,0x1
    802001c0:	acc50513          	addi	a0,a0,-1332 # 80200c88 <etext+0x26a>
    802001c4:	ea9ff0ef          	jal	ra,8020006c <cprintf>
    cprintf("  gp       0x%08x\n", gpr->gp);
    802001c8:	6c0c                	ld	a1,24(s0)
    802001ca:	00001517          	auipc	a0,0x1
    802001ce:	ad650513          	addi	a0,a0,-1322 # 80200ca0 <etext+0x282>
    802001d2:	e9bff0ef          	jal	ra,8020006c <cprintf>
    cprintf("  tp       0x%08x\n", gpr->tp);
    802001d6:	700c                	ld	a1,32(s0)
    802001d8:	00001517          	auipc	a0,0x1
    802001dc:	ae050513          	addi	a0,a0,-1312 # 80200cb8 <etext+0x29a>
    802001e0:	e8dff0ef          	jal	ra,8020006c <cprintf>
    cprintf("  t0       0x%08x\n", gpr->t0);
    802001e4:	740c                	ld	a1,40(s0)
    802001e6:	00001517          	auipc	a0,0x1
    802001ea:	aea50513          	addi	a0,a0,-1302 # 80200cd0 <etext+0x2b2>
    802001ee:	e7fff0ef          	jal	ra,8020006c <cprintf>
    cprintf("  t1       0x%08x\n", gpr->t1);
    802001f2:	780c                	ld	a1,48(s0)
    802001f4:	00001517          	auipc	a0,0x1
    802001f8:	af450513          	addi	a0,a0,-1292 # 80200ce8 <etext+0x2ca>
    802001fc:	e71ff0ef          	jal	ra,8020006c <cprintf>
    cprintf("  t2       0x%08x\n", gpr->t2);
    80200200:	7c0c                	ld	a1,56(s0)
    80200202:	00001517          	auipc	a0,0x1
    80200206:	afe50513          	addi	a0,a0,-1282 # 80200d00 <etext+0x2e2>
    8020020a:	e63ff0ef          	jal	ra,8020006c <cprintf>
    cprintf("  s0       0x%08x\n", gpr->s0);
    8020020e:	602c                	ld	a1,64(s0)
    80200210:	00001517          	auipc	a0,0x1
    80200214:	b0850513          	addi	a0,a0,-1272 # 80200d18 <etext+0x2fa>
    80200218:	e55ff0ef          	jal	ra,8020006c <cprintf>
    cprintf("  s1       0x%08x\n", gpr->s1);
    8020021c:	642c                	ld	a1,72(s0)
    8020021e:	00001517          	auipc	a0,0x1
    80200222:	b1250513          	addi	a0,a0,-1262 # 80200d30 <etext+0x312>
    80200226:	e47ff0ef          	jal	ra,8020006c <cprintf>
    cprintf("  a0       0x%08x\n", gpr->a0);
    8020022a:	682c                	ld	a1,80(s0)
    8020022c:	00001517          	auipc	a0,0x1
    80200230:	b1c50513          	addi	a0,a0,-1252 # 80200d48 <etext+0x32a>
    80200234:	e39ff0ef          	jal	ra,8020006c <cprintf>
    cprintf("  a1       0x%08x\n", gpr->a1);
    80200238:	6c2c                	ld	a1,88(s0)
    8020023a:	00001517          	auipc	a0,0x1
    8020023e:	b2650513          	addi	a0,a0,-1242 # 80200d60 <etext+0x342>
    80200242:	e2bff0ef          	jal	ra,8020006c <cprintf>
    cprintf("  a2       0x%08x\n", gpr->a2);
    80200246:	702c                	ld	a1,96(s0)
    80200248:	00001517          	auipc	a0,0x1
    8020024c:	b3050513          	addi	a0,a0,-1232 # 80200d78 <etext+0x35a>
    80200250:	e1dff0ef          	jal	ra,8020006c <cprintf>
    cprintf("  a3       0x%08x\n", gpr->a3);
    80200254:	742c                	ld	a1,104(s0)
    80200256:	00001517          	auipc	a0,0x1
    8020025a:	b3a50513          	addi	a0,a0,-1222 # 80200d90 <etext+0x372>
    8020025e:	e0fff0ef          	jal	ra,8020006c <cprintf>
    cprintf("  a4       0x%08x\n", gpr->a4);
    80200262:	782c                	ld	a1,112(s0)
    80200264:	00001517          	auipc	a0,0x1
    80200268:	b4450513          	addi	a0,a0,-1212 # 80200da8 <etext+0x38a>
    8020026c:	e01ff0ef          	jal	ra,8020006c <cprintf>
    cprintf("  a5       0x%08x\n", gpr->a5);
    80200270:	7c2c                	ld	a1,120(s0)
    80200272:	00001517          	auipc	a0,0x1
    80200276:	b4e50513          	addi	a0,a0,-1202 # 80200dc0 <etext+0x3a2>
    8020027a:	df3ff0ef          	jal	ra,8020006c <cprintf>
    cprintf("  a6       0x%08x\n", gpr->a6);
    8020027e:	604c                	ld	a1,128(s0)
    80200280:	00001517          	auipc	a0,0x1
    80200284:	b5850513          	addi	a0,a0,-1192 # 80200dd8 <etext+0x3ba>
    80200288:	de5ff0ef          	jal	ra,8020006c <cprintf>
    cprintf("  a7       0x%08x\n", gpr->a7);
    8020028c:	644c                	ld	a1,136(s0)
    8020028e:	00001517          	auipc	a0,0x1
    80200292:	b6250513          	addi	a0,a0,-1182 # 80200df0 <etext+0x3d2>
    80200296:	dd7ff0ef          	jal	ra,8020006c <cprintf>
    cprintf("  s2       0x%08x\n", gpr->s2);
    8020029a:	684c                	ld	a1,144(s0)
    8020029c:	00001517          	auipc	a0,0x1
    802002a0:	b6c50513          	addi	a0,a0,-1172 # 80200e08 <etext+0x3ea>
    802002a4:	dc9ff0ef          	jal	ra,8020006c <cprintf>
    cprintf("  s3       0x%08x\n", gpr->s3);
    802002a8:	6c4c                	ld	a1,152(s0)
    802002aa:	00001517          	auipc	a0,0x1
    802002ae:	b7650513          	addi	a0,a0,-1162 # 80200e20 <etext+0x402>
    802002b2:	dbbff0ef          	jal	ra,8020006c <cprintf>
    cprintf("  s4       0x%08x\n", gpr->s4);
    802002b6:	704c                	ld	a1,160(s0)
    802002b8:	00001517          	auipc	a0,0x1
    802002bc:	b8050513          	addi	a0,a0,-1152 # 80200e38 <etext+0x41a>
    802002c0:	dadff0ef          	jal	ra,8020006c <cprintf>
    cprintf("  s5       0x%08x\n", gpr->s5);
    802002c4:	744c                	ld	a1,168(s0)
    802002c6:	00001517          	auipc	a0,0x1
    802002ca:	b8a50513          	addi	a0,a0,-1142 # 80200e50 <etext+0x432>
    802002ce:	d9fff0ef          	jal	ra,8020006c <cprintf>
    cprintf("  s6       0x%08x\n", gpr->s6);
    802002d2:	784c                	ld	a1,176(s0)
    802002d4:	00001517          	auipc	a0,0x1
    802002d8:	b9450513          	addi	a0,a0,-1132 # 80200e68 <etext+0x44a>
    802002dc:	d91ff0ef          	jal	ra,8020006c <cprintf>
    cprintf("  s7       0x%08x\n", gpr->s7);
    802002e0:	7c4c                	ld	a1,184(s0)
    802002e2:	00001517          	auipc	a0,0x1
    802002e6:	b9e50513          	addi	a0,a0,-1122 # 80200e80 <etext+0x462>
    802002ea:	d83ff0ef          	jal	ra,8020006c <cprintf>
    cprintf("  s8       0x%08x\n", gpr->s8);
    802002ee:	606c                	ld	a1,192(s0)
    802002f0:	00001517          	auipc	a0,0x1
    802002f4:	ba850513          	addi	a0,a0,-1112 # 80200e98 <etext+0x47a>
    802002f8:	d75ff0ef          	jal	ra,8020006c <cprintf>
    cprintf("  s9       0x%08x\n", gpr->s9);
    802002fc:	646c                	ld	a1,200(s0)
    802002fe:	00001517          	auipc	a0,0x1
    80200302:	bb250513          	addi	a0,a0,-1102 # 80200eb0 <etext+0x492>
    80200306:	d67ff0ef          	jal	ra,8020006c <cprintf>
    cprintf("  s10      0x%08x\n", gpr->s10);
    8020030a:	686c                	ld	a1,208(s0)
    8020030c:	00001517          	auipc	a0,0x1
    80200310:	bbc50513          	addi	a0,a0,-1092 # 80200ec8 <etext+0x4aa>
    80200314:	d59ff0ef          	jal	ra,8020006c <cprintf>
    cprintf("  s11      0x%08x\n", gpr->s11);
    80200318:	6c6c                	ld	a1,216(s0)
    8020031a:	00001517          	auipc	a0,0x1
    8020031e:	bc650513          	addi	a0,a0,-1082 # 80200ee0 <etext+0x4c2>
    80200322:	d4bff0ef          	jal	ra,8020006c <cprintf>
    cprintf("  t3       0x%08x\n", gpr->t3);
    80200326:	706c                	ld	a1,224(s0)
    80200328:	00001517          	auipc	a0,0x1
    8020032c:	bd050513          	addi	a0,a0,-1072 # 80200ef8 <etext+0x4da>
    80200330:	d3dff0ef          	jal	ra,8020006c <cprintf>
    cprintf("  t4       0x%08x\n", gpr->t4);
    80200334:	746c                	ld	a1,232(s0)
    80200336:	00001517          	auipc	a0,0x1
    8020033a:	bda50513          	addi	a0,a0,-1062 # 80200f10 <etext+0x4f2>
    8020033e:	d2fff0ef          	jal	ra,8020006c <cprintf>
    cprintf("  t5       0x%08x\n", gpr->t5);
    80200342:	786c                	ld	a1,240(s0)
    80200344:	00001517          	auipc	a0,0x1
    80200348:	be450513          	addi	a0,a0,-1052 # 80200f28 <etext+0x50a>
    8020034c:	d21ff0ef          	jal	ra,8020006c <cprintf>
    cprintf("  t6       0x%08x\n", gpr->t6);
    80200350:	7c6c                	ld	a1,248(s0)
}
    80200352:	6402                	ld	s0,0(sp)
    80200354:	60a2                	ld	ra,8(sp)
    cprintf("  t6       0x%08x\n", gpr->t6);
    80200356:	00001517          	auipc	a0,0x1
    8020035a:	bea50513          	addi	a0,a0,-1046 # 80200f40 <etext+0x522>
}
    8020035e:	0141                	addi	sp,sp,16
    cprintf("  t6       0x%08x\n", gpr->t6);
    80200360:	d0dff06f          	j	8020006c <cprintf>

0000000080200364 <print_trapframe>:
void print_trapframe(struct trapframe *tf) {
    80200364:	1141                	addi	sp,sp,-16
    80200366:	e022                	sd	s0,0(sp)
    cprintf("trapframe at %p\n", tf);
    80200368:	85aa                	mv	a1,a0
void print_trapframe(struct trapframe *tf) {
    8020036a:	842a                	mv	s0,a0
    cprintf("trapframe at %p\n", tf);
    8020036c:	00001517          	auipc	a0,0x1
    80200370:	bec50513          	addi	a0,a0,-1044 # 80200f58 <etext+0x53a>
void print_trapframe(struct trapframe *tf) {
    80200374:	e406                	sd	ra,8(sp)
    cprintf("trapframe at %p\n", tf);
    80200376:	cf7ff0ef          	jal	ra,8020006c <cprintf>
    print_regs(&tf->gpr);
    8020037a:	8522                	mv	a0,s0
    8020037c:	e1bff0ef          	jal	ra,80200196 <print_regs>
    cprintf("  status   0x%08x\n", tf->status);
    80200380:	10043583          	ld	a1,256(s0)
    80200384:	00001517          	auipc	a0,0x1
    80200388:	bec50513          	addi	a0,a0,-1044 # 80200f70 <etext+0x552>
    8020038c:	ce1ff0ef          	jal	ra,8020006c <cprintf>
    cprintf("  epc      0x%08x\n", tf->epc);
    80200390:	10843583          	ld	a1,264(s0)
    80200394:	00001517          	auipc	a0,0x1
    80200398:	bf450513          	addi	a0,a0,-1036 # 80200f88 <etext+0x56a>
    8020039c:	cd1ff0ef          	jal	ra,8020006c <cprintf>
    cprintf("  badvaddr 0x%08x\n", tf->badvaddr);
    802003a0:	11043583          	ld	a1,272(s0)
    802003a4:	00001517          	auipc	a0,0x1
    802003a8:	bfc50513          	addi	a0,a0,-1028 # 80200fa0 <etext+0x582>
    802003ac:	cc1ff0ef          	jal	ra,8020006c <cprintf>
    cprintf("  cause    0x%08x\n", tf->cause);
    802003b0:	11843583          	ld	a1,280(s0)
}
    802003b4:	6402                	ld	s0,0(sp)
    802003b6:	60a2                	ld	ra,8(sp)
    cprintf("  cause    0x%08x\n", tf->cause);
    802003b8:	00001517          	auipc	a0,0x1
    802003bc:	c0050513          	addi	a0,a0,-1024 # 80200fb8 <etext+0x59a>
}
    802003c0:	0141                	addi	sp,sp,16
    cprintf("  cause    0x%08x\n", tf->cause);
    802003c2:	cabff06f          	j	8020006c <cprintf>

00000000802003c6 <interrupt_handler>:

void interrupt_handler(struct trapframe *tf) {
    intptr_t cause = (tf->cause << 1) >> 1;
    802003c6:	11853783          	ld	a5,280(a0)
    802003ca:	577d                	li	a4,-1
    802003cc:	8305                	srli	a4,a4,0x1
    802003ce:	8ff9                	and	a5,a5,a4
    switch (cause) {
    802003d0:	472d                	li	a4,11
    802003d2:	08f76963          	bltu	a4,a5,80200464 <interrupt_handler+0x9e>
    802003d6:	00000717          	auipc	a4,0x0
    802003da:	75e70713          	addi	a4,a4,1886 # 80200b34 <etext+0x116>
    802003de:	078a                	slli	a5,a5,0x2
    802003e0:	97ba                	add	a5,a5,a4
    802003e2:	439c                	lw	a5,0(a5)
    802003e4:	97ba                	add	a5,a5,a4
    802003e6:	8782                	jr	a5
            break;
        case IRQ_H_SOFT:
            cprintf("Hypervisor software interrupt\n");
            break;
        case IRQ_M_SOFT:
            cprintf("Machine software interrupt\n");
    802003e8:	00001517          	auipc	a0,0x1
    802003ec:	82050513          	addi	a0,a0,-2016 # 80200c08 <etext+0x1ea>
    802003f0:	c7dff06f          	j	8020006c <cprintf>
            cprintf("Hypervisor software interrupt\n");
    802003f4:	00000517          	auipc	a0,0x0
    802003f8:	7f450513          	addi	a0,a0,2036 # 80200be8 <etext+0x1ca>
    802003fc:	c71ff06f          	j	8020006c <cprintf>
            cprintf("User software interrupt\n");
    80200400:	00000517          	auipc	a0,0x0
    80200404:	7a850513          	addi	a0,a0,1960 # 80200ba8 <etext+0x18a>
    80200408:	c65ff06f          	j	8020006c <cprintf>
            cprintf("Supervisor software interrupt\n");
    8020040c:	00000517          	auipc	a0,0x0
    80200410:	7bc50513          	addi	a0,a0,1980 # 80200bc8 <etext+0x1aa>
    80200414:	c59ff06f          	j	8020006c <cprintf>
            break;
        case IRQ_U_EXT:
            cprintf("User software interrupt\n");
            break;
        case IRQ_S_EXT:
            cprintf("Supervisor external interrupt\n");
    80200418:	00001517          	auipc	a0,0x1
    8020041c:	82050513          	addi	a0,a0,-2016 # 80200c38 <etext+0x21a>
    80200420:	c4dff06f          	j	8020006c <cprintf>
void interrupt_handler(struct trapframe *tf) {
    80200424:	1141                	addi	sp,sp,-16
    80200426:	e022                	sd	s0,0(sp)
    80200428:	e406                	sd	ra,8(sp)
            if(num==10){//判断打印了几次
    8020042a:	00004417          	auipc	s0,0x4
    8020042e:	be640413          	addi	s0,s0,-1050 # 80204010 <edata>
            clock_set_next_event();//发生这次时钟中断的时候，我们要设置下一次时钟中断
    80200432:	d33ff0ef          	jal	ra,80200164 <clock_set_next_event>
            if(num==10){//判断打印了几次
    80200436:	6018                	ld	a4,0(s0)
    80200438:	47a9                	li	a5,10
    8020043a:	04f70663          	beq	a4,a5,80200486 <interrupt_handler+0xc0>
            if (++ticks % TICK_NUM == 0) {
    8020043e:	00004797          	auipc	a5,0x4
    80200442:	be278793          	addi	a5,a5,-1054 # 80204020 <ticks>
    80200446:	639c                	ld	a5,0(a5)
    80200448:	06400713          	li	a4,100
    8020044c:	0785                	addi	a5,a5,1
    8020044e:	02e7f733          	remu	a4,a5,a4
    80200452:	00004697          	auipc	a3,0x4
    80200456:	bcf6b723          	sd	a5,-1074(a3) # 80204020 <ticks>
    8020045a:	c719                	beqz	a4,80200468 <interrupt_handler+0xa2>
            break;
        default:
            print_trapframe(tf);
            break;
    }
}
    8020045c:	60a2                	ld	ra,8(sp)
    8020045e:	6402                	ld	s0,0(sp)
    80200460:	0141                	addi	sp,sp,16
    80200462:	8082                	ret
            print_trapframe(tf);
    80200464:	f01ff06f          	j	80200364 <print_trapframe>
    cprintf("%d ticks\n", TICK_NUM);
    80200468:	06400593          	li	a1,100
    8020046c:	00000517          	auipc	a0,0x0
    80200470:	7bc50513          	addi	a0,a0,1980 # 80200c28 <etext+0x20a>
    80200474:	bf9ff0ef          	jal	ra,8020006c <cprintf>
                num++;
    80200478:	601c                	ld	a5,0(s0)
    8020047a:	0785                	addi	a5,a5,1
    8020047c:	00004717          	auipc	a4,0x4
    80200480:	b8f73a23          	sd	a5,-1132(a4) # 80204010 <edata>
    80200484:	bfe1                	j	8020045c <interrupt_handler+0x96>
            sbi_shutdown();//关机函数
    80200486:	544000ef          	jal	ra,802009ca <sbi_shutdown>
    8020048a:	bf55                	j	8020043e <interrupt_handler+0x78>

000000008020048c <exception_handler>:

void exception_handler(struct trapframe *tf) {
int which_dev = 0;
    switch (tf->cause) {
    8020048c:	11853783          	ld	a5,280(a0)
    80200490:	472d                	li	a4,11
    80200492:	00f76e63          	bltu	a4,a5,802004ae <exception_handler+0x22>
    80200496:	4705                	li	a4,1
    80200498:	00f71733          	sll	a4,a4,a5
    8020049c:	6785                	lui	a5,0x1
    8020049e:	17cd                	addi	a5,a5,-13
    802004a0:	8ff9                	and	a5,a5,a4
    802004a2:	eb81                	bnez	a5,802004b2 <exception_handler+0x26>
    802004a4:	00877793          	andi	a5,a4,8
    802004a8:	ef91                	bnez	a5,802004c4 <exception_handler+0x38>
    802004aa:	8b11                	andi	a4,a4,4
    802004ac:	e701                	bnez	a4,802004b4 <exception_handler+0x28>
        case CAUSE_HYPERVISOR_ECALL:
            break;
        case CAUSE_MACHINE_ECALL:
            break;
        default:
            print_trapframe(tf);
    802004ae:	eb7ff06f          	j	80200364 <print_trapframe>
            break;
    }
}
    802004b2:	8082                	ret
            cprintf("Illegal instruction caught at 0x%x\n", tf->epc);
    802004b4:	10853583          	ld	a1,264(a0)
    802004b8:	00000517          	auipc	a0,0x0
    802004bc:	6b050513          	addi	a0,a0,1712 # 80200b68 <etext+0x14a>
    802004c0:	badff06f          	j	8020006c <cprintf>
            cprintf("ebreak caught at 0x%x\n", tf->epc);
    802004c4:	10853583          	ld	a1,264(a0)
    802004c8:	00000517          	auipc	a0,0x0
    802004cc:	6c850513          	addi	a0,a0,1736 # 80200b90 <etext+0x172>
    802004d0:	b9dff06f          	j	8020006c <cprintf>

00000000802004d4 <trap>:

/* trap_dispatch - dispatch based on what type of trap occurred */
static inline void trap_dispatch(struct trapframe *tf) {
    if ((intptr_t)tf->cause < 0) {
    802004d4:	11853783          	ld	a5,280(a0)
    802004d8:	0007c463          	bltz	a5,802004e0 <trap+0xc>
        // interrupts
        interrupt_handler(tf);
    } else {
        // exceptions
        exception_handler(tf);
    802004dc:	fb1ff06f          	j	8020048c <exception_handler>
        interrupt_handler(tf);
    802004e0:	ee7ff06f          	j	802003c6 <interrupt_handler>

00000000802004e4 <__alltraps>:
    .endm

    .globl __alltraps
.align(2)
__alltraps:
    SAVE_ALL
    802004e4:	14011073          	csrw	sscratch,sp
    802004e8:	712d                	addi	sp,sp,-288
    802004ea:	e002                	sd	zero,0(sp)
    802004ec:	e406                	sd	ra,8(sp)
    802004ee:	ec0e                	sd	gp,24(sp)
    802004f0:	f012                	sd	tp,32(sp)
    802004f2:	f416                	sd	t0,40(sp)
    802004f4:	f81a                	sd	t1,48(sp)
    802004f6:	fc1e                	sd	t2,56(sp)
    802004f8:	e0a2                	sd	s0,64(sp)
    802004fa:	e4a6                	sd	s1,72(sp)
    802004fc:	e8aa                	sd	a0,80(sp)
    802004fe:	ecae                	sd	a1,88(sp)
    80200500:	f0b2                	sd	a2,96(sp)
    80200502:	f4b6                	sd	a3,104(sp)
    80200504:	f8ba                	sd	a4,112(sp)
    80200506:	fcbe                	sd	a5,120(sp)
    80200508:	e142                	sd	a6,128(sp)
    8020050a:	e546                	sd	a7,136(sp)
    8020050c:	e94a                	sd	s2,144(sp)
    8020050e:	ed4e                	sd	s3,152(sp)
    80200510:	f152                	sd	s4,160(sp)
    80200512:	f556                	sd	s5,168(sp)
    80200514:	f95a                	sd	s6,176(sp)
    80200516:	fd5e                	sd	s7,184(sp)
    80200518:	e1e2                	sd	s8,192(sp)
    8020051a:	e5e6                	sd	s9,200(sp)
    8020051c:	e9ea                	sd	s10,208(sp)
    8020051e:	edee                	sd	s11,216(sp)
    80200520:	f1f2                	sd	t3,224(sp)
    80200522:	f5f6                	sd	t4,232(sp)
    80200524:	f9fa                	sd	t5,240(sp)
    80200526:	fdfe                	sd	t6,248(sp)
    80200528:	14001473          	csrrw	s0,sscratch,zero
    8020052c:	100024f3          	csrr	s1,sstatus
    80200530:	14102973          	csrr	s2,sepc
    80200534:	143029f3          	csrr	s3,stval
    80200538:	14202a73          	csrr	s4,scause
    8020053c:	e822                	sd	s0,16(sp)
    8020053e:	e226                	sd	s1,256(sp)
    80200540:	e64a                	sd	s2,264(sp)
    80200542:	ea4e                	sd	s3,272(sp)
    80200544:	ee52                	sd	s4,280(sp)

    move  a0, sp
    80200546:	850a                	mv	a0,sp
    jal trap
    80200548:	f8dff0ef          	jal	ra,802004d4 <trap>

000000008020054c <__trapret>:
    # sp should be the same as before "jal trap"

    .globl __trapret
__trapret:
    RESTORE_ALL
    8020054c:	6492                	ld	s1,256(sp)
    8020054e:	6932                	ld	s2,264(sp)
    80200550:	10049073          	csrw	sstatus,s1
    80200554:	14191073          	csrw	sepc,s2
    80200558:	60a2                	ld	ra,8(sp)
    8020055a:	61e2                	ld	gp,24(sp)
    8020055c:	7202                	ld	tp,32(sp)
    8020055e:	72a2                	ld	t0,40(sp)
    80200560:	7342                	ld	t1,48(sp)
    80200562:	73e2                	ld	t2,56(sp)
    80200564:	6406                	ld	s0,64(sp)
    80200566:	64a6                	ld	s1,72(sp)
    80200568:	6546                	ld	a0,80(sp)
    8020056a:	65e6                	ld	a1,88(sp)
    8020056c:	7606                	ld	a2,96(sp)
    8020056e:	76a6                	ld	a3,104(sp)
    80200570:	7746                	ld	a4,112(sp)
    80200572:	77e6                	ld	a5,120(sp)
    80200574:	680a                	ld	a6,128(sp)
    80200576:	68aa                	ld	a7,136(sp)
    80200578:	694a                	ld	s2,144(sp)
    8020057a:	69ea                	ld	s3,152(sp)
    8020057c:	7a0a                	ld	s4,160(sp)
    8020057e:	7aaa                	ld	s5,168(sp)
    80200580:	7b4a                	ld	s6,176(sp)
    80200582:	7bea                	ld	s7,184(sp)
    80200584:	6c0e                	ld	s8,192(sp)
    80200586:	6cae                	ld	s9,200(sp)
    80200588:	6d4e                	ld	s10,208(sp)
    8020058a:	6dee                	ld	s11,216(sp)
    8020058c:	7e0e                	ld	t3,224(sp)
    8020058e:	7eae                	ld	t4,232(sp)
    80200590:	7f4e                	ld	t5,240(sp)
    80200592:	7fee                	ld	t6,248(sp)
    80200594:	6142                	ld	sp,16(sp)
    # return from supervisor call
    sret
    80200596:	10200073          	sret

000000008020059a <printnum>:
 * */
static void
printnum(void (*putch)(int, void*), void *putdat,
        unsigned long long num, unsigned base, int width, int padc) {
    unsigned long long result = num;
    unsigned mod = do_div(result, base);
    8020059a:	02069813          	slli	a6,a3,0x20
        unsigned long long num, unsigned base, int width, int padc) {
    8020059e:	7179                	addi	sp,sp,-48
    unsigned mod = do_div(result, base);
    802005a0:	02085813          	srli	a6,a6,0x20
        unsigned long long num, unsigned base, int width, int padc) {
    802005a4:	e052                	sd	s4,0(sp)
    unsigned mod = do_div(result, base);
    802005a6:	03067a33          	remu	s4,a2,a6
        unsigned long long num, unsigned base, int width, int padc) {
    802005aa:	f022                	sd	s0,32(sp)
    802005ac:	ec26                	sd	s1,24(sp)
    802005ae:	e84a                	sd	s2,16(sp)
    802005b0:	f406                	sd	ra,40(sp)
    802005b2:	e44e                	sd	s3,8(sp)
    802005b4:	84aa                	mv	s1,a0
    802005b6:	892e                	mv	s2,a1
    802005b8:	fff7041b          	addiw	s0,a4,-1
    unsigned mod = do_div(result, base);
    802005bc:	2a01                	sext.w	s4,s4

    // first recursively print all preceding (more significant) digits
    if (num >= base) {
    802005be:	03067e63          	bleu	a6,a2,802005fa <printnum+0x60>
    802005c2:	89be                	mv	s3,a5
        printnum(putch, putdat, result, base, width - 1, padc);
    } else {
        // print any needed pad characters before first digit
        while (-- width > 0)
    802005c4:	00805763          	blez	s0,802005d2 <printnum+0x38>
    802005c8:	347d                	addiw	s0,s0,-1
            putch(padc, putdat);
    802005ca:	85ca                	mv	a1,s2
    802005cc:	854e                	mv	a0,s3
    802005ce:	9482                	jalr	s1
        while (-- width > 0)
    802005d0:	fc65                	bnez	s0,802005c8 <printnum+0x2e>
    }
    // then print this (the least significant) digit
    putch("0123456789abcdef"[mod], putdat);
    802005d2:	1a02                	slli	s4,s4,0x20
    802005d4:	020a5a13          	srli	s4,s4,0x20
    802005d8:	00001797          	auipc	a5,0x1
    802005dc:	b8878793          	addi	a5,a5,-1144 # 80201160 <error_string+0x38>
    802005e0:	9a3e                	add	s4,s4,a5
}
    802005e2:	7402                	ld	s0,32(sp)
    putch("0123456789abcdef"[mod], putdat);
    802005e4:	000a4503          	lbu	a0,0(s4)
}
    802005e8:	70a2                	ld	ra,40(sp)
    802005ea:	69a2                	ld	s3,8(sp)
    802005ec:	6a02                	ld	s4,0(sp)
    putch("0123456789abcdef"[mod], putdat);
    802005ee:	85ca                	mv	a1,s2
    802005f0:	8326                	mv	t1,s1
}
    802005f2:	6942                	ld	s2,16(sp)
    802005f4:	64e2                	ld	s1,24(sp)
    802005f6:	6145                	addi	sp,sp,48
    putch("0123456789abcdef"[mod], putdat);
    802005f8:	8302                	jr	t1
        printnum(putch, putdat, result, base, width - 1, padc);
    802005fa:	03065633          	divu	a2,a2,a6
    802005fe:	8722                	mv	a4,s0
    80200600:	f9bff0ef          	jal	ra,8020059a <printnum>
    80200604:	b7f9                	j	802005d2 <printnum+0x38>

0000000080200606 <vprintfmt>:
 *
 * Call this function if you are already dealing with a va_list.
 * Or you probably want printfmt() instead.
 * */
void
vprintfmt(void (*putch)(int, void*), void *putdat, const char *fmt, va_list ap) {
    80200606:	7119                	addi	sp,sp,-128
    80200608:	f4a6                	sd	s1,104(sp)
    8020060a:	f0ca                	sd	s2,96(sp)
    8020060c:	e8d2                	sd	s4,80(sp)
    8020060e:	e4d6                	sd	s5,72(sp)
    80200610:	e0da                	sd	s6,64(sp)
    80200612:	fc5e                	sd	s7,56(sp)
    80200614:	f862                	sd	s8,48(sp)
    80200616:	f06a                	sd	s10,32(sp)
    80200618:	fc86                	sd	ra,120(sp)
    8020061a:	f8a2                	sd	s0,112(sp)
    8020061c:	ecce                	sd	s3,88(sp)
    8020061e:	f466                	sd	s9,40(sp)
    80200620:	ec6e                	sd	s11,24(sp)
    80200622:	892a                	mv	s2,a0
    80200624:	84ae                	mv	s1,a1
    80200626:	8d32                	mv	s10,a2
    80200628:	8ab6                	mv	s5,a3
            putch(ch, putdat);
        }

        // Process a %-escape sequence
        char padc = ' ';
        width = precision = -1;
    8020062a:	5b7d                	li	s6,-1
        lflag = altflag = 0;

    reswitch:
        switch (ch = *(unsigned char *)fmt ++) {
    8020062c:	00001a17          	auipc	s4,0x1
    80200630:	9a0a0a13          	addi	s4,s4,-1632 # 80200fcc <etext+0x5ae>
                for (width -= strnlen(p, precision); width > 0; width --) {
                    putch(padc, putdat);
                }
            }
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
                if (altflag && (ch < ' ' || ch > '~')) {
    80200634:	05e00b93          	li	s7,94
            if (err > MAXERROR || (p = error_string[err]) == NULL) {
    80200638:	00001c17          	auipc	s8,0x1
    8020063c:	af0c0c13          	addi	s8,s8,-1296 # 80201128 <error_string>
        while ((ch = *(unsigned char *)fmt ++) != '%') {
    80200640:	000d4503          	lbu	a0,0(s10)
    80200644:	02500793          	li	a5,37
    80200648:	001d0413          	addi	s0,s10,1
    8020064c:	00f50e63          	beq	a0,a5,80200668 <vprintfmt+0x62>
            if (ch == '\0') {
    80200650:	c521                	beqz	a0,80200698 <vprintfmt+0x92>
        while ((ch = *(unsigned char *)fmt ++) != '%') {
    80200652:	02500993          	li	s3,37
    80200656:	a011                	j	8020065a <vprintfmt+0x54>
            if (ch == '\0') {
    80200658:	c121                	beqz	a0,80200698 <vprintfmt+0x92>
            putch(ch, putdat);
    8020065a:	85a6                	mv	a1,s1
        while ((ch = *(unsigned char *)fmt ++) != '%') {
    8020065c:	0405                	addi	s0,s0,1
            putch(ch, putdat);
    8020065e:	9902                	jalr	s2
        while ((ch = *(unsigned char *)fmt ++) != '%') {
    80200660:	fff44503          	lbu	a0,-1(s0)
    80200664:	ff351ae3          	bne	a0,s3,80200658 <vprintfmt+0x52>
    80200668:	00044603          	lbu	a2,0(s0)
        char padc = ' ';
    8020066c:	02000793          	li	a5,32
        lflag = altflag = 0;
    80200670:	4981                	li	s3,0
    80200672:	4801                	li	a6,0
        width = precision = -1;
    80200674:	5cfd                	li	s9,-1
    80200676:	5dfd                	li	s11,-1
        switch (ch = *(unsigned char *)fmt ++) {
    80200678:	05500593          	li	a1,85
                if (ch < '0' || ch > '9') {
    8020067c:	4525                	li	a0,9
        switch (ch = *(unsigned char *)fmt ++) {
    8020067e:	fdd6069b          	addiw	a3,a2,-35
    80200682:	0ff6f693          	andi	a3,a3,255
    80200686:	00140d13          	addi	s10,s0,1
    8020068a:	20d5e563          	bltu	a1,a3,80200894 <vprintfmt+0x28e>
    8020068e:	068a                	slli	a3,a3,0x2
    80200690:	96d2                	add	a3,a3,s4
    80200692:	4294                	lw	a3,0(a3)
    80200694:	96d2                	add	a3,a3,s4
    80200696:	8682                	jr	a3
            for (fmt --; fmt[-1] != '%'; fmt --)
                /* do nothing */;
            break;
        }
    }
}
    80200698:	70e6                	ld	ra,120(sp)
    8020069a:	7446                	ld	s0,112(sp)
    8020069c:	74a6                	ld	s1,104(sp)
    8020069e:	7906                	ld	s2,96(sp)
    802006a0:	69e6                	ld	s3,88(sp)
    802006a2:	6a46                	ld	s4,80(sp)
    802006a4:	6aa6                	ld	s5,72(sp)
    802006a6:	6b06                	ld	s6,64(sp)
    802006a8:	7be2                	ld	s7,56(sp)
    802006aa:	7c42                	ld	s8,48(sp)
    802006ac:	7ca2                	ld	s9,40(sp)
    802006ae:	7d02                	ld	s10,32(sp)
    802006b0:	6de2                	ld	s11,24(sp)
    802006b2:	6109                	addi	sp,sp,128
    802006b4:	8082                	ret
    if (lflag >= 2) {
    802006b6:	4705                	li	a4,1
    802006b8:	008a8593          	addi	a1,s5,8
    802006bc:	01074463          	blt	a4,a6,802006c4 <vprintfmt+0xbe>
    else if (lflag) {
    802006c0:	26080363          	beqz	a6,80200926 <vprintfmt+0x320>
        return va_arg(*ap, unsigned long);
    802006c4:	000ab603          	ld	a2,0(s5)
    802006c8:	46c1                	li	a3,16
    802006ca:	8aae                	mv	s5,a1
    802006cc:	a06d                	j	80200776 <vprintfmt+0x170>
            goto reswitch;
    802006ce:	00144603          	lbu	a2,1(s0)
            altflag = 1;
    802006d2:	4985                	li	s3,1
        switch (ch = *(unsigned char *)fmt ++) {
    802006d4:	846a                	mv	s0,s10
            goto reswitch;
    802006d6:	b765                	j	8020067e <vprintfmt+0x78>
            putch(va_arg(ap, int), putdat);
    802006d8:	000aa503          	lw	a0,0(s5)
    802006dc:	85a6                	mv	a1,s1
    802006de:	0aa1                	addi	s5,s5,8
    802006e0:	9902                	jalr	s2
            break;
    802006e2:	bfb9                	j	80200640 <vprintfmt+0x3a>
    if (lflag >= 2) {
    802006e4:	4705                	li	a4,1
    802006e6:	008a8993          	addi	s3,s5,8
    802006ea:	01074463          	blt	a4,a6,802006f2 <vprintfmt+0xec>
    else if (lflag) {
    802006ee:	22080463          	beqz	a6,80200916 <vprintfmt+0x310>
        return va_arg(*ap, long);
    802006f2:	000ab403          	ld	s0,0(s5)
            if ((long long)num < 0) {
    802006f6:	24044463          	bltz	s0,8020093e <vprintfmt+0x338>
            num = getint(&ap, lflag);
    802006fa:	8622                	mv	a2,s0
    802006fc:	8ace                	mv	s5,s3
    802006fe:	46a9                	li	a3,10
    80200700:	a89d                	j	80200776 <vprintfmt+0x170>
            err = va_arg(ap, int);
    80200702:	000aa783          	lw	a5,0(s5)
            if (err > MAXERROR || (p = error_string[err]) == NULL) {
    80200706:	4719                	li	a4,6
            err = va_arg(ap, int);
    80200708:	0aa1                	addi	s5,s5,8
            if (err < 0) {
    8020070a:	41f7d69b          	sraiw	a3,a5,0x1f
    8020070e:	8fb5                	xor	a5,a5,a3
    80200710:	40d786bb          	subw	a3,a5,a3
            if (err > MAXERROR || (p = error_string[err]) == NULL) {
    80200714:	1ad74363          	blt	a4,a3,802008ba <vprintfmt+0x2b4>
    80200718:	00369793          	slli	a5,a3,0x3
    8020071c:	97e2                	add	a5,a5,s8
    8020071e:	639c                	ld	a5,0(a5)
    80200720:	18078d63          	beqz	a5,802008ba <vprintfmt+0x2b4>
                printfmt(putch, putdat, "%s", p);
    80200724:	86be                	mv	a3,a5
    80200726:	00001617          	auipc	a2,0x1
    8020072a:	aea60613          	addi	a2,a2,-1302 # 80201210 <error_string+0xe8>
    8020072e:	85a6                	mv	a1,s1
    80200730:	854a                	mv	a0,s2
    80200732:	240000ef          	jal	ra,80200972 <printfmt>
    80200736:	b729                	j	80200640 <vprintfmt+0x3a>
            lflag ++;
    80200738:	00144603          	lbu	a2,1(s0)
    8020073c:	2805                	addiw	a6,a6,1
        switch (ch = *(unsigned char *)fmt ++) {
    8020073e:	846a                	mv	s0,s10
            goto reswitch;
    80200740:	bf3d                	j	8020067e <vprintfmt+0x78>
    if (lflag >= 2) {
    80200742:	4705                	li	a4,1
    80200744:	008a8593          	addi	a1,s5,8
    80200748:	01074463          	blt	a4,a6,80200750 <vprintfmt+0x14a>
    else if (lflag) {
    8020074c:	1e080263          	beqz	a6,80200930 <vprintfmt+0x32a>
        return va_arg(*ap, unsigned long);
    80200750:	000ab603          	ld	a2,0(s5)
    80200754:	46a1                	li	a3,8
    80200756:	8aae                	mv	s5,a1
    80200758:	a839                	j	80200776 <vprintfmt+0x170>
            putch('0', putdat);
    8020075a:	03000513          	li	a0,48
    8020075e:	85a6                	mv	a1,s1
    80200760:	e03e                	sd	a5,0(sp)
    80200762:	9902                	jalr	s2
            putch('x', putdat);
    80200764:	85a6                	mv	a1,s1
    80200766:	07800513          	li	a0,120
    8020076a:	9902                	jalr	s2
            num = (unsigned long long)va_arg(ap, void *);
    8020076c:	0aa1                	addi	s5,s5,8
    8020076e:	ff8ab603          	ld	a2,-8(s5)
            goto number;
    80200772:	6782                	ld	a5,0(sp)
    80200774:	46c1                	li	a3,16
            printnum(putch, putdat, num, base, width, padc);
    80200776:	876e                	mv	a4,s11
    80200778:	85a6                	mv	a1,s1
    8020077a:	854a                	mv	a0,s2
    8020077c:	e1fff0ef          	jal	ra,8020059a <printnum>
            break;
    80200780:	b5c1                	j	80200640 <vprintfmt+0x3a>
            if ((p = va_arg(ap, char *)) == NULL) {
    80200782:	000ab603          	ld	a2,0(s5)
    80200786:	0aa1                	addi	s5,s5,8
    80200788:	1c060663          	beqz	a2,80200954 <vprintfmt+0x34e>
            if (width > 0 && padc != '-') {
    8020078c:	00160413          	addi	s0,a2,1
    80200790:	17b05c63          	blez	s11,80200908 <vprintfmt+0x302>
    80200794:	02d00593          	li	a1,45
    80200798:	14b79263          	bne	a5,a1,802008dc <vprintfmt+0x2d6>
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
    8020079c:	00064783          	lbu	a5,0(a2)
    802007a0:	0007851b          	sext.w	a0,a5
    802007a4:	c905                	beqz	a0,802007d4 <vprintfmt+0x1ce>
    802007a6:	000cc563          	bltz	s9,802007b0 <vprintfmt+0x1aa>
    802007aa:	3cfd                	addiw	s9,s9,-1
    802007ac:	036c8263          	beq	s9,s6,802007d0 <vprintfmt+0x1ca>
                    putch('?', putdat);
    802007b0:	85a6                	mv	a1,s1
                if (altflag && (ch < ' ' || ch > '~')) {
    802007b2:	18098463          	beqz	s3,8020093a <vprintfmt+0x334>
    802007b6:	3781                	addiw	a5,a5,-32
    802007b8:	18fbf163          	bleu	a5,s7,8020093a <vprintfmt+0x334>
                    putch('?', putdat);
    802007bc:	03f00513          	li	a0,63
    802007c0:	9902                	jalr	s2
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
    802007c2:	0405                	addi	s0,s0,1
    802007c4:	fff44783          	lbu	a5,-1(s0)
    802007c8:	3dfd                	addiw	s11,s11,-1
    802007ca:	0007851b          	sext.w	a0,a5
    802007ce:	fd61                	bnez	a0,802007a6 <vprintfmt+0x1a0>
            for (; width > 0; width --) {
    802007d0:	e7b058e3          	blez	s11,80200640 <vprintfmt+0x3a>
    802007d4:	3dfd                	addiw	s11,s11,-1
                putch(' ', putdat);
    802007d6:	85a6                	mv	a1,s1
    802007d8:	02000513          	li	a0,32
    802007dc:	9902                	jalr	s2
            for (; width > 0; width --) {
    802007de:	e60d81e3          	beqz	s11,80200640 <vprintfmt+0x3a>
    802007e2:	3dfd                	addiw	s11,s11,-1
                putch(' ', putdat);
    802007e4:	85a6                	mv	a1,s1
    802007e6:	02000513          	li	a0,32
    802007ea:	9902                	jalr	s2
            for (; width > 0; width --) {
    802007ec:	fe0d94e3          	bnez	s11,802007d4 <vprintfmt+0x1ce>
    802007f0:	bd81                	j	80200640 <vprintfmt+0x3a>
    if (lflag >= 2) {
    802007f2:	4705                	li	a4,1
    802007f4:	008a8593          	addi	a1,s5,8
    802007f8:	01074463          	blt	a4,a6,80200800 <vprintfmt+0x1fa>
    else if (lflag) {
    802007fc:	12080063          	beqz	a6,8020091c <vprintfmt+0x316>
        return va_arg(*ap, unsigned long);
    80200800:	000ab603          	ld	a2,0(s5)
    80200804:	46a9                	li	a3,10
    80200806:	8aae                	mv	s5,a1
    80200808:	b7bd                	j	80200776 <vprintfmt+0x170>
    8020080a:	00144603          	lbu	a2,1(s0)
            padc = '-';
    8020080e:	02d00793          	li	a5,45
        switch (ch = *(unsigned char *)fmt ++) {
    80200812:	846a                	mv	s0,s10
    80200814:	b5ad                	j	8020067e <vprintfmt+0x78>
            putch(ch, putdat);
    80200816:	85a6                	mv	a1,s1
    80200818:	02500513          	li	a0,37
    8020081c:	9902                	jalr	s2
            break;
    8020081e:	b50d                	j	80200640 <vprintfmt+0x3a>
            precision = va_arg(ap, int);
    80200820:	000aac83          	lw	s9,0(s5)
            goto process_precision;
    80200824:	00144603          	lbu	a2,1(s0)
            precision = va_arg(ap, int);
    80200828:	0aa1                	addi	s5,s5,8
        switch (ch = *(unsigned char *)fmt ++) {
    8020082a:	846a                	mv	s0,s10
            if (width < 0)
    8020082c:	e40dd9e3          	bgez	s11,8020067e <vprintfmt+0x78>
                width = precision, precision = -1;
    80200830:	8de6                	mv	s11,s9
    80200832:	5cfd                	li	s9,-1
    80200834:	b5a9                	j	8020067e <vprintfmt+0x78>
            goto reswitch;
    80200836:	00144603          	lbu	a2,1(s0)
            padc = '0';
    8020083a:	03000793          	li	a5,48
        switch (ch = *(unsigned char *)fmt ++) {
    8020083e:	846a                	mv	s0,s10
            goto reswitch;
    80200840:	bd3d                	j	8020067e <vprintfmt+0x78>
                precision = precision * 10 + ch - '0';
    80200842:	fd060c9b          	addiw	s9,a2,-48
                ch = *fmt;
    80200846:	00144603          	lbu	a2,1(s0)
        switch (ch = *(unsigned char *)fmt ++) {
    8020084a:	846a                	mv	s0,s10
                if (ch < '0' || ch > '9') {
    8020084c:	fd06069b          	addiw	a3,a2,-48
                ch = *fmt;
    80200850:	0006089b          	sext.w	a7,a2
                if (ch < '0' || ch > '9') {
    80200854:	fcd56ce3          	bltu	a0,a3,8020082c <vprintfmt+0x226>
            for (precision = 0; ; ++ fmt) {
    80200858:	0405                	addi	s0,s0,1
                precision = precision * 10 + ch - '0';
    8020085a:	002c969b          	slliw	a3,s9,0x2
                ch = *fmt;
    8020085e:	00044603          	lbu	a2,0(s0)
                precision = precision * 10 + ch - '0';
    80200862:	0196873b          	addw	a4,a3,s9
    80200866:	0017171b          	slliw	a4,a4,0x1
    8020086a:	0117073b          	addw	a4,a4,a7
                if (ch < '0' || ch > '9') {
    8020086e:	fd06069b          	addiw	a3,a2,-48
                precision = precision * 10 + ch - '0';
    80200872:	fd070c9b          	addiw	s9,a4,-48
                ch = *fmt;
    80200876:	0006089b          	sext.w	a7,a2
                if (ch < '0' || ch > '9') {
    8020087a:	fcd57fe3          	bleu	a3,a0,80200858 <vprintfmt+0x252>
    8020087e:	b77d                	j	8020082c <vprintfmt+0x226>
            if (width < 0)
    80200880:	fffdc693          	not	a3,s11
    80200884:	96fd                	srai	a3,a3,0x3f
    80200886:	00ddfdb3          	and	s11,s11,a3
    8020088a:	00144603          	lbu	a2,1(s0)
    8020088e:	2d81                	sext.w	s11,s11
        switch (ch = *(unsigned char *)fmt ++) {
    80200890:	846a                	mv	s0,s10
    80200892:	b3f5                	j	8020067e <vprintfmt+0x78>
            putch('%', putdat);
    80200894:	85a6                	mv	a1,s1
    80200896:	02500513          	li	a0,37
    8020089a:	9902                	jalr	s2
            for (fmt --; fmt[-1] != '%'; fmt --)
    8020089c:	fff44703          	lbu	a4,-1(s0)
    802008a0:	02500793          	li	a5,37
    802008a4:	8d22                	mv	s10,s0
    802008a6:	d8f70de3          	beq	a4,a5,80200640 <vprintfmt+0x3a>
    802008aa:	02500713          	li	a4,37
    802008ae:	1d7d                	addi	s10,s10,-1
    802008b0:	fffd4783          	lbu	a5,-1(s10)
    802008b4:	fee79de3          	bne	a5,a4,802008ae <vprintfmt+0x2a8>
    802008b8:	b361                	j	80200640 <vprintfmt+0x3a>
                printfmt(putch, putdat, "error %d", err);
    802008ba:	00001617          	auipc	a2,0x1
    802008be:	94660613          	addi	a2,a2,-1722 # 80201200 <error_string+0xd8>
    802008c2:	85a6                	mv	a1,s1
    802008c4:	854a                	mv	a0,s2
    802008c6:	0ac000ef          	jal	ra,80200972 <printfmt>
    802008ca:	bb9d                	j	80200640 <vprintfmt+0x3a>
                p = "(null)";
    802008cc:	00001617          	auipc	a2,0x1
    802008d0:	92c60613          	addi	a2,a2,-1748 # 802011f8 <error_string+0xd0>
            if (width > 0 && padc != '-') {
    802008d4:	00001417          	auipc	s0,0x1
    802008d8:	92540413          	addi	s0,s0,-1755 # 802011f9 <error_string+0xd1>
                for (width -= strnlen(p, precision); width > 0; width --) {
    802008dc:	8532                	mv	a0,a2
    802008de:	85e6                	mv	a1,s9
    802008e0:	e032                	sd	a2,0(sp)
    802008e2:	e43e                	sd	a5,8(sp)
    802008e4:	102000ef          	jal	ra,802009e6 <strnlen>
    802008e8:	40ad8dbb          	subw	s11,s11,a0
    802008ec:	6602                	ld	a2,0(sp)
    802008ee:	01b05d63          	blez	s11,80200908 <vprintfmt+0x302>
    802008f2:	67a2                	ld	a5,8(sp)
    802008f4:	2781                	sext.w	a5,a5
    802008f6:	e43e                	sd	a5,8(sp)
                    putch(padc, putdat);
    802008f8:	6522                	ld	a0,8(sp)
    802008fa:	85a6                	mv	a1,s1
    802008fc:	e032                	sd	a2,0(sp)
                for (width -= strnlen(p, precision); width > 0; width --) {
    802008fe:	3dfd                	addiw	s11,s11,-1
                    putch(padc, putdat);
    80200900:	9902                	jalr	s2
                for (width -= strnlen(p, precision); width > 0; width --) {
    80200902:	6602                	ld	a2,0(sp)
    80200904:	fe0d9ae3          	bnez	s11,802008f8 <vprintfmt+0x2f2>
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
    80200908:	00064783          	lbu	a5,0(a2)
    8020090c:	0007851b          	sext.w	a0,a5
    80200910:	e8051be3          	bnez	a0,802007a6 <vprintfmt+0x1a0>
    80200914:	b335                	j	80200640 <vprintfmt+0x3a>
        return va_arg(*ap, int);
    80200916:	000aa403          	lw	s0,0(s5)
    8020091a:	bbf1                	j	802006f6 <vprintfmt+0xf0>
        return va_arg(*ap, unsigned int);
    8020091c:	000ae603          	lwu	a2,0(s5)
    80200920:	46a9                	li	a3,10
    80200922:	8aae                	mv	s5,a1
    80200924:	bd89                	j	80200776 <vprintfmt+0x170>
    80200926:	000ae603          	lwu	a2,0(s5)
    8020092a:	46c1                	li	a3,16
    8020092c:	8aae                	mv	s5,a1
    8020092e:	b5a1                	j	80200776 <vprintfmt+0x170>
    80200930:	000ae603          	lwu	a2,0(s5)
    80200934:	46a1                	li	a3,8
    80200936:	8aae                	mv	s5,a1
    80200938:	bd3d                	j	80200776 <vprintfmt+0x170>
                    putch(ch, putdat);
    8020093a:	9902                	jalr	s2
    8020093c:	b559                	j	802007c2 <vprintfmt+0x1bc>
                putch('-', putdat);
    8020093e:	85a6                	mv	a1,s1
    80200940:	02d00513          	li	a0,45
    80200944:	e03e                	sd	a5,0(sp)
    80200946:	9902                	jalr	s2
                num = -(long long)num;
    80200948:	8ace                	mv	s5,s3
    8020094a:	40800633          	neg	a2,s0
    8020094e:	46a9                	li	a3,10
    80200950:	6782                	ld	a5,0(sp)
    80200952:	b515                	j	80200776 <vprintfmt+0x170>
            if (width > 0 && padc != '-') {
    80200954:	01b05663          	blez	s11,80200960 <vprintfmt+0x35a>
    80200958:	02d00693          	li	a3,45
    8020095c:	f6d798e3          	bne	a5,a3,802008cc <vprintfmt+0x2c6>
    80200960:	00001417          	auipc	s0,0x1
    80200964:	89940413          	addi	s0,s0,-1895 # 802011f9 <error_string+0xd1>
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
    80200968:	02800513          	li	a0,40
    8020096c:	02800793          	li	a5,40
    80200970:	bd1d                	j	802007a6 <vprintfmt+0x1a0>

0000000080200972 <printfmt>:
printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...) {
    80200972:	715d                	addi	sp,sp,-80
    va_start(ap, fmt);
    80200974:	02810313          	addi	t1,sp,40
printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...) {
    80200978:	f436                	sd	a3,40(sp)
    vprintfmt(putch, putdat, fmt, ap);
    8020097a:	869a                	mv	a3,t1
printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...) {
    8020097c:	ec06                	sd	ra,24(sp)
    8020097e:	f83a                	sd	a4,48(sp)
    80200980:	fc3e                	sd	a5,56(sp)
    80200982:	e0c2                	sd	a6,64(sp)
    80200984:	e4c6                	sd	a7,72(sp)
    va_start(ap, fmt);
    80200986:	e41a                	sd	t1,8(sp)
    vprintfmt(putch, putdat, fmt, ap);
    80200988:	c7fff0ef          	jal	ra,80200606 <vprintfmt>
}
    8020098c:	60e2                	ld	ra,24(sp)
    8020098e:	6161                	addi	sp,sp,80
    80200990:	8082                	ret

0000000080200992 <sbi_console_putchar>:

int sbi_console_getchar(void) {
    return sbi_call(SBI_CONSOLE_GETCHAR, 0, 0, 0);
}
void sbi_console_putchar(unsigned char ch) {
    sbi_call(SBI_CONSOLE_PUTCHAR, ch, 0, 0);
    80200992:	00003797          	auipc	a5,0x3
    80200996:	66e78793          	addi	a5,a5,1646 # 80204000 <bootstacktop>
    __asm__ volatile (
    8020099a:	6398                	ld	a4,0(a5)
    8020099c:	4781                	li	a5,0
    8020099e:	88ba                	mv	a7,a4
    802009a0:	852a                	mv	a0,a0
    802009a2:	85be                	mv	a1,a5
    802009a4:	863e                	mv	a2,a5
    802009a6:	00000073          	ecall
    802009aa:	87aa                	mv	a5,a0
}
    802009ac:	8082                	ret

00000000802009ae <sbi_set_timer>:

void sbi_set_timer(unsigned long long stime_value) {
    sbi_call(SBI_SET_TIMER, stime_value, 0, 0);
    802009ae:	00003797          	auipc	a5,0x3
    802009b2:	66a78793          	addi	a5,a5,1642 # 80204018 <SBI_SET_TIMER>
    __asm__ volatile (
    802009b6:	6398                	ld	a4,0(a5)
    802009b8:	4781                	li	a5,0
    802009ba:	88ba                	mv	a7,a4
    802009bc:	852a                	mv	a0,a0
    802009be:	85be                	mv	a1,a5
    802009c0:	863e                	mv	a2,a5
    802009c2:	00000073          	ecall
    802009c6:	87aa                	mv	a5,a0
}
    802009c8:	8082                	ret

00000000802009ca <sbi_shutdown>:


void sbi_shutdown(void)
{
    sbi_call(SBI_SHUTDOWN,0,0,0);
    802009ca:	00003797          	auipc	a5,0x3
    802009ce:	63e78793          	addi	a5,a5,1598 # 80204008 <SBI_SHUTDOWN>
    __asm__ volatile (
    802009d2:	6398                	ld	a4,0(a5)
    802009d4:	4781                	li	a5,0
    802009d6:	88ba                	mv	a7,a4
    802009d8:	853e                	mv	a0,a5
    802009da:	85be                	mv	a1,a5
    802009dc:	863e                	mv	a2,a5
    802009de:	00000073          	ecall
    802009e2:	87aa                	mv	a5,a0
    802009e4:	8082                	ret

00000000802009e6 <strnlen>:
 * pointed by @s.
 * */
size_t
strnlen(const char *s, size_t len) {
    size_t cnt = 0;
    while (cnt < len && *s ++ != '\0') {
    802009e6:	c185                	beqz	a1,80200a06 <strnlen+0x20>
    802009e8:	00054783          	lbu	a5,0(a0)
    802009ec:	cf89                	beqz	a5,80200a06 <strnlen+0x20>
    size_t cnt = 0;
    802009ee:	4781                	li	a5,0
    802009f0:	a021                	j	802009f8 <strnlen+0x12>
    while (cnt < len && *s ++ != '\0') {
    802009f2:	00074703          	lbu	a4,0(a4)
    802009f6:	c711                	beqz	a4,80200a02 <strnlen+0x1c>
        cnt ++;
    802009f8:	0785                	addi	a5,a5,1
    while (cnt < len && *s ++ != '\0') {
    802009fa:	00f50733          	add	a4,a0,a5
    802009fe:	fef59ae3          	bne	a1,a5,802009f2 <strnlen+0xc>
    }
    return cnt;
}
    80200a02:	853e                	mv	a0,a5
    80200a04:	8082                	ret
    size_t cnt = 0;
    80200a06:	4781                	li	a5,0
}
    80200a08:	853e                	mv	a0,a5
    80200a0a:	8082                	ret

0000000080200a0c <memset>:
memset(void *s, char c, size_t n) {
#ifdef __HAVE_ARCH_MEMSET
    return __memset(s, c, n);
#else
    char *p = s;
    while (n -- > 0) {
    80200a0c:	ca01                	beqz	a2,80200a1c <memset+0x10>
    80200a0e:	962a                	add	a2,a2,a0
    char *p = s;
    80200a10:	87aa                	mv	a5,a0
        *p ++ = c;
    80200a12:	0785                	addi	a5,a5,1
    80200a14:	feb78fa3          	sb	a1,-1(a5)
    while (n -- > 0) {
    80200a18:	fec79de3          	bne	a5,a2,80200a12 <memset+0x6>
    }
    return s;
#endif /* __HAVE_ARCH_MEMSET */
}
    80200a1c:	8082                	ret
