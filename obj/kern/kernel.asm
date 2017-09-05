
obj/kern/kernel:     file format elf32-i386


Disassembly of section .text:

f0100000 <_start+0xeffffff4>:
.globl      _start
_start = RELOC(entry)

.globl entry
entry:
    movw    $0x1234,0x472           # warm boot
f0100000:	02 b0 ad 1b 00 00    	add    0x1bad(%eax),%dh
f0100006:	00 00                	add    %al,(%eax)
f0100008:	fe 4f 52             	decb   0x52(%edi)
f010000b:	e4                   	.byte 0xe4

f010000c <entry>:
f010000c:	66 c7 05 72 04 00 00 	movw   $0x1234,0x472
f0100013:	34 12 
    # sufficient until we set up our real page table in mem_init
    # in lab 2.

    # Load the physical address of entry_pgdir into cr3.  entry_pgdir
    # is defined in entrypgdir.c.
    movl    $(RELOC(entry_pgdir)), %eax
f0100015:	b8 00 20 11 00       	mov    $0x112000,%eax
    movl    %eax, %cr3
f010001a:	0f 22 d8             	mov    %eax,%cr3
    # Turn on paging.
    movl    %cr0, %eax
f010001d:	0f 20 c0             	mov    %cr0,%eax
    orl $(CR0_PE|CR0_PG|CR0_WP), %eax
f0100020:	0d 01 00 01 80       	or     $0x80010001,%eax
    movl    %eax, %cr0
f0100025:	0f 22 c0             	mov    %eax,%cr0

    # Now paging is enabled, but we're still running at a low EIP
    # (why is this okay?).  Jump up above KERNBASE before entering
    # C code.
    mov $relocated, %eax
f0100028:	b8 2f 00 10 f0       	mov    $0xf010002f,%eax
    jmp *%eax
f010002d:	ff e0                	jmp    *%eax

f010002f <relocated>:
relocated:

    # Clear the frame pointer register (EBP)
    # so that once we get into debugging C code,
    # stack backtraces will be terminated properly.
    movl    $0x0,%ebp           # nuke frame pointer
f010002f:	bd 00 00 00 00       	mov    $0x0,%ebp

    # Set the stack pointer
    movl    $(bootstacktop),%esp
f0100034:	bc 00 20 11 f0       	mov    $0xf0112000,%esp

    # now to C code
    call    i386_init
f0100039:	e8 02 00 00 00       	call   f0100040 <i386_init>

f010003e <spin>:

    # Should never get here, but in case we do, just spin.
spin:   jmp spin
f010003e:	eb fe                	jmp    f010003e <spin>

f0100040 <i386_init>:
#include <kern/pmap.h>
#include <kern/kclock.h>


void i386_init(void)
{
f0100040:	55                   	push   %ebp
f0100041:	89 e5                	mov    %esp,%ebp
f0100043:	83 ec 0c             	sub    $0xc,%esp
    extern char edata[], end[];

    /* Before doing anything else, complete the ELF loading process.
     * Clear the uninitialized global data (BSS) section of our program.
     * This ensures that all static/global variables start out zero. */
    memset(edata, 0, end - edata);
f0100046:	b8 6c 49 11 f0       	mov    $0xf011496c,%eax
f010004b:	2d 00 43 11 f0       	sub    $0xf0114300,%eax
f0100050:	50                   	push   %eax
f0100051:	6a 00                	push   $0x0
f0100053:	68 00 43 11 f0       	push   $0xf0114300
f0100058:	e8 cf 1b 00 00       	call   f0101c2c <memset>

    /* Initialize the console.
     * Can't call cprintf until after we do this! */
    cons_init();
f010005d:	e8 a6 05 00 00       	call   f0100608 <cons_init>

    /* Lab 1 memory management initialization functions */
    mem_init();
f0100062:	e8 83 0e 00 00       	call   f0100eea <mem_init>
f0100067:	83 c4 10             	add    $0x10,%esp

    /* Drop into the kernel monitor. */
    while (1)
        monitor(NULL);
f010006a:	83 ec 0c             	sub    $0xc,%esp
f010006d:	6a 00                	push   $0x0
f010006f:	e8 01 09 00 00       	call   f0100975 <monitor>
f0100074:	83 c4 10             	add    $0x10,%esp
f0100077:	eb f1                	jmp    f010006a <i386_init+0x2a>

f0100079 <_panic>:
/*
 * Panic is called on unresolvable fatal errors.
 * It prints "panic: mesg", and then enters the kernel monitor.
 */
void _panic(const char *file, int line, const char *fmt,...)
{
f0100079:	55                   	push   %ebp
f010007a:	89 e5                	mov    %esp,%ebp
f010007c:	56                   	push   %esi
f010007d:	53                   	push   %ebx
f010007e:	8b 75 10             	mov    0x10(%ebp),%esi
    va_list ap;

    if (panicstr)
f0100081:	83 3d 60 49 11 f0 00 	cmpl   $0x0,0xf0114960
f0100088:	75 37                	jne    f01000c1 <_panic+0x48>
        goto dead;
    panicstr = fmt;
f010008a:	89 35 60 49 11 f0    	mov    %esi,0xf0114960

    /* Be extra sure that the machine is in as reasonable state */
    __asm __volatile("cli; cld");
f0100090:	fa                   	cli    
f0100091:	fc                   	cld    

    va_start(ap, fmt);
f0100092:	8d 5d 14             	lea    0x14(%ebp),%ebx
    cprintf("kernel panic at %s:%d: ", file, line);
f0100095:	83 ec 04             	sub    $0x4,%esp
f0100098:	ff 75 0c             	pushl  0xc(%ebp)
f010009b:	ff 75 08             	pushl  0x8(%ebp)
f010009e:	68 00 21 10 f0       	push   $0xf0102100
f01000a3:	e8 9a 0f 00 00       	call   f0101042 <cprintf>
    vcprintf(fmt, ap);
f01000a8:	83 c4 08             	add    $0x8,%esp
f01000ab:	53                   	push   %ebx
f01000ac:	56                   	push   %esi
f01000ad:	e8 6a 0f 00 00       	call   f010101c <vcprintf>
    cprintf("\n");
f01000b2:	c7 04 24 3c 21 10 f0 	movl   $0xf010213c,(%esp)
f01000b9:	e8 84 0f 00 00       	call   f0101042 <cprintf>
    va_end(ap);
f01000be:	83 c4 10             	add    $0x10,%esp

dead:
    /* break into the kernel monitor */
    while (1)
        monitor(NULL);
f01000c1:	83 ec 0c             	sub    $0xc,%esp
f01000c4:	6a 00                	push   $0x0
f01000c6:	e8 aa 08 00 00       	call   f0100975 <monitor>
f01000cb:	83 c4 10             	add    $0x10,%esp
f01000ce:	eb f1                	jmp    f01000c1 <_panic+0x48>

f01000d0 <_warn>:
}

/* Like panic, but don't. */
void _warn(const char *file, int line, const char *fmt,...)
{
f01000d0:	55                   	push   %ebp
f01000d1:	89 e5                	mov    %esp,%ebp
f01000d3:	53                   	push   %ebx
f01000d4:	83 ec 08             	sub    $0x8,%esp
    va_list ap;

    va_start(ap, fmt);
f01000d7:	8d 5d 14             	lea    0x14(%ebp),%ebx
    cprintf("kernel warning at %s:%d: ", file, line);
f01000da:	ff 75 0c             	pushl  0xc(%ebp)
f01000dd:	ff 75 08             	pushl  0x8(%ebp)
f01000e0:	68 18 21 10 f0       	push   $0xf0102118
f01000e5:	e8 58 0f 00 00       	call   f0101042 <cprintf>
    vcprintf(fmt, ap);
f01000ea:	83 c4 08             	add    $0x8,%esp
f01000ed:	53                   	push   %ebx
f01000ee:	ff 75 10             	pushl  0x10(%ebp)
f01000f1:	e8 26 0f 00 00       	call   f010101c <vcprintf>
    cprintf("\n");
f01000f6:	c7 04 24 3c 21 10 f0 	movl   $0xf010213c,(%esp)
f01000fd:	e8 40 0f 00 00       	call   f0101042 <cprintf>
    va_end(ap);
}
f0100102:	83 c4 10             	add    $0x10,%esp
f0100105:	8b 5d fc             	mov    -0x4(%ebp),%ebx
f0100108:	c9                   	leave  
f0100109:	c3                   	ret    

f010010a <delay>:
static void cons_intr(int (*proc)(void));
static void cons_putc(int c);

/* Stupid I/O delay routine necessitated by historical PC design flaws */
static void delay(void)
{
f010010a:	55                   	push   %ebp
f010010b:	89 e5                	mov    %esp,%ebp
}

static __inline uint8_t inb(int port)
{
    uint8_t data;
    __asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f010010d:	ba 84 00 00 00       	mov    $0x84,%edx
f0100112:	ec                   	in     (%dx),%al
f0100113:	ec                   	in     (%dx),%al
f0100114:	ec                   	in     (%dx),%al
f0100115:	ec                   	in     (%dx),%al
    inb(0x84);
    inb(0x84);
    inb(0x84);
    inb(0x84);
}
f0100116:	5d                   	pop    %ebp
f0100117:	c3                   	ret    

f0100118 <serial_proc_data>:
#define   COM_LSR_TSRE  0x40    /*   Transmitter off */

static bool serial_exists;

static int serial_proc_data(void)
{
f0100118:	55                   	push   %ebp
f0100119:	89 e5                	mov    %esp,%ebp
f010011b:	ba fd 03 00 00       	mov    $0x3fd,%edx
f0100120:	ec                   	in     (%dx),%al
    if (!(inb(COM1+COM_LSR) & COM_LSR_DATA))
f0100121:	a8 01                	test   $0x1,%al
f0100123:	74 0b                	je     f0100130 <serial_proc_data+0x18>
f0100125:	ba f8 03 00 00       	mov    $0x3f8,%edx
f010012a:	ec                   	in     (%dx),%al
        return -1;
    return inb(COM1+COM_RX);
f010012b:	0f b6 c0             	movzbl %al,%eax
f010012e:	eb 05                	jmp    f0100135 <serial_proc_data+0x1d>
static bool serial_exists;

static int serial_proc_data(void)
{
    if (!(inb(COM1+COM_LSR) & COM_LSR_DATA))
        return -1;
f0100130:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
    return inb(COM1+COM_RX);
}
f0100135:	5d                   	pop    %ebp
f0100136:	c3                   	ret    

f0100137 <serial_putc>:
    if (serial_exists)
        cons_intr(serial_proc_data);
}

static void serial_putc(int c)
{
f0100137:	55                   	push   %ebp
f0100138:	89 e5                	mov    %esp,%ebp
f010013a:	57                   	push   %edi
f010013b:	56                   	push   %esi
f010013c:	53                   	push   %ebx
f010013d:	89 c7                	mov    %eax,%edi
f010013f:	ba fd 03 00 00       	mov    $0x3fd,%edx
f0100144:	ec                   	in     (%dx),%al
    int i;

    for (i = 0;
         !(inb(COM1 + COM_LSR) & COM_LSR_TXRDY) && i < 12800;
f0100145:	a8 20                	test   $0x20,%al
f0100147:	75 21                	jne    f010016a <serial_putc+0x33>
f0100149:	bb 00 00 00 00       	mov    $0x0,%ebx
f010014e:	be fd 03 00 00       	mov    $0x3fd,%esi
         i++)
        delay();
f0100153:	e8 b2 ff ff ff       	call   f010010a <delay>
{
    int i;

    for (i = 0;
         !(inb(COM1 + COM_LSR) & COM_LSR_TXRDY) && i < 12800;
         i++)
f0100158:	83 c3 01             	add    $0x1,%ebx
f010015b:	89 f2                	mov    %esi,%edx
f010015d:	ec                   	in     (%dx),%al
static void serial_putc(int c)
{
    int i;

    for (i = 0;
         !(inb(COM1 + COM_LSR) & COM_LSR_TXRDY) && i < 12800;
f010015e:	a8 20                	test   $0x20,%al
f0100160:	75 08                	jne    f010016a <serial_putc+0x33>
f0100162:	81 fb ff 31 00 00    	cmp    $0x31ff,%ebx
f0100168:	7e e9                	jle    f0100153 <serial_putc+0x1c>
             "memory", "cc");
}

static __inline void outb(int port, uint8_t data)
{
    __asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f010016a:	ba f8 03 00 00       	mov    $0x3f8,%edx
f010016f:	89 f8                	mov    %edi,%eax
f0100171:	ee                   	out    %al,(%dx)
         i++)
        delay();

    outb(COM1 + COM_TX, c);
}
f0100172:	5b                   	pop    %ebx
f0100173:	5e                   	pop    %esi
f0100174:	5f                   	pop    %edi
f0100175:	5d                   	pop    %ebp
f0100176:	c3                   	ret    

f0100177 <serial_init>:

static void serial_init(void)
{
f0100177:	55                   	push   %ebp
f0100178:	89 e5                	mov    %esp,%ebp
f010017a:	53                   	push   %ebx
f010017b:	bb fa 03 00 00       	mov    $0x3fa,%ebx
f0100180:	b8 00 00 00 00       	mov    $0x0,%eax
f0100185:	89 da                	mov    %ebx,%edx
f0100187:	ee                   	out    %al,(%dx)
f0100188:	ba fb 03 00 00       	mov    $0x3fb,%edx
f010018d:	b8 80 ff ff ff       	mov    $0xffffff80,%eax
f0100192:	ee                   	out    %al,(%dx)
f0100193:	b9 f8 03 00 00       	mov    $0x3f8,%ecx
f0100198:	b8 0c 00 00 00       	mov    $0xc,%eax
f010019d:	89 ca                	mov    %ecx,%edx
f010019f:	ee                   	out    %al,(%dx)
f01001a0:	ba f9 03 00 00       	mov    $0x3f9,%edx
f01001a5:	b8 00 00 00 00       	mov    $0x0,%eax
f01001aa:	ee                   	out    %al,(%dx)
f01001ab:	ba fb 03 00 00       	mov    $0x3fb,%edx
f01001b0:	b8 03 00 00 00       	mov    $0x3,%eax
f01001b5:	ee                   	out    %al,(%dx)
f01001b6:	ba fc 03 00 00       	mov    $0x3fc,%edx
f01001bb:	b8 00 00 00 00       	mov    $0x0,%eax
f01001c0:	ee                   	out    %al,(%dx)
f01001c1:	ba f9 03 00 00       	mov    $0x3f9,%edx
f01001c6:	b8 01 00 00 00       	mov    $0x1,%eax
f01001cb:	ee                   	out    %al,(%dx)
}

static __inline uint8_t inb(int port)
{
    uint8_t data;
    __asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f01001cc:	ba fd 03 00 00       	mov    $0x3fd,%edx
f01001d1:	ec                   	in     (%dx),%al
    /* Enable rcv interrupts */
    outb(COM1+COM_IER, COM_IER_RDI);

    /* Clear any preexisting overrun indications and interrupts
     * Serial port doesn't exist if COM_LSR returns 0xFF */
    serial_exists = (inb(COM1+COM_LSR) != 0xFF);
f01001d2:	3c ff                	cmp    $0xff,%al
f01001d4:	0f 95 05 34 45 11 f0 	setne  0xf0114534
f01001db:	89 da                	mov    %ebx,%edx
f01001dd:	ec                   	in     (%dx),%al
f01001de:	89 ca                	mov    %ecx,%edx
f01001e0:	ec                   	in     (%dx),%al
    (void) inb(COM1+COM_IIR);
    (void) inb(COM1+COM_RX);

}
f01001e1:	5b                   	pop    %ebx
f01001e2:	5d                   	pop    %ebp
f01001e3:	c3                   	ret    

f01001e4 <lpt_putc>:
/***** Parallel port output code *****/
/* For information on PC parallel port programming, see the class References
 * page. */

static void lpt_putc(int c)
{
f01001e4:	55                   	push   %ebp
f01001e5:	89 e5                	mov    %esp,%ebp
f01001e7:	57                   	push   %edi
f01001e8:	56                   	push   %esi
f01001e9:	53                   	push   %ebx
f01001ea:	89 c7                	mov    %eax,%edi
f01001ec:	ba 79 03 00 00       	mov    $0x379,%edx
f01001f1:	ec                   	in     (%dx),%al
    int i;

    for (i = 0; !(inb(0x378+1) & 0x80) && i < 12800; i++)
f01001f2:	84 c0                	test   %al,%al
f01001f4:	78 21                	js     f0100217 <lpt_putc+0x33>
f01001f6:	bb 00 00 00 00       	mov    $0x0,%ebx
f01001fb:	be 79 03 00 00       	mov    $0x379,%esi
        delay();
f0100200:	e8 05 ff ff ff       	call   f010010a <delay>

static void lpt_putc(int c)
{
    int i;

    for (i = 0; !(inb(0x378+1) & 0x80) && i < 12800; i++)
f0100205:	83 c3 01             	add    $0x1,%ebx
f0100208:	89 f2                	mov    %esi,%edx
f010020a:	ec                   	in     (%dx),%al
f010020b:	81 fb ff 31 00 00    	cmp    $0x31ff,%ebx
f0100211:	7f 04                	jg     f0100217 <lpt_putc+0x33>
f0100213:	84 c0                	test   %al,%al
f0100215:	79 e9                	jns    f0100200 <lpt_putc+0x1c>
             "memory", "cc");
}

static __inline void outb(int port, uint8_t data)
{
    __asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0100217:	ba 78 03 00 00       	mov    $0x378,%edx
f010021c:	89 f8                	mov    %edi,%eax
f010021e:	ee                   	out    %al,(%dx)
f010021f:	ba 7a 03 00 00       	mov    $0x37a,%edx
f0100224:	b8 0d 00 00 00       	mov    $0xd,%eax
f0100229:	ee                   	out    %al,(%dx)
f010022a:	b8 08 00 00 00       	mov    $0x8,%eax
f010022f:	ee                   	out    %al,(%dx)
        delay();
    outb(0x378+0, c);
    outb(0x378+2, 0x08|0x04|0x01);
    outb(0x378+2, 0x08);
}
f0100230:	5b                   	pop    %ebx
f0100231:	5e                   	pop    %esi
f0100232:	5f                   	pop    %edi
f0100233:	5d                   	pop    %ebp
f0100234:	c3                   	ret    

f0100235 <cga_init>:
static unsigned addr_6845;
static uint16_t *crt_buf;
static uint16_t crt_pos;

static void cga_init(void)
{
f0100235:	55                   	push   %ebp
f0100236:	89 e5                	mov    %esp,%ebp
f0100238:	57                   	push   %edi
f0100239:	56                   	push   %esi
f010023a:	53                   	push   %ebx
    volatile uint16_t *cp;
    uint16_t was;
    unsigned pos;

    cp = (uint16_t*) (KERNBASE + CGA_BUF);
    was = *cp;
f010023b:	0f b7 15 00 80 0b f0 	movzwl 0xf00b8000,%edx
    *cp = (uint16_t) 0xA55A;
f0100242:	66 c7 05 00 80 0b f0 	movw   $0xa55a,0xf00b8000
f0100249:	5a a5 
    if (*cp != 0xA55A) {
f010024b:	0f b7 05 00 80 0b f0 	movzwl 0xf00b8000,%eax
f0100252:	66 3d 5a a5          	cmp    $0xa55a,%ax
f0100256:	74 11                	je     f0100269 <cga_init+0x34>
        cp = (uint16_t*) (KERNBASE + MONO_BUF);
        addr_6845 = MONO_BASE;
f0100258:	c7 05 30 45 11 f0 b4 	movl   $0x3b4,0xf0114530
f010025f:	03 00 00 

    cp = (uint16_t*) (KERNBASE + CGA_BUF);
    was = *cp;
    *cp = (uint16_t) 0xA55A;
    if (*cp != 0xA55A) {
        cp = (uint16_t*) (KERNBASE + MONO_BUF);
f0100262:	be 00 00 0b f0       	mov    $0xf00b0000,%esi
f0100267:	eb 16                	jmp    f010027f <cga_init+0x4a>
        addr_6845 = MONO_BASE;
    } else {
        *cp = was;
f0100269:	66 89 15 00 80 0b f0 	mov    %dx,0xf00b8000
        addr_6845 = CGA_BASE;
f0100270:	c7 05 30 45 11 f0 d4 	movl   $0x3d4,0xf0114530
f0100277:	03 00 00 
{
    volatile uint16_t *cp;
    uint16_t was;
    unsigned pos;

    cp = (uint16_t*) (KERNBASE + CGA_BUF);
f010027a:	be 00 80 0b f0       	mov    $0xf00b8000,%esi
        *cp = was;
        addr_6845 = CGA_BASE;
    }

    /* Extract cursor location */
    outb(addr_6845, 14);
f010027f:	8b 3d 30 45 11 f0    	mov    0xf0114530,%edi
f0100285:	b8 0e 00 00 00       	mov    $0xe,%eax
f010028a:	89 fa                	mov    %edi,%edx
f010028c:	ee                   	out    %al,(%dx)
    pos = inb(addr_6845 + 1) << 8;
f010028d:	8d 5f 01             	lea    0x1(%edi),%ebx
}

static __inline uint8_t inb(int port)
{
    uint8_t data;
    __asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f0100290:	89 da                	mov    %ebx,%edx
f0100292:	ec                   	in     (%dx),%al
f0100293:	0f b6 c8             	movzbl %al,%ecx
f0100296:	c1 e1 08             	shl    $0x8,%ecx
             "memory", "cc");
}

static __inline void outb(int port, uint8_t data)
{
    __asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0100299:	b8 0f 00 00 00       	mov    $0xf,%eax
f010029e:	89 fa                	mov    %edi,%edx
f01002a0:	ee                   	out    %al,(%dx)
}

static __inline uint8_t inb(int port)
{
    uint8_t data;
    __asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f01002a1:	89 da                	mov    %ebx,%edx
f01002a3:	ec                   	in     (%dx),%al
    outb(addr_6845, 15);
    pos |= inb(addr_6845 + 1);

    crt_buf = (uint16_t*) cp;
f01002a4:	89 35 2c 45 11 f0    	mov    %esi,0xf011452c
    crt_pos = pos;
f01002aa:	0f b6 c0             	movzbl %al,%eax
f01002ad:	09 c8                	or     %ecx,%eax
f01002af:	66 a3 28 45 11 f0    	mov    %ax,0xf0114528
}
f01002b5:	5b                   	pop    %ebx
f01002b6:	5e                   	pop    %esi
f01002b7:	5f                   	pop    %edi
f01002b8:	5d                   	pop    %ebp
f01002b9:	c3                   	ret    

f01002ba <cons_intr>:
} cons;

/* called by device interrupt routines to feed input characters
 * into the circular console input buffer. */
static void cons_intr(int (*proc)(void))
{
f01002ba:	55                   	push   %ebp
f01002bb:	89 e5                	mov    %esp,%ebp
f01002bd:	53                   	push   %ebx
f01002be:	83 ec 04             	sub    $0x4,%esp
f01002c1:	89 c3                	mov    %eax,%ebx
    int c;

    while ((c = (*proc)()) != -1) {
f01002c3:	eb 2b                	jmp    f01002f0 <cons_intr+0x36>
        if (c == 0)
f01002c5:	85 c0                	test   %eax,%eax
f01002c7:	74 27                	je     f01002f0 <cons_intr+0x36>
            continue;
        cons.buf[cons.wpos++] = c;
f01002c9:	8b 0d 24 45 11 f0    	mov    0xf0114524,%ecx
f01002cf:	8d 51 01             	lea    0x1(%ecx),%edx
f01002d2:	89 15 24 45 11 f0    	mov    %edx,0xf0114524
f01002d8:	88 81 20 43 11 f0    	mov    %al,-0xfeebce0(%ecx)
        if (cons.wpos == CONSBUFSIZE)
f01002de:	81 fa 00 02 00 00    	cmp    $0x200,%edx
f01002e4:	75 0a                	jne    f01002f0 <cons_intr+0x36>
            cons.wpos = 0;
f01002e6:	c7 05 24 45 11 f0 00 	movl   $0x0,0xf0114524
f01002ed:	00 00 00 
 * into the circular console input buffer. */
static void cons_intr(int (*proc)(void))
{
    int c;

    while ((c = (*proc)()) != -1) {
f01002f0:	ff d3                	call   *%ebx
f01002f2:	83 f8 ff             	cmp    $0xffffffff,%eax
f01002f5:	75 ce                	jne    f01002c5 <cons_intr+0xb>
            continue;
        cons.buf[cons.wpos++] = c;
        if (cons.wpos == CONSBUFSIZE)
            cons.wpos = 0;
    }
}
f01002f7:	83 c4 04             	add    $0x4,%esp
f01002fa:	5b                   	pop    %ebx
f01002fb:	5d                   	pop    %ebp
f01002fc:	c3                   	ret    

f01002fd <kbd_proc_data>:
f01002fd:	ba 64 00 00 00       	mov    $0x64,%edx
f0100302:	ec                   	in     (%dx),%al
{
    int c;
    uint8_t data;
    static uint32_t shift;

    if ((inb(KBSTATP) & KBS_DIB) == 0)
f0100303:	a8 01                	test   $0x1,%al
f0100305:	0f 84 f0 00 00 00    	je     f01003fb <kbd_proc_data+0xfe>
f010030b:	ba 60 00 00 00       	mov    $0x60,%edx
f0100310:	ec                   	in     (%dx),%al
f0100311:	89 c2                	mov    %eax,%edx
        return -1;

    data = inb(KBDATAP);

    if (data == 0xE0) {
f0100313:	3c e0                	cmp    $0xe0,%al
f0100315:	75 0d                	jne    f0100324 <kbd_proc_data+0x27>
        /* E0 escape character */
        shift |= E0ESC;
f0100317:	83 0d 00 43 11 f0 40 	orl    $0x40,0xf0114300
        return 0;
f010031e:	b8 00 00 00 00       	mov    $0x0,%eax
        cprintf("Rebooting!\n");
        outb(0x92, 0x3); /* courtesy of Chris Frost */
    }

    return c;
}
f0100323:	c3                   	ret    
/*
 * Get data from the keyboard.  If we finish a character, return it.  Else 0.
 * Return -1 if no data.
 */
static int kbd_proc_data(void)
{
f0100324:	55                   	push   %ebp
f0100325:	89 e5                	mov    %esp,%ebp
f0100327:	53                   	push   %ebx
f0100328:	83 ec 04             	sub    $0x4,%esp

    if (data == 0xE0) {
        /* E0 escape character */
        shift |= E0ESC;
        return 0;
    } else if (data & 0x80) {
f010032b:	84 c0                	test   %al,%al
f010032d:	79 36                	jns    f0100365 <kbd_proc_data+0x68>
        /* Key released */
        data = (shift & E0ESC ? data : data & 0x7F);
f010032f:	8b 0d 00 43 11 f0    	mov    0xf0114300,%ecx
f0100335:	89 cb                	mov    %ecx,%ebx
f0100337:	83 e3 40             	and    $0x40,%ebx
f010033a:	83 e0 7f             	and    $0x7f,%eax
f010033d:	85 db                	test   %ebx,%ebx
f010033f:	0f 44 d0             	cmove  %eax,%edx
        shift &= ~(shiftcode[data] | E0ESC);
f0100342:	0f b6 d2             	movzbl %dl,%edx
f0100345:	0f b6 82 80 22 10 f0 	movzbl -0xfefdd80(%edx),%eax
f010034c:	83 c8 40             	or     $0x40,%eax
f010034f:	0f b6 c0             	movzbl %al,%eax
f0100352:	f7 d0                	not    %eax
f0100354:	21 c8                	and    %ecx,%eax
f0100356:	a3 00 43 11 f0       	mov    %eax,0xf0114300
        return 0;
f010035b:	b8 00 00 00 00       	mov    $0x0,%eax
f0100360:	e9 9e 00 00 00       	jmp    f0100403 <kbd_proc_data+0x106>
    } else if (shift & E0ESC) {
f0100365:	8b 0d 00 43 11 f0    	mov    0xf0114300,%ecx
f010036b:	f6 c1 40             	test   $0x40,%cl
f010036e:	74 0e                	je     f010037e <kbd_proc_data+0x81>
        /* Last character was an E0 escape; or with 0x80 */
        data |= 0x80;
f0100370:	83 c8 80             	or     $0xffffff80,%eax
f0100373:	89 c2                	mov    %eax,%edx
        shift &= ~E0ESC;
f0100375:	83 e1 bf             	and    $0xffffffbf,%ecx
f0100378:	89 0d 00 43 11 f0    	mov    %ecx,0xf0114300
    }

    shift |= shiftcode[data];
f010037e:	0f b6 d2             	movzbl %dl,%edx
    shift ^= togglecode[data];
f0100381:	0f b6 82 80 22 10 f0 	movzbl -0xfefdd80(%edx),%eax
f0100388:	0b 05 00 43 11 f0    	or     0xf0114300,%eax
f010038e:	0f b6 8a 80 21 10 f0 	movzbl -0xfefde80(%edx),%ecx
f0100395:	31 c8                	xor    %ecx,%eax
f0100397:	a3 00 43 11 f0       	mov    %eax,0xf0114300

    c = charcode[shift & (CTL | SHIFT)][data];
f010039c:	89 c1                	mov    %eax,%ecx
f010039e:	83 e1 03             	and    $0x3,%ecx
f01003a1:	8b 0c 8d 60 21 10 f0 	mov    -0xfefdea0(,%ecx,4),%ecx
f01003a8:	0f b6 14 11          	movzbl (%ecx,%edx,1),%edx
f01003ac:	0f b6 da             	movzbl %dl,%ebx
    if (shift & CAPSLOCK) {
f01003af:	a8 08                	test   $0x8,%al
f01003b1:	74 1b                	je     f01003ce <kbd_proc_data+0xd1>
        if ('a' <= c && c <= 'z')
f01003b3:	89 da                	mov    %ebx,%edx
f01003b5:	8d 4b 9f             	lea    -0x61(%ebx),%ecx
f01003b8:	83 f9 19             	cmp    $0x19,%ecx
f01003bb:	77 05                	ja     f01003c2 <kbd_proc_data+0xc5>
            c += 'A' - 'a';
f01003bd:	83 eb 20             	sub    $0x20,%ebx
f01003c0:	eb 0c                	jmp    f01003ce <kbd_proc_data+0xd1>
        else if ('A' <= c && c <= 'Z')
f01003c2:	83 ea 41             	sub    $0x41,%edx
            c += 'a' - 'A';
f01003c5:	8d 4b 20             	lea    0x20(%ebx),%ecx
f01003c8:	83 fa 19             	cmp    $0x19,%edx
f01003cb:	0f 46 d9             	cmovbe %ecx,%ebx
    }

    /* Process special keys
     * Ctrl-Alt-Del: reboot */
    if (!(~shift & (CTL | ALT)) && c == KEY_DEL) {
f01003ce:	f7 d0                	not    %eax
f01003d0:	a8 06                	test   $0x6,%al
f01003d2:	75 2d                	jne    f0100401 <kbd_proc_data+0x104>
f01003d4:	81 fb e9 00 00 00    	cmp    $0xe9,%ebx
f01003da:	75 25                	jne    f0100401 <kbd_proc_data+0x104>
        cprintf("Rebooting!\n");
f01003dc:	83 ec 0c             	sub    $0xc,%esp
f01003df:	68 32 21 10 f0       	push   $0xf0102132
f01003e4:	e8 59 0c 00 00       	call   f0101042 <cprintf>
             "memory", "cc");
}

static __inline void outb(int port, uint8_t data)
{
    __asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f01003e9:	ba 92 00 00 00       	mov    $0x92,%edx
f01003ee:	b8 03 00 00 00       	mov    $0x3,%eax
f01003f3:	ee                   	out    %al,(%dx)
f01003f4:	83 c4 10             	add    $0x10,%esp
        outb(0x92, 0x3); /* courtesy of Chris Frost */
    }

    return c;
f01003f7:	89 d8                	mov    %ebx,%eax
f01003f9:	eb 08                	jmp    f0100403 <kbd_proc_data+0x106>
    int c;
    uint8_t data;
    static uint32_t shift;

    if ((inb(KBSTATP) & KBS_DIB) == 0)
        return -1;
f01003fb:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0100400:	c3                   	ret    
    if (!(~shift & (CTL | ALT)) && c == KEY_DEL) {
        cprintf("Rebooting!\n");
        outb(0x92, 0x3); /* courtesy of Chris Frost */
    }

    return c;
f0100401:	89 d8                	mov    %ebx,%eax
}
f0100403:	8b 5d fc             	mov    -0x4(%ebp),%ebx
f0100406:	c9                   	leave  
f0100407:	c3                   	ret    

f0100408 <cga_putc>:
}



static void cga_putc(int c)
{
f0100408:	55                   	push   %ebp
f0100409:	89 e5                	mov    %esp,%ebp
f010040b:	56                   	push   %esi
f010040c:	53                   	push   %ebx
    /* If no attribute given, then use black on white. */
    if (!(c & ~0xFF))
f010040d:	89 c1                	mov    %eax,%ecx
f010040f:	81 e1 00 ff ff ff    	and    $0xffffff00,%ecx
        c |= 0x0700;
f0100415:	89 c2                	mov    %eax,%edx
f0100417:	80 ce 07             	or     $0x7,%dh
f010041a:	85 c9                	test   %ecx,%ecx
f010041c:	0f 44 c2             	cmove  %edx,%eax

    switch (c & 0xff) {
f010041f:	0f b6 d0             	movzbl %al,%edx
f0100422:	83 fa 09             	cmp    $0x9,%edx
f0100425:	74 72                	je     f0100499 <cga_putc+0x91>
f0100427:	83 fa 09             	cmp    $0x9,%edx
f010042a:	7f 0a                	jg     f0100436 <cga_putc+0x2e>
f010042c:	83 fa 08             	cmp    $0x8,%edx
f010042f:	74 14                	je     f0100445 <cga_putc+0x3d>
f0100431:	e9 97 00 00 00       	jmp    f01004cd <cga_putc+0xc5>
f0100436:	83 fa 0a             	cmp    $0xa,%edx
f0100439:	74 38                	je     f0100473 <cga_putc+0x6b>
f010043b:	83 fa 0d             	cmp    $0xd,%edx
f010043e:	74 3b                	je     f010047b <cga_putc+0x73>
f0100440:	e9 88 00 00 00       	jmp    f01004cd <cga_putc+0xc5>
    case '\b':
        if (crt_pos > 0) {
f0100445:	0f b7 15 28 45 11 f0 	movzwl 0xf0114528,%edx
f010044c:	66 85 d2             	test   %dx,%dx
f010044f:	0f 84 e4 00 00 00    	je     f0100539 <cga_putc+0x131>
            crt_pos--;
f0100455:	83 ea 01             	sub    $0x1,%edx
f0100458:	66 89 15 28 45 11 f0 	mov    %dx,0xf0114528
            crt_buf[crt_pos] = (c & ~0xff) | ' ';
f010045f:	0f b7 d2             	movzwl %dx,%edx
f0100462:	b0 00                	mov    $0x0,%al
f0100464:	83 c8 20             	or     $0x20,%eax
f0100467:	8b 0d 2c 45 11 f0    	mov    0xf011452c,%ecx
f010046d:	66 89 04 51          	mov    %ax,(%ecx,%edx,2)
f0100471:	eb 78                	jmp    f01004eb <cga_putc+0xe3>
        }
        break;
    case '\n':
        crt_pos += CRT_COLS;
f0100473:	66 83 05 28 45 11 f0 	addw   $0x50,0xf0114528
f010047a:	50 
        /* fallthru */
    case '\r':
        crt_pos -= (crt_pos % CRT_COLS);
f010047b:	0f b7 05 28 45 11 f0 	movzwl 0xf0114528,%eax
f0100482:	69 c0 cd cc 00 00    	imul   $0xcccd,%eax,%eax
f0100488:	c1 e8 16             	shr    $0x16,%eax
f010048b:	8d 04 80             	lea    (%eax,%eax,4),%eax
f010048e:	c1 e0 04             	shl    $0x4,%eax
f0100491:	66 a3 28 45 11 f0    	mov    %ax,0xf0114528
        break;
f0100497:	eb 52                	jmp    f01004eb <cga_putc+0xe3>
    case '\t':
        cons_putc(' ');
f0100499:	b8 20 00 00 00       	mov    $0x20,%eax
f010049e:	e8 cb 00 00 00       	call   f010056e <cons_putc>
        cons_putc(' ');
f01004a3:	b8 20 00 00 00       	mov    $0x20,%eax
f01004a8:	e8 c1 00 00 00       	call   f010056e <cons_putc>
        cons_putc(' ');
f01004ad:	b8 20 00 00 00       	mov    $0x20,%eax
f01004b2:	e8 b7 00 00 00       	call   f010056e <cons_putc>
        cons_putc(' ');
f01004b7:	b8 20 00 00 00       	mov    $0x20,%eax
f01004bc:	e8 ad 00 00 00       	call   f010056e <cons_putc>
        cons_putc(' ');
f01004c1:	b8 20 00 00 00       	mov    $0x20,%eax
f01004c6:	e8 a3 00 00 00       	call   f010056e <cons_putc>
        break;
f01004cb:	eb 1e                	jmp    f01004eb <cga_putc+0xe3>
    default:
        crt_buf[crt_pos++] = c;     /* write the character */
f01004cd:	0f b7 15 28 45 11 f0 	movzwl 0xf0114528,%edx
f01004d4:	8d 4a 01             	lea    0x1(%edx),%ecx
f01004d7:	66 89 0d 28 45 11 f0 	mov    %cx,0xf0114528
f01004de:	0f b7 d2             	movzwl %dx,%edx
f01004e1:	8b 0d 2c 45 11 f0    	mov    0xf011452c,%ecx
f01004e7:	66 89 04 51          	mov    %ax,(%ecx,%edx,2)
        break;
    }

    /* What is the purpose of this? */
    if (crt_pos >= CRT_SIZE) {
f01004eb:	66 81 3d 28 45 11 f0 	cmpw   $0x7cf,0xf0114528
f01004f2:	cf 07 
f01004f4:	76 43                	jbe    f0100539 <cga_putc+0x131>
        int i;

        memmove(crt_buf, crt_buf + CRT_COLS, (CRT_SIZE - CRT_COLS) * sizeof(uint16_t));
f01004f6:	a1 2c 45 11 f0       	mov    0xf011452c,%eax
f01004fb:	83 ec 04             	sub    $0x4,%esp
f01004fe:	68 00 0f 00 00       	push   $0xf00
f0100503:	8d 90 a0 00 00 00    	lea    0xa0(%eax),%edx
f0100509:	52                   	push   %edx
f010050a:	50                   	push   %eax
f010050b:	e8 69 17 00 00       	call   f0101c79 <memmove>
        for (i = CRT_SIZE - CRT_COLS; i < CRT_SIZE; i++)
            crt_buf[i] = 0x0700 | ' ';
f0100510:	8b 15 2c 45 11 f0    	mov    0xf011452c,%edx
f0100516:	8d 82 00 0f 00 00    	lea    0xf00(%edx),%eax
f010051c:	81 c2 a0 0f 00 00    	add    $0xfa0,%edx
f0100522:	83 c4 10             	add    $0x10,%esp
f0100525:	66 c7 00 20 07       	movw   $0x720,(%eax)
f010052a:	83 c0 02             	add    $0x2,%eax
    /* What is the purpose of this? */
    if (crt_pos >= CRT_SIZE) {
        int i;

        memmove(crt_buf, crt_buf + CRT_COLS, (CRT_SIZE - CRT_COLS) * sizeof(uint16_t));
        for (i = CRT_SIZE - CRT_COLS; i < CRT_SIZE; i++)
f010052d:	39 d0                	cmp    %edx,%eax
f010052f:	75 f4                	jne    f0100525 <cga_putc+0x11d>
            crt_buf[i] = 0x0700 | ' ';
        crt_pos -= CRT_COLS;
f0100531:	66 83 2d 28 45 11 f0 	subw   $0x50,0xf0114528
f0100538:	50 
    }

    /* move that little blinky thing */
    outb(addr_6845, 14);
f0100539:	8b 0d 30 45 11 f0    	mov    0xf0114530,%ecx
f010053f:	b8 0e 00 00 00       	mov    $0xe,%eax
f0100544:	89 ca                	mov    %ecx,%edx
f0100546:	ee                   	out    %al,(%dx)
    outb(addr_6845 + 1, crt_pos >> 8);
f0100547:	0f b7 1d 28 45 11 f0 	movzwl 0xf0114528,%ebx
f010054e:	8d 71 01             	lea    0x1(%ecx),%esi
f0100551:	89 d8                	mov    %ebx,%eax
f0100553:	66 c1 e8 08          	shr    $0x8,%ax
f0100557:	89 f2                	mov    %esi,%edx
f0100559:	ee                   	out    %al,(%dx)
f010055a:	b8 0f 00 00 00       	mov    $0xf,%eax
f010055f:	89 ca                	mov    %ecx,%edx
f0100561:	ee                   	out    %al,(%dx)
f0100562:	89 d8                	mov    %ebx,%eax
f0100564:	89 f2                	mov    %esi,%edx
f0100566:	ee                   	out    %al,(%dx)
    outb(addr_6845, 15);
    outb(addr_6845 + 1, crt_pos);
}
f0100567:	8d 65 f8             	lea    -0x8(%ebp),%esp
f010056a:	5b                   	pop    %ebx
f010056b:	5e                   	pop    %esi
f010056c:	5d                   	pop    %ebp
f010056d:	c3                   	ret    

f010056e <cons_putc>:
    return 0;
}

/* Output a character to the console. */
static void cons_putc(int c)
{
f010056e:	55                   	push   %ebp
f010056f:	89 e5                	mov    %esp,%ebp
f0100571:	53                   	push   %ebx
f0100572:	83 ec 04             	sub    $0x4,%esp
f0100575:	89 c3                	mov    %eax,%ebx
    serial_putc(c);
f0100577:	e8 bb fb ff ff       	call   f0100137 <serial_putc>
    lpt_putc(c);
f010057c:	89 d8                	mov    %ebx,%eax
f010057e:	e8 61 fc ff ff       	call   f01001e4 <lpt_putc>
    cga_putc(c);
f0100583:	89 d8                	mov    %ebx,%eax
f0100585:	e8 7e fe ff ff       	call   f0100408 <cga_putc>
}
f010058a:	83 c4 04             	add    $0x4,%esp
f010058d:	5b                   	pop    %ebx
f010058e:	5d                   	pop    %ebp
f010058f:	c3                   	ret    

f0100590 <serial_intr>:
    return inb(COM1+COM_RX);
}

void serial_intr(void)
{
    if (serial_exists)
f0100590:	80 3d 34 45 11 f0 00 	cmpb   $0x0,0xf0114534
f0100597:	74 11                	je     f01005aa <serial_intr+0x1a>
        return -1;
    return inb(COM1+COM_RX);
}

void serial_intr(void)
{
f0100599:	55                   	push   %ebp
f010059a:	89 e5                	mov    %esp,%ebp
f010059c:	83 ec 08             	sub    $0x8,%esp
    if (serial_exists)
        cons_intr(serial_proc_data);
f010059f:	b8 18 01 10 f0       	mov    $0xf0100118,%eax
f01005a4:	e8 11 fd ff ff       	call   f01002ba <cons_intr>
}
f01005a9:	c9                   	leave  
f01005aa:	f3 c3                	repz ret 

f01005ac <kbd_intr>:

    return c;
}

void kbd_intr(void)
{
f01005ac:	55                   	push   %ebp
f01005ad:	89 e5                	mov    %esp,%ebp
f01005af:	83 ec 08             	sub    $0x8,%esp
    cons_intr(kbd_proc_data);
f01005b2:	b8 fd 02 10 f0       	mov    $0xf01002fd,%eax
f01005b7:	e8 fe fc ff ff       	call   f01002ba <cons_intr>
}
f01005bc:	c9                   	leave  
f01005bd:	c3                   	ret    

f01005be <cons_getc>:
    }
}

/* return the next input character from the console, or 0 if none waiting */
int cons_getc(void)
{
f01005be:	55                   	push   %ebp
f01005bf:	89 e5                	mov    %esp,%ebp
f01005c1:	83 ec 08             	sub    $0x8,%esp
    int c;

    /* Poll for any pending input characters, so that this function works even
     * when interrupts are disabled (e.g., when called from the kernel
     * monitor). */
    serial_intr();
f01005c4:	e8 c7 ff ff ff       	call   f0100590 <serial_intr>
    kbd_intr();
f01005c9:	e8 de ff ff ff       	call   f01005ac <kbd_intr>

    /* grab the next character from the input buffer. */
    if (cons.rpos != cons.wpos) {
f01005ce:	a1 20 45 11 f0       	mov    0xf0114520,%eax
f01005d3:	3b 05 24 45 11 f0    	cmp    0xf0114524,%eax
f01005d9:	74 26                	je     f0100601 <cons_getc+0x43>
        c = cons.buf[cons.rpos++];
f01005db:	8d 50 01             	lea    0x1(%eax),%edx
f01005de:	89 15 20 45 11 f0    	mov    %edx,0xf0114520
f01005e4:	0f b6 88 20 43 11 f0 	movzbl -0xfeebce0(%eax),%ecx
        if (cons.rpos == CONSBUFSIZE)
            cons.rpos = 0;
        return c;
f01005eb:	89 c8                	mov    %ecx,%eax
    kbd_intr();

    /* grab the next character from the input buffer. */
    if (cons.rpos != cons.wpos) {
        c = cons.buf[cons.rpos++];
        if (cons.rpos == CONSBUFSIZE)
f01005ed:	81 fa 00 02 00 00    	cmp    $0x200,%edx
f01005f3:	75 11                	jne    f0100606 <cons_getc+0x48>
            cons.rpos = 0;
f01005f5:	c7 05 20 45 11 f0 00 	movl   $0x0,0xf0114520
f01005fc:	00 00 00 
f01005ff:	eb 05                	jmp    f0100606 <cons_getc+0x48>
        return c;
    }
    return 0;
f0100601:	b8 00 00 00 00       	mov    $0x0,%eax
}
f0100606:	c9                   	leave  
f0100607:	c3                   	ret    

f0100608 <cons_init>:
    cga_putc(c);
}

/* Initialize the console devices. */
void cons_init(void)
{
f0100608:	55                   	push   %ebp
f0100609:	89 e5                	mov    %esp,%ebp
f010060b:	83 ec 08             	sub    $0x8,%esp
    cga_init();
f010060e:	e8 22 fc ff ff       	call   f0100235 <cga_init>
    kbd_init();
    serial_init();
f0100613:	e8 5f fb ff ff       	call   f0100177 <serial_init>

    if (!serial_exists)
f0100618:	80 3d 34 45 11 f0 00 	cmpb   $0x0,0xf0114534
f010061f:	75 10                	jne    f0100631 <cons_init+0x29>
        cprintf("Serial port does not exist!\n");
f0100621:	83 ec 0c             	sub    $0xc,%esp
f0100624:	68 3e 21 10 f0       	push   $0xf010213e
f0100629:	e8 14 0a 00 00       	call   f0101042 <cprintf>
f010062e:	83 c4 10             	add    $0x10,%esp
}
f0100631:	c9                   	leave  
f0100632:	c3                   	ret    

f0100633 <cputchar>:


/* `High'-level console I/O.  Used by readline and cprintf. */

void cputchar(int c)
{
f0100633:	55                   	push   %ebp
f0100634:	89 e5                	mov    %esp,%ebp
f0100636:	83 ec 08             	sub    $0x8,%esp
    cons_putc(c);
f0100639:	8b 45 08             	mov    0x8(%ebp),%eax
f010063c:	e8 2d ff ff ff       	call   f010056e <cons_putc>
}
f0100641:	c9                   	leave  
f0100642:	c3                   	ret    

f0100643 <getchar>:

int getchar(void)
{
f0100643:	55                   	push   %ebp
f0100644:	89 e5                	mov    %esp,%ebp
f0100646:	83 ec 08             	sub    $0x8,%esp
    int c;

    while ((c = cons_getc()) == 0)
f0100649:	e8 70 ff ff ff       	call   f01005be <cons_getc>
f010064e:	85 c0                	test   %eax,%eax
f0100650:	74 f7                	je     f0100649 <getchar+0x6>
        /* do nothing */;
    return c;
}
f0100652:	c9                   	leave  
f0100653:	c3                   	ret    

f0100654 <iscons>:

int iscons(int fdnum)
{
f0100654:	55                   	push   %ebp
f0100655:	89 e5                	mov    %esp,%ebp
    /* used by readline */
    return 1;
}
f0100657:	b8 01 00 00 00       	mov    $0x1,%eax
f010065c:	5d                   	pop    %ebp
f010065d:	c3                   	ret    

f010065e <mon_help>:
#define NCOMMANDS (sizeof(commands)/sizeof(commands[0]))

/***** Implementations of basic kernel monitor commands *****/

int mon_help(int argc, char **argv, struct trapframe *tf)
{
f010065e:	55                   	push   %ebp
f010065f:	89 e5                	mov    %esp,%ebp
f0100661:	83 ec 0c             	sub    $0xc,%esp
    int i;

    for (i = 0; i < NCOMMANDS; i++)
        cprintf("%s - %s\n", commands[i].name, commands[i].desc);
f0100664:	68 80 23 10 f0       	push   $0xf0102380
f0100669:	68 9e 23 10 f0       	push   $0xf010239e
f010066e:	68 a3 23 10 f0       	push   $0xf01023a3
f0100673:	e8 ca 09 00 00       	call   f0101042 <cprintf>
f0100678:	83 c4 0c             	add    $0xc,%esp
f010067b:	68 78 24 10 f0       	push   $0xf0102478
f0100680:	68 ac 23 10 f0       	push   $0xf01023ac
f0100685:	68 a3 23 10 f0       	push   $0xf01023a3
f010068a:	e8 b3 09 00 00       	call   f0101042 <cprintf>
f010068f:	83 c4 0c             	add    $0xc,%esp
f0100692:	68 b5 23 10 f0       	push   $0xf01023b5
f0100697:	68 c3 23 10 f0       	push   $0xf01023c3
f010069c:	68 a3 23 10 f0       	push   $0xf01023a3
f01006a1:	e8 9c 09 00 00       	call   f0101042 <cprintf>
    return 0;
}
f01006a6:	b8 00 00 00 00       	mov    $0x0,%eax
f01006ab:	c9                   	leave  
f01006ac:	c3                   	ret    

f01006ad <mon_kerninfo>:

int mon_kerninfo(int argc, char **argv, struct trapframe *tf)
{
f01006ad:	55                   	push   %ebp
f01006ae:	89 e5                	mov    %esp,%ebp
f01006b0:	83 ec 14             	sub    $0x14,%esp
    extern char _start[], entry[], etext[], edata[], end[];

    cprintf("Special kernel symbols:\n");
f01006b3:	68 cd 23 10 f0       	push   $0xf01023cd
f01006b8:	e8 85 09 00 00       	call   f0101042 <cprintf>
    cprintf("  _start                  %08x (phys)\n", _start);
f01006bd:	83 c4 08             	add    $0x8,%esp
f01006c0:	68 0c 00 10 00       	push   $0x10000c
f01006c5:	68 a0 24 10 f0       	push   $0xf01024a0
f01006ca:	e8 73 09 00 00       	call   f0101042 <cprintf>
    cprintf("  entry  %08x (virt)  %08x (phys)\n", entry, entry - KERNBASE);
f01006cf:	83 c4 0c             	add    $0xc,%esp
f01006d2:	68 0c 00 10 00       	push   $0x10000c
f01006d7:	68 0c 00 10 f0       	push   $0xf010000c
f01006dc:	68 c8 24 10 f0       	push   $0xf01024c8
f01006e1:	e8 5c 09 00 00       	call   f0101042 <cprintf>
    cprintf("  etext  %08x (virt)  %08x (phys)\n", etext, etext - KERNBASE);
f01006e6:	83 c4 0c             	add    $0xc,%esp
f01006e9:	68 f1 20 10 00       	push   $0x1020f1
f01006ee:	68 f1 20 10 f0       	push   $0xf01020f1
f01006f3:	68 ec 24 10 f0       	push   $0xf01024ec
f01006f8:	e8 45 09 00 00       	call   f0101042 <cprintf>
    cprintf("  edata  %08x (virt)  %08x (phys)\n", edata, edata - KERNBASE);
f01006fd:	83 c4 0c             	add    $0xc,%esp
f0100700:	68 00 43 11 00       	push   $0x114300
f0100705:	68 00 43 11 f0       	push   $0xf0114300
f010070a:	68 10 25 10 f0       	push   $0xf0102510
f010070f:	e8 2e 09 00 00       	call   f0101042 <cprintf>
    cprintf("  end    %08x (virt)  %08x (phys)\n", end, end - KERNBASE);
f0100714:	83 c4 0c             	add    $0xc,%esp
f0100717:	68 6c 49 11 00       	push   $0x11496c
f010071c:	68 6c 49 11 f0       	push   $0xf011496c
f0100721:	68 34 25 10 f0       	push   $0xf0102534
f0100726:	e8 17 09 00 00       	call   f0101042 <cprintf>
    cprintf("Kernel executable memory footprint: %dKB\n",
        ROUNDUP(end - entry, 1024) / 1024);
f010072b:	b8 6b 4d 11 f0       	mov    $0xf0114d6b,%eax
f0100730:	2d 0c 00 10 f0       	sub    $0xf010000c,%eax
    cprintf("  _start                  %08x (phys)\n", _start);
    cprintf("  entry  %08x (virt)  %08x (phys)\n", entry, entry - KERNBASE);
    cprintf("  etext  %08x (virt)  %08x (phys)\n", etext, etext - KERNBASE);
    cprintf("  edata  %08x (virt)  %08x (phys)\n", edata, edata - KERNBASE);
    cprintf("  end    %08x (virt)  %08x (phys)\n", end, end - KERNBASE);
    cprintf("Kernel executable memory footprint: %dKB\n",
f0100735:	83 c4 08             	add    $0x8,%esp
f0100738:	25 00 fc ff ff       	and    $0xfffffc00,%eax
f010073d:	8d 90 ff 03 00 00    	lea    0x3ff(%eax),%edx
f0100743:	85 c0                	test   %eax,%eax
f0100745:	0f 48 c2             	cmovs  %edx,%eax
f0100748:	c1 f8 0a             	sar    $0xa,%eax
f010074b:	50                   	push   %eax
f010074c:	68 58 25 10 f0       	push   $0xf0102558
f0100751:	e8 ec 08 00 00       	call   f0101042 <cprintf>
        ROUNDUP(end - entry, 1024) / 1024);
    return 0;
}
f0100756:	b8 00 00 00 00       	mov    $0x0,%eax
f010075b:	c9                   	leave  
f010075c:	c3                   	ret    

f010075d <mon_backtrace>:

int mon_backtrace(int argc, char **argv, struct trapframe *tf)
{
f010075d:	55                   	push   %ebp
f010075e:	89 e5                	mov    %esp,%ebp
f0100760:	57                   	push   %edi
f0100761:	56                   	push   %esi
f0100762:	53                   	push   %ebx
f0100763:	83 ec 38             	sub    $0x38,%esp
}

static __inline uint32_t read_ebp(void)
{
    uint32_t ebp;
    __asm __volatile("movl %%ebp,%0" : "=r" (ebp));
f0100766:	89 eb                	mov    %ebp,%ebx
    int i;
    int *ebp = (int *)read_ebp();
f0100768:	89 de                	mov    %ebx,%esi
    cprintf("Stack backtrace:\n");
f010076a:	68 e6 23 10 f0       	push   $0xf01023e6
f010076f:	e8 ce 08 00 00       	call   f0101042 <cprintf>
    while (ebp) {
f0100774:	83 c4 10             	add    $0x10,%esp
f0100777:	85 db                	test   %ebx,%ebx
f0100779:	0f 84 db 00 00 00    	je     f010085a <mon_backtrace+0xfd>
        uintptr_t eip = *(ebp + 1);
f010077f:	8b 5e 04             	mov    0x4(%esi),%ebx
        struct eip_debuginfo info;
        int *args = ebp + 2;
        int nargs;

        cprintf("  EIP: %08x ", eip);
f0100782:	83 ec 08             	sub    $0x8,%esp
f0100785:	53                   	push   %ebx
f0100786:	68 f8 23 10 f0       	push   $0xf01023f8
f010078b:	e8 b2 08 00 00       	call   f0101042 <cprintf>
        if (!debuginfo_eip(eip, &info)) {
f0100790:	83 c4 08             	add    $0x8,%esp
f0100793:	8d 45 d0             	lea    -0x30(%ebp),%eax
f0100796:	50                   	push   %eax
f0100797:	53                   	push   %ebx
f0100798:	e8 e5 09 00 00       	call   f0101182 <debuginfo_eip>
f010079d:	83 c4 10             	add    $0x10,%esp
f01007a0:	85 c0                	test   %eax,%eax
f01007a2:	75 37                	jne    f01007db <mon_backtrace+0x7e>
            cprintf("%s:%d: %.*s+%d\t", info.eip_file, info.eip_line,
f01007a4:	83 ec 08             	sub    $0x8,%esp
f01007a7:	2b 5d e0             	sub    -0x20(%ebp),%ebx
f01007aa:	53                   	push   %ebx
f01007ab:	ff 75 d8             	pushl  -0x28(%ebp)
f01007ae:	ff 75 dc             	pushl  -0x24(%ebp)
f01007b1:	ff 75 d4             	pushl  -0x2c(%ebp)
f01007b4:	ff 75 d0             	pushl  -0x30(%ebp)
f01007b7:	68 05 24 10 f0       	push   $0xf0102405
f01007bc:	e8 81 08 00 00       	call   f0101042 <cprintf>
                    info.eip_fn_namelen, info.eip_fn_name,
                    eip - info.eip_fn_addr);
            nargs = info.eip_fn_narg;
f01007c1:	8b 7d e4             	mov    -0x1c(%ebp),%edi
        } else {
            cprintf("<no debug info>\t");
            nargs = 6;
        }
        cprintf("  EBP: %08x ", ebp);
f01007c4:	83 c4 18             	add    $0x18,%esp
f01007c7:	56                   	push   %esi
f01007c8:	68 15 24 10 f0       	push   $0xf0102415
f01007cd:	e8 70 08 00 00       	call   f0101042 <cprintf>
        if (nargs)
f01007d2:	83 c4 10             	add    $0x10,%esp
f01007d5:	85 ff                	test   %edi,%edi
f01007d7:	74 67                	je     f0100840 <mon_backtrace+0xe3>
f01007d9:	eb 31                	jmp    f010080c <mon_backtrace+0xaf>
            cprintf("%s:%d: %.*s+%d\t", info.eip_file, info.eip_line,
                    info.eip_fn_namelen, info.eip_fn_name,
                    eip - info.eip_fn_addr);
            nargs = info.eip_fn_narg;
        } else {
            cprintf("<no debug info>\t");
f01007db:	83 ec 0c             	sub    $0xc,%esp
f01007de:	68 22 24 10 f0       	push   $0xf0102422
f01007e3:	e8 5a 08 00 00       	call   f0101042 <cprintf>
            nargs = 6;
        }
        cprintf("  EBP: %08x ", ebp);
f01007e8:	83 c4 08             	add    $0x8,%esp
f01007eb:	56                   	push   %esi
f01007ec:	68 15 24 10 f0       	push   $0xf0102415
f01007f1:	e8 4c 08 00 00       	call   f0101042 <cprintf>
        if (nargs)
            cprintf("  args ");
f01007f6:	c7 04 24 33 24 10 f0 	movl   $0xf0102433,(%esp)
f01007fd:	e8 40 08 00 00       	call   f0101042 <cprintf>
f0100802:	83 c4 10             	add    $0x10,%esp
                    info.eip_fn_namelen, info.eip_fn_name,
                    eip - info.eip_fn_addr);
            nargs = info.eip_fn_narg;
        } else {
            cprintf("<no debug info>\t");
            nargs = 6;
f0100805:	bf 06 00 00 00       	mov    $0x6,%edi
f010080a:	eb 14                	jmp    f0100820 <mon_backtrace+0xc3>
        }
        cprintf("  EBP: %08x ", ebp);
        if (nargs)
            cprintf("  args ");
f010080c:	83 ec 0c             	sub    $0xc,%esp
f010080f:	68 33 24 10 f0       	push   $0xf0102433
f0100814:	e8 29 08 00 00       	call   f0101042 <cprintf>
        for (i = 0; i < nargs; i++)
f0100819:	83 c4 10             	add    $0x10,%esp
f010081c:	85 ff                	test   %edi,%edi
f010081e:	7e 20                	jle    f0100840 <mon_backtrace+0xe3>
                    info.eip_fn_namelen, info.eip_fn_name,
                    eip - info.eip_fn_addr);
            nargs = info.eip_fn_narg;
        } else {
            cprintf("<no debug info>\t");
            nargs = 6;
f0100820:	bb 00 00 00 00       	mov    $0x0,%ebx
        }
        cprintf("  EBP: %08x ", ebp);
        if (nargs)
            cprintf("  args ");
        for (i = 0; i < nargs; i++)
            cprintf("%08x ", args[i]);
f0100825:	83 ec 08             	sub    $0x8,%esp
f0100828:	ff 74 9e 08          	pushl  0x8(%esi,%ebx,4)
f010082c:	68 1c 24 10 f0       	push   $0xf010241c
f0100831:	e8 0c 08 00 00       	call   f0101042 <cprintf>
            nargs = 6;
        }
        cprintf("  EBP: %08x ", ebp);
        if (nargs)
            cprintf("  args ");
        for (i = 0; i < nargs; i++)
f0100836:	83 c3 01             	add    $0x1,%ebx
f0100839:	83 c4 10             	add    $0x10,%esp
f010083c:	39 fb                	cmp    %edi,%ebx
f010083e:	75 e5                	jne    f0100825 <mon_backtrace+0xc8>
            cprintf("%08x ", args[i]);
        cprintf("\n");
f0100840:	83 ec 0c             	sub    $0xc,%esp
f0100843:	68 3c 21 10 f0       	push   $0xf010213c
f0100848:	e8 f5 07 00 00       	call   f0101042 <cprintf>
        ebp = (int *)*ebp;
f010084d:	8b 36                	mov    (%esi),%esi
int mon_backtrace(int argc, char **argv, struct trapframe *tf)
{
    int i;
    int *ebp = (int *)read_ebp();
    cprintf("Stack backtrace:\n");
    while (ebp) {
f010084f:	83 c4 10             	add    $0x10,%esp
f0100852:	85 f6                	test   %esi,%esi
f0100854:	0f 85 25 ff ff ff    	jne    f010077f <mon_backtrace+0x22>
            cprintf("%08x ", args[i]);
        cprintf("\n");
        ebp = (int *)*ebp;
    }
    return 0;
}
f010085a:	b8 00 00 00 00       	mov    $0x0,%eax
f010085f:	8d 65 f4             	lea    -0xc(%ebp),%esp
f0100862:	5b                   	pop    %ebx
f0100863:	5e                   	pop    %esi
f0100864:	5f                   	pop    %edi
f0100865:	5d                   	pop    %ebp
f0100866:	c3                   	ret    

f0100867 <runcmd>:

#define WHITESPACE "\t\r\n "
#define MAXARGS 16

static int runcmd(char *buf, struct trapframe *tf)
{
f0100867:	55                   	push   %ebp
f0100868:	89 e5                	mov    %esp,%ebp
f010086a:	57                   	push   %edi
f010086b:	56                   	push   %esi
f010086c:	53                   	push   %ebx
f010086d:	83 ec 5c             	sub    $0x5c,%esp
f0100870:	89 c3                	mov    %eax,%ebx
f0100872:	89 55 a4             	mov    %edx,-0x5c(%ebp)
    char *argv[MAXARGS];
    int i;

    /* Parse the command buffer into whitespace-separated arguments */
    argc = 0;
    argv[argc] = 0;
f0100875:	c7 45 a8 00 00 00 00 	movl   $0x0,-0x58(%ebp)
    int argc;
    char *argv[MAXARGS];
    int i;

    /* Parse the command buffer into whitespace-separated arguments */
    argc = 0;
f010087c:	be 00 00 00 00       	mov    $0x0,%esi
f0100881:	eb 0a                	jmp    f010088d <runcmd+0x26>
    argv[argc] = 0;
    while (1) {
        /* gobble whitespace */
        while (*buf && strchr(WHITESPACE, *buf))
            *buf++ = 0;
f0100883:	c6 03 00             	movb   $0x0,(%ebx)
f0100886:	89 f7                	mov    %esi,%edi
f0100888:	8d 5b 01             	lea    0x1(%ebx),%ebx
f010088b:	89 fe                	mov    %edi,%esi
    /* Parse the command buffer into whitespace-separated arguments */
    argc = 0;
    argv[argc] = 0;
    while (1) {
        /* gobble whitespace */
        while (*buf && strchr(WHITESPACE, *buf))
f010088d:	0f b6 03             	movzbl (%ebx),%eax
f0100890:	84 c0                	test   %al,%al
f0100892:	74 6d                	je     f0100901 <runcmd+0x9a>
f0100894:	83 ec 08             	sub    $0x8,%esp
f0100897:	0f be c0             	movsbl %al,%eax
f010089a:	50                   	push   %eax
f010089b:	68 3b 24 10 f0       	push   $0xf010243b
f01008a0:	e8 29 13 00 00       	call   f0101bce <strchr>
f01008a5:	83 c4 10             	add    $0x10,%esp
f01008a8:	85 c0                	test   %eax,%eax
f01008aa:	75 d7                	jne    f0100883 <runcmd+0x1c>
            *buf++ = 0;
        if (*buf == 0)
f01008ac:	0f b6 03             	movzbl (%ebx),%eax
f01008af:	84 c0                	test   %al,%al
f01008b1:	74 4e                	je     f0100901 <runcmd+0x9a>
            break;

        /* save and scan past next arg */
        if (argc == MAXARGS-1) {
f01008b3:	83 fe 0f             	cmp    $0xf,%esi
f01008b6:	75 1c                	jne    f01008d4 <runcmd+0x6d>
            cprintf("Too many arguments (max %d)\n", MAXARGS);
f01008b8:	83 ec 08             	sub    $0x8,%esp
f01008bb:	6a 10                	push   $0x10
f01008bd:	68 40 24 10 f0       	push   $0xf0102440
f01008c2:	e8 7b 07 00 00       	call   f0101042 <cprintf>
            return 0;
f01008c7:	83 c4 10             	add    $0x10,%esp
f01008ca:	b8 00 00 00 00       	mov    $0x0,%eax
f01008cf:	e9 99 00 00 00       	jmp    f010096d <runcmd+0x106>
        }
        argv[argc++] = buf;
f01008d4:	8d 7e 01             	lea    0x1(%esi),%edi
f01008d7:	89 5c b5 a8          	mov    %ebx,-0x58(%ebp,%esi,4)
f01008db:	eb 0a                	jmp    f01008e7 <runcmd+0x80>
        while (*buf && !strchr(WHITESPACE, *buf))
            buf++;
f01008dd:	83 c3 01             	add    $0x1,%ebx
        if (argc == MAXARGS-1) {
            cprintf("Too many arguments (max %d)\n", MAXARGS);
            return 0;
        }
        argv[argc++] = buf;
        while (*buf && !strchr(WHITESPACE, *buf))
f01008e0:	0f b6 03             	movzbl (%ebx),%eax
f01008e3:	84 c0                	test   %al,%al
f01008e5:	74 a4                	je     f010088b <runcmd+0x24>
f01008e7:	83 ec 08             	sub    $0x8,%esp
f01008ea:	0f be c0             	movsbl %al,%eax
f01008ed:	50                   	push   %eax
f01008ee:	68 3b 24 10 f0       	push   $0xf010243b
f01008f3:	e8 d6 12 00 00       	call   f0101bce <strchr>
f01008f8:	83 c4 10             	add    $0x10,%esp
f01008fb:	85 c0                	test   %eax,%eax
f01008fd:	74 de                	je     f01008dd <runcmd+0x76>
f01008ff:	eb 8a                	jmp    f010088b <runcmd+0x24>
            buf++;
    }
    argv[argc] = 0;
f0100901:	c7 44 b5 a8 00 00 00 	movl   $0x0,-0x58(%ebp,%esi,4)
f0100908:	00 

    /* Lookup and invoke the command */
    if (argc == 0)
        return 0;
f0100909:	b8 00 00 00 00       	mov    $0x0,%eax
            buf++;
    }
    argv[argc] = 0;

    /* Lookup and invoke the command */
    if (argc == 0)
f010090e:	85 f6                	test   %esi,%esi
f0100910:	74 5b                	je     f010096d <runcmd+0x106>
f0100912:	bb 00 00 00 00       	mov    $0x0,%ebx
        return 0;
    for (i = 0; i < NCOMMANDS; i++) {
        if (strcmp(argv[0], commands[i].name) == 0)
f0100917:	83 ec 08             	sub    $0x8,%esp
f010091a:	8d 04 5b             	lea    (%ebx,%ebx,2),%eax
f010091d:	ff 34 85 e0 25 10 f0 	pushl  -0xfefda20(,%eax,4)
f0100924:	ff 75 a8             	pushl  -0x58(%ebp)
f0100927:	e8 1e 12 00 00       	call   f0101b4a <strcmp>
f010092c:	83 c4 10             	add    $0x10,%esp
f010092f:	85 c0                	test   %eax,%eax
f0100931:	75 1a                	jne    f010094d <runcmd+0xe6>
            return commands[i].func(argc, argv, tf);
f0100933:	83 ec 04             	sub    $0x4,%esp
f0100936:	8d 04 5b             	lea    (%ebx,%ebx,2),%eax
f0100939:	ff 75 a4             	pushl  -0x5c(%ebp)
f010093c:	8d 55 a8             	lea    -0x58(%ebp),%edx
f010093f:	52                   	push   %edx
f0100940:	56                   	push   %esi
f0100941:	ff 14 85 e8 25 10 f0 	call   *-0xfefda18(,%eax,4)
f0100948:	83 c4 10             	add    $0x10,%esp
f010094b:	eb 20                	jmp    f010096d <runcmd+0x106>
    argv[argc] = 0;

    /* Lookup and invoke the command */
    if (argc == 0)
        return 0;
    for (i = 0; i < NCOMMANDS; i++) {
f010094d:	83 c3 01             	add    $0x1,%ebx
f0100950:	83 fb 03             	cmp    $0x3,%ebx
f0100953:	75 c2                	jne    f0100917 <runcmd+0xb0>
        if (strcmp(argv[0], commands[i].name) == 0)
            return commands[i].func(argc, argv, tf);
    }
    cprintf("Unknown command '%s'\n", argv[0]);
f0100955:	83 ec 08             	sub    $0x8,%esp
f0100958:	ff 75 a8             	pushl  -0x58(%ebp)
f010095b:	68 5d 24 10 f0       	push   $0xf010245d
f0100960:	e8 dd 06 00 00       	call   f0101042 <cprintf>
    return 0;
f0100965:	83 c4 10             	add    $0x10,%esp
f0100968:	b8 00 00 00 00       	mov    $0x0,%eax
}
f010096d:	8d 65 f4             	lea    -0xc(%ebp),%esp
f0100970:	5b                   	pop    %ebx
f0100971:	5e                   	pop    %esi
f0100972:	5f                   	pop    %edi
f0100973:	5d                   	pop    %ebp
f0100974:	c3                   	ret    

f0100975 <monitor>:

void monitor(struct trapframe *tf)
{
f0100975:	55                   	push   %ebp
f0100976:	89 e5                	mov    %esp,%ebp
f0100978:	53                   	push   %ebx
f0100979:	83 ec 10             	sub    $0x10,%esp
f010097c:	8b 5d 08             	mov    0x8(%ebp),%ebx
    char *buf;

    cprintf("Welcome to the JOS kernel monitor!\n");
f010097f:	68 84 25 10 f0       	push   $0xf0102584
f0100984:	e8 b9 06 00 00       	call   f0101042 <cprintf>
    cprintf("Type 'help' for a list of commands.\n");
f0100989:	c7 04 24 a8 25 10 f0 	movl   $0xf01025a8,(%esp)
f0100990:	e8 ad 06 00 00       	call   f0101042 <cprintf>
f0100995:	83 c4 10             	add    $0x10,%esp


    while (1) {
        buf = readline("K> ");
f0100998:	83 ec 0c             	sub    $0xc,%esp
f010099b:	68 73 24 10 f0       	push   $0xf0102473
f01009a0:	e8 b1 0f 00 00       	call   f0101956 <readline>
        if (buf != NULL)
f01009a5:	83 c4 10             	add    $0x10,%esp
f01009a8:	85 c0                	test   %eax,%eax
f01009aa:	74 ec                	je     f0100998 <monitor+0x23>
            if (runcmd(buf, tf) < 0)
f01009ac:	89 da                	mov    %ebx,%edx
f01009ae:	e8 b4 fe ff ff       	call   f0100867 <runcmd>
f01009b3:	85 c0                	test   %eax,%eax
f01009b5:	79 e1                	jns    f0100998 <monitor+0x23>
                break;
    }
}
f01009b7:	8b 5d fc             	mov    -0x4(%ebp),%ebx
f01009ba:	c9                   	leave  
f01009bb:	c3                   	ret    

f01009bc <page2pa>:
struct page_info *page_alloc(int alloc_flags);
void page_free(struct page_info *pp);
void page_decref(struct page_info *pp);

static inline physaddr_t page2pa(struct page_info *pp)
{
f01009bc:	55                   	push   %ebp
f01009bd:	89 e5                	mov    %esp,%ebp
    return (pp - pages) << PGSHIFT;
f01009bf:	2b 05 68 49 11 f0    	sub    0xf0114968,%eax
f01009c5:	c1 f8 03             	sar    $0x3,%eax
f01009c8:	c1 e0 0c             	shl    $0xc,%eax
}
f01009cb:	5d                   	pop    %ebp
f01009cc:	c3                   	ret    

f01009cd <boot_alloc>:
 *
 * If we're out of memory, boot_alloc should panic.
 * This function may ONLY be used during initialization, before the
 * page_free_list list has been set up. */
static void *boot_alloc(uint32_t n)
{
f01009cd:	55                   	push   %ebp
f01009ce:	89 e5                	mov    %esp,%ebp
f01009d0:	53                   	push   %ebx
f01009d1:	83 ec 04             	sub    $0x4,%esp
f01009d4:	89 c3                	mov    %eax,%ebx

    /* Initialize nextfree if this is the first time. 'end' is a magic symbol
     * automatically generated by the linker, which points to the end of the
     * kernel's bss segment: the first virtual address that the linker did *not*
     * assign to any kernel code or global variables. */
    if (!nextfree) {
f01009d6:	83 3d 38 45 11 f0 00 	cmpl   $0x0,0xf0114538
f01009dd:	75 0f                	jne    f01009ee <boot_alloc+0x21>
        extern char end[];
        nextfree = ROUNDUP((char *) end, PGSIZE);
f01009df:	b8 6b 59 11 f0       	mov    $0xf011596b,%eax
f01009e4:	25 00 f0 ff ff       	and    $0xfffff000,%eax
f01009e9:	a3 38 45 11 f0       	mov    %eax,0xf0114538
    }

    // Calc available:
    unsigned avail = npages * PGSIZE - (unsigned) nextfree;
    cprintf("available mem in bytes: %u\n", avail);
f01009ee:	83 ec 08             	sub    $0x8,%esp
f01009f1:	a1 64 49 11 f0       	mov    0xf0114964,%eax
f01009f6:	c1 e0 0c             	shl    $0xc,%eax
f01009f9:	2b 05 38 45 11 f0    	sub    0xf0114538,%eax
f01009ff:	50                   	push   %eax
f0100a00:	68 04 26 10 f0       	push   $0xf0102604
f0100a05:	e8 38 06 00 00       	call   f0101042 <cprintf>

    // Calc Requested:
    unsigned req = n;
    cprintf("Requested mem in bytes: %u\n", req);
f0100a0a:	83 c4 08             	add    $0x8,%esp
f0100a0d:	53                   	push   %ebx
f0100a0e:	68 20 26 10 f0       	push   $0xf0102620
f0100a13:	e8 2a 06 00 00       	call   f0101042 <cprintf>


    // See if there are enough bytes:
    if (npages * PGSIZE  - (unsigned) nextfree < n){  // Avalable < Requested
f0100a18:	8b 0d 38 45 11 f0    	mov    0xf0114538,%ecx
f0100a1e:	a1 64 49 11 f0       	mov    0xf0114964,%eax
f0100a23:	c1 e0 0c             	shl    $0xc,%eax
f0100a26:	29 c8                	sub    %ecx,%eax
f0100a28:	83 c4 10             	add    $0x10,%esp
f0100a2b:	39 c3                	cmp    %eax,%ebx
f0100a2d:	76 14                	jbe    f0100a43 <boot_alloc+0x76>
        panic("boot_alloc: not enough memory.");
f0100a2f:	83 ec 04             	sub    $0x4,%esp
f0100a32:	68 74 27 10 f0       	push   $0xf0102774
f0100a37:	6a 62                	push   $0x62
f0100a39:	68 3c 26 10 f0       	push   $0xf010263c
f0100a3e:	e8 36 f6 ff ff       	call   f0100079 <_panic>
     */

    // CASE: n == 0:
    if (n == 0)
    {
        return nextfree;
f0100a43:	89 c8                	mov    %ecx,%eax
     *
     * LAB 1: Your code here.
     */

    // CASE: n == 0:
    if (n == 0)
f0100a45:	85 db                	test   %ebx,%ebx
f0100a47:	74 3e                	je     f0100a87 <boot_alloc+0xba>
    // CASE n > 0:
    } else if (n > 0)
    {
        
        // Allocate chunk
        if (PGSIZE % n != 0)
f0100a49:	b8 00 10 00 00       	mov    $0x1000,%eax
f0100a4e:	ba 00 00 00 00       	mov    $0x0,%edx
f0100a53:	f7 f3                	div    %ebx
f0100a55:	85 d2                	test   %edx,%edx
f0100a57:	74 08                	je     f0100a61 <boot_alloc+0x94>
        {
            pages_to_alloc = n / PGSIZE + 1;
f0100a59:	c1 eb 0c             	shr    $0xc,%ebx
f0100a5c:	83 c3 01             	add    $0x1,%ebx
f0100a5f:	eb 03                	jmp    f0100a64 <boot_alloc+0x97>
        } else {
            pages_to_alloc = n / PGSIZE;
f0100a61:	c1 eb 0c             	shr    $0xc,%ebx
        }

        // Increment nextfree:
        result = nextfree;
        nextfree += PGSIZE * pages_to_alloc;
f0100a64:	89 d8                	mov    %ebx,%eax
f0100a66:	c1 e0 0c             	shl    $0xc,%eax
f0100a69:	01 c1                	add    %eax,%ecx
f0100a6b:	89 0d 38 45 11 f0    	mov    %ecx,0xf0114538
        cprintf("pages to alloc: %u\n", pages_to_alloc);
f0100a71:	83 ec 08             	sub    $0x8,%esp
f0100a74:	53                   	push   %ebx
f0100a75:	68 48 26 10 f0       	push   $0xf0102648
f0100a7a:	e8 c3 05 00 00       	call   f0101042 <cprintf>


        return nextfree;
f0100a7f:	a1 38 45 11 f0       	mov    0xf0114538,%eax
f0100a84:	83 c4 10             	add    $0x10,%esp
        // alloc(pages_to_alloc);
    }
    // CASE else:
    return NULL;
}
f0100a87:	8b 5d fc             	mov    -0x4(%ebp),%ebx
f0100a8a:	c9                   	leave  
f0100a8b:	c3                   	ret    

f0100a8c <_kaddr>:
/* This macro takes a physical address and returns the corresponding kernel
 * virtual address.  It panics if you pass an invalid physical address. */
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void *_kaddr(const char *file, int line, physaddr_t pa)
{
f0100a8c:	55                   	push   %ebp
f0100a8d:	89 e5                	mov    %esp,%ebp
f0100a8f:	53                   	push   %ebx
f0100a90:	83 ec 04             	sub    $0x4,%esp
    if (PGNUM(pa) >= npages)
f0100a93:	89 cb                	mov    %ecx,%ebx
f0100a95:	c1 eb 0c             	shr    $0xc,%ebx
f0100a98:	3b 1d 64 49 11 f0    	cmp    0xf0114964,%ebx
f0100a9e:	72 0d                	jb     f0100aad <_kaddr+0x21>
        _panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0100aa0:	51                   	push   %ecx
f0100aa1:	68 94 27 10 f0       	push   $0xf0102794
f0100aa6:	52                   	push   %edx
f0100aa7:	50                   	push   %eax
f0100aa8:	e8 cc f5 ff ff       	call   f0100079 <_panic>
    return (void *)(pa + KERNBASE);
f0100aad:	8d 81 00 00 00 f0    	lea    -0x10000000(%ecx),%eax
}
f0100ab3:	8b 5d fc             	mov    -0x4(%ebp),%ebx
f0100ab6:	c9                   	leave  
f0100ab7:	c3                   	ret    

f0100ab8 <page2kva>:
        panic("pa2page called with invalid pa");
    return &pages[PGNUM(pa)];
}

static inline void *page2kva(struct page_info *pp)
{
f0100ab8:	55                   	push   %ebp
f0100ab9:	89 e5                	mov    %esp,%ebp
f0100abb:	83 ec 08             	sub    $0x8,%esp
    return KADDR(page2pa(pp));
f0100abe:	e8 f9 fe ff ff       	call   f01009bc <page2pa>
f0100ac3:	89 c1                	mov    %eax,%ecx
f0100ac5:	ba 48 00 00 00       	mov    $0x48,%edx
f0100aca:	b8 5c 26 10 f0       	mov    $0xf010265c,%eax
f0100acf:	e8 b8 ff ff ff       	call   f0100a8c <_kaddr>
}
f0100ad4:	c9                   	leave  
f0100ad5:	c3                   	ret    

f0100ad6 <nvram_read>:
/***************************************************************
 * Detect machine's physical memory setup.
 ***************************************************************/

static int nvram_read(int r)
{
f0100ad6:	55                   	push   %ebp
f0100ad7:	89 e5                	mov    %esp,%ebp
f0100ad9:	56                   	push   %esi
f0100ada:	53                   	push   %ebx
f0100adb:	89 c3                	mov    %eax,%ebx
    return mc146818_read(r) | (mc146818_read(r + 1) << 8);
f0100add:	83 ec 0c             	sub    $0xc,%esp
f0100ae0:	50                   	push   %eax
f0100ae1:	e8 f5 04 00 00       	call   f0100fdb <mc146818_read>
f0100ae6:	89 c6                	mov    %eax,%esi
f0100ae8:	83 c3 01             	add    $0x1,%ebx
f0100aeb:	89 1c 24             	mov    %ebx,(%esp)
f0100aee:	e8 e8 04 00 00       	call   f0100fdb <mc146818_read>
f0100af3:	c1 e0 08             	shl    $0x8,%eax
f0100af6:	09 f0                	or     %esi,%eax
}
f0100af8:	8d 65 f8             	lea    -0x8(%ebp),%esp
f0100afb:	5b                   	pop    %ebx
f0100afc:	5e                   	pop    %esi
f0100afd:	5d                   	pop    %ebp
f0100afe:	c3                   	ret    

f0100aff <i386_detect_memory>:

static void i386_detect_memory(void)
{
f0100aff:	55                   	push   %ebp
f0100b00:	89 e5                	mov    %esp,%ebp
f0100b02:	83 ec 08             	sub    $0x8,%esp
    size_t npages_extmem;

    /* Use CMOS calls to measure available base & extended memory.
     * (CMOS calls return results in kilobytes.) */
    npages_basemem = (nvram_read(NVRAM_BASELO) * 1024) / PGSIZE;
f0100b05:	b8 15 00 00 00       	mov    $0x15,%eax
f0100b0a:	e8 c7 ff ff ff       	call   f0100ad6 <nvram_read>
f0100b0f:	c1 e0 0a             	shl    $0xa,%eax
f0100b12:	8d 90 ff 0f 00 00    	lea    0xfff(%eax),%edx
f0100b18:	85 c0                	test   %eax,%eax
f0100b1a:	0f 48 c2             	cmovs  %edx,%eax
f0100b1d:	c1 f8 0c             	sar    $0xc,%eax
f0100b20:	a3 40 45 11 f0       	mov    %eax,0xf0114540
    npages_extmem = (nvram_read(NVRAM_EXTLO) * 1024) / PGSIZE;
f0100b25:	b8 17 00 00 00       	mov    $0x17,%eax
f0100b2a:	e8 a7 ff ff ff       	call   f0100ad6 <nvram_read>
f0100b2f:	c1 e0 0a             	shl    $0xa,%eax
f0100b32:	8d 90 ff 0f 00 00    	lea    0xfff(%eax),%edx
f0100b38:	85 c0                	test   %eax,%eax
f0100b3a:	0f 48 c2             	cmovs  %edx,%eax
f0100b3d:	c1 f8 0c             	sar    $0xc,%eax

    /* Calculate the number of physical pages available in both base and
     * extended memory. */
    if (npages_extmem)
f0100b40:	85 c0                	test   %eax,%eax
f0100b42:	74 0e                	je     f0100b52 <i386_detect_memory+0x53>
        npages = (EXTPHYSMEM / PGSIZE) + npages_extmem;
f0100b44:	8d 90 00 01 00 00    	lea    0x100(%eax),%edx
f0100b4a:	89 15 64 49 11 f0    	mov    %edx,0xf0114964
f0100b50:	eb 0c                	jmp    f0100b5e <i386_detect_memory+0x5f>
    else
        npages = npages_basemem;
f0100b52:	8b 15 40 45 11 f0    	mov    0xf0114540,%edx
f0100b58:	89 15 64 49 11 f0    	mov    %edx,0xf0114964

    cprintf("Physical memory: %uK available, base = %uK, extended = %uK\n",
f0100b5e:	c1 e0 0c             	shl    $0xc,%eax
f0100b61:	c1 e8 0a             	shr    $0xa,%eax
f0100b64:	50                   	push   %eax
f0100b65:	a1 40 45 11 f0       	mov    0xf0114540,%eax
f0100b6a:	c1 e0 0c             	shl    $0xc,%eax
f0100b6d:	c1 e8 0a             	shr    $0xa,%eax
f0100b70:	50                   	push   %eax
f0100b71:	a1 64 49 11 f0       	mov    0xf0114964,%eax
f0100b76:	c1 e0 0c             	shl    $0xc,%eax
f0100b79:	c1 e8 0a             	shr    $0xa,%eax
f0100b7c:	50                   	push   %eax
f0100b7d:	68 b8 27 10 f0       	push   $0xf01027b8
f0100b82:	e8 bb 04 00 00       	call   f0101042 <cprintf>
        npages * PGSIZE / 1024,
        npages_basemem * PGSIZE / 1024,
        npages_extmem * PGSIZE / 1024);
}
f0100b87:	83 c4 10             	add    $0x10,%esp
f0100b8a:	c9                   	leave  
f0100b8b:	c3                   	ret    

f0100b8c <check_page_free_list>:

/*
 * Check that the pages on the page_free_list are reasonable.
 */
static void check_page_free_list(bool only_low_memory)
{
f0100b8c:	55                   	push   %ebp
f0100b8d:	89 e5                	mov    %esp,%ebp
f0100b8f:	57                   	push   %edi
f0100b90:	56                   	push   %esi
f0100b91:	53                   	push   %ebx
f0100b92:	83 ec 2c             	sub    $0x2c,%esp
    struct page_info *pp;
    unsigned pdx_limit = only_low_memory ? 1 : NPDENTRIES;
f0100b95:	84 c0                	test   %al,%al
f0100b97:	0f 85 51 02 00 00    	jne    f0100dee <check_page_free_list+0x262>
    int nfree_basemem = 0, nfree_extmem = 0;
    char *first_free_page;

    if (!page_free_list)
f0100b9d:	8b 1d 3c 45 11 f0    	mov    0xf011453c,%ebx
 * Check that the pages on the page_free_list are reasonable.
 */
static void check_page_free_list(bool only_low_memory)
{
    struct page_info *pp;
    unsigned pdx_limit = only_low_memory ? 1 : NPDENTRIES;
f0100ba3:	be 00 04 00 00       	mov    $0x400,%esi
    int nfree_basemem = 0, nfree_extmem = 0;
    char *first_free_page;

    if (!page_free_list)
f0100ba8:	85 db                	test   %ebx,%ebx
f0100baa:	75 68                	jne    f0100c14 <check_page_free_list+0x88>
        panic("'page_free_list' is a null pointer!");
f0100bac:	83 ec 04             	sub    $0x4,%esp
f0100baf:	68 f4 27 10 f0       	push   $0xf01027f4
f0100bb4:	68 4b 01 00 00       	push   $0x14b
f0100bb9:	68 3c 26 10 f0       	push   $0xf010263c
f0100bbe:	e8 b6 f4 ff ff       	call   f0100079 <_panic>

    if (only_low_memory) {
        /* Move pages with lower addresses first in the free list, since
         * entry_pgdir does not map all pages. */
        struct page_info *pp1, *pp2;
        struct page_info **tp[2] = { &pp1, &pp2 };
f0100bc3:	8d 45 d8             	lea    -0x28(%ebp),%eax
f0100bc6:	89 45 e0             	mov    %eax,-0x20(%ebp)
f0100bc9:	8d 45 dc             	lea    -0x24(%ebp),%eax
f0100bcc:	89 45 e4             	mov    %eax,-0x1c(%ebp)
        for (pp = page_free_list; pp; pp = pp->pp_link) {
            int pagetype = PDX(page2pa(pp)) >= pdx_limit;
f0100bcf:	89 d8                	mov    %ebx,%eax
f0100bd1:	e8 e6 fd ff ff       	call   f01009bc <page2pa>
f0100bd6:	c1 e8 16             	shr    $0x16,%eax
f0100bd9:	85 c0                	test   %eax,%eax
f0100bdb:	0f 95 c0             	setne  %al
f0100bde:	0f b6 c0             	movzbl %al,%eax
            *tp[pagetype] = pp;
f0100be1:	8b 54 85 e0          	mov    -0x20(%ebp,%eax,4),%edx
f0100be5:	89 1a                	mov    %ebx,(%edx)
            tp[pagetype] = &pp->pp_link;
f0100be7:	89 5c 85 e0          	mov    %ebx,-0x20(%ebp,%eax,4)
    if (only_low_memory) {
        /* Move pages with lower addresses first in the free list, since
         * entry_pgdir does not map all pages. */
        struct page_info *pp1, *pp2;
        struct page_info **tp[2] = { &pp1, &pp2 };
        for (pp = page_free_list; pp; pp = pp->pp_link) {
f0100beb:	8b 1b                	mov    (%ebx),%ebx
f0100bed:	85 db                	test   %ebx,%ebx
f0100bef:	75 de                	jne    f0100bcf <check_page_free_list+0x43>
            int pagetype = PDX(page2pa(pp)) >= pdx_limit;
            *tp[pagetype] = pp;
            tp[pagetype] = &pp->pp_link;
        }
        *tp[1] = 0;
f0100bf1:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0100bf4:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
        *tp[0] = pp2;
f0100bfa:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0100bfd:	8b 55 dc             	mov    -0x24(%ebp),%edx
f0100c00:	89 10                	mov    %edx,(%eax)
        page_free_list = pp1;
f0100c02:	8b 5d d8             	mov    -0x28(%ebp),%ebx
f0100c05:	89 1d 3c 45 11 f0    	mov    %ebx,0xf011453c
    }

    /* if there's a page that shouldn't be on the free list,
     * try to make sure it eventually causes trouble. */
    for (pp = page_free_list; pp; pp = pp->pp_link)
f0100c0b:	85 db                	test   %ebx,%ebx
f0100c0d:	74 36                	je     f0100c45 <check_page_free_list+0xb9>
f0100c0f:	be 01 00 00 00       	mov    $0x1,%esi
        if (PDX(page2pa(pp)) < pdx_limit)
f0100c14:	89 d8                	mov    %ebx,%eax
f0100c16:	e8 a1 fd ff ff       	call   f01009bc <page2pa>
f0100c1b:	c1 e8 16             	shr    $0x16,%eax
f0100c1e:	39 f0                	cmp    %esi,%eax
f0100c20:	73 1d                	jae    f0100c3f <check_page_free_list+0xb3>
            memset(page2kva(pp), 0x97, 128);
f0100c22:	89 d8                	mov    %ebx,%eax
f0100c24:	e8 8f fe ff ff       	call   f0100ab8 <page2kva>
f0100c29:	83 ec 04             	sub    $0x4,%esp
f0100c2c:	68 80 00 00 00       	push   $0x80
f0100c31:	68 97 00 00 00       	push   $0x97
f0100c36:	50                   	push   %eax
f0100c37:	e8 f0 0f 00 00       	call   f0101c2c <memset>
f0100c3c:	83 c4 10             	add    $0x10,%esp
        page_free_list = pp1;
    }

    /* if there's a page that shouldn't be on the free list,
     * try to make sure it eventually causes trouble. */
    for (pp = page_free_list; pp; pp = pp->pp_link)
f0100c3f:	8b 1b                	mov    (%ebx),%ebx
f0100c41:	85 db                	test   %ebx,%ebx
f0100c43:	75 cf                	jne    f0100c14 <check_page_free_list+0x88>
        if (PDX(page2pa(pp)) < pdx_limit)
            memset(page2kva(pp), 0x97, 128);

    first_free_page = (char *) boot_alloc(0);
f0100c45:	b8 00 00 00 00       	mov    $0x0,%eax
f0100c4a:	e8 7e fd ff ff       	call   f01009cd <boot_alloc>
f0100c4f:	89 45 c8             	mov    %eax,-0x38(%ebp)
    for (pp = page_free_list; pp; pp = pp->pp_link) {
f0100c52:	8b 1d 3c 45 11 f0    	mov    0xf011453c,%ebx
f0100c58:	85 db                	test   %ebx,%ebx
f0100c5a:	0f 84 58 01 00 00    	je     f0100db8 <check_page_free_list+0x22c>
        /* check that we didn't corrupt the free list itself */
        assert(pp >= pages);
f0100c60:	8b 35 68 49 11 f0    	mov    0xf0114968,%esi
f0100c66:	39 f3                	cmp    %esi,%ebx
f0100c68:	72 2c                	jb     f0100c96 <check_page_free_list+0x10a>
        assert(pp < pages + npages);
f0100c6a:	a1 64 49 11 f0       	mov    0xf0114964,%eax
f0100c6f:	8d 04 c6             	lea    (%esi,%eax,8),%eax
f0100c72:	89 45 d4             	mov    %eax,-0x2c(%ebp)
f0100c75:	39 c3                	cmp    %eax,%ebx
f0100c77:	73 3b                	jae    f0100cb4 <check_page_free_list+0x128>
        assert(((char *) pp - (char *) pages) % sizeof(*pp) == 0);
f0100c79:	89 75 d0             	mov    %esi,-0x30(%ebp)
f0100c7c:	89 d8                	mov    %ebx,%eax
f0100c7e:	29 f0                	sub    %esi,%eax
f0100c80:	a8 07                	test   $0x7,%al
f0100c82:	75 52                	jne    f0100cd6 <check_page_free_list+0x14a>
f0100c84:	bf 00 00 00 00       	mov    $0x0,%edi
f0100c89:	c7 45 cc 00 00 00 00 	movl   $0x0,-0x34(%ebp)
f0100c90:	eb 5d                	jmp    f0100cef <check_page_free_list+0x163>
            memset(page2kva(pp), 0x97, 128);

    first_free_page = (char *) boot_alloc(0);
    for (pp = page_free_list; pp; pp = pp->pp_link) {
        /* check that we didn't corrupt the free list itself */
        assert(pp >= pages);
f0100c92:	39 f3                	cmp    %esi,%ebx
f0100c94:	73 19                	jae    f0100caf <check_page_free_list+0x123>
f0100c96:	68 6a 26 10 f0       	push   $0xf010266a
f0100c9b:	68 76 26 10 f0       	push   $0xf0102676
f0100ca0:	68 65 01 00 00       	push   $0x165
f0100ca5:	68 3c 26 10 f0       	push   $0xf010263c
f0100caa:	e8 ca f3 ff ff       	call   f0100079 <_panic>
        assert(pp < pages + npages);
f0100caf:	3b 5d d4             	cmp    -0x2c(%ebp),%ebx
f0100cb2:	72 19                	jb     f0100ccd <check_page_free_list+0x141>
f0100cb4:	68 8b 26 10 f0       	push   $0xf010268b
f0100cb9:	68 76 26 10 f0       	push   $0xf0102676
f0100cbe:	68 66 01 00 00       	push   $0x166
f0100cc3:	68 3c 26 10 f0       	push   $0xf010263c
f0100cc8:	e8 ac f3 ff ff       	call   f0100079 <_panic>
        assert(((char *) pp - (char *) pages) % sizeof(*pp) == 0);
f0100ccd:	89 d8                	mov    %ebx,%eax
f0100ccf:	2b 45 d0             	sub    -0x30(%ebp),%eax
f0100cd2:	a8 07                	test   $0x7,%al
f0100cd4:	74 19                	je     f0100cef <check_page_free_list+0x163>
f0100cd6:	68 18 28 10 f0       	push   $0xf0102818
f0100cdb:	68 76 26 10 f0       	push   $0xf0102676
f0100ce0:	68 67 01 00 00       	push   $0x167
f0100ce5:	68 3c 26 10 f0       	push   $0xf010263c
f0100cea:	e8 8a f3 ff ff       	call   f0100079 <_panic>

        /* check a few pages that shouldn't be on the free list */
        assert(page2pa(pp) != 0);
f0100cef:	89 d8                	mov    %ebx,%eax
f0100cf1:	e8 c6 fc ff ff       	call   f01009bc <page2pa>
f0100cf6:	85 c0                	test   %eax,%eax
f0100cf8:	75 19                	jne    f0100d13 <check_page_free_list+0x187>
f0100cfa:	68 9f 26 10 f0       	push   $0xf010269f
f0100cff:	68 76 26 10 f0       	push   $0xf0102676
f0100d04:	68 6a 01 00 00       	push   $0x16a
f0100d09:	68 3c 26 10 f0       	push   $0xf010263c
f0100d0e:	e8 66 f3 ff ff       	call   f0100079 <_panic>
        assert(page2pa(pp) != IOPHYSMEM);
f0100d13:	3d 00 00 0a 00       	cmp    $0xa0000,%eax
f0100d18:	75 19                	jne    f0100d33 <check_page_free_list+0x1a7>
f0100d1a:	68 b0 26 10 f0       	push   $0xf01026b0
f0100d1f:	68 76 26 10 f0       	push   $0xf0102676
f0100d24:	68 6b 01 00 00       	push   $0x16b
f0100d29:	68 3c 26 10 f0       	push   $0xf010263c
f0100d2e:	e8 46 f3 ff ff       	call   f0100079 <_panic>
        assert(page2pa(pp) != EXTPHYSMEM - PGSIZE);
f0100d33:	3d 00 f0 0f 00       	cmp    $0xff000,%eax
f0100d38:	75 19                	jne    f0100d53 <check_page_free_list+0x1c7>
f0100d3a:	68 4c 28 10 f0       	push   $0xf010284c
f0100d3f:	68 76 26 10 f0       	push   $0xf0102676
f0100d44:	68 6c 01 00 00       	push   $0x16c
f0100d49:	68 3c 26 10 f0       	push   $0xf010263c
f0100d4e:	e8 26 f3 ff ff       	call   f0100079 <_panic>
        assert(page2pa(pp) != EXTPHYSMEM);
f0100d53:	3d 00 00 10 00       	cmp    $0x100000,%eax
f0100d58:	75 19                	jne    f0100d73 <check_page_free_list+0x1e7>
f0100d5a:	68 c9 26 10 f0       	push   $0xf01026c9
f0100d5f:	68 76 26 10 f0       	push   $0xf0102676
f0100d64:	68 6d 01 00 00       	push   $0x16d
f0100d69:	68 3c 26 10 f0       	push   $0xf010263c
f0100d6e:	e8 06 f3 ff ff       	call   f0100079 <_panic>
        assert(page2pa(pp) < EXTPHYSMEM || (char *) page2kva(pp) >= first_free_page);
f0100d73:	3d ff ff 0f 00       	cmp    $0xfffff,%eax
f0100d78:	76 25                	jbe    f0100d9f <check_page_free_list+0x213>
f0100d7a:	89 d8                	mov    %ebx,%eax
f0100d7c:	e8 37 fd ff ff       	call   f0100ab8 <page2kva>
f0100d81:	39 45 c8             	cmp    %eax,-0x38(%ebp)
f0100d84:	76 1f                	jbe    f0100da5 <check_page_free_list+0x219>
f0100d86:	68 70 28 10 f0       	push   $0xf0102870
f0100d8b:	68 76 26 10 f0       	push   $0xf0102676
f0100d90:	68 6e 01 00 00       	push   $0x16e
f0100d95:	68 3c 26 10 f0       	push   $0xf010263c
f0100d9a:	e8 da f2 ff ff       	call   f0100079 <_panic>

        if (page2pa(pp) < EXTPHYSMEM)
            ++nfree_basemem;
f0100d9f:	83 45 cc 01          	addl   $0x1,-0x34(%ebp)
f0100da3:	eb 03                	jmp    f0100da8 <check_page_free_list+0x21c>
        else
            ++nfree_extmem;
f0100da5:	83 c7 01             	add    $0x1,%edi
    for (pp = page_free_list; pp; pp = pp->pp_link)
        if (PDX(page2pa(pp)) < pdx_limit)
            memset(page2kva(pp), 0x97, 128);

    first_free_page = (char *) boot_alloc(0);
    for (pp = page_free_list; pp; pp = pp->pp_link) {
f0100da8:	8b 1b                	mov    (%ebx),%ebx
f0100daa:	85 db                	test   %ebx,%ebx
f0100dac:	0f 85 e0 fe ff ff    	jne    f0100c92 <check_page_free_list+0x106>
            ++nfree_basemem;
        else
            ++nfree_extmem;
    }

    assert(nfree_basemem > 0);
f0100db2:	83 7d cc 00          	cmpl   $0x0,-0x34(%ebp)
f0100db6:	7f 19                	jg     f0100dd1 <check_page_free_list+0x245>
f0100db8:	68 e3 26 10 f0       	push   $0xf01026e3
f0100dbd:	68 76 26 10 f0       	push   $0xf0102676
f0100dc2:	68 76 01 00 00       	push   $0x176
f0100dc7:	68 3c 26 10 f0       	push   $0xf010263c
f0100dcc:	e8 a8 f2 ff ff       	call   f0100079 <_panic>
    assert(nfree_extmem > 0);
f0100dd1:	85 ff                	test   %edi,%edi
f0100dd3:	7f 2c                	jg     f0100e01 <check_page_free_list+0x275>
f0100dd5:	68 f5 26 10 f0       	push   $0xf01026f5
f0100dda:	68 76 26 10 f0       	push   $0xf0102676
f0100ddf:	68 77 01 00 00       	push   $0x177
f0100de4:	68 3c 26 10 f0       	push   $0xf010263c
f0100de9:	e8 8b f2 ff ff       	call   f0100079 <_panic>
    struct page_info *pp;
    unsigned pdx_limit = only_low_memory ? 1 : NPDENTRIES;
    int nfree_basemem = 0, nfree_extmem = 0;
    char *first_free_page;

    if (!page_free_list)
f0100dee:	8b 1d 3c 45 11 f0    	mov    0xf011453c,%ebx
f0100df4:	85 db                	test   %ebx,%ebx
f0100df6:	0f 85 c7 fd ff ff    	jne    f0100bc3 <check_page_free_list+0x37>
f0100dfc:	e9 ab fd ff ff       	jmp    f0100bac <check_page_free_list+0x20>
            ++nfree_extmem;
    }

    assert(nfree_basemem > 0);
    assert(nfree_extmem > 0);
}
f0100e01:	8d 65 f4             	lea    -0xc(%ebp),%esp
f0100e04:	5b                   	pop    %ebx
f0100e05:	5e                   	pop    %esi
f0100e06:	5f                   	pop    %edi
f0100e07:	5d                   	pop    %ebp
f0100e08:	c3                   	ret    

f0100e09 <page_init>:
     *
     * Change the code to reflect this.
     * NB: DO NOT actually touch the physical memory corresponding to free
     *     pages! */
    size_t i;
    for (i = 0; i < npages; i++) {
f0100e09:	83 3d 64 49 11 f0 00 	cmpl   $0x0,0xf0114964
f0100e10:	74 41                	je     f0100e53 <page_init+0x4a>
 * After this is done, NEVER use boot_alloc again.  ONLY use the page
 * allocator functions below to allocate and deallocate physical
 * memory via the page_free_list.
 */
void page_init(void)
{
f0100e12:	55                   	push   %ebp
f0100e13:	89 e5                	mov    %esp,%ebp
f0100e15:	53                   	push   %ebx
f0100e16:	8b 1d 3c 45 11 f0    	mov    0xf011453c,%ebx
     *
     * Change the code to reflect this.
     * NB: DO NOT actually touch the physical memory corresponding to free
     *     pages! */
    size_t i;
    for (i = 0; i < npages; i++) {
f0100e1c:	b8 00 00 00 00       	mov    $0x0,%eax
f0100e21:	8d 14 c5 00 00 00 00 	lea    0x0(,%eax,8),%edx
        pages[i].pp_ref = 0;
f0100e28:	89 d1                	mov    %edx,%ecx
f0100e2a:	03 0d 68 49 11 f0    	add    0xf0114968,%ecx
f0100e30:	66 c7 41 04 00 00    	movw   $0x0,0x4(%ecx)
        pages[i].pp_link = page_free_list;
f0100e36:	89 19                	mov    %ebx,(%ecx)
        page_free_list = &pages[i];
f0100e38:	89 d3                	mov    %edx,%ebx
f0100e3a:	03 1d 68 49 11 f0    	add    0xf0114968,%ebx
     *
     * Change the code to reflect this.
     * NB: DO NOT actually touch the physical memory corresponding to free
     *     pages! */
    size_t i;
    for (i = 0; i < npages; i++) {
f0100e40:	83 c0 01             	add    $0x1,%eax
f0100e43:	39 05 64 49 11 f0    	cmp    %eax,0xf0114964
f0100e49:	77 d6                	ja     f0100e21 <page_init+0x18>
f0100e4b:	89 1d 3c 45 11 f0    	mov    %ebx,0xf011453c
        pages[i].pp_ref = 0;
        pages[i].pp_link = page_free_list;
        page_free_list = &pages[i];
    }
}
f0100e51:	5b                   	pop    %ebx
f0100e52:	5d                   	pop    %ebp
f0100e53:	f3 c3                	repz ret 

f0100e55 <page_alloc>:
 * 4MB huge pages:
 * Come back later to extend this function to support 4MB huge page allocation.
 * If (alloc_flags & ALLOC_HUGE), returns a huge physical page of 4MB size.
 */
struct page_info *page_alloc(int alloc_flags)
{
f0100e55:	55                   	push   %ebp
f0100e56:	89 e5                	mov    %esp,%ebp
    /* Fill this function in */
    return 0;
}
f0100e58:	b8 00 00 00 00       	mov    $0x0,%eax
f0100e5d:	5d                   	pop    %ebp
f0100e5e:	c3                   	ret    

f0100e5f <check_page_alloc>:
/*
 * Check the physical page allocator (page_alloc(), page_free(),
 * and page_init()).
 */
static void check_page_alloc(void)
{
f0100e5f:	55                   	push   %ebp
f0100e60:	89 e5                	mov    %esp,%ebp
f0100e62:	83 ec 08             	sub    $0x8,%esp
    int nfree, total_free;
    struct page_info *fl;
    char *c;
    int i;

    if (!pages)
f0100e65:	83 3d 68 49 11 f0 00 	cmpl   $0x0,0xf0114968
f0100e6c:	75 17                	jne    f0100e85 <check_page_alloc+0x26>
        panic("'pages' is a null pointer!");
f0100e6e:	83 ec 04             	sub    $0x4,%esp
f0100e71:	68 06 27 10 f0       	push   $0xf0102706
f0100e76:	68 88 01 00 00       	push   $0x188
f0100e7b:	68 3c 26 10 f0       	push   $0xf010263c
f0100e80:	e8 f4 f1 ff ff       	call   f0100079 <_panic>

    /* check number of free pages */
    for (pp = page_free_list, nfree = 0; pp; pp = pp->pp_link)
f0100e85:	a1 3c 45 11 f0       	mov    0xf011453c,%eax
f0100e8a:	85 c0                	test   %eax,%eax
f0100e8c:	74 49                	je     f0100ed7 <check_page_alloc+0x78>
f0100e8e:	8b 00                	mov    (%eax),%eax
f0100e90:	85 c0                	test   %eax,%eax
f0100e92:	75 fa                	jne    f0100e8e <check_page_alloc+0x2f>
        ++nfree;
    total_free = nfree;

    /* should be able to allocate three pages */
    pp0 = pp1 = pp2 = 0;
    assert((pp0 = page_alloc(0)));
f0100e94:	83 ec 0c             	sub    $0xc,%esp
f0100e97:	6a 00                	push   $0x0
f0100e99:	e8 b7 ff ff ff       	call   f0100e55 <page_alloc>
f0100e9e:	83 c4 10             	add    $0x10,%esp
f0100ea1:	85 c0                	test   %eax,%eax
f0100ea3:	75 19                	jne    f0100ebe <check_page_alloc+0x5f>
f0100ea5:	68 21 27 10 f0       	push   $0xf0102721
f0100eaa:	68 76 26 10 f0       	push   $0xf0102676
f0100eaf:	68 91 01 00 00       	push   $0x191
f0100eb4:	68 3c 26 10 f0       	push   $0xf010263c
f0100eb9:	e8 bb f1 ff ff       	call   f0100079 <_panic>
    assert((pp1 = page_alloc(0)));
    assert((pp2 = page_alloc(0)));

    assert(pp0);
    assert(pp1 && pp1 != pp0);
f0100ebe:	68 37 27 10 f0       	push   $0xf0102737
f0100ec3:	68 76 26 10 f0       	push   $0xf0102676
f0100ec8:	68 96 01 00 00       	push   $0x196
f0100ecd:	68 3c 26 10 f0       	push   $0xf010263c
f0100ed2:	e8 a2 f1 ff ff       	call   f0100079 <_panic>
        ++nfree;
    total_free = nfree;

    /* should be able to allocate three pages */
    pp0 = pp1 = pp2 = 0;
    assert((pp0 = page_alloc(0)));
f0100ed7:	83 ec 0c             	sub    $0xc,%esp
f0100eda:	6a 00                	push   $0x0
f0100edc:	e8 74 ff ff ff       	call   f0100e55 <page_alloc>
f0100ee1:	83 c4 10             	add    $0x10,%esp
f0100ee4:	85 c0                	test   %eax,%eax
f0100ee6:	75 d6                	jne    f0100ebe <check_page_alloc+0x5f>
f0100ee8:	eb bb                	jmp    f0100ea5 <check_page_alloc+0x46>

f0100eea <mem_init>:
 *
 * From UTOP to ULIM, the user is allowed to read but not write.
 * Above ULIM the user cannot read or write.
 */
void mem_init(void)
{
f0100eea:	55                   	push   %ebp
f0100eeb:	89 e5                	mov    %esp,%ebp
f0100eed:	56                   	push   %esi
f0100eee:	53                   	push   %ebx
    uint32_t cr0;
    size_t n;

    /* Find out how much memory the machine has (npages & npages_basemem). */
    i386_detect_memory();
f0100eef:	e8 0b fc ff ff       	call   f0100aff <i386_detect_memory>

    cprintf("detected %u\n", npages);
f0100ef4:	83 ec 08             	sub    $0x8,%esp
f0100ef7:	ff 35 64 49 11 f0    	pushl  0xf0114964
f0100efd:	68 49 27 10 f0       	push   $0xf0102749
f0100f02:	e8 3b 01 00 00       	call   f0101042 <cprintf>
    void *pages_ba, *pages_lim;
    //temporary variable to create the pages list
    struct page_info *pg0, *pg1;

    // Allocate enough memory to contain the pages list
    pages_ba = boot_alloc(npages*sizeof(struct page_info));
f0100f07:	a1 64 49 11 f0       	mov    0xf0114964,%eax
f0100f0c:	c1 e0 03             	shl    $0x3,%eax
f0100f0f:	e8 b9 fa ff ff       	call   f01009cd <boot_alloc>
f0100f14:	89 c3                	mov    %eax,%ebx
    // Define the pages memory limit
    pages_lim = pages_ba + (npages*sizeof(struct page_info));
f0100f16:	a1 64 49 11 f0       	mov    0xf0114964,%eax
f0100f1b:	8d 34 c3             	lea    (%ebx,%eax,8),%esi
    //initialise the first page pointer with the first available allocated byte

    pg0 = (struct page_info *) pages_ba;
    pages = (struct page_info *) pages_ba;
f0100f1e:	89 1d 68 49 11 f0    	mov    %ebx,0xf0114968

    cprintf("pre loop!\n");
f0100f24:	c7 04 24 56 27 10 f0 	movl   $0xf0102756,(%esp)
f0100f2b:	e8 12 01 00 00       	call   f0101042 <cprintf>

    //initialize the pages list
    for(int i=0; i< npages; i++){
f0100f30:	a1 64 49 11 f0       	mov    0xf0114964,%eax
f0100f35:	83 c4 10             	add    $0x10,%esp
f0100f38:	85 c0                	test   %eax,%eax
f0100f3a:	74 79                	je     f0100fb5 <mem_init+0xcb>

        assert(pg0 != pages_lim);
f0100f3c:	39 f3                	cmp    %esi,%ebx
f0100f3e:	74 0b                	je     f0100f4b <mem_init+0x61>
f0100f40:	ba 00 00 00 00       	mov    $0x0,%edx
f0100f45:	eb 1d                	jmp    f0100f64 <mem_init+0x7a>
f0100f47:	39 f3                	cmp    %esi,%ebx
f0100f49:	75 19                	jne    f0100f64 <mem_init+0x7a>
f0100f4b:	68 61 27 10 f0       	push   $0xf0102761
f0100f50:	68 76 26 10 f0       	push   $0xf0102676
f0100f55:	68 bc 00 00 00       	push   $0xbc
f0100f5a:	68 3c 26 10 f0       	push   $0xf010263c
f0100f5f:	e8 15 f1 ff ff       	call   f0100079 <_panic>
        // works here...

        pg0->pp_ref = 0;
f0100f64:	66 c7 43 04 00 00    	movw   $0x0,0x4(%ebx)

        pg1 = pg0 + sizeof(struct page_info);
        
        // cprintf("after assert!\n");

        if(i != npages - 1){
f0100f6a:	83 e8 01             	sub    $0x1,%eax
f0100f6d:	39 d0                	cmp    %edx,%eax
f0100f6f:	74 07                	je     f0100f78 <mem_init+0x8e>

        pg0->pp_ref = 0;
        // cprintf("after assert!\n");


        pg1 = pg0 + sizeof(struct page_info);
f0100f71:	8d 43 40             	lea    0x40(%ebx),%eax
        
        // cprintf("after assert!\n");

        if(i != npages - 1){
            pg0->pp_link = pg1;
f0100f74:	89 03                	mov    %eax,(%ebx)
            pg0 = pg1;
f0100f76:	89 c3                	mov    %eax,%ebx
    pages = (struct page_info *) pages_ba;

    cprintf("pre loop!\n");

    //initialize the pages list
    for(int i=0; i< npages; i++){
f0100f78:	83 c2 01             	add    $0x1,%edx
f0100f7b:	a1 64 49 11 f0       	mov    0xf0114964,%eax
f0100f80:	39 c2                	cmp    %eax,%edx
f0100f82:	72 c3                	jb     f0100f47 <mem_init+0x5d>
        }

    }

    /* DEBUG */
    pg0 = pages;
f0100f84:	8b 1d 68 49 11 f0    	mov    0xf0114968,%ebx
    for(int i=0; i<npages; i++){   
f0100f8a:	85 c0                	test   %eax,%eax
f0100f8c:	74 27                	je     f0100fb5 <mem_init+0xcb>
f0100f8e:	be 00 00 00 00       	mov    $0x0,%esi
        cprintf("pp: %x pp_link: %x pp_ref: %d \n",pg0, pg0->pp_link, pg0->pp_ref );
f0100f93:	0f b7 43 04          	movzwl 0x4(%ebx),%eax
f0100f97:	50                   	push   %eax
f0100f98:	ff 33                	pushl  (%ebx)
f0100f9a:	53                   	push   %ebx
f0100f9b:	68 b8 28 10 f0       	push   $0xf01028b8
f0100fa0:	e8 9d 00 00 00       	call   f0101042 <cprintf>
        pg0 = pg0->pp_link;
f0100fa5:	8b 1b                	mov    (%ebx),%ebx

    }

    /* DEBUG */
    pg0 = pages;
    for(int i=0; i<npages; i++){   
f0100fa7:	83 c6 01             	add    $0x1,%esi
f0100faa:	83 c4 10             	add    $0x10,%esp
f0100fad:	3b 35 64 49 11 f0    	cmp    0xf0114964,%esi
f0100fb3:	72 de                	jb     f0100f93 <mem_init+0xa9>
     * Now that we've allocated the initial kernel data structures, we set
     * up the list of free physical pages. Once we've done so, all further
     * memory management will go through the page_* functions. In particular, we
     * can now map memory using boot_map_region or page_insert.
     */
    page_init();
f0100fb5:	e8 4f fe ff ff       	call   f0100e09 <page_init>

    check_page_free_list(1);
f0100fba:	b8 01 00 00 00       	mov    $0x1,%eax
f0100fbf:	e8 c8 fb ff ff       	call   f0100b8c <check_page_free_list>
    check_page_alloc();
f0100fc4:	e8 96 fe ff ff       	call   f0100e5f <check_page_alloc>

f0100fc9 <page_free>:
/*
 * Return a page to the free list.
 * (This function should only be called when pp->pp_ref reaches 0.)
 */
void page_free(struct page_info *pp)
{
f0100fc9:	55                   	push   %ebp
f0100fca:	89 e5                	mov    %esp,%ebp
    /* Fill this function in
     * Hint: You may want to panic if pp->pp_ref is nonzero or
     * pp->pp_link is not NULL. */
}
f0100fcc:	5d                   	pop    %ebp
f0100fcd:	c3                   	ret    

f0100fce <page_decref>:
/*
 * Decrement the reference count on a page,
 * freeing it if there are no more refs.
 */
void page_decref(struct page_info* pp)
{
f0100fce:	55                   	push   %ebp
f0100fcf:	89 e5                	mov    %esp,%ebp
f0100fd1:	8b 45 08             	mov    0x8(%ebp),%eax
    if (--pp->pp_ref == 0)
f0100fd4:	66 83 68 04 01       	subw   $0x1,0x4(%eax)
        page_free(pp);
}
f0100fd9:	5d                   	pop    %ebp
f0100fda:	c3                   	ret    

f0100fdb <mc146818_read>:

#include <kern/kclock.h>


unsigned mc146818_read(unsigned reg)
{
f0100fdb:	55                   	push   %ebp
f0100fdc:	89 e5                	mov    %esp,%ebp
             "memory", "cc");
}

static __inline void outb(int port, uint8_t data)
{
    __asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0100fde:	ba 70 00 00 00       	mov    $0x70,%edx
f0100fe3:	8b 45 08             	mov    0x8(%ebp),%eax
f0100fe6:	ee                   	out    %al,(%dx)
}

static __inline uint8_t inb(int port)
{
    uint8_t data;
    __asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f0100fe7:	ba 71 00 00 00       	mov    $0x71,%edx
f0100fec:	ec                   	in     (%dx),%al
    outb(IO_RTC, reg);
    return inb(IO_RTC+1);
f0100fed:	0f b6 c0             	movzbl %al,%eax
}
f0100ff0:	5d                   	pop    %ebp
f0100ff1:	c3                   	ret    

f0100ff2 <mc146818_write>:

void mc146818_write(unsigned reg, unsigned datum)
{
f0100ff2:	55                   	push   %ebp
f0100ff3:	89 e5                	mov    %esp,%ebp
             "memory", "cc");
}

static __inline void outb(int port, uint8_t data)
{
    __asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0100ff5:	ba 70 00 00 00       	mov    $0x70,%edx
f0100ffa:	8b 45 08             	mov    0x8(%ebp),%eax
f0100ffd:	ee                   	out    %al,(%dx)
f0100ffe:	ba 71 00 00 00       	mov    $0x71,%edx
f0101003:	8b 45 0c             	mov    0xc(%ebp),%eax
f0101006:	ee                   	out    %al,(%dx)
    outb(IO_RTC, reg);
    outb(IO_RTC+1, datum);
}
f0101007:	5d                   	pop    %ebp
f0101008:	c3                   	ret    

f0101009 <putch>:
#include <inc/stdio.h>
#include <inc/stdarg.h>


static void putch(int ch, int *cnt)
{
f0101009:	55                   	push   %ebp
f010100a:	89 e5                	mov    %esp,%ebp
f010100c:	83 ec 14             	sub    $0x14,%esp
    cputchar(ch);
f010100f:	ff 75 08             	pushl  0x8(%ebp)
f0101012:	e8 1c f6 ff ff       	call   f0100633 <cputchar>
    *cnt++;
}
f0101017:	83 c4 10             	add    $0x10,%esp
f010101a:	c9                   	leave  
f010101b:	c3                   	ret    

f010101c <vcprintf>:

int vcprintf(const char *fmt, va_list ap)
{
f010101c:	55                   	push   %ebp
f010101d:	89 e5                	mov    %esp,%ebp
f010101f:	83 ec 18             	sub    $0x18,%esp
    int cnt = 0;
f0101022:	c7 45 f4 00 00 00 00 	movl   $0x0,-0xc(%ebp)

    vprintfmt((void*)putch, &cnt, fmt, ap);
f0101029:	ff 75 0c             	pushl  0xc(%ebp)
f010102c:	ff 75 08             	pushl  0x8(%ebp)
f010102f:	8d 45 f4             	lea    -0xc(%ebp),%eax
f0101032:	50                   	push   %eax
f0101033:	68 09 10 10 f0       	push   $0xf0101009
f0101038:	e8 fc 04 00 00       	call   f0101539 <vprintfmt>
    return cnt;
}
f010103d:	8b 45 f4             	mov    -0xc(%ebp),%eax
f0101040:	c9                   	leave  
f0101041:	c3                   	ret    

f0101042 <cprintf>:

int cprintf(const char *fmt, ...)
{
f0101042:	55                   	push   %ebp
f0101043:	89 e5                	mov    %esp,%ebp
f0101045:	83 ec 10             	sub    $0x10,%esp
    va_list ap;
    int cnt;

    va_start(ap, fmt);
f0101048:	8d 45 0c             	lea    0xc(%ebp),%eax
    cnt = vcprintf(fmt, ap);
f010104b:	50                   	push   %eax
f010104c:	ff 75 08             	pushl  0x8(%ebp)
f010104f:	e8 c8 ff ff ff       	call   f010101c <vcprintf>
    va_end(ap);

    return cnt;
}
f0101054:	c9                   	leave  
f0101055:	c3                   	ret    

f0101056 <stab_binsearch>:
 *      stab_binsearch(stabs, &left, &right, N_SO, 0xf0100184);
 *  will exit setting left = 118, right = 554.
 */
static void stab_binsearch(const struct stab *stabs, int *region_left,
        int *region_right, int type, uintptr_t addr)
{
f0101056:	55                   	push   %ebp
f0101057:	89 e5                	mov    %esp,%ebp
f0101059:	57                   	push   %edi
f010105a:	56                   	push   %esi
f010105b:	53                   	push   %ebx
f010105c:	83 ec 14             	sub    $0x14,%esp
f010105f:	89 45 ec             	mov    %eax,-0x14(%ebp)
f0101062:	89 55 e4             	mov    %edx,-0x1c(%ebp)
f0101065:	89 4d e0             	mov    %ecx,-0x20(%ebp)
f0101068:	8b 7d 08             	mov    0x8(%ebp),%edi
    int l = *region_left, r = *region_right, any_matches = 0;
f010106b:	8b 1a                	mov    (%edx),%ebx
f010106d:	8b 01                	mov    (%ecx),%eax
f010106f:	89 45 f0             	mov    %eax,-0x10(%ebp)

    while (l <= r) {
f0101072:	39 c3                	cmp    %eax,%ebx
f0101074:	0f 8f 9a 00 00 00    	jg     f0101114 <stab_binsearch+0xbe>
f010107a:	c7 45 e8 00 00 00 00 	movl   $0x0,-0x18(%ebp)
        int true_m = (l + r) / 2, m = true_m;
f0101081:	8b 45 f0             	mov    -0x10(%ebp),%eax
f0101084:	01 d8                	add    %ebx,%eax
f0101086:	89 c6                	mov    %eax,%esi
f0101088:	c1 ee 1f             	shr    $0x1f,%esi
f010108b:	01 c6                	add    %eax,%esi
f010108d:	d1 fe                	sar    %esi

        /* search for earliest stab with right type */
        while (m >= l && stabs[m].n_type != type)
f010108f:	39 de                	cmp    %ebx,%esi
f0101091:	0f 8c c4 00 00 00    	jl     f010115b <stab_binsearch+0x105>
f0101097:	8d 04 76             	lea    (%esi,%esi,2),%eax
f010109a:	8b 4d ec             	mov    -0x14(%ebp),%ecx
f010109d:	8d 14 81             	lea    (%ecx,%eax,4),%edx
f01010a0:	0f b6 42 04          	movzbl 0x4(%edx),%eax
f01010a4:	39 c7                	cmp    %eax,%edi
f01010a6:	0f 84 b4 00 00 00    	je     f0101160 <stab_binsearch+0x10a>
f01010ac:	89 f0                	mov    %esi,%eax
            m--;
f01010ae:	83 e8 01             	sub    $0x1,%eax

    while (l <= r) {
        int true_m = (l + r) / 2, m = true_m;

        /* search for earliest stab with right type */
        while (m >= l && stabs[m].n_type != type)
f01010b1:	39 d8                	cmp    %ebx,%eax
f01010b3:	0f 8c a2 00 00 00    	jl     f010115b <stab_binsearch+0x105>
f01010b9:	0f b6 4a f8          	movzbl -0x8(%edx),%ecx
f01010bd:	83 ea 0c             	sub    $0xc,%edx
f01010c0:	39 f9                	cmp    %edi,%ecx
f01010c2:	75 ea                	jne    f01010ae <stab_binsearch+0x58>
f01010c4:	e9 99 00 00 00       	jmp    f0101162 <stab_binsearch+0x10c>
        }

        /* actual binary search */
        any_matches = 1;
        if (stabs[m].n_value < addr) {
            *region_left = m;
f01010c9:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
f01010cc:	89 03                	mov    %eax,(%ebx)
            l = true_m + 1;
f01010ce:	8d 5e 01             	lea    0x1(%esi),%ebx
            l = true_m + 1;
            continue;
        }

        /* actual binary search */
        any_matches = 1;
f01010d1:	c7 45 e8 01 00 00 00 	movl   $0x1,-0x18(%ebp)
f01010d8:	eb 2b                	jmp    f0101105 <stab_binsearch+0xaf>
        if (stabs[m].n_value < addr) {
            *region_left = m;
            l = true_m + 1;
        } else if (stabs[m].n_value > addr) {
f01010da:	3b 55 0c             	cmp    0xc(%ebp),%edx
f01010dd:	76 14                	jbe    f01010f3 <stab_binsearch+0x9d>
            *region_right = m - 1;
f01010df:	83 e8 01             	sub    $0x1,%eax
f01010e2:	89 45 f0             	mov    %eax,-0x10(%ebp)
f01010e5:	8b 75 e0             	mov    -0x20(%ebp),%esi
f01010e8:	89 06                	mov    %eax,(%esi)
            l = true_m + 1;
            continue;
        }

        /* actual binary search */
        any_matches = 1;
f01010ea:	c7 45 e8 01 00 00 00 	movl   $0x1,-0x18(%ebp)
f01010f1:	eb 12                	jmp    f0101105 <stab_binsearch+0xaf>
            *region_right = m - 1;
            r = m - 1;
        } else {
            /* exact match for 'addr', but continue loop to find
             * *region_right */
            *region_left = m;
f01010f3:	8b 75 e4             	mov    -0x1c(%ebp),%esi
f01010f6:	89 06                	mov    %eax,(%esi)
            l = m;
            addr++;
f01010f8:	83 45 0c 01          	addl   $0x1,0xc(%ebp)
f01010fc:	89 c3                	mov    %eax,%ebx
            l = true_m + 1;
            continue;
        }

        /* actual binary search */
        any_matches = 1;
f01010fe:	c7 45 e8 01 00 00 00 	movl   $0x1,-0x18(%ebp)
static void stab_binsearch(const struct stab *stabs, int *region_left,
        int *region_right, int type, uintptr_t addr)
{
    int l = *region_left, r = *region_right, any_matches = 0;

    while (l <= r) {
f0101105:	39 5d f0             	cmp    %ebx,-0x10(%ebp)
f0101108:	0f 8d 73 ff ff ff    	jge    f0101081 <stab_binsearch+0x2b>
            l = m;
            addr++;
        }
    }

    if (!any_matches)
f010110e:	83 7d e8 00          	cmpl   $0x0,-0x18(%ebp)
f0101112:	75 0f                	jne    f0101123 <stab_binsearch+0xcd>
        *region_right = *region_left - 1;
f0101114:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0101117:	8b 00                	mov    (%eax),%eax
f0101119:	83 e8 01             	sub    $0x1,%eax
f010111c:	8b 7d e0             	mov    -0x20(%ebp),%edi
f010111f:	89 07                	mov    %eax,(%edi)
f0101121:	eb 57                	jmp    f010117a <stab_binsearch+0x124>
    else {
        /* find rightmost region containing 'addr' */
        for (l = *region_right;
f0101123:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0101126:	8b 00                	mov    (%eax),%eax
             l > *region_left && stabs[l].n_type != type;
f0101128:	8b 75 e4             	mov    -0x1c(%ebp),%esi
f010112b:	8b 0e                	mov    (%esi),%ecx

    if (!any_matches)
        *region_right = *region_left - 1;
    else {
        /* find rightmost region containing 'addr' */
        for (l = *region_right;
f010112d:	39 c8                	cmp    %ecx,%eax
f010112f:	7e 23                	jle    f0101154 <stab_binsearch+0xfe>
             l > *region_left && stabs[l].n_type != type;
f0101131:	8d 14 40             	lea    (%eax,%eax,2),%edx
f0101134:	8b 75 ec             	mov    -0x14(%ebp),%esi
f0101137:	8d 14 96             	lea    (%esi,%edx,4),%edx
f010113a:	0f b6 5a 04          	movzbl 0x4(%edx),%ebx
f010113e:	39 df                	cmp    %ebx,%edi
f0101140:	74 12                	je     f0101154 <stab_binsearch+0xfe>
             l--)
f0101142:	83 e8 01             	sub    $0x1,%eax

    if (!any_matches)
        *region_right = *region_left - 1;
    else {
        /* find rightmost region containing 'addr' */
        for (l = *region_right;
f0101145:	39 c8                	cmp    %ecx,%eax
f0101147:	7e 0b                	jle    f0101154 <stab_binsearch+0xfe>
             l > *region_left && stabs[l].n_type != type;
f0101149:	0f b6 5a f8          	movzbl -0x8(%edx),%ebx
f010114d:	83 ea 0c             	sub    $0xc,%edx
f0101150:	39 df                	cmp    %ebx,%edi
f0101152:	75 ee                	jne    f0101142 <stab_binsearch+0xec>
             l--)
            /* do nothing */;
        *region_left = l;
f0101154:	8b 7d e4             	mov    -0x1c(%ebp),%edi
f0101157:	89 07                	mov    %eax,(%edi)
    }
}
f0101159:	eb 1f                	jmp    f010117a <stab_binsearch+0x124>

        /* search for earliest stab with right type */
        while (m >= l && stabs[m].n_type != type)
            m--;
        if (m < l) {    /* no match in [l, m] */
            l = true_m + 1;
f010115b:	8d 5e 01             	lea    0x1(%esi),%ebx
            continue;
f010115e:	eb a5                	jmp    f0101105 <stab_binsearch+0xaf>
        int *region_right, int type, uintptr_t addr)
{
    int l = *region_left, r = *region_right, any_matches = 0;

    while (l <= r) {
        int true_m = (l + r) / 2, m = true_m;
f0101160:	89 f0                	mov    %esi,%eax
            continue;
        }

        /* actual binary search */
        any_matches = 1;
        if (stabs[m].n_value < addr) {
f0101162:	8d 14 40             	lea    (%eax,%eax,2),%edx
f0101165:	8b 4d ec             	mov    -0x14(%ebp),%ecx
f0101168:	8b 54 91 08          	mov    0x8(%ecx,%edx,4),%edx
f010116c:	3b 55 0c             	cmp    0xc(%ebp),%edx
f010116f:	0f 82 54 ff ff ff    	jb     f01010c9 <stab_binsearch+0x73>
f0101175:	e9 60 ff ff ff       	jmp    f01010da <stab_binsearch+0x84>
             l > *region_left && stabs[l].n_type != type;
             l--)
            /* do nothing */;
        *region_left = l;
    }
}
f010117a:	83 c4 14             	add    $0x14,%esp
f010117d:	5b                   	pop    %ebx
f010117e:	5e                   	pop    %esi
f010117f:	5f                   	pop    %edi
f0101180:	5d                   	pop    %ebp
f0101181:	c3                   	ret    

f0101182 <debuginfo_eip>:
 *  instruction address, 'addr'.  Returns 0 if information was found, and
 *  negative if not.  But even if it returns negative it has stored some
 *  information into '*info'.
 */
int debuginfo_eip(uintptr_t addr, struct eip_debuginfo *info)
{
f0101182:	55                   	push   %ebp
f0101183:	89 e5                	mov    %esp,%ebp
f0101185:	57                   	push   %edi
f0101186:	56                   	push   %esi
f0101187:	53                   	push   %ebx
f0101188:	83 ec 3c             	sub    $0x3c,%esp
f010118b:	8b 75 08             	mov    0x8(%ebp),%esi
f010118e:	8b 5d 0c             	mov    0xc(%ebp),%ebx
    const struct stab *stabs, *stab_end;
    const char *stabstr, *stabstr_end;
    int lfile, rfile, lfun, rfun, lline, rline;

    /* Initialize *info */
    info->eip_file = "<unknown>";
f0101191:	c7 03 d8 28 10 f0    	movl   $0xf01028d8,(%ebx)
    info->eip_line = 0;
f0101197:	c7 43 04 00 00 00 00 	movl   $0x0,0x4(%ebx)
    info->eip_fn_name = "<unknown>";
f010119e:	c7 43 08 d8 28 10 f0 	movl   $0xf01028d8,0x8(%ebx)
    info->eip_fn_namelen = 9;
f01011a5:	c7 43 0c 09 00 00 00 	movl   $0x9,0xc(%ebx)
    info->eip_fn_addr = addr;
f01011ac:	89 73 10             	mov    %esi,0x10(%ebx)
    info->eip_fn_narg = 0;
f01011af:	c7 43 14 00 00 00 00 	movl   $0x0,0x14(%ebx)

    /* Find the relevant set of stabs */
    if (addr >= ULIM) {
f01011b6:	81 fe ff ff 7f ef    	cmp    $0xef7fffff,%esi
f01011bc:	76 11                	jbe    f01011cf <debuginfo_eip+0x4d>
        /* Can't search for user-level addresses yet! */
        panic("User address");
    }

    /* String table validity checks */
    if (stabstr_end <= stabstr || stabstr_end[-1] != 0)
f01011be:	b8 5c 92 10 f0       	mov    $0xf010925c,%eax
f01011c3:	3d 1d 75 10 f0       	cmp    $0xf010751d,%eax
f01011c8:	77 19                	ja     f01011e3 <debuginfo_eip+0x61>
f01011ca:	e9 d9 01 00 00       	jmp    f01013a8 <debuginfo_eip+0x226>
        stab_end = __STAB_END__;
        stabstr = __STABSTR_BEGIN__;
        stabstr_end = __STABSTR_END__;
    } else {
        /* Can't search for user-level addresses yet! */
        panic("User address");
f01011cf:	83 ec 04             	sub    $0x4,%esp
f01011d2:	68 e2 28 10 f0       	push   $0xf01028e2
f01011d7:	6a 7e                	push   $0x7e
f01011d9:	68 ef 28 10 f0       	push   $0xf01028ef
f01011de:	e8 96 ee ff ff       	call   f0100079 <_panic>
    }

    /* String table validity checks */
    if (stabstr_end <= stabstr || stabstr_end[-1] != 0)
f01011e3:	80 3d 5b 92 10 f0 00 	cmpb   $0x0,0xf010925b
f01011ea:	0f 85 bf 01 00 00    	jne    f01013af <debuginfo_eip+0x22d>
     * 'eip'.  First, we find the basic source file containing 'eip'.
     * Then, we look in that source file for the function.  Then we look
     * for the line number. */

    /* Search the entire set of stabs for the source file (type N_SO). */
    lfile = 0;
f01011f0:	c7 45 e4 00 00 00 00 	movl   $0x0,-0x1c(%ebp)
    rfile = (stab_end - stabs) - 1;
f01011f7:	b8 1c 75 10 f0       	mov    $0xf010751c,%eax
f01011fc:	2d 30 2b 10 f0       	sub    $0xf0102b30,%eax
f0101201:	c1 f8 02             	sar    $0x2,%eax
f0101204:	69 c0 ab aa aa aa    	imul   $0xaaaaaaab,%eax,%eax
f010120a:	83 e8 01             	sub    $0x1,%eax
f010120d:	89 45 e0             	mov    %eax,-0x20(%ebp)
    stab_binsearch(stabs, &lfile, &rfile, N_SO, addr);
f0101210:	83 ec 08             	sub    $0x8,%esp
f0101213:	56                   	push   %esi
f0101214:	6a 64                	push   $0x64
f0101216:	8d 4d e0             	lea    -0x20(%ebp),%ecx
f0101219:	8d 55 e4             	lea    -0x1c(%ebp),%edx
f010121c:	b8 30 2b 10 f0       	mov    $0xf0102b30,%eax
f0101221:	e8 30 fe ff ff       	call   f0101056 <stab_binsearch>
    if (lfile == 0)
f0101226:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0101229:	83 c4 10             	add    $0x10,%esp
f010122c:	85 c0                	test   %eax,%eax
f010122e:	0f 84 82 01 00 00    	je     f01013b6 <debuginfo_eip+0x234>
        return -1;

    /* Search within that file's stabs for the function definition (N_FUN). */
    lfun = lfile;
f0101234:	89 45 dc             	mov    %eax,-0x24(%ebp)
    rfun = rfile;
f0101237:	8b 45 e0             	mov    -0x20(%ebp),%eax
f010123a:	89 45 d8             	mov    %eax,-0x28(%ebp)
    stab_binsearch(stabs, &lfun, &rfun, N_FUN, addr);
f010123d:	83 ec 08             	sub    $0x8,%esp
f0101240:	56                   	push   %esi
f0101241:	6a 24                	push   $0x24
f0101243:	8d 4d d8             	lea    -0x28(%ebp),%ecx
f0101246:	8d 55 dc             	lea    -0x24(%ebp),%edx
f0101249:	b8 30 2b 10 f0       	mov    $0xf0102b30,%eax
f010124e:	e8 03 fe ff ff       	call   f0101056 <stab_binsearch>

    if (lfun <= rfun) {
f0101253:	8b 45 dc             	mov    -0x24(%ebp),%eax
f0101256:	8b 55 d8             	mov    -0x28(%ebp),%edx
f0101259:	83 c4 10             	add    $0x10,%esp
f010125c:	39 d0                	cmp    %edx,%eax
f010125e:	7f 40                	jg     f01012a0 <debuginfo_eip+0x11e>
        /* stabs[lfun] points to the function name in the string table, but
         * check bounds just in case. */
        if (stabs[lfun].n_strx < stabstr_end - stabstr)
f0101260:	8d 0c 40             	lea    (%eax,%eax,2),%ecx
f0101263:	c1 e1 02             	shl    $0x2,%ecx
f0101266:	8d b9 30 2b 10 f0    	lea    -0xfefd4d0(%ecx),%edi
f010126c:	89 7d c4             	mov    %edi,-0x3c(%ebp)
f010126f:	8b b9 30 2b 10 f0    	mov    -0xfefd4d0(%ecx),%edi
f0101275:	b9 5c 92 10 f0       	mov    $0xf010925c,%ecx
f010127a:	81 e9 1d 75 10 f0    	sub    $0xf010751d,%ecx
f0101280:	39 cf                	cmp    %ecx,%edi
f0101282:	73 09                	jae    f010128d <debuginfo_eip+0x10b>
            info->eip_fn_name = stabstr + stabs[lfun].n_strx;
f0101284:	81 c7 1d 75 10 f0    	add    $0xf010751d,%edi
f010128a:	89 7b 08             	mov    %edi,0x8(%ebx)
        info->eip_fn_addr = stabs[lfun].n_value;
f010128d:	8b 7d c4             	mov    -0x3c(%ebp),%edi
f0101290:	8b 4f 08             	mov    0x8(%edi),%ecx
f0101293:	89 4b 10             	mov    %ecx,0x10(%ebx)
        addr -= info->eip_fn_addr;
f0101296:	29 ce                	sub    %ecx,%esi
        /* Search within the function definition for the line number. */
        lline = lfun;
f0101298:	89 45 d4             	mov    %eax,-0x2c(%ebp)
        rline = rfun;
f010129b:	89 55 d0             	mov    %edx,-0x30(%ebp)
f010129e:	eb 0f                	jmp    f01012af <debuginfo_eip+0x12d>
    } else {
        /* Couldn't find function stab!  Maybe we're in an assembly file.
         * Search the whole file for the line number. */
        info->eip_fn_addr = addr;
f01012a0:	89 73 10             	mov    %esi,0x10(%ebx)
        lline = lfile;
f01012a3:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f01012a6:	89 45 d4             	mov    %eax,-0x2c(%ebp)
        rline = rfile;
f01012a9:	8b 45 e0             	mov    -0x20(%ebp),%eax
f01012ac:	89 45 d0             	mov    %eax,-0x30(%ebp)
    }
    /* Ignore stuff after the colon. */
    info->eip_fn_namelen = strfind(info->eip_fn_name, ':') - info->eip_fn_name;
f01012af:	83 ec 08             	sub    $0x8,%esp
f01012b2:	6a 3a                	push   $0x3a
f01012b4:	ff 73 08             	pushl  0x8(%ebx)
f01012b7:	e8 48 09 00 00       	call   f0101c04 <strfind>
f01012bc:	2b 43 08             	sub    0x8(%ebx),%eax
f01012bf:	89 43 0c             	mov    %eax,0xc(%ebx)
    /*
     * Search within [lline, rline] for the line number stab.
     * If found, set info->eip_line to the right line number.
     * If not found, return -1.
     */
    stab_binsearch(stabs, &lline, &rline, N_SLINE, addr);
f01012c2:	83 c4 08             	add    $0x8,%esp
f01012c5:	56                   	push   %esi
f01012c6:	6a 44                	push   $0x44
f01012c8:	8d 4d d0             	lea    -0x30(%ebp),%ecx
f01012cb:	8d 55 d4             	lea    -0x2c(%ebp),%edx
f01012ce:	b8 30 2b 10 f0       	mov    $0xf0102b30,%eax
f01012d3:	e8 7e fd ff ff       	call   f0101056 <stab_binsearch>
    if (lline > rline)
f01012d8:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f01012db:	8b 55 d0             	mov    -0x30(%ebp),%edx
f01012de:	83 c4 10             	add    $0x10,%esp
f01012e1:	39 d0                	cmp    %edx,%eax
f01012e3:	0f 8f d4 00 00 00    	jg     f01013bd <debuginfo_eip+0x23b>
        return -1;
    info->eip_line = stabs[rline].n_desc;
f01012e9:	8d 14 52             	lea    (%edx,%edx,2),%edx
f01012ec:	0f b7 14 95 36 2b 10 	movzwl -0xfefd4ca(,%edx,4),%edx
f01012f3:	f0 
f01012f4:	89 53 04             	mov    %edx,0x4(%ebx)
    /* Search backwards from the line number for the relevant filename stab.
     * We can't just use the "lfile" stab because inlined functions can
     * interpolate code from a different file!
     * Such included source files use the N_SOL stab type.
     */
    while (lline >= lfile
f01012f7:	8b 7d e4             	mov    -0x1c(%ebp),%edi
f01012fa:	39 f8                	cmp    %edi,%eax
f01012fc:	7c 5e                	jl     f010135c <debuginfo_eip+0x1da>
           && stabs[lline].n_type != N_SOL
f01012fe:	8d 14 40             	lea    (%eax,%eax,2),%edx
f0101301:	8d 34 95 30 2b 10 f0 	lea    -0xfefd4d0(,%edx,4),%esi
f0101308:	0f b6 56 04          	movzbl 0x4(%esi),%edx
f010130c:	80 fa 84             	cmp    $0x84,%dl
f010130f:	74 2b                	je     f010133c <debuginfo_eip+0x1ba>
f0101311:	89 f1                	mov    %esi,%ecx
f0101313:	83 c6 08             	add    $0x8,%esi
f0101316:	eb 16                	jmp    f010132e <debuginfo_eip+0x1ac>
           && (stabs[lline].n_type != N_SO || !stabs[lline].n_value))
        lline--;
f0101318:	83 e8 01             	sub    $0x1,%eax
    /* Search backwards from the line number for the relevant filename stab.
     * We can't just use the "lfile" stab because inlined functions can
     * interpolate code from a different file!
     * Such included source files use the N_SOL stab type.
     */
    while (lline >= lfile
f010131b:	39 f8                	cmp    %edi,%eax
f010131d:	7c 3d                	jl     f010135c <debuginfo_eip+0x1da>
           && stabs[lline].n_type != N_SOL
f010131f:	0f b6 51 f8          	movzbl -0x8(%ecx),%edx
f0101323:	83 e9 0c             	sub    $0xc,%ecx
f0101326:	83 ee 0c             	sub    $0xc,%esi
f0101329:	80 fa 84             	cmp    $0x84,%dl
f010132c:	74 0e                	je     f010133c <debuginfo_eip+0x1ba>
           && (stabs[lline].n_type != N_SO || !stabs[lline].n_value))
f010132e:	80 fa 64             	cmp    $0x64,%dl
f0101331:	75 e5                	jne    f0101318 <debuginfo_eip+0x196>
f0101333:	83 3e 00             	cmpl   $0x0,(%esi)
f0101336:	74 e0                	je     f0101318 <debuginfo_eip+0x196>
        lline--;
    if (lline >= lfile && stabs[lline].n_strx < stabstr_end - stabstr)
f0101338:	39 c7                	cmp    %eax,%edi
f010133a:	7f 20                	jg     f010135c <debuginfo_eip+0x1da>
f010133c:	8d 04 40             	lea    (%eax,%eax,2),%eax
f010133f:	8b 14 85 30 2b 10 f0 	mov    -0xfefd4d0(,%eax,4),%edx
f0101346:	b8 5c 92 10 f0       	mov    $0xf010925c,%eax
f010134b:	2d 1d 75 10 f0       	sub    $0xf010751d,%eax
f0101350:	39 c2                	cmp    %eax,%edx
f0101352:	73 08                	jae    f010135c <debuginfo_eip+0x1da>
        info->eip_file = stabstr + stabs[lline].n_strx;
f0101354:	81 c2 1d 75 10 f0    	add    $0xf010751d,%edx
f010135a:	89 13                	mov    %edx,(%ebx)


    /* Set eip_fn_narg to the number of arguments taken by the function, or 0 if
     * there was no containing function. */
    if (lfun < rfun)
f010135c:	8b 4d dc             	mov    -0x24(%ebp),%ecx
f010135f:	8b 75 d8             	mov    -0x28(%ebp),%esi
        for (lline = lfun + 1;
             lline < rfun && stabs[lline].n_type == N_PSYM;
             lline++)
            info->eip_fn_narg++;

    return 0;
f0101362:	b8 00 00 00 00       	mov    $0x0,%eax
        info->eip_file = stabstr + stabs[lline].n_strx;


    /* Set eip_fn_narg to the number of arguments taken by the function, or 0 if
     * there was no containing function. */
    if (lfun < rfun)
f0101367:	39 f1                	cmp    %esi,%ecx
f0101369:	7d 6c                	jge    f01013d7 <debuginfo_eip+0x255>
        for (lline = lfun + 1;
f010136b:	8d 41 01             	lea    0x1(%ecx),%eax
f010136e:	39 c6                	cmp    %eax,%esi
f0101370:	7e 52                	jle    f01013c4 <debuginfo_eip+0x242>
             lline < rfun && stabs[lline].n_type == N_PSYM;
f0101372:	8d 14 40             	lea    (%eax,%eax,2),%edx
f0101375:	c1 e2 02             	shl    $0x2,%edx
f0101378:	80 ba 34 2b 10 f0 a0 	cmpb   $0xa0,-0xfefd4cc(%edx)
f010137f:	75 4a                	jne    f01013cb <debuginfo_eip+0x249>
f0101381:	8d 41 02             	lea    0x2(%ecx),%eax
f0101384:	81 c2 24 2b 10 f0    	add    $0xf0102b24,%edx
             lline++)
            info->eip_fn_narg++;
f010138a:	83 43 14 01          	addl   $0x1,0x14(%ebx)


    /* Set eip_fn_narg to the number of arguments taken by the function, or 0 if
     * there was no containing function. */
    if (lfun < rfun)
        for (lline = lfun + 1;
f010138e:	39 c6                	cmp    %eax,%esi
f0101390:	74 40                	je     f01013d2 <debuginfo_eip+0x250>
             lline < rfun && stabs[lline].n_type == N_PSYM;
f0101392:	0f b6 4a 1c          	movzbl 0x1c(%edx),%ecx
f0101396:	83 c0 01             	add    $0x1,%eax
f0101399:	83 c2 0c             	add    $0xc,%edx
f010139c:	80 f9 a0             	cmp    $0xa0,%cl
f010139f:	74 e9                	je     f010138a <debuginfo_eip+0x208>
             lline++)
            info->eip_fn_narg++;

    return 0;
f01013a1:	b8 00 00 00 00       	mov    $0x0,%eax
f01013a6:	eb 2f                	jmp    f01013d7 <debuginfo_eip+0x255>
        panic("User address");
    }

    /* String table validity checks */
    if (stabstr_end <= stabstr || stabstr_end[-1] != 0)
        return -1;
f01013a8:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f01013ad:	eb 28                	jmp    f01013d7 <debuginfo_eip+0x255>
f01013af:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f01013b4:	eb 21                	jmp    f01013d7 <debuginfo_eip+0x255>
    /* Search the entire set of stabs for the source file (type N_SO). */
    lfile = 0;
    rfile = (stab_end - stabs) - 1;
    stab_binsearch(stabs, &lfile, &rfile, N_SO, addr);
    if (lfile == 0)
        return -1;
f01013b6:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f01013bb:	eb 1a                	jmp    f01013d7 <debuginfo_eip+0x255>
     * If found, set info->eip_line to the right line number.
     * If not found, return -1.
     */
    stab_binsearch(stabs, &lline, &rline, N_SLINE, addr);
    if (lline > rline)
        return -1;
f01013bd:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f01013c2:	eb 13                	jmp    f01013d7 <debuginfo_eip+0x255>
        for (lline = lfun + 1;
             lline < rfun && stabs[lline].n_type == N_PSYM;
             lline++)
            info->eip_fn_narg++;

    return 0;
f01013c4:	b8 00 00 00 00       	mov    $0x0,%eax
f01013c9:	eb 0c                	jmp    f01013d7 <debuginfo_eip+0x255>
f01013cb:	b8 00 00 00 00       	mov    $0x0,%eax
f01013d0:	eb 05                	jmp    f01013d7 <debuginfo_eip+0x255>
f01013d2:	b8 00 00 00 00       	mov    $0x0,%eax
}
f01013d7:	8d 65 f4             	lea    -0xc(%ebp),%esp
f01013da:	5b                   	pop    %ebx
f01013db:	5e                   	pop    %esi
f01013dc:	5f                   	pop    %edi
f01013dd:	5d                   	pop    %ebp
f01013de:	c3                   	ret    

f01013df <printnum>:
 * Print a number (base <= 16) in reverse order,
 * using specified putch function and associated pointer putdat.
 */
static void printnum(void (*putch)(int, void*), void *putdat,
     unsigned long long num, unsigned base, int width, int padc)
{
f01013df:	55                   	push   %ebp
f01013e0:	89 e5                	mov    %esp,%ebp
f01013e2:	57                   	push   %edi
f01013e3:	56                   	push   %esi
f01013e4:	53                   	push   %ebx
f01013e5:	83 ec 1c             	sub    $0x1c,%esp
f01013e8:	89 c7                	mov    %eax,%edi
f01013ea:	89 d6                	mov    %edx,%esi
f01013ec:	8b 45 08             	mov    0x8(%ebp),%eax
f01013ef:	8b 55 0c             	mov    0xc(%ebp),%edx
f01013f2:	89 45 d8             	mov    %eax,-0x28(%ebp)
f01013f5:	89 55 dc             	mov    %edx,-0x24(%ebp)
    /* First recursively print all preceding (more significant) digits. */
    if (num >= base) {
f01013f8:	8b 4d 10             	mov    0x10(%ebp),%ecx
f01013fb:	bb 00 00 00 00       	mov    $0x0,%ebx
f0101400:	89 4d e0             	mov    %ecx,-0x20(%ebp)
f0101403:	89 5d e4             	mov    %ebx,-0x1c(%ebp)
f0101406:	39 d3                	cmp    %edx,%ebx
f0101408:	72 11                	jb     f010141b <printnum+0x3c>
f010140a:	39 45 10             	cmp    %eax,0x10(%ebp)
f010140d:	76 0c                	jbe    f010141b <printnum+0x3c>
        printnum(putch, putdat, num / base, base, width - 1, padc);
    } else {
        /* print any needed pad characters before first digit. */
        while (--width > 0)
f010140f:	8b 45 14             	mov    0x14(%ebp),%eax
f0101412:	8d 58 ff             	lea    -0x1(%eax),%ebx
f0101415:	85 db                	test   %ebx,%ebx
f0101417:	7f 39                	jg     f0101452 <printnum+0x73>
f0101419:	eb 48                	jmp    f0101463 <printnum+0x84>
static void printnum(void (*putch)(int, void*), void *putdat,
     unsigned long long num, unsigned base, int width, int padc)
{
    /* First recursively print all preceding (more significant) digits. */
    if (num >= base) {
        printnum(putch, putdat, num / base, base, width - 1, padc);
f010141b:	83 ec 0c             	sub    $0xc,%esp
f010141e:	ff 75 18             	pushl  0x18(%ebp)
f0101421:	8b 45 14             	mov    0x14(%ebp),%eax
f0101424:	83 e8 01             	sub    $0x1,%eax
f0101427:	50                   	push   %eax
f0101428:	ff 75 10             	pushl  0x10(%ebp)
f010142b:	83 ec 08             	sub    $0x8,%esp
f010142e:	ff 75 e4             	pushl  -0x1c(%ebp)
f0101431:	ff 75 e0             	pushl  -0x20(%ebp)
f0101434:	ff 75 dc             	pushl  -0x24(%ebp)
f0101437:	ff 75 d8             	pushl  -0x28(%ebp)
f010143a:	e8 31 0a 00 00       	call   f0101e70 <__udivdi3>
f010143f:	83 c4 18             	add    $0x18,%esp
f0101442:	52                   	push   %edx
f0101443:	50                   	push   %eax
f0101444:	89 f2                	mov    %esi,%edx
f0101446:	89 f8                	mov    %edi,%eax
f0101448:	e8 92 ff ff ff       	call   f01013df <printnum>
f010144d:	83 c4 20             	add    $0x20,%esp
f0101450:	eb 11                	jmp    f0101463 <printnum+0x84>
    } else {
        /* print any needed pad characters before first digit. */
        while (--width > 0)
            putch(padc, putdat);
f0101452:	83 ec 08             	sub    $0x8,%esp
f0101455:	56                   	push   %esi
f0101456:	ff 75 18             	pushl  0x18(%ebp)
f0101459:	ff d7                	call   *%edi
    /* First recursively print all preceding (more significant) digits. */
    if (num >= base) {
        printnum(putch, putdat, num / base, base, width - 1, padc);
    } else {
        /* print any needed pad characters before first digit. */
        while (--width > 0)
f010145b:	83 c4 10             	add    $0x10,%esp
f010145e:	83 eb 01             	sub    $0x1,%ebx
f0101461:	75 ef                	jne    f0101452 <printnum+0x73>
            putch(padc, putdat);
    }

    /* Then print this (the least significant) digit. */
    putch("0123456789abcdef"[num % base], putdat);
f0101463:	83 ec 08             	sub    $0x8,%esp
f0101466:	56                   	push   %esi
f0101467:	83 ec 04             	sub    $0x4,%esp
f010146a:	ff 75 e4             	pushl  -0x1c(%ebp)
f010146d:	ff 75 e0             	pushl  -0x20(%ebp)
f0101470:	ff 75 dc             	pushl  -0x24(%ebp)
f0101473:	ff 75 d8             	pushl  -0x28(%ebp)
f0101476:	e8 25 0b 00 00       	call   f0101fa0 <__umoddi3>
f010147b:	83 c4 14             	add    $0x14,%esp
f010147e:	0f be 80 fd 28 10 f0 	movsbl -0xfefd703(%eax),%eax
f0101485:	50                   	push   %eax
f0101486:	ff d7                	call   *%edi
}
f0101488:	83 c4 10             	add    $0x10,%esp
f010148b:	8d 65 f4             	lea    -0xc(%ebp),%esp
f010148e:	5b                   	pop    %ebx
f010148f:	5e                   	pop    %esi
f0101490:	5f                   	pop    %edi
f0101491:	5d                   	pop    %ebp
f0101492:	c3                   	ret    

f0101493 <getuint>:
/*
 * Get an unsigned int of various possible sizes from a varargs list,
 * depending on the lflag parameter.
 */
static unsigned long long getuint(va_list *ap, int lflag)
{
f0101493:	55                   	push   %ebp
f0101494:	89 e5                	mov    %esp,%ebp
    if (lflag >= 2)
f0101496:	83 fa 01             	cmp    $0x1,%edx
f0101499:	7e 0e                	jle    f01014a9 <getuint+0x16>
        return va_arg(*ap, unsigned long long);
f010149b:	8b 10                	mov    (%eax),%edx
f010149d:	8d 4a 08             	lea    0x8(%edx),%ecx
f01014a0:	89 08                	mov    %ecx,(%eax)
f01014a2:	8b 02                	mov    (%edx),%eax
f01014a4:	8b 52 04             	mov    0x4(%edx),%edx
f01014a7:	eb 22                	jmp    f01014cb <getuint+0x38>
    else if (lflag)
f01014a9:	85 d2                	test   %edx,%edx
f01014ab:	74 10                	je     f01014bd <getuint+0x2a>
        return va_arg(*ap, unsigned long);
f01014ad:	8b 10                	mov    (%eax),%edx
f01014af:	8d 4a 04             	lea    0x4(%edx),%ecx
f01014b2:	89 08                	mov    %ecx,(%eax)
f01014b4:	8b 02                	mov    (%edx),%eax
f01014b6:	ba 00 00 00 00       	mov    $0x0,%edx
f01014bb:	eb 0e                	jmp    f01014cb <getuint+0x38>
    else
        return va_arg(*ap, unsigned int);
f01014bd:	8b 10                	mov    (%eax),%edx
f01014bf:	8d 4a 04             	lea    0x4(%edx),%ecx
f01014c2:	89 08                	mov    %ecx,(%eax)
f01014c4:	8b 02                	mov    (%edx),%eax
f01014c6:	ba 00 00 00 00       	mov    $0x0,%edx
}
f01014cb:	5d                   	pop    %ebp
f01014cc:	c3                   	ret    

f01014cd <getint>:

/*
 * Same as getuint but signed - can't use getuint because of sign extension
 */
static long long getint(va_list *ap, int lflag)
{
f01014cd:	55                   	push   %ebp
f01014ce:	89 e5                	mov    %esp,%ebp
    if (lflag >= 2)
f01014d0:	83 fa 01             	cmp    $0x1,%edx
f01014d3:	7e 0e                	jle    f01014e3 <getint+0x16>
        return va_arg(*ap, long long);
f01014d5:	8b 10                	mov    (%eax),%edx
f01014d7:	8d 4a 08             	lea    0x8(%edx),%ecx
f01014da:	89 08                	mov    %ecx,(%eax)
f01014dc:	8b 02                	mov    (%edx),%eax
f01014de:	8b 52 04             	mov    0x4(%edx),%edx
f01014e1:	eb 1a                	jmp    f01014fd <getint+0x30>
    else if (lflag)
f01014e3:	85 d2                	test   %edx,%edx
f01014e5:	74 0c                	je     f01014f3 <getint+0x26>
        return va_arg(*ap, long);
f01014e7:	8b 10                	mov    (%eax),%edx
f01014e9:	8d 4a 04             	lea    0x4(%edx),%ecx
f01014ec:	89 08                	mov    %ecx,(%eax)
f01014ee:	8b 02                	mov    (%edx),%eax
f01014f0:	99                   	cltd   
f01014f1:	eb 0a                	jmp    f01014fd <getint+0x30>
    else
        return va_arg(*ap, int);
f01014f3:	8b 10                	mov    (%eax),%edx
f01014f5:	8d 4a 04             	lea    0x4(%edx),%ecx
f01014f8:	89 08                	mov    %ecx,(%eax)
f01014fa:	8b 02                	mov    (%edx),%eax
f01014fc:	99                   	cltd   
}
f01014fd:	5d                   	pop    %ebp
f01014fe:	c3                   	ret    

f01014ff <sprintputch>:
    char *ebuf;
    int cnt;
};

static void sprintputch(int ch, struct sprintbuf *b)
{
f01014ff:	55                   	push   %ebp
f0101500:	89 e5                	mov    %esp,%ebp
f0101502:	8b 45 0c             	mov    0xc(%ebp),%eax
    b->cnt++;
f0101505:	83 40 08 01          	addl   $0x1,0x8(%eax)
    if (b->buf < b->ebuf)
f0101509:	8b 10                	mov    (%eax),%edx
f010150b:	3b 50 04             	cmp    0x4(%eax),%edx
f010150e:	73 0a                	jae    f010151a <sprintputch+0x1b>
        *b->buf++ = ch;
f0101510:	8d 4a 01             	lea    0x1(%edx),%ecx
f0101513:	89 08                	mov    %ecx,(%eax)
f0101515:	8b 45 08             	mov    0x8(%ebp),%eax
f0101518:	88 02                	mov    %al,(%edx)
}
f010151a:	5d                   	pop    %ebp
f010151b:	c3                   	ret    

f010151c <printfmt>:
        }
    }
}

void printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...)
{
f010151c:	55                   	push   %ebp
f010151d:	89 e5                	mov    %esp,%ebp
f010151f:	83 ec 08             	sub    $0x8,%esp
    va_list ap;

    va_start(ap, fmt);
f0101522:	8d 45 14             	lea    0x14(%ebp),%eax
    vprintfmt(putch, putdat, fmt, ap);
f0101525:	50                   	push   %eax
f0101526:	ff 75 10             	pushl  0x10(%ebp)
f0101529:	ff 75 0c             	pushl  0xc(%ebp)
f010152c:	ff 75 08             	pushl  0x8(%ebp)
f010152f:	e8 05 00 00 00       	call   f0101539 <vprintfmt>
    va_end(ap);
}
f0101534:	83 c4 10             	add    $0x10,%esp
f0101537:	c9                   	leave  
f0101538:	c3                   	ret    

f0101539 <vprintfmt>:
/* Main function to format and print a string. */
void printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...);

void vprintfmt(void (*putch)(int, void*), void *putdat, const char *fmt,
        va_list ap)
{
f0101539:	55                   	push   %ebp
f010153a:	89 e5                	mov    %esp,%ebp
f010153c:	57                   	push   %edi
f010153d:	56                   	push   %esi
f010153e:	53                   	push   %ebx
f010153f:	83 ec 2c             	sub    $0x2c,%esp
f0101542:	8b 7d 08             	mov    0x8(%ebp),%edi
f0101545:	8b 5d 0c             	mov    0xc(%ebp),%ebx
f0101548:	eb 03                	jmp    f010154d <vprintfmt+0x14>
            break;

        /* unrecognized escape sequence - just print it literally */
        default:
            putch('%', putdat);
            for (fmt--; fmt[-1] != '%'; fmt--)
f010154a:	89 75 10             	mov    %esi,0x10(%ebp)
    unsigned long long num;
    int base, lflag, width, precision, altflag;
    char padc;

    while (1) {
        while ((ch = *(unsigned char *) fmt++) != '%') {
f010154d:	8b 45 10             	mov    0x10(%ebp),%eax
f0101550:	8d 70 01             	lea    0x1(%eax),%esi
f0101553:	0f b6 00             	movzbl (%eax),%eax
f0101556:	83 f8 25             	cmp    $0x25,%eax
f0101559:	74 27                	je     f0101582 <vprintfmt+0x49>
            if (ch == '\0')
f010155b:	85 c0                	test   %eax,%eax
f010155d:	75 0d                	jne    f010156c <vprintfmt+0x33>
f010155f:	e9 82 03 00 00       	jmp    f01018e6 <vprintfmt+0x3ad>
f0101564:	85 c0                	test   %eax,%eax
f0101566:	0f 84 7a 03 00 00    	je     f01018e6 <vprintfmt+0x3ad>
                return;
            putch(ch, putdat);
f010156c:	83 ec 08             	sub    $0x8,%esp
f010156f:	53                   	push   %ebx
f0101570:	50                   	push   %eax
f0101571:	ff d7                	call   *%edi
    unsigned long long num;
    int base, lflag, width, precision, altflag;
    char padc;

    while (1) {
        while ((ch = *(unsigned char *) fmt++) != '%') {
f0101573:	83 c6 01             	add    $0x1,%esi
f0101576:	0f b6 46 ff          	movzbl -0x1(%esi),%eax
f010157a:	83 c4 10             	add    $0x10,%esp
f010157d:	83 f8 25             	cmp    $0x25,%eax
f0101580:	75 e2                	jne    f0101564 <vprintfmt+0x2b>
            if (width < 0)
                width = 0;
            goto reswitch;

        case '#':
            altflag = 1;
f0101582:	c6 45 e3 20          	movb   $0x20,-0x1d(%ebp)
f0101586:	c7 45 d8 00 00 00 00 	movl   $0x0,-0x28(%ebp)
f010158d:	c7 45 d4 ff ff ff ff 	movl   $0xffffffff,-0x2c(%ebp)
f0101594:	c7 45 e4 ff ff ff ff 	movl   $0xffffffff,-0x1c(%ebp)
f010159b:	ba 00 00 00 00       	mov    $0x0,%edx
f01015a0:	eb 07                	jmp    f01015a9 <vprintfmt+0x70>
        width = -1;
        precision = -1;
        lflag = 0;
        altflag = 0;
    reswitch:
        switch (ch = *(unsigned char *) fmt++) {
f01015a2:	8b 75 10             	mov    0x10(%ebp),%esi

        /* flag to pad on the right */
        case '-':
            padc = '-';
f01015a5:	c6 45 e3 2d          	movb   $0x2d,-0x1d(%ebp)
        width = -1;
        precision = -1;
        lflag = 0;
        altflag = 0;
    reswitch:
        switch (ch = *(unsigned char *) fmt++) {
f01015a9:	8d 46 01             	lea    0x1(%esi),%eax
f01015ac:	89 45 10             	mov    %eax,0x10(%ebp)
f01015af:	0f b6 06             	movzbl (%esi),%eax
f01015b2:	0f b6 c8             	movzbl %al,%ecx
f01015b5:	83 e8 23             	sub    $0x23,%eax
f01015b8:	3c 55                	cmp    $0x55,%al
f01015ba:	0f 87 e7 02 00 00    	ja     f01018a7 <vprintfmt+0x36e>
f01015c0:	0f b6 c0             	movzbl %al,%eax
f01015c3:	ff 24 85 a0 29 10 f0 	jmp    *-0xfefd660(,%eax,4)
f01015ca:	8b 75 10             	mov    0x10(%ebp),%esi
            padc = '-';
            goto reswitch;

        /* flag to pad with 0's instead of spaces */
        case '0':
            padc = '0';
f01015cd:	c6 45 e3 30          	movb   $0x30,-0x1d(%ebp)
f01015d1:	eb d6                	jmp    f01015a9 <vprintfmt+0x70>
        case '6':
        case '7':
        case '8':
        case '9':
            for (precision = 0; ; ++fmt) {
                precision = precision * 10 + ch - '0';
f01015d3:	8d 41 d0             	lea    -0x30(%ecx),%eax
f01015d6:	89 45 d4             	mov    %eax,-0x2c(%ebp)
                ch = *fmt;
f01015d9:	0f be 46 01          	movsbl 0x1(%esi),%eax
                if (ch < '0' || ch > '9')
f01015dd:	8d 48 d0             	lea    -0x30(%eax),%ecx
f01015e0:	83 f9 09             	cmp    $0x9,%ecx
f01015e3:	77 60                	ja     f0101645 <vprintfmt+0x10c>
f01015e5:	8b 75 10             	mov    0x10(%ebp),%esi
f01015e8:	89 55 d0             	mov    %edx,-0x30(%ebp)
f01015eb:	8b 55 d4             	mov    -0x2c(%ebp),%edx
        case '5':
        case '6':
        case '7':
        case '8':
        case '9':
            for (precision = 0; ; ++fmt) {
f01015ee:	83 c6 01             	add    $0x1,%esi
                precision = precision * 10 + ch - '0';
f01015f1:	8d 14 92             	lea    (%edx,%edx,4),%edx
f01015f4:	8d 54 50 d0          	lea    -0x30(%eax,%edx,2),%edx
                ch = *fmt;
f01015f8:	0f be 06             	movsbl (%esi),%eax
                if (ch < '0' || ch > '9')
f01015fb:	8d 48 d0             	lea    -0x30(%eax),%ecx
f01015fe:	83 f9 09             	cmp    $0x9,%ecx
f0101601:	76 eb                	jbe    f01015ee <vprintfmt+0xb5>
f0101603:	89 55 d4             	mov    %edx,-0x2c(%ebp)
f0101606:	8b 55 d0             	mov    -0x30(%ebp),%edx
f0101609:	eb 3d                	jmp    f0101648 <vprintfmt+0x10f>
                    break;
            }
            goto process_precision;

        case '*':
            precision = va_arg(ap, int);
f010160b:	8b 45 14             	mov    0x14(%ebp),%eax
f010160e:	8d 48 04             	lea    0x4(%eax),%ecx
f0101611:	89 4d 14             	mov    %ecx,0x14(%ebp)
f0101614:	8b 00                	mov    (%eax),%eax
f0101616:	89 45 d4             	mov    %eax,-0x2c(%ebp)
        width = -1;
        precision = -1;
        lflag = 0;
        altflag = 0;
    reswitch:
        switch (ch = *(unsigned char *) fmt++) {
f0101619:	8b 75 10             	mov    0x10(%ebp),%esi
            }
            goto process_precision;

        case '*':
            precision = va_arg(ap, int);
            goto process_precision;
f010161c:	eb 2a                	jmp    f0101648 <vprintfmt+0x10f>
f010161e:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0101621:	85 c0                	test   %eax,%eax
f0101623:	b9 00 00 00 00       	mov    $0x0,%ecx
f0101628:	0f 49 c8             	cmovns %eax,%ecx
f010162b:	89 4d e4             	mov    %ecx,-0x1c(%ebp)
        width = -1;
        precision = -1;
        lflag = 0;
        altflag = 0;
    reswitch:
        switch (ch = *(unsigned char *) fmt++) {
f010162e:	8b 75 10             	mov    0x10(%ebp),%esi
f0101631:	e9 73 ff ff ff       	jmp    f01015a9 <vprintfmt+0x70>
f0101636:	8b 75 10             	mov    0x10(%ebp),%esi
            if (width < 0)
                width = 0;
            goto reswitch;

        case '#':
            altflag = 1;
f0101639:	c7 45 d8 01 00 00 00 	movl   $0x1,-0x28(%ebp)
            goto reswitch;
f0101640:	e9 64 ff ff ff       	jmp    f01015a9 <vprintfmt+0x70>
        width = -1;
        precision = -1;
        lflag = 0;
        altflag = 0;
    reswitch:
        switch (ch = *(unsigned char *) fmt++) {
f0101645:	8b 75 10             	mov    0x10(%ebp),%esi
        case '#':
            altflag = 1;
            goto reswitch;

        process_precision:
            if (width < 0)
f0101648:	83 7d e4 00          	cmpl   $0x0,-0x1c(%ebp)
f010164c:	0f 89 57 ff ff ff    	jns    f01015a9 <vprintfmt+0x70>
                width = precision, precision = -1;
f0101652:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101655:	89 45 e4             	mov    %eax,-0x1c(%ebp)
f0101658:	c7 45 d4 ff ff ff ff 	movl   $0xffffffff,-0x2c(%ebp)
f010165f:	e9 45 ff ff ff       	jmp    f01015a9 <vprintfmt+0x70>
            goto reswitch;

        /* long flag (doubled for long long) */
        case 'l':
            lflag++;
f0101664:	83 c2 01             	add    $0x1,%edx
        width = -1;
        precision = -1;
        lflag = 0;
        altflag = 0;
    reswitch:
        switch (ch = *(unsigned char *) fmt++) {
f0101667:	8b 75 10             	mov    0x10(%ebp),%esi
            goto reswitch;

        /* long flag (doubled for long long) */
        case 'l':
            lflag++;
            goto reswitch;
f010166a:	e9 3a ff ff ff       	jmp    f01015a9 <vprintfmt+0x70>

        /* character */
        case 'c':
            putch(va_arg(ap, int), putdat);
f010166f:	8b 45 14             	mov    0x14(%ebp),%eax
f0101672:	8d 50 04             	lea    0x4(%eax),%edx
f0101675:	89 55 14             	mov    %edx,0x14(%ebp)
f0101678:	83 ec 08             	sub    $0x8,%esp
f010167b:	53                   	push   %ebx
f010167c:	ff 30                	pushl  (%eax)
f010167e:	ff d7                	call   *%edi
            break;
f0101680:	83 c4 10             	add    $0x10,%esp
f0101683:	e9 c5 fe ff ff       	jmp    f010154d <vprintfmt+0x14>

        /* error message */
        case 'e':
            err = va_arg(ap, int);
f0101688:	8b 45 14             	mov    0x14(%ebp),%eax
f010168b:	8d 50 04             	lea    0x4(%eax),%edx
f010168e:	89 55 14             	mov    %edx,0x14(%ebp)
f0101691:	8b 00                	mov    (%eax),%eax
f0101693:	99                   	cltd   
f0101694:	31 d0                	xor    %edx,%eax
f0101696:	29 d0                	sub    %edx,%eax
            if (err < 0)
                err = -err;
            if (err >= MAXERROR || (p = error_string[err]) == NULL)
f0101698:	83 f8 07             	cmp    $0x7,%eax
f010169b:	7f 0b                	jg     f01016a8 <vprintfmt+0x16f>
f010169d:	8b 14 85 00 2b 10 f0 	mov    -0xfefd500(,%eax,4),%edx
f01016a4:	85 d2                	test   %edx,%edx
f01016a6:	75 15                	jne    f01016bd <vprintfmt+0x184>
                printfmt(putch, putdat, "error %d", err);
f01016a8:	50                   	push   %eax
f01016a9:	68 15 29 10 f0       	push   $0xf0102915
f01016ae:	53                   	push   %ebx
f01016af:	57                   	push   %edi
f01016b0:	e8 67 fe ff ff       	call   f010151c <printfmt>
f01016b5:	83 c4 10             	add    $0x10,%esp
f01016b8:	e9 90 fe ff ff       	jmp    f010154d <vprintfmt+0x14>
            else
                printfmt(putch, putdat, "%s", p);
f01016bd:	52                   	push   %edx
f01016be:	68 88 26 10 f0       	push   $0xf0102688
f01016c3:	53                   	push   %ebx
f01016c4:	57                   	push   %edi
f01016c5:	e8 52 fe ff ff       	call   f010151c <printfmt>
f01016ca:	83 c4 10             	add    $0x10,%esp
f01016cd:	e9 7b fe ff ff       	jmp    f010154d <vprintfmt+0x14>
            break;

        /* string */
        case 's':
            if ((p = va_arg(ap, char *)) == NULL)
f01016d2:	8b 45 14             	mov    0x14(%ebp),%eax
f01016d5:	8d 50 04             	lea    0x4(%eax),%edx
f01016d8:	89 55 14             	mov    %edx,0x14(%ebp)
f01016db:	8b 00                	mov    (%eax),%eax
                p = "(null)";
f01016dd:	85 c0                	test   %eax,%eax
f01016df:	b9 0e 29 10 f0       	mov    $0xf010290e,%ecx
f01016e4:	0f 45 c8             	cmovne %eax,%ecx
f01016e7:	89 4d d0             	mov    %ecx,-0x30(%ebp)
            if (width > 0 && padc != '-')
f01016ea:	83 7d e4 00          	cmpl   $0x0,-0x1c(%ebp)
f01016ee:	7e 06                	jle    f01016f6 <vprintfmt+0x1bd>
f01016f0:	80 7d e3 2d          	cmpb   $0x2d,-0x1d(%ebp)
f01016f4:	75 19                	jne    f010170f <vprintfmt+0x1d6>
                for (width -= strnlen(p, precision); width > 0; width--)
                    putch(padc, putdat);
            for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0);
f01016f6:	8b 45 d0             	mov    -0x30(%ebp),%eax
f01016f9:	8d 70 01             	lea    0x1(%eax),%esi
f01016fc:	0f b6 00             	movzbl (%eax),%eax
f01016ff:	0f be d0             	movsbl %al,%edx
f0101702:	85 d2                	test   %edx,%edx
f0101704:	0f 85 9f 00 00 00    	jne    f01017a9 <vprintfmt+0x270>
f010170a:	e9 8c 00 00 00       	jmp    f010179b <vprintfmt+0x262>
        /* string */
        case 's':
            if ((p = va_arg(ap, char *)) == NULL)
                p = "(null)";
            if (width > 0 && padc != '-')
                for (width -= strnlen(p, precision); width > 0; width--)
f010170f:	83 ec 08             	sub    $0x8,%esp
f0101712:	ff 75 d4             	pushl  -0x2c(%ebp)
f0101715:	ff 75 d0             	pushl  -0x30(%ebp)
f0101718:	e8 34 03 00 00       	call   f0101a51 <strnlen>
f010171d:	29 45 e4             	sub    %eax,-0x1c(%ebp)
f0101720:	8b 4d e4             	mov    -0x1c(%ebp),%ecx
f0101723:	83 c4 10             	add    $0x10,%esp
f0101726:	85 c9                	test   %ecx,%ecx
f0101728:	0f 8e 9f 01 00 00    	jle    f01018cd <vprintfmt+0x394>
                    putch(padc, putdat);
f010172e:	0f be 75 e3          	movsbl -0x1d(%ebp),%esi
f0101732:	89 5d 0c             	mov    %ebx,0xc(%ebp)
f0101735:	89 cb                	mov    %ecx,%ebx
f0101737:	83 ec 08             	sub    $0x8,%esp
f010173a:	ff 75 0c             	pushl  0xc(%ebp)
f010173d:	56                   	push   %esi
f010173e:	ff d7                	call   *%edi
        /* string */
        case 's':
            if ((p = va_arg(ap, char *)) == NULL)
                p = "(null)";
            if (width > 0 && padc != '-')
                for (width -= strnlen(p, precision); width > 0; width--)
f0101740:	83 c4 10             	add    $0x10,%esp
f0101743:	83 eb 01             	sub    $0x1,%ebx
f0101746:	75 ef                	jne    f0101737 <vprintfmt+0x1fe>
f0101748:	89 5d e4             	mov    %ebx,-0x1c(%ebp)
f010174b:	8b 5d 0c             	mov    0xc(%ebp),%ebx
f010174e:	e9 7a 01 00 00       	jmp    f01018cd <vprintfmt+0x394>
                    putch(padc, putdat);
            for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0);
                    width--)
                if (altflag && (ch < ' ' || ch > '~'))
f0101753:	83 7d d8 00          	cmpl   $0x0,-0x28(%ebp)
f0101757:	74 1b                	je     f0101774 <vprintfmt+0x23b>
f0101759:	0f be c0             	movsbl %al,%eax
f010175c:	83 e8 20             	sub    $0x20,%eax
f010175f:	83 f8 5e             	cmp    $0x5e,%eax
f0101762:	76 10                	jbe    f0101774 <vprintfmt+0x23b>
                    putch('?', putdat);
f0101764:	83 ec 08             	sub    $0x8,%esp
f0101767:	ff 75 0c             	pushl  0xc(%ebp)
f010176a:	6a 3f                	push   $0x3f
f010176c:	ff 55 08             	call   *0x8(%ebp)
f010176f:	83 c4 10             	add    $0x10,%esp
f0101772:	eb 0d                	jmp    f0101781 <vprintfmt+0x248>
                else
                    putch(ch, putdat);
f0101774:	83 ec 08             	sub    $0x8,%esp
f0101777:	ff 75 0c             	pushl  0xc(%ebp)
f010177a:	52                   	push   %edx
f010177b:	ff 55 08             	call   *0x8(%ebp)
f010177e:	83 c4 10             	add    $0x10,%esp
                p = "(null)";
            if (width > 0 && padc != '-')
                for (width -= strnlen(p, precision); width > 0; width--)
                    putch(padc, putdat);
            for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0);
                    width--)
f0101781:	83 eb 01             	sub    $0x1,%ebx
            if ((p = va_arg(ap, char *)) == NULL)
                p = "(null)";
            if (width > 0 && padc != '-')
                for (width -= strnlen(p, precision); width > 0; width--)
                    putch(padc, putdat);
            for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0);
f0101784:	83 c6 01             	add    $0x1,%esi
f0101787:	0f b6 46 ff          	movzbl -0x1(%esi),%eax
f010178b:	0f be d0             	movsbl %al,%edx
f010178e:	85 d2                	test   %edx,%edx
f0101790:	75 31                	jne    f01017c3 <vprintfmt+0x28a>
f0101792:	89 5d e4             	mov    %ebx,-0x1c(%ebp)
f0101795:	8b 7d 08             	mov    0x8(%ebp),%edi
f0101798:	8b 5d 0c             	mov    0xc(%ebp),%ebx
f010179b:	8b 75 e4             	mov    -0x1c(%ebp),%esi
                    width--)
                if (altflag && (ch < ' ' || ch > '~'))
                    putch('?', putdat);
                else
                    putch(ch, putdat);
            for (; width > 0; width--)
f010179e:	83 7d e4 00          	cmpl   $0x0,-0x1c(%ebp)
f01017a2:	7f 33                	jg     f01017d7 <vprintfmt+0x29e>
f01017a4:	e9 a4 fd ff ff       	jmp    f010154d <vprintfmt+0x14>
f01017a9:	89 7d 08             	mov    %edi,0x8(%ebp)
f01017ac:	8b 7d d4             	mov    -0x2c(%ebp),%edi
f01017af:	89 5d 0c             	mov    %ebx,0xc(%ebp)
f01017b2:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
f01017b5:	eb 0c                	jmp    f01017c3 <vprintfmt+0x28a>
f01017b7:	89 7d 08             	mov    %edi,0x8(%ebp)
f01017ba:	8b 7d d4             	mov    -0x2c(%ebp),%edi
f01017bd:	89 5d 0c             	mov    %ebx,0xc(%ebp)
f01017c0:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
            if ((p = va_arg(ap, char *)) == NULL)
                p = "(null)";
            if (width > 0 && padc != '-')
                for (width -= strnlen(p, precision); width > 0; width--)
                    putch(padc, putdat);
            for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0);
f01017c3:	85 ff                	test   %edi,%edi
f01017c5:	78 8c                	js     f0101753 <vprintfmt+0x21a>
f01017c7:	83 ef 01             	sub    $0x1,%edi
f01017ca:	79 87                	jns    f0101753 <vprintfmt+0x21a>
f01017cc:	89 5d e4             	mov    %ebx,-0x1c(%ebp)
f01017cf:	8b 7d 08             	mov    0x8(%ebp),%edi
f01017d2:	8b 5d 0c             	mov    0xc(%ebp),%ebx
f01017d5:	eb c4                	jmp    f010179b <vprintfmt+0x262>
                if (altflag && (ch < ' ' || ch > '~'))
                    putch('?', putdat);
                else
                    putch(ch, putdat);
            for (; width > 0; width--)
                putch(' ', putdat);
f01017d7:	83 ec 08             	sub    $0x8,%esp
f01017da:	53                   	push   %ebx
f01017db:	6a 20                	push   $0x20
f01017dd:	ff d7                	call   *%edi
                    width--)
                if (altflag && (ch < ' ' || ch > '~'))
                    putch('?', putdat);
                else
                    putch(ch, putdat);
            for (; width > 0; width--)
f01017df:	83 c4 10             	add    $0x10,%esp
f01017e2:	83 ee 01             	sub    $0x1,%esi
f01017e5:	75 f0                	jne    f01017d7 <vprintfmt+0x29e>
f01017e7:	e9 61 fd ff ff       	jmp    f010154d <vprintfmt+0x14>
                putch(' ', putdat);
            break;

        /* (signed) decimal */
        case 'd':
            num = getint(&ap, lflag);
f01017ec:	8d 45 14             	lea    0x14(%ebp),%eax
f01017ef:	e8 d9 fc ff ff       	call   f01014cd <getint>
f01017f4:	89 45 d8             	mov    %eax,-0x28(%ebp)
f01017f7:	89 55 dc             	mov    %edx,-0x24(%ebp)
            if ((long long) num < 0) {
                putch('-', putdat);
                num = -(long long) num;
            }
            base = 10;
f01017fa:	b9 0a 00 00 00       	mov    $0xa,%ecx
            break;

        /* (signed) decimal */
        case 'd':
            num = getint(&ap, lflag);
            if ((long long) num < 0) {
f01017ff:	83 7d dc 00          	cmpl   $0x0,-0x24(%ebp)
f0101803:	79 74                	jns    f0101879 <vprintfmt+0x340>
                putch('-', putdat);
f0101805:	83 ec 08             	sub    $0x8,%esp
f0101808:	53                   	push   %ebx
f0101809:	6a 2d                	push   $0x2d
f010180b:	ff d7                	call   *%edi
                num = -(long long) num;
f010180d:	8b 45 d8             	mov    -0x28(%ebp),%eax
f0101810:	8b 55 dc             	mov    -0x24(%ebp),%edx
f0101813:	f7 d8                	neg    %eax
f0101815:	83 d2 00             	adc    $0x0,%edx
f0101818:	f7 da                	neg    %edx
f010181a:	83 c4 10             	add    $0x10,%esp
            }
            base = 10;
f010181d:	b9 0a 00 00 00       	mov    $0xa,%ecx
f0101822:	eb 55                	jmp    f0101879 <vprintfmt+0x340>
            goto number;

        /* unsigned decimal */
        case 'u':
            num = getuint(&ap, lflag);
f0101824:	8d 45 14             	lea    0x14(%ebp),%eax
f0101827:	e8 67 fc ff ff       	call   f0101493 <getuint>
            base = 10;
f010182c:	b9 0a 00 00 00       	mov    $0xa,%ecx
            goto number;
f0101831:	eb 46                	jmp    f0101879 <vprintfmt+0x340>

        /* (unsigned) octal */
        case 'o':
            num = getuint(&ap, lflag);
f0101833:	8d 45 14             	lea    0x14(%ebp),%eax
f0101836:	e8 58 fc ff ff       	call   f0101493 <getuint>
            base = 8;
f010183b:	b9 08 00 00 00       	mov    $0x8,%ecx
            goto number;
f0101840:	eb 37                	jmp    f0101879 <vprintfmt+0x340>

        /* pointer */
        case 'p':
            putch('0', putdat);
f0101842:	83 ec 08             	sub    $0x8,%esp
f0101845:	53                   	push   %ebx
f0101846:	6a 30                	push   $0x30
f0101848:	ff d7                	call   *%edi
            putch('x', putdat);
f010184a:	83 c4 08             	add    $0x8,%esp
f010184d:	53                   	push   %ebx
f010184e:	6a 78                	push   $0x78
f0101850:	ff d7                	call   *%edi
            num = (unsigned long long)
                (uintptr_t) va_arg(ap, void *);
f0101852:	8b 45 14             	mov    0x14(%ebp),%eax
f0101855:	8d 50 04             	lea    0x4(%eax),%edx
f0101858:	89 55 14             	mov    %edx,0x14(%ebp)

        /* pointer */
        case 'p':
            putch('0', putdat);
            putch('x', putdat);
            num = (unsigned long long)
f010185b:	8b 00                	mov    (%eax),%eax
f010185d:	ba 00 00 00 00       	mov    $0x0,%edx
                (uintptr_t) va_arg(ap, void *);
            base = 16;
            goto number;
f0101862:	83 c4 10             	add    $0x10,%esp
        case 'p':
            putch('0', putdat);
            putch('x', putdat);
            num = (unsigned long long)
                (uintptr_t) va_arg(ap, void *);
            base = 16;
f0101865:	b9 10 00 00 00       	mov    $0x10,%ecx
            goto number;
f010186a:	eb 0d                	jmp    f0101879 <vprintfmt+0x340>

        /* (unsigned) hexadecimal */
        case 'x':
            num = getuint(&ap, lflag);
f010186c:	8d 45 14             	lea    0x14(%ebp),%eax
f010186f:	e8 1f fc ff ff       	call   f0101493 <getuint>
            base = 16;
f0101874:	b9 10 00 00 00       	mov    $0x10,%ecx
        number:
            printnum(putch, putdat, num, base, width, padc);
f0101879:	83 ec 0c             	sub    $0xc,%esp
f010187c:	0f be 75 e3          	movsbl -0x1d(%ebp),%esi
f0101880:	56                   	push   %esi
f0101881:	ff 75 e4             	pushl  -0x1c(%ebp)
f0101884:	51                   	push   %ecx
f0101885:	52                   	push   %edx
f0101886:	50                   	push   %eax
f0101887:	89 da                	mov    %ebx,%edx
f0101889:	89 f8                	mov    %edi,%eax
f010188b:	e8 4f fb ff ff       	call   f01013df <printnum>
            break;
f0101890:	83 c4 20             	add    $0x20,%esp
f0101893:	e9 b5 fc ff ff       	jmp    f010154d <vprintfmt+0x14>

        /* escaped '%' character */
        case '%':
            putch(ch, putdat);
f0101898:	83 ec 08             	sub    $0x8,%esp
f010189b:	53                   	push   %ebx
f010189c:	51                   	push   %ecx
f010189d:	ff d7                	call   *%edi
            break;
f010189f:	83 c4 10             	add    $0x10,%esp
f01018a2:	e9 a6 fc ff ff       	jmp    f010154d <vprintfmt+0x14>

        /* unrecognized escape sequence - just print it literally */
        default:
            putch('%', putdat);
f01018a7:	83 ec 08             	sub    $0x8,%esp
f01018aa:	53                   	push   %ebx
f01018ab:	6a 25                	push   $0x25
f01018ad:	ff d7                	call   *%edi
            for (fmt--; fmt[-1] != '%'; fmt--)
f01018af:	83 c4 10             	add    $0x10,%esp
f01018b2:	80 7e ff 25          	cmpb   $0x25,-0x1(%esi)
f01018b6:	0f 84 8e fc ff ff    	je     f010154a <vprintfmt+0x11>
f01018bc:	83 ee 01             	sub    $0x1,%esi
f01018bf:	80 7e ff 25          	cmpb   $0x25,-0x1(%esi)
f01018c3:	75 f7                	jne    f01018bc <vprintfmt+0x383>
f01018c5:	89 75 10             	mov    %esi,0x10(%ebp)
f01018c8:	e9 80 fc ff ff       	jmp    f010154d <vprintfmt+0x14>
            if ((p = va_arg(ap, char *)) == NULL)
                p = "(null)";
            if (width > 0 && padc != '-')
                for (width -= strnlen(p, precision); width > 0; width--)
                    putch(padc, putdat);
            for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0);
f01018cd:	8b 45 d0             	mov    -0x30(%ebp),%eax
f01018d0:	8d 70 01             	lea    0x1(%eax),%esi
f01018d3:	0f b6 00             	movzbl (%eax),%eax
f01018d6:	0f be d0             	movsbl %al,%edx
f01018d9:	85 d2                	test   %edx,%edx
f01018db:	0f 85 d6 fe ff ff    	jne    f01017b7 <vprintfmt+0x27e>
f01018e1:	e9 67 fc ff ff       	jmp    f010154d <vprintfmt+0x14>
            for (fmt--; fmt[-1] != '%'; fmt--)
                /* do nothing */;
            break;
        }
    }
}
f01018e6:	8d 65 f4             	lea    -0xc(%ebp),%esp
f01018e9:	5b                   	pop    %ebx
f01018ea:	5e                   	pop    %esi
f01018eb:	5f                   	pop    %edi
f01018ec:	5d                   	pop    %ebp
f01018ed:	c3                   	ret    

f01018ee <vsnprintf>:
    if (b->buf < b->ebuf)
        *b->buf++ = ch;
}

int vsnprintf(char *buf, int n, const char *fmt, va_list ap)
{
f01018ee:	55                   	push   %ebp
f01018ef:	89 e5                	mov    %esp,%ebp
f01018f1:	83 ec 18             	sub    $0x18,%esp
f01018f4:	8b 45 08             	mov    0x8(%ebp),%eax
f01018f7:	8b 55 0c             	mov    0xc(%ebp),%edx
    struct sprintbuf b = {buf, buf+n-1, 0};
f01018fa:	89 45 ec             	mov    %eax,-0x14(%ebp)
f01018fd:	8d 4c 10 ff          	lea    -0x1(%eax,%edx,1),%ecx
f0101901:	89 4d f0             	mov    %ecx,-0x10(%ebp)
f0101904:	c7 45 f4 00 00 00 00 	movl   $0x0,-0xc(%ebp)

    if (buf == NULL || n < 1)
f010190b:	85 c0                	test   %eax,%eax
f010190d:	74 26                	je     f0101935 <vsnprintf+0x47>
f010190f:	85 d2                	test   %edx,%edx
f0101911:	7e 22                	jle    f0101935 <vsnprintf+0x47>
        return -E_INVAL;

    /* Print the string to the buffer. */
    vprintfmt((void*)sprintputch, &b, fmt, ap);
f0101913:	ff 75 14             	pushl  0x14(%ebp)
f0101916:	ff 75 10             	pushl  0x10(%ebp)
f0101919:	8d 45 ec             	lea    -0x14(%ebp),%eax
f010191c:	50                   	push   %eax
f010191d:	68 ff 14 10 f0       	push   $0xf01014ff
f0101922:	e8 12 fc ff ff       	call   f0101539 <vprintfmt>

    /* Null terminate the buffer. */
    *b.buf = '\0';
f0101927:	8b 45 ec             	mov    -0x14(%ebp),%eax
f010192a:	c6 00 00             	movb   $0x0,(%eax)

    return b.cnt;
f010192d:	8b 45 f4             	mov    -0xc(%ebp),%eax
f0101930:	83 c4 10             	add    $0x10,%esp
f0101933:	eb 05                	jmp    f010193a <vsnprintf+0x4c>
int vsnprintf(char *buf, int n, const char *fmt, va_list ap)
{
    struct sprintbuf b = {buf, buf+n-1, 0};

    if (buf == NULL || n < 1)
        return -E_INVAL;
f0101935:	b8 fd ff ff ff       	mov    $0xfffffffd,%eax

    /* Null terminate the buffer. */
    *b.buf = '\0';

    return b.cnt;
}
f010193a:	c9                   	leave  
f010193b:	c3                   	ret    

f010193c <snprintf>:

int snprintf(char *buf, int n, const char *fmt, ...)
{
f010193c:	55                   	push   %ebp
f010193d:	89 e5                	mov    %esp,%ebp
f010193f:	83 ec 08             	sub    $0x8,%esp
    va_list ap;
    int rc;

    va_start(ap, fmt);
f0101942:	8d 45 14             	lea    0x14(%ebp),%eax
    rc = vsnprintf(buf, n, fmt, ap);
f0101945:	50                   	push   %eax
f0101946:	ff 75 10             	pushl  0x10(%ebp)
f0101949:	ff 75 0c             	pushl  0xc(%ebp)
f010194c:	ff 75 08             	pushl  0x8(%ebp)
f010194f:	e8 9a ff ff ff       	call   f01018ee <vsnprintf>
    va_end(ap);

    return rc;
}
f0101954:	c9                   	leave  
f0101955:	c3                   	ret    

f0101956 <readline>:

#define BUFLEN 1024
static char buf[BUFLEN];

char *readline(const char *prompt)
{
f0101956:	55                   	push   %ebp
f0101957:	89 e5                	mov    %esp,%ebp
f0101959:	57                   	push   %edi
f010195a:	56                   	push   %esi
f010195b:	53                   	push   %ebx
f010195c:	83 ec 0c             	sub    $0xc,%esp
f010195f:	8b 45 08             	mov    0x8(%ebp),%eax
    int i, c, echoing;

    if (prompt != NULL)
f0101962:	85 c0                	test   %eax,%eax
f0101964:	74 11                	je     f0101977 <readline+0x21>
        cprintf("%s", prompt);
f0101966:	83 ec 08             	sub    $0x8,%esp
f0101969:	50                   	push   %eax
f010196a:	68 88 26 10 f0       	push   $0xf0102688
f010196f:	e8 ce f6 ff ff       	call   f0101042 <cprintf>
f0101974:	83 c4 10             	add    $0x10,%esp

    i = 0;
    echoing = iscons(0);
f0101977:	83 ec 0c             	sub    $0xc,%esp
f010197a:	6a 00                	push   $0x0
f010197c:	e8 d3 ec ff ff       	call   f0100654 <iscons>
f0101981:	89 c7                	mov    %eax,%edi
f0101983:	83 c4 10             	add    $0x10,%esp
    int i, c, echoing;

    if (prompt != NULL)
        cprintf("%s", prompt);

    i = 0;
f0101986:	be 00 00 00 00       	mov    $0x0,%esi
    echoing = iscons(0);
    while (1) {
        c = getchar();
f010198b:	e8 b3 ec ff ff       	call   f0100643 <getchar>
f0101990:	89 c3                	mov    %eax,%ebx
        if (c < 0) {
f0101992:	85 c0                	test   %eax,%eax
f0101994:	79 18                	jns    f01019ae <readline+0x58>
            cprintf("read error: %e\n", c);
f0101996:	83 ec 08             	sub    $0x8,%esp
f0101999:	50                   	push   %eax
f010199a:	68 20 2b 10 f0       	push   $0xf0102b20
f010199f:	e8 9e f6 ff ff       	call   f0101042 <cprintf>
            return NULL;
f01019a4:	83 c4 10             	add    $0x10,%esp
f01019a7:	b8 00 00 00 00       	mov    $0x0,%eax
f01019ac:	eb 79                	jmp    f0101a27 <readline+0xd1>
        } else if ((c == '\b' || c == '\x7f') && i > 0) {
f01019ae:	83 f8 08             	cmp    $0x8,%eax
f01019b1:	0f 94 c2             	sete   %dl
f01019b4:	83 f8 7f             	cmp    $0x7f,%eax
f01019b7:	0f 94 c0             	sete   %al
f01019ba:	08 c2                	or     %al,%dl
f01019bc:	74 1a                	je     f01019d8 <readline+0x82>
f01019be:	85 f6                	test   %esi,%esi
f01019c0:	7e 16                	jle    f01019d8 <readline+0x82>
            if (echoing)
f01019c2:	85 ff                	test   %edi,%edi
f01019c4:	74 0d                	je     f01019d3 <readline+0x7d>
                cputchar('\b');
f01019c6:	83 ec 0c             	sub    $0xc,%esp
f01019c9:	6a 08                	push   $0x8
f01019cb:	e8 63 ec ff ff       	call   f0100633 <cputchar>
f01019d0:	83 c4 10             	add    $0x10,%esp
            i--;
f01019d3:	83 ee 01             	sub    $0x1,%esi
f01019d6:	eb b3                	jmp    f010198b <readline+0x35>
        } else if (c >= ' ' && i < BUFLEN-1) {
f01019d8:	83 fb 1f             	cmp    $0x1f,%ebx
f01019db:	7e 23                	jle    f0101a00 <readline+0xaa>
f01019dd:	81 fe fe 03 00 00    	cmp    $0x3fe,%esi
f01019e3:	7f 1b                	jg     f0101a00 <readline+0xaa>
            if (echoing)
f01019e5:	85 ff                	test   %edi,%edi
f01019e7:	74 0c                	je     f01019f5 <readline+0x9f>
                cputchar(c);
f01019e9:	83 ec 0c             	sub    $0xc,%esp
f01019ec:	53                   	push   %ebx
f01019ed:	e8 41 ec ff ff       	call   f0100633 <cputchar>
f01019f2:	83 c4 10             	add    $0x10,%esp
            buf[i++] = c;
f01019f5:	88 9e 60 45 11 f0    	mov    %bl,-0xfeebaa0(%esi)
f01019fb:	8d 76 01             	lea    0x1(%esi),%esi
f01019fe:	eb 8b                	jmp    f010198b <readline+0x35>
        } else if (c == '\n' || c == '\r') {
f0101a00:	83 fb 0a             	cmp    $0xa,%ebx
f0101a03:	74 05                	je     f0101a0a <readline+0xb4>
f0101a05:	83 fb 0d             	cmp    $0xd,%ebx
f0101a08:	75 81                	jne    f010198b <readline+0x35>
            if (echoing)
f0101a0a:	85 ff                	test   %edi,%edi
f0101a0c:	74 0d                	je     f0101a1b <readline+0xc5>
                cputchar('\n');
f0101a0e:	83 ec 0c             	sub    $0xc,%esp
f0101a11:	6a 0a                	push   $0xa
f0101a13:	e8 1b ec ff ff       	call   f0100633 <cputchar>
f0101a18:	83 c4 10             	add    $0x10,%esp
            buf[i] = 0;
f0101a1b:	c6 86 60 45 11 f0 00 	movb   $0x0,-0xfeebaa0(%esi)
            return buf;
f0101a22:	b8 60 45 11 f0       	mov    $0xf0114560,%eax
        }
    }
}
f0101a27:	8d 65 f4             	lea    -0xc(%ebp),%esp
f0101a2a:	5b                   	pop    %ebx
f0101a2b:	5e                   	pop    %esi
f0101a2c:	5f                   	pop    %edi
f0101a2d:	5d                   	pop    %ebp
f0101a2e:	c3                   	ret    

f0101a2f <strlen>:
 * Primespipe runs 3x faster this way.
 */
#define ASM 1

int strlen(const char *s)
{
f0101a2f:	55                   	push   %ebp
f0101a30:	89 e5                	mov    %esp,%ebp
f0101a32:	8b 55 08             	mov    0x8(%ebp),%edx
    int n;

    for (n = 0; *s != '\0'; s++)
f0101a35:	80 3a 00             	cmpb   $0x0,(%edx)
f0101a38:	74 10                	je     f0101a4a <strlen+0x1b>
f0101a3a:	b8 00 00 00 00       	mov    $0x0,%eax
        n++;
f0101a3f:	83 c0 01             	add    $0x1,%eax

int strlen(const char *s)
{
    int n;

    for (n = 0; *s != '\0'; s++)
f0101a42:	80 3c 02 00          	cmpb   $0x0,(%edx,%eax,1)
f0101a46:	75 f7                	jne    f0101a3f <strlen+0x10>
f0101a48:	eb 05                	jmp    f0101a4f <strlen+0x20>
f0101a4a:	b8 00 00 00 00       	mov    $0x0,%eax
        n++;
    return n;
}
f0101a4f:	5d                   	pop    %ebp
f0101a50:	c3                   	ret    

f0101a51 <strnlen>:

int strnlen(const char *s, size_t size)
{
f0101a51:	55                   	push   %ebp
f0101a52:	89 e5                	mov    %esp,%ebp
f0101a54:	53                   	push   %ebx
f0101a55:	8b 5d 08             	mov    0x8(%ebp),%ebx
f0101a58:	8b 4d 0c             	mov    0xc(%ebp),%ecx
    int n;

    for (n = 0; size > 0 && *s != '\0'; s++, size--)
f0101a5b:	85 c9                	test   %ecx,%ecx
f0101a5d:	74 1c                	je     f0101a7b <strnlen+0x2a>
f0101a5f:	80 3b 00             	cmpb   $0x0,(%ebx)
f0101a62:	74 1e                	je     f0101a82 <strnlen+0x31>
f0101a64:	ba 01 00 00 00       	mov    $0x1,%edx
        n++;
f0101a69:	89 d0                	mov    %edx,%eax

int strnlen(const char *s, size_t size)
{
    int n;

    for (n = 0; size > 0 && *s != '\0'; s++, size--)
f0101a6b:	39 ca                	cmp    %ecx,%edx
f0101a6d:	74 18                	je     f0101a87 <strnlen+0x36>
f0101a6f:	83 c2 01             	add    $0x1,%edx
f0101a72:	80 7c 13 ff 00       	cmpb   $0x0,-0x1(%ebx,%edx,1)
f0101a77:	75 f0                	jne    f0101a69 <strnlen+0x18>
f0101a79:	eb 0c                	jmp    f0101a87 <strnlen+0x36>
f0101a7b:	b8 00 00 00 00       	mov    $0x0,%eax
f0101a80:	eb 05                	jmp    f0101a87 <strnlen+0x36>
f0101a82:	b8 00 00 00 00       	mov    $0x0,%eax
        n++;
    return n;
}
f0101a87:	5b                   	pop    %ebx
f0101a88:	5d                   	pop    %ebp
f0101a89:	c3                   	ret    

f0101a8a <strcpy>:

char *strcpy(char *dst, const char *src)
{
f0101a8a:	55                   	push   %ebp
f0101a8b:	89 e5                	mov    %esp,%ebp
f0101a8d:	53                   	push   %ebx
f0101a8e:	8b 45 08             	mov    0x8(%ebp),%eax
f0101a91:	8b 4d 0c             	mov    0xc(%ebp),%ecx
    char *ret;

    ret = dst;
    while ((*dst++ = *src++) != '\0')
f0101a94:	89 c2                	mov    %eax,%edx
f0101a96:	83 c2 01             	add    $0x1,%edx
f0101a99:	83 c1 01             	add    $0x1,%ecx
f0101a9c:	0f b6 59 ff          	movzbl -0x1(%ecx),%ebx
f0101aa0:	88 5a ff             	mov    %bl,-0x1(%edx)
f0101aa3:	84 db                	test   %bl,%bl
f0101aa5:	75 ef                	jne    f0101a96 <strcpy+0xc>
        /* do nothing */;
    return ret;
}
f0101aa7:	5b                   	pop    %ebx
f0101aa8:	5d                   	pop    %ebp
f0101aa9:	c3                   	ret    

f0101aaa <strcat>:

char *strcat(char *dst, const char *src)
{
f0101aaa:	55                   	push   %ebp
f0101aab:	89 e5                	mov    %esp,%ebp
f0101aad:	53                   	push   %ebx
f0101aae:	8b 5d 08             	mov    0x8(%ebp),%ebx
    int len = strlen(dst);
f0101ab1:	53                   	push   %ebx
f0101ab2:	e8 78 ff ff ff       	call   f0101a2f <strlen>
f0101ab7:	83 c4 04             	add    $0x4,%esp
    strcpy(dst + len, src);
f0101aba:	ff 75 0c             	pushl  0xc(%ebp)
f0101abd:	01 d8                	add    %ebx,%eax
f0101abf:	50                   	push   %eax
f0101ac0:	e8 c5 ff ff ff       	call   f0101a8a <strcpy>
    return dst;
}
f0101ac5:	89 d8                	mov    %ebx,%eax
f0101ac7:	8b 5d fc             	mov    -0x4(%ebp),%ebx
f0101aca:	c9                   	leave  
f0101acb:	c3                   	ret    

f0101acc <strncpy>:

char *strncpy(char *dst, const char *src, size_t size) {
f0101acc:	55                   	push   %ebp
f0101acd:	89 e5                	mov    %esp,%ebp
f0101acf:	56                   	push   %esi
f0101ad0:	53                   	push   %ebx
f0101ad1:	8b 75 08             	mov    0x8(%ebp),%esi
f0101ad4:	8b 55 0c             	mov    0xc(%ebp),%edx
f0101ad7:	8b 5d 10             	mov    0x10(%ebp),%ebx
    size_t i;
    char *ret;

    ret = dst;
    for (i = 0; i < size; i++) {
f0101ada:	85 db                	test   %ebx,%ebx
f0101adc:	74 17                	je     f0101af5 <strncpy+0x29>
f0101ade:	01 f3                	add    %esi,%ebx
f0101ae0:	89 f1                	mov    %esi,%ecx
        *dst++ = *src;
f0101ae2:	83 c1 01             	add    $0x1,%ecx
f0101ae5:	0f b6 02             	movzbl (%edx),%eax
f0101ae8:	88 41 ff             	mov    %al,-0x1(%ecx)
        /* If strlen(src) < size, null-pad 'dst' out to 'size' chars. */
        if (*src != '\0')
            src++;
f0101aeb:	80 3a 01             	cmpb   $0x1,(%edx)
f0101aee:	83 da ff             	sbb    $0xffffffff,%edx
char *strncpy(char *dst, const char *src, size_t size) {
    size_t i;
    char *ret;

    ret = dst;
    for (i = 0; i < size; i++) {
f0101af1:	39 cb                	cmp    %ecx,%ebx
f0101af3:	75 ed                	jne    f0101ae2 <strncpy+0x16>
        /* If strlen(src) < size, null-pad 'dst' out to 'size' chars. */
        if (*src != '\0')
            src++;
    }
    return ret;
}
f0101af5:	89 f0                	mov    %esi,%eax
f0101af7:	5b                   	pop    %ebx
f0101af8:	5e                   	pop    %esi
f0101af9:	5d                   	pop    %ebp
f0101afa:	c3                   	ret    

f0101afb <strlcpy>:

size_t strlcpy(char *dst, const char *src, size_t size)
{
f0101afb:	55                   	push   %ebp
f0101afc:	89 e5                	mov    %esp,%ebp
f0101afe:	56                   	push   %esi
f0101aff:	53                   	push   %ebx
f0101b00:	8b 75 08             	mov    0x8(%ebp),%esi
f0101b03:	8b 5d 0c             	mov    0xc(%ebp),%ebx
f0101b06:	8b 55 10             	mov    0x10(%ebp),%edx
f0101b09:	89 f0                	mov    %esi,%eax
    char *dst_in;

    dst_in = dst;
    if (size > 0) {
f0101b0b:	85 d2                	test   %edx,%edx
f0101b0d:	74 35                	je     f0101b44 <strlcpy+0x49>
        while (--size > 0 && *src != '\0')
f0101b0f:	89 d0                	mov    %edx,%eax
f0101b11:	83 e8 01             	sub    $0x1,%eax
f0101b14:	74 25                	je     f0101b3b <strlcpy+0x40>
f0101b16:	0f b6 0b             	movzbl (%ebx),%ecx
f0101b19:	84 c9                	test   %cl,%cl
f0101b1b:	74 22                	je     f0101b3f <strlcpy+0x44>
f0101b1d:	8d 53 01             	lea    0x1(%ebx),%edx
f0101b20:	01 c3                	add    %eax,%ebx
f0101b22:	89 f0                	mov    %esi,%eax
            *dst++ = *src++;
f0101b24:	83 c0 01             	add    $0x1,%eax
f0101b27:	88 48 ff             	mov    %cl,-0x1(%eax)
{
    char *dst_in;

    dst_in = dst;
    if (size > 0) {
        while (--size > 0 && *src != '\0')
f0101b2a:	39 da                	cmp    %ebx,%edx
f0101b2c:	74 13                	je     f0101b41 <strlcpy+0x46>
f0101b2e:	83 c2 01             	add    $0x1,%edx
f0101b31:	0f b6 4a ff          	movzbl -0x1(%edx),%ecx
f0101b35:	84 c9                	test   %cl,%cl
f0101b37:	75 eb                	jne    f0101b24 <strlcpy+0x29>
f0101b39:	eb 06                	jmp    f0101b41 <strlcpy+0x46>
f0101b3b:	89 f0                	mov    %esi,%eax
f0101b3d:	eb 02                	jmp    f0101b41 <strlcpy+0x46>
f0101b3f:	89 f0                	mov    %esi,%eax
            *dst++ = *src++;
        *dst = '\0';
f0101b41:	c6 00 00             	movb   $0x0,(%eax)
    }
    return dst - dst_in;
f0101b44:	29 f0                	sub    %esi,%eax
}
f0101b46:	5b                   	pop    %ebx
f0101b47:	5e                   	pop    %esi
f0101b48:	5d                   	pop    %ebp
f0101b49:	c3                   	ret    

f0101b4a <strcmp>:

int strcmp(const char *p, const char *q)
{
f0101b4a:	55                   	push   %ebp
f0101b4b:	89 e5                	mov    %esp,%ebp
f0101b4d:	8b 4d 08             	mov    0x8(%ebp),%ecx
f0101b50:	8b 55 0c             	mov    0xc(%ebp),%edx
    while (*p && *p == *q)
f0101b53:	0f b6 01             	movzbl (%ecx),%eax
f0101b56:	84 c0                	test   %al,%al
f0101b58:	74 15                	je     f0101b6f <strcmp+0x25>
f0101b5a:	3a 02                	cmp    (%edx),%al
f0101b5c:	75 11                	jne    f0101b6f <strcmp+0x25>
        p++, q++;
f0101b5e:	83 c1 01             	add    $0x1,%ecx
f0101b61:	83 c2 01             	add    $0x1,%edx
    return dst - dst_in;
}

int strcmp(const char *p, const char *q)
{
    while (*p && *p == *q)
f0101b64:	0f b6 01             	movzbl (%ecx),%eax
f0101b67:	84 c0                	test   %al,%al
f0101b69:	74 04                	je     f0101b6f <strcmp+0x25>
f0101b6b:	3a 02                	cmp    (%edx),%al
f0101b6d:	74 ef                	je     f0101b5e <strcmp+0x14>
        p++, q++;
    return (int) ((unsigned char) *p - (unsigned char) *q);
f0101b6f:	0f b6 c0             	movzbl %al,%eax
f0101b72:	0f b6 12             	movzbl (%edx),%edx
f0101b75:	29 d0                	sub    %edx,%eax
}
f0101b77:	5d                   	pop    %ebp
f0101b78:	c3                   	ret    

f0101b79 <strncmp>:

int strncmp(const char *p, const char *q, size_t n)
{
f0101b79:	55                   	push   %ebp
f0101b7a:	89 e5                	mov    %esp,%ebp
f0101b7c:	56                   	push   %esi
f0101b7d:	53                   	push   %ebx
f0101b7e:	8b 5d 08             	mov    0x8(%ebp),%ebx
f0101b81:	8b 55 0c             	mov    0xc(%ebp),%edx
f0101b84:	8b 75 10             	mov    0x10(%ebp),%esi
    while (n > 0 && *p && *p == *q)
f0101b87:	85 f6                	test   %esi,%esi
f0101b89:	74 29                	je     f0101bb4 <strncmp+0x3b>
f0101b8b:	0f b6 03             	movzbl (%ebx),%eax
f0101b8e:	84 c0                	test   %al,%al
f0101b90:	74 30                	je     f0101bc2 <strncmp+0x49>
f0101b92:	3a 02                	cmp    (%edx),%al
f0101b94:	75 2c                	jne    f0101bc2 <strncmp+0x49>
f0101b96:	8d 43 01             	lea    0x1(%ebx),%eax
f0101b99:	01 de                	add    %ebx,%esi
        n--, p++, q++;
f0101b9b:	89 c3                	mov    %eax,%ebx
f0101b9d:	83 c2 01             	add    $0x1,%edx
    return (int) ((unsigned char) *p - (unsigned char) *q);
}

int strncmp(const char *p, const char *q, size_t n)
{
    while (n > 0 && *p && *p == *q)
f0101ba0:	39 c6                	cmp    %eax,%esi
f0101ba2:	74 17                	je     f0101bbb <strncmp+0x42>
f0101ba4:	0f b6 08             	movzbl (%eax),%ecx
f0101ba7:	84 c9                	test   %cl,%cl
f0101ba9:	74 17                	je     f0101bc2 <strncmp+0x49>
f0101bab:	83 c0 01             	add    $0x1,%eax
f0101bae:	3a 0a                	cmp    (%edx),%cl
f0101bb0:	74 e9                	je     f0101b9b <strncmp+0x22>
f0101bb2:	eb 0e                	jmp    f0101bc2 <strncmp+0x49>
        n--, p++, q++;
    if (n == 0)
        return 0;
f0101bb4:	b8 00 00 00 00       	mov    $0x0,%eax
f0101bb9:	eb 0f                	jmp    f0101bca <strncmp+0x51>
f0101bbb:	b8 00 00 00 00       	mov    $0x0,%eax
f0101bc0:	eb 08                	jmp    f0101bca <strncmp+0x51>
    else
        return (int) ((unsigned char) *p - (unsigned char) *q);
f0101bc2:	0f b6 03             	movzbl (%ebx),%eax
f0101bc5:	0f b6 12             	movzbl (%edx),%edx
f0101bc8:	29 d0                	sub    %edx,%eax
}
f0101bca:	5b                   	pop    %ebx
f0101bcb:	5e                   	pop    %esi
f0101bcc:	5d                   	pop    %ebp
f0101bcd:	c3                   	ret    

f0101bce <strchr>:
/*
 * Return a pointer to the first occurrence of 'c' in 's',
 * or a null pointer if the string has no 'c'.
 */
char *strchr(const char *s, char c)
{
f0101bce:	55                   	push   %ebp
f0101bcf:	89 e5                	mov    %esp,%ebp
f0101bd1:	53                   	push   %ebx
f0101bd2:	8b 45 08             	mov    0x8(%ebp),%eax
f0101bd5:	8b 5d 0c             	mov    0xc(%ebp),%ebx
    for (; *s; s++)
f0101bd8:	0f b6 10             	movzbl (%eax),%edx
f0101bdb:	84 d2                	test   %dl,%dl
f0101bdd:	74 1d                	je     f0101bfc <strchr+0x2e>
f0101bdf:	89 d9                	mov    %ebx,%ecx
        if (*s == c)
f0101be1:	38 d3                	cmp    %dl,%bl
f0101be3:	75 06                	jne    f0101beb <strchr+0x1d>
f0101be5:	eb 1a                	jmp    f0101c01 <strchr+0x33>
f0101be7:	38 ca                	cmp    %cl,%dl
f0101be9:	74 16                	je     f0101c01 <strchr+0x33>
 * Return a pointer to the first occurrence of 'c' in 's',
 * or a null pointer if the string has no 'c'.
 */
char *strchr(const char *s, char c)
{
    for (; *s; s++)
f0101beb:	83 c0 01             	add    $0x1,%eax
f0101bee:	0f b6 10             	movzbl (%eax),%edx
f0101bf1:	84 d2                	test   %dl,%dl
f0101bf3:	75 f2                	jne    f0101be7 <strchr+0x19>
        if (*s == c)
            return (char *) s;
    return 0;
f0101bf5:	b8 00 00 00 00       	mov    $0x0,%eax
f0101bfa:	eb 05                	jmp    f0101c01 <strchr+0x33>
f0101bfc:	b8 00 00 00 00       	mov    $0x0,%eax
}
f0101c01:	5b                   	pop    %ebx
f0101c02:	5d                   	pop    %ebp
f0101c03:	c3                   	ret    

f0101c04 <strfind>:
/*
 * Return a pointer to the first occurrence of 'c' in 's',
 * or a pointer to the string-ending null character if the string has no 'c'.
 */
char *strfind(const char *s, char c)
{
f0101c04:	55                   	push   %ebp
f0101c05:	89 e5                	mov    %esp,%ebp
f0101c07:	53                   	push   %ebx
f0101c08:	8b 45 08             	mov    0x8(%ebp),%eax
f0101c0b:	8b 55 0c             	mov    0xc(%ebp),%edx
    for (; *s; s++)
f0101c0e:	0f b6 18             	movzbl (%eax),%ebx
        if (*s == c)
f0101c11:	38 d3                	cmp    %dl,%bl
f0101c13:	74 14                	je     f0101c29 <strfind+0x25>
f0101c15:	89 d1                	mov    %edx,%ecx
f0101c17:	84 db                	test   %bl,%bl
f0101c19:	74 0e                	je     f0101c29 <strfind+0x25>
 * Return a pointer to the first occurrence of 'c' in 's',
 * or a pointer to the string-ending null character if the string has no 'c'.
 */
char *strfind(const char *s, char c)
{
    for (; *s; s++)
f0101c1b:	83 c0 01             	add    $0x1,%eax
f0101c1e:	0f b6 10             	movzbl (%eax),%edx
        if (*s == c)
f0101c21:	38 ca                	cmp    %cl,%dl
f0101c23:	74 04                	je     f0101c29 <strfind+0x25>
f0101c25:	84 d2                	test   %dl,%dl
f0101c27:	75 f2                	jne    f0101c1b <strfind+0x17>
            break;
    return (char *) s;
}
f0101c29:	5b                   	pop    %ebx
f0101c2a:	5d                   	pop    %ebp
f0101c2b:	c3                   	ret    

f0101c2c <memset>:

#if ASM
void *memset(void *v, int c, size_t n)
{
f0101c2c:	55                   	push   %ebp
f0101c2d:	89 e5                	mov    %esp,%ebp
f0101c2f:	57                   	push   %edi
f0101c30:	56                   	push   %esi
f0101c31:	53                   	push   %ebx
f0101c32:	8b 7d 08             	mov    0x8(%ebp),%edi
f0101c35:	8b 4d 10             	mov    0x10(%ebp),%ecx
    char *p;

    if (n == 0)
f0101c38:	85 c9                	test   %ecx,%ecx
f0101c3a:	74 36                	je     f0101c72 <memset+0x46>
        return v;
    if ((int)v%4 == 0 && n%4 == 0) {
f0101c3c:	f7 c7 03 00 00 00    	test   $0x3,%edi
f0101c42:	75 28                	jne    f0101c6c <memset+0x40>
f0101c44:	f6 c1 03             	test   $0x3,%cl
f0101c47:	75 23                	jne    f0101c6c <memset+0x40>
        c &= 0xFF;
f0101c49:	0f b6 55 0c          	movzbl 0xc(%ebp),%edx
        c = (c<<24)|(c<<16)|(c<<8)|c;
f0101c4d:	89 d3                	mov    %edx,%ebx
f0101c4f:	c1 e3 08             	shl    $0x8,%ebx
f0101c52:	89 d6                	mov    %edx,%esi
f0101c54:	c1 e6 18             	shl    $0x18,%esi
f0101c57:	89 d0                	mov    %edx,%eax
f0101c59:	c1 e0 10             	shl    $0x10,%eax
f0101c5c:	09 f0                	or     %esi,%eax
f0101c5e:	09 c2                	or     %eax,%edx
        asm volatile("cld; rep stosl\n"
f0101c60:	89 d8                	mov    %ebx,%eax
f0101c62:	09 d0                	or     %edx,%eax
f0101c64:	c1 e9 02             	shr    $0x2,%ecx
f0101c67:	fc                   	cld    
f0101c68:	f3 ab                	rep stos %eax,%es:(%edi)
f0101c6a:	eb 06                	jmp    f0101c72 <memset+0x46>
            :: "D" (v), "a" (c), "c" (n/4)
            : "cc", "memory");
    } else
        asm volatile("cld; rep stosb\n"
f0101c6c:	8b 45 0c             	mov    0xc(%ebp),%eax
f0101c6f:	fc                   	cld    
f0101c70:	f3 aa                	rep stos %al,%es:(%edi)
            :: "D" (v), "a" (c), "c" (n)
            : "cc", "memory");
    return v;
}
f0101c72:	89 f8                	mov    %edi,%eax
f0101c74:	5b                   	pop    %ebx
f0101c75:	5e                   	pop    %esi
f0101c76:	5f                   	pop    %edi
f0101c77:	5d                   	pop    %ebp
f0101c78:	c3                   	ret    

f0101c79 <memmove>:

void *memmove(void *dst, const void *src, size_t n)
{
f0101c79:	55                   	push   %ebp
f0101c7a:	89 e5                	mov    %esp,%ebp
f0101c7c:	57                   	push   %edi
f0101c7d:	56                   	push   %esi
f0101c7e:	8b 45 08             	mov    0x8(%ebp),%eax
f0101c81:	8b 75 0c             	mov    0xc(%ebp),%esi
f0101c84:	8b 4d 10             	mov    0x10(%ebp),%ecx
    const char *s;
    char *d;

    s = src;
    d = dst;
    if (s < d && s + n > d) {
f0101c87:	39 c6                	cmp    %eax,%esi
f0101c89:	73 35                	jae    f0101cc0 <memmove+0x47>
f0101c8b:	8d 14 0e             	lea    (%esi,%ecx,1),%edx
f0101c8e:	39 d0                	cmp    %edx,%eax
f0101c90:	73 2e                	jae    f0101cc0 <memmove+0x47>
        s += n;
        d += n;
f0101c92:	8d 3c 08             	lea    (%eax,%ecx,1),%edi
        if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
f0101c95:	89 d6                	mov    %edx,%esi
f0101c97:	09 fe                	or     %edi,%esi
f0101c99:	f7 c6 03 00 00 00    	test   $0x3,%esi
f0101c9f:	75 13                	jne    f0101cb4 <memmove+0x3b>
f0101ca1:	f6 c1 03             	test   $0x3,%cl
f0101ca4:	75 0e                	jne    f0101cb4 <memmove+0x3b>
            asm volatile("std; rep movsl\n"
f0101ca6:	83 ef 04             	sub    $0x4,%edi
f0101ca9:	8d 72 fc             	lea    -0x4(%edx),%esi
f0101cac:	c1 e9 02             	shr    $0x2,%ecx
f0101caf:	fd                   	std    
f0101cb0:	f3 a5                	rep movsl %ds:(%esi),%es:(%edi)
f0101cb2:	eb 09                	jmp    f0101cbd <memmove+0x44>
                :: "D" (d-4), "S" (s-4), "c" (n/4) : "cc", "memory");
        else
            asm volatile("std; rep movsb\n"
f0101cb4:	83 ef 01             	sub    $0x1,%edi
f0101cb7:	8d 72 ff             	lea    -0x1(%edx),%esi
f0101cba:	fd                   	std    
f0101cbb:	f3 a4                	rep movsb %ds:(%esi),%es:(%edi)
                :: "D" (d-1), "S" (s-1), "c" (n) : "cc", "memory");
        /* Some versions of GCC rely on DF being clear. */
        asm volatile("cld" ::: "cc");
f0101cbd:	fc                   	cld    
f0101cbe:	eb 1d                	jmp    f0101cdd <memmove+0x64>
    } else {
        if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
f0101cc0:	89 f2                	mov    %esi,%edx
f0101cc2:	09 c2                	or     %eax,%edx
f0101cc4:	f6 c2 03             	test   $0x3,%dl
f0101cc7:	75 0f                	jne    f0101cd8 <memmove+0x5f>
f0101cc9:	f6 c1 03             	test   $0x3,%cl
f0101ccc:	75 0a                	jne    f0101cd8 <memmove+0x5f>
            asm volatile("cld; rep movsl\n"
f0101cce:	c1 e9 02             	shr    $0x2,%ecx
f0101cd1:	89 c7                	mov    %eax,%edi
f0101cd3:	fc                   	cld    
f0101cd4:	f3 a5                	rep movsl %ds:(%esi),%es:(%edi)
f0101cd6:	eb 05                	jmp    f0101cdd <memmove+0x64>
                :: "D" (d), "S" (s), "c" (n/4) : "cc", "memory");
        else
            asm volatile("cld; rep movsb\n"
f0101cd8:	89 c7                	mov    %eax,%edi
f0101cda:	fc                   	cld    
f0101cdb:	f3 a4                	rep movsb %ds:(%esi),%es:(%edi)
                :: "D" (d), "S" (s), "c" (n) : "cc", "memory");
    }
    return dst;
}
f0101cdd:	5e                   	pop    %esi
f0101cde:	5f                   	pop    %edi
f0101cdf:	5d                   	pop    %ebp
f0101ce0:	c3                   	ret    

f0101ce1 <memcpy>:
    return dst;
}
#endif

void *memcpy(void *dst, const void *src, size_t n)
{
f0101ce1:	55                   	push   %ebp
f0101ce2:	89 e5                	mov    %esp,%ebp
    return memmove(dst, src, n);
f0101ce4:	ff 75 10             	pushl  0x10(%ebp)
f0101ce7:	ff 75 0c             	pushl  0xc(%ebp)
f0101cea:	ff 75 08             	pushl  0x8(%ebp)
f0101ced:	e8 87 ff ff ff       	call   f0101c79 <memmove>
}
f0101cf2:	c9                   	leave  
f0101cf3:	c3                   	ret    

f0101cf4 <memcmp>:

int memcmp(const void *v1, const void *v2, size_t n)
{
f0101cf4:	55                   	push   %ebp
f0101cf5:	89 e5                	mov    %esp,%ebp
f0101cf7:	57                   	push   %edi
f0101cf8:	56                   	push   %esi
f0101cf9:	53                   	push   %ebx
f0101cfa:	8b 5d 08             	mov    0x8(%ebp),%ebx
f0101cfd:	8b 75 0c             	mov    0xc(%ebp),%esi
f0101d00:	8b 45 10             	mov    0x10(%ebp),%eax
    const uint8_t *s1 = (const uint8_t *) v1;
    const uint8_t *s2 = (const uint8_t *) v2;

    while (n-- > 0) {
f0101d03:	85 c0                	test   %eax,%eax
f0101d05:	74 39                	je     f0101d40 <memcmp+0x4c>
f0101d07:	8d 78 ff             	lea    -0x1(%eax),%edi
        if (*s1 != *s2)
f0101d0a:	0f b6 13             	movzbl (%ebx),%edx
f0101d0d:	0f b6 0e             	movzbl (%esi),%ecx
f0101d10:	38 ca                	cmp    %cl,%dl
f0101d12:	75 17                	jne    f0101d2b <memcmp+0x37>
f0101d14:	b8 00 00 00 00       	mov    $0x0,%eax
f0101d19:	eb 1a                	jmp    f0101d35 <memcmp+0x41>
f0101d1b:	0f b6 54 03 01       	movzbl 0x1(%ebx,%eax,1),%edx
f0101d20:	83 c0 01             	add    $0x1,%eax
f0101d23:	0f b6 0c 06          	movzbl (%esi,%eax,1),%ecx
f0101d27:	38 ca                	cmp    %cl,%dl
f0101d29:	74 0a                	je     f0101d35 <memcmp+0x41>
            return (int) *s1 - (int) *s2;
f0101d2b:	0f b6 c2             	movzbl %dl,%eax
f0101d2e:	0f b6 c9             	movzbl %cl,%ecx
f0101d31:	29 c8                	sub    %ecx,%eax
f0101d33:	eb 10                	jmp    f0101d45 <memcmp+0x51>
int memcmp(const void *v1, const void *v2, size_t n)
{
    const uint8_t *s1 = (const uint8_t *) v1;
    const uint8_t *s2 = (const uint8_t *) v2;

    while (n-- > 0) {
f0101d35:	39 f8                	cmp    %edi,%eax
f0101d37:	75 e2                	jne    f0101d1b <memcmp+0x27>
        if (*s1 != *s2)
            return (int) *s1 - (int) *s2;
        s1++, s2++;
    }

    return 0;
f0101d39:	b8 00 00 00 00       	mov    $0x0,%eax
f0101d3e:	eb 05                	jmp    f0101d45 <memcmp+0x51>
f0101d40:	b8 00 00 00 00       	mov    $0x0,%eax
}
f0101d45:	5b                   	pop    %ebx
f0101d46:	5e                   	pop    %esi
f0101d47:	5f                   	pop    %edi
f0101d48:	5d                   	pop    %ebp
f0101d49:	c3                   	ret    

f0101d4a <memfind>:

void *memfind(const void *s, int c, size_t n)
{
f0101d4a:	55                   	push   %ebp
f0101d4b:	89 e5                	mov    %esp,%ebp
f0101d4d:	53                   	push   %ebx
f0101d4e:	8b 55 08             	mov    0x8(%ebp),%edx
    const void *ends = (const char *) s + n;
f0101d51:	89 d0                	mov    %edx,%eax
f0101d53:	03 45 10             	add    0x10(%ebp),%eax
    for (; s < ends; s++)
f0101d56:	39 c2                	cmp    %eax,%edx
f0101d58:	73 1d                	jae    f0101d77 <memfind+0x2d>
        if (*(const unsigned char *) s == (unsigned char) c)
f0101d5a:	0f b6 5d 0c          	movzbl 0xc(%ebp),%ebx
f0101d5e:	0f b6 0a             	movzbl (%edx),%ecx
f0101d61:	39 d9                	cmp    %ebx,%ecx
f0101d63:	75 09                	jne    f0101d6e <memfind+0x24>
f0101d65:	eb 14                	jmp    f0101d7b <memfind+0x31>
f0101d67:	0f b6 0a             	movzbl (%edx),%ecx
f0101d6a:	39 d9                	cmp    %ebx,%ecx
f0101d6c:	74 11                	je     f0101d7f <memfind+0x35>
}

void *memfind(const void *s, int c, size_t n)
{
    const void *ends = (const char *) s + n;
    for (; s < ends; s++)
f0101d6e:	83 c2 01             	add    $0x1,%edx
f0101d71:	39 d0                	cmp    %edx,%eax
f0101d73:	75 f2                	jne    f0101d67 <memfind+0x1d>
f0101d75:	eb 0a                	jmp    f0101d81 <memfind+0x37>
f0101d77:	89 d0                	mov    %edx,%eax
f0101d79:	eb 06                	jmp    f0101d81 <memfind+0x37>
        if (*(const unsigned char *) s == (unsigned char) c)
f0101d7b:	89 d0                	mov    %edx,%eax
f0101d7d:	eb 02                	jmp    f0101d81 <memfind+0x37>
}

void *memfind(const void *s, int c, size_t n)
{
    const void *ends = (const char *) s + n;
    for (; s < ends; s++)
f0101d7f:	89 d0                	mov    %edx,%eax
        if (*(const unsigned char *) s == (unsigned char) c)
            break;
    return (void *) s;
}
f0101d81:	5b                   	pop    %ebx
f0101d82:	5d                   	pop    %ebp
f0101d83:	c3                   	ret    

f0101d84 <strtol>:

long strtol(const char *s, char **endptr, int base)
{
f0101d84:	55                   	push   %ebp
f0101d85:	89 e5                	mov    %esp,%ebp
f0101d87:	57                   	push   %edi
f0101d88:	56                   	push   %esi
f0101d89:	53                   	push   %ebx
f0101d8a:	8b 4d 08             	mov    0x8(%ebp),%ecx
f0101d8d:	8b 5d 10             	mov    0x10(%ebp),%ebx
    int neg = 0;
    long val = 0;

    /* gobble initial whitespace */
    while (*s == ' ' || *s == '\t')
f0101d90:	0f b6 01             	movzbl (%ecx),%eax
f0101d93:	3c 20                	cmp    $0x20,%al
f0101d95:	74 04                	je     f0101d9b <strtol+0x17>
f0101d97:	3c 09                	cmp    $0x9,%al
f0101d99:	75 0e                	jne    f0101da9 <strtol+0x25>
        s++;
f0101d9b:	83 c1 01             	add    $0x1,%ecx
{
    int neg = 0;
    long val = 0;

    /* gobble initial whitespace */
    while (*s == ' ' || *s == '\t')
f0101d9e:	0f b6 01             	movzbl (%ecx),%eax
f0101da1:	3c 20                	cmp    $0x20,%al
f0101da3:	74 f6                	je     f0101d9b <strtol+0x17>
f0101da5:	3c 09                	cmp    $0x9,%al
f0101da7:	74 f2                	je     f0101d9b <strtol+0x17>
        s++;

    /* plus/minus sign */
    if (*s == '+')
f0101da9:	3c 2b                	cmp    $0x2b,%al
f0101dab:	75 0a                	jne    f0101db7 <strtol+0x33>
        s++;
f0101dad:	83 c1 01             	add    $0x1,%ecx
    return (void *) s;
}

long strtol(const char *s, char **endptr, int base)
{
    int neg = 0;
f0101db0:	bf 00 00 00 00       	mov    $0x0,%edi
f0101db5:	eb 11                	jmp    f0101dc8 <strtol+0x44>
f0101db7:	bf 00 00 00 00       	mov    $0x0,%edi
        s++;

    /* plus/minus sign */
    if (*s == '+')
        s++;
    else if (*s == '-')
f0101dbc:	3c 2d                	cmp    $0x2d,%al
f0101dbe:	75 08                	jne    f0101dc8 <strtol+0x44>
        s++, neg = 1;
f0101dc0:	83 c1 01             	add    $0x1,%ecx
f0101dc3:	bf 01 00 00 00       	mov    $0x1,%edi

    /* hex or octal base prefix */
    if ((base == 0 || base == 16) && (s[0] == '0' && s[1] == 'x'))
f0101dc8:	f7 c3 ef ff ff ff    	test   $0xffffffef,%ebx
f0101dce:	75 15                	jne    f0101de5 <strtol+0x61>
f0101dd0:	80 39 30             	cmpb   $0x30,(%ecx)
f0101dd3:	75 10                	jne    f0101de5 <strtol+0x61>
f0101dd5:	80 79 01 78          	cmpb   $0x78,0x1(%ecx)
f0101dd9:	75 7c                	jne    f0101e57 <strtol+0xd3>
        s += 2, base = 16;
f0101ddb:	83 c1 02             	add    $0x2,%ecx
f0101dde:	bb 10 00 00 00       	mov    $0x10,%ebx
f0101de3:	eb 16                	jmp    f0101dfb <strtol+0x77>
    else if (base == 0 && s[0] == '0')
f0101de5:	85 db                	test   %ebx,%ebx
f0101de7:	75 12                	jne    f0101dfb <strtol+0x77>
        s++, base = 8;
    else if (base == 0)
        base = 10;
f0101de9:	bb 0a 00 00 00       	mov    $0xa,%ebx
        s++, neg = 1;

    /* hex or octal base prefix */
    if ((base == 0 || base == 16) && (s[0] == '0' && s[1] == 'x'))
        s += 2, base = 16;
    else if (base == 0 && s[0] == '0')
f0101dee:	80 39 30             	cmpb   $0x30,(%ecx)
f0101df1:	75 08                	jne    f0101dfb <strtol+0x77>
        s++, base = 8;
f0101df3:	83 c1 01             	add    $0x1,%ecx
f0101df6:	bb 08 00 00 00       	mov    $0x8,%ebx
    else if (base == 0)
        base = 10;
f0101dfb:	b8 00 00 00 00       	mov    $0x0,%eax
f0101e00:	89 5d 10             	mov    %ebx,0x10(%ebp)

    /* digits */
    while (1) {
        int dig;

        if (*s >= '0' && *s <= '9')
f0101e03:	0f b6 11             	movzbl (%ecx),%edx
f0101e06:	8d 72 d0             	lea    -0x30(%edx),%esi
f0101e09:	89 f3                	mov    %esi,%ebx
f0101e0b:	80 fb 09             	cmp    $0x9,%bl
f0101e0e:	77 08                	ja     f0101e18 <strtol+0x94>
            dig = *s - '0';
f0101e10:	0f be d2             	movsbl %dl,%edx
f0101e13:	83 ea 30             	sub    $0x30,%edx
f0101e16:	eb 22                	jmp    f0101e3a <strtol+0xb6>
        else if (*s >= 'a' && *s <= 'z')
f0101e18:	8d 72 9f             	lea    -0x61(%edx),%esi
f0101e1b:	89 f3                	mov    %esi,%ebx
f0101e1d:	80 fb 19             	cmp    $0x19,%bl
f0101e20:	77 08                	ja     f0101e2a <strtol+0xa6>
            dig = *s - 'a' + 10;
f0101e22:	0f be d2             	movsbl %dl,%edx
f0101e25:	83 ea 57             	sub    $0x57,%edx
f0101e28:	eb 10                	jmp    f0101e3a <strtol+0xb6>
        else if (*s >= 'A' && *s <= 'Z')
f0101e2a:	8d 72 bf             	lea    -0x41(%edx),%esi
f0101e2d:	89 f3                	mov    %esi,%ebx
f0101e2f:	80 fb 19             	cmp    $0x19,%bl
f0101e32:	77 16                	ja     f0101e4a <strtol+0xc6>
            dig = *s - 'A' + 10;
f0101e34:	0f be d2             	movsbl %dl,%edx
f0101e37:	83 ea 37             	sub    $0x37,%edx
        else
            break;
        if (dig >= base)
f0101e3a:	3b 55 10             	cmp    0x10(%ebp),%edx
f0101e3d:	7d 0b                	jge    f0101e4a <strtol+0xc6>
            break;
        s++, val = (val * base) + dig;
f0101e3f:	83 c1 01             	add    $0x1,%ecx
f0101e42:	0f af 45 10          	imul   0x10(%ebp),%eax
f0101e46:	01 d0                	add    %edx,%eax
        /* we don't properly detect overflow! */
    }
f0101e48:	eb b9                	jmp    f0101e03 <strtol+0x7f>

    if (endptr)
f0101e4a:	83 7d 0c 00          	cmpl   $0x0,0xc(%ebp)
f0101e4e:	74 0d                	je     f0101e5d <strtol+0xd9>
        *endptr = (char *) s;
f0101e50:	8b 75 0c             	mov    0xc(%ebp),%esi
f0101e53:	89 0e                	mov    %ecx,(%esi)
f0101e55:	eb 06                	jmp    f0101e5d <strtol+0xd9>
        s++, neg = 1;

    /* hex or octal base prefix */
    if ((base == 0 || base == 16) && (s[0] == '0' && s[1] == 'x'))
        s += 2, base = 16;
    else if (base == 0 && s[0] == '0')
f0101e57:	85 db                	test   %ebx,%ebx
f0101e59:	74 98                	je     f0101df3 <strtol+0x6f>
f0101e5b:	eb 9e                	jmp    f0101dfb <strtol+0x77>
        /* we don't properly detect overflow! */
    }

    if (endptr)
        *endptr = (char *) s;
    return (neg ? -val : val);
f0101e5d:	89 c2                	mov    %eax,%edx
f0101e5f:	f7 da                	neg    %edx
f0101e61:	85 ff                	test   %edi,%edi
f0101e63:	0f 45 c2             	cmovne %edx,%eax
}
f0101e66:	5b                   	pop    %ebx
f0101e67:	5e                   	pop    %esi
f0101e68:	5f                   	pop    %edi
f0101e69:	5d                   	pop    %ebp
f0101e6a:	c3                   	ret    
f0101e6b:	66 90                	xchg   %ax,%ax
f0101e6d:	66 90                	xchg   %ax,%ax
f0101e6f:	90                   	nop

f0101e70 <__udivdi3>:
f0101e70:	55                   	push   %ebp
f0101e71:	57                   	push   %edi
f0101e72:	56                   	push   %esi
f0101e73:	53                   	push   %ebx
f0101e74:	83 ec 1c             	sub    $0x1c,%esp
f0101e77:	8b 74 24 3c          	mov    0x3c(%esp),%esi
f0101e7b:	8b 5c 24 30          	mov    0x30(%esp),%ebx
f0101e7f:	8b 4c 24 34          	mov    0x34(%esp),%ecx
f0101e83:	8b 7c 24 38          	mov    0x38(%esp),%edi
f0101e87:	85 f6                	test   %esi,%esi
f0101e89:	89 5c 24 08          	mov    %ebx,0x8(%esp)
f0101e8d:	89 ca                	mov    %ecx,%edx
f0101e8f:	89 f8                	mov    %edi,%eax
f0101e91:	75 3d                	jne    f0101ed0 <__udivdi3+0x60>
f0101e93:	39 cf                	cmp    %ecx,%edi
f0101e95:	0f 87 c5 00 00 00    	ja     f0101f60 <__udivdi3+0xf0>
f0101e9b:	85 ff                	test   %edi,%edi
f0101e9d:	89 fd                	mov    %edi,%ebp
f0101e9f:	75 0b                	jne    f0101eac <__udivdi3+0x3c>
f0101ea1:	b8 01 00 00 00       	mov    $0x1,%eax
f0101ea6:	31 d2                	xor    %edx,%edx
f0101ea8:	f7 f7                	div    %edi
f0101eaa:	89 c5                	mov    %eax,%ebp
f0101eac:	89 c8                	mov    %ecx,%eax
f0101eae:	31 d2                	xor    %edx,%edx
f0101eb0:	f7 f5                	div    %ebp
f0101eb2:	89 c1                	mov    %eax,%ecx
f0101eb4:	89 d8                	mov    %ebx,%eax
f0101eb6:	89 cf                	mov    %ecx,%edi
f0101eb8:	f7 f5                	div    %ebp
f0101eba:	89 c3                	mov    %eax,%ebx
f0101ebc:	89 d8                	mov    %ebx,%eax
f0101ebe:	89 fa                	mov    %edi,%edx
f0101ec0:	83 c4 1c             	add    $0x1c,%esp
f0101ec3:	5b                   	pop    %ebx
f0101ec4:	5e                   	pop    %esi
f0101ec5:	5f                   	pop    %edi
f0101ec6:	5d                   	pop    %ebp
f0101ec7:	c3                   	ret    
f0101ec8:	90                   	nop
f0101ec9:	8d b4 26 00 00 00 00 	lea    0x0(%esi,%eiz,1),%esi
f0101ed0:	39 ce                	cmp    %ecx,%esi
f0101ed2:	77 74                	ja     f0101f48 <__udivdi3+0xd8>
f0101ed4:	0f bd fe             	bsr    %esi,%edi
f0101ed7:	83 f7 1f             	xor    $0x1f,%edi
f0101eda:	0f 84 98 00 00 00    	je     f0101f78 <__udivdi3+0x108>
f0101ee0:	bb 20 00 00 00       	mov    $0x20,%ebx
f0101ee5:	89 f9                	mov    %edi,%ecx
f0101ee7:	89 c5                	mov    %eax,%ebp
f0101ee9:	29 fb                	sub    %edi,%ebx
f0101eeb:	d3 e6                	shl    %cl,%esi
f0101eed:	89 d9                	mov    %ebx,%ecx
f0101eef:	d3 ed                	shr    %cl,%ebp
f0101ef1:	89 f9                	mov    %edi,%ecx
f0101ef3:	d3 e0                	shl    %cl,%eax
f0101ef5:	09 ee                	or     %ebp,%esi
f0101ef7:	89 d9                	mov    %ebx,%ecx
f0101ef9:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0101efd:	89 d5                	mov    %edx,%ebp
f0101eff:	8b 44 24 08          	mov    0x8(%esp),%eax
f0101f03:	d3 ed                	shr    %cl,%ebp
f0101f05:	89 f9                	mov    %edi,%ecx
f0101f07:	d3 e2                	shl    %cl,%edx
f0101f09:	89 d9                	mov    %ebx,%ecx
f0101f0b:	d3 e8                	shr    %cl,%eax
f0101f0d:	09 c2                	or     %eax,%edx
f0101f0f:	89 d0                	mov    %edx,%eax
f0101f11:	89 ea                	mov    %ebp,%edx
f0101f13:	f7 f6                	div    %esi
f0101f15:	89 d5                	mov    %edx,%ebp
f0101f17:	89 c3                	mov    %eax,%ebx
f0101f19:	f7 64 24 0c          	mull   0xc(%esp)
f0101f1d:	39 d5                	cmp    %edx,%ebp
f0101f1f:	72 10                	jb     f0101f31 <__udivdi3+0xc1>
f0101f21:	8b 74 24 08          	mov    0x8(%esp),%esi
f0101f25:	89 f9                	mov    %edi,%ecx
f0101f27:	d3 e6                	shl    %cl,%esi
f0101f29:	39 c6                	cmp    %eax,%esi
f0101f2b:	73 07                	jae    f0101f34 <__udivdi3+0xc4>
f0101f2d:	39 d5                	cmp    %edx,%ebp
f0101f2f:	75 03                	jne    f0101f34 <__udivdi3+0xc4>
f0101f31:	83 eb 01             	sub    $0x1,%ebx
f0101f34:	31 ff                	xor    %edi,%edi
f0101f36:	89 d8                	mov    %ebx,%eax
f0101f38:	89 fa                	mov    %edi,%edx
f0101f3a:	83 c4 1c             	add    $0x1c,%esp
f0101f3d:	5b                   	pop    %ebx
f0101f3e:	5e                   	pop    %esi
f0101f3f:	5f                   	pop    %edi
f0101f40:	5d                   	pop    %ebp
f0101f41:	c3                   	ret    
f0101f42:	8d b6 00 00 00 00    	lea    0x0(%esi),%esi
f0101f48:	31 ff                	xor    %edi,%edi
f0101f4a:	31 db                	xor    %ebx,%ebx
f0101f4c:	89 d8                	mov    %ebx,%eax
f0101f4e:	89 fa                	mov    %edi,%edx
f0101f50:	83 c4 1c             	add    $0x1c,%esp
f0101f53:	5b                   	pop    %ebx
f0101f54:	5e                   	pop    %esi
f0101f55:	5f                   	pop    %edi
f0101f56:	5d                   	pop    %ebp
f0101f57:	c3                   	ret    
f0101f58:	90                   	nop
f0101f59:	8d b4 26 00 00 00 00 	lea    0x0(%esi,%eiz,1),%esi
f0101f60:	89 d8                	mov    %ebx,%eax
f0101f62:	f7 f7                	div    %edi
f0101f64:	31 ff                	xor    %edi,%edi
f0101f66:	89 c3                	mov    %eax,%ebx
f0101f68:	89 d8                	mov    %ebx,%eax
f0101f6a:	89 fa                	mov    %edi,%edx
f0101f6c:	83 c4 1c             	add    $0x1c,%esp
f0101f6f:	5b                   	pop    %ebx
f0101f70:	5e                   	pop    %esi
f0101f71:	5f                   	pop    %edi
f0101f72:	5d                   	pop    %ebp
f0101f73:	c3                   	ret    
f0101f74:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0101f78:	39 ce                	cmp    %ecx,%esi
f0101f7a:	72 0c                	jb     f0101f88 <__udivdi3+0x118>
f0101f7c:	31 db                	xor    %ebx,%ebx
f0101f7e:	3b 44 24 08          	cmp    0x8(%esp),%eax
f0101f82:	0f 87 34 ff ff ff    	ja     f0101ebc <__udivdi3+0x4c>
f0101f88:	bb 01 00 00 00       	mov    $0x1,%ebx
f0101f8d:	e9 2a ff ff ff       	jmp    f0101ebc <__udivdi3+0x4c>
f0101f92:	66 90                	xchg   %ax,%ax
f0101f94:	66 90                	xchg   %ax,%ax
f0101f96:	66 90                	xchg   %ax,%ax
f0101f98:	66 90                	xchg   %ax,%ax
f0101f9a:	66 90                	xchg   %ax,%ax
f0101f9c:	66 90                	xchg   %ax,%ax
f0101f9e:	66 90                	xchg   %ax,%ax

f0101fa0 <__umoddi3>:
f0101fa0:	55                   	push   %ebp
f0101fa1:	57                   	push   %edi
f0101fa2:	56                   	push   %esi
f0101fa3:	53                   	push   %ebx
f0101fa4:	83 ec 1c             	sub    $0x1c,%esp
f0101fa7:	8b 54 24 3c          	mov    0x3c(%esp),%edx
f0101fab:	8b 4c 24 30          	mov    0x30(%esp),%ecx
f0101faf:	8b 74 24 34          	mov    0x34(%esp),%esi
f0101fb3:	8b 7c 24 38          	mov    0x38(%esp),%edi
f0101fb7:	85 d2                	test   %edx,%edx
f0101fb9:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
f0101fbd:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f0101fc1:	89 f3                	mov    %esi,%ebx
f0101fc3:	89 3c 24             	mov    %edi,(%esp)
f0101fc6:	89 74 24 04          	mov    %esi,0x4(%esp)
f0101fca:	75 1c                	jne    f0101fe8 <__umoddi3+0x48>
f0101fcc:	39 f7                	cmp    %esi,%edi
f0101fce:	76 50                	jbe    f0102020 <__umoddi3+0x80>
f0101fd0:	89 c8                	mov    %ecx,%eax
f0101fd2:	89 f2                	mov    %esi,%edx
f0101fd4:	f7 f7                	div    %edi
f0101fd6:	89 d0                	mov    %edx,%eax
f0101fd8:	31 d2                	xor    %edx,%edx
f0101fda:	83 c4 1c             	add    $0x1c,%esp
f0101fdd:	5b                   	pop    %ebx
f0101fde:	5e                   	pop    %esi
f0101fdf:	5f                   	pop    %edi
f0101fe0:	5d                   	pop    %ebp
f0101fe1:	c3                   	ret    
f0101fe2:	8d b6 00 00 00 00    	lea    0x0(%esi),%esi
f0101fe8:	39 f2                	cmp    %esi,%edx
f0101fea:	89 d0                	mov    %edx,%eax
f0101fec:	77 52                	ja     f0102040 <__umoddi3+0xa0>
f0101fee:	0f bd ea             	bsr    %edx,%ebp
f0101ff1:	83 f5 1f             	xor    $0x1f,%ebp
f0101ff4:	75 5a                	jne    f0102050 <__umoddi3+0xb0>
f0101ff6:	3b 54 24 04          	cmp    0x4(%esp),%edx
f0101ffa:	0f 82 e0 00 00 00    	jb     f01020e0 <__umoddi3+0x140>
f0102000:	39 0c 24             	cmp    %ecx,(%esp)
f0102003:	0f 86 d7 00 00 00    	jbe    f01020e0 <__umoddi3+0x140>
f0102009:	8b 44 24 08          	mov    0x8(%esp),%eax
f010200d:	8b 54 24 04          	mov    0x4(%esp),%edx
f0102011:	83 c4 1c             	add    $0x1c,%esp
f0102014:	5b                   	pop    %ebx
f0102015:	5e                   	pop    %esi
f0102016:	5f                   	pop    %edi
f0102017:	5d                   	pop    %ebp
f0102018:	c3                   	ret    
f0102019:	8d b4 26 00 00 00 00 	lea    0x0(%esi,%eiz,1),%esi
f0102020:	85 ff                	test   %edi,%edi
f0102022:	89 fd                	mov    %edi,%ebp
f0102024:	75 0b                	jne    f0102031 <__umoddi3+0x91>
f0102026:	b8 01 00 00 00       	mov    $0x1,%eax
f010202b:	31 d2                	xor    %edx,%edx
f010202d:	f7 f7                	div    %edi
f010202f:	89 c5                	mov    %eax,%ebp
f0102031:	89 f0                	mov    %esi,%eax
f0102033:	31 d2                	xor    %edx,%edx
f0102035:	f7 f5                	div    %ebp
f0102037:	89 c8                	mov    %ecx,%eax
f0102039:	f7 f5                	div    %ebp
f010203b:	89 d0                	mov    %edx,%eax
f010203d:	eb 99                	jmp    f0101fd8 <__umoddi3+0x38>
f010203f:	90                   	nop
f0102040:	89 c8                	mov    %ecx,%eax
f0102042:	89 f2                	mov    %esi,%edx
f0102044:	83 c4 1c             	add    $0x1c,%esp
f0102047:	5b                   	pop    %ebx
f0102048:	5e                   	pop    %esi
f0102049:	5f                   	pop    %edi
f010204a:	5d                   	pop    %ebp
f010204b:	c3                   	ret    
f010204c:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0102050:	8b 34 24             	mov    (%esp),%esi
f0102053:	bf 20 00 00 00       	mov    $0x20,%edi
f0102058:	89 e9                	mov    %ebp,%ecx
f010205a:	29 ef                	sub    %ebp,%edi
f010205c:	d3 e0                	shl    %cl,%eax
f010205e:	89 f9                	mov    %edi,%ecx
f0102060:	89 f2                	mov    %esi,%edx
f0102062:	d3 ea                	shr    %cl,%edx
f0102064:	89 e9                	mov    %ebp,%ecx
f0102066:	09 c2                	or     %eax,%edx
f0102068:	89 d8                	mov    %ebx,%eax
f010206a:	89 14 24             	mov    %edx,(%esp)
f010206d:	89 f2                	mov    %esi,%edx
f010206f:	d3 e2                	shl    %cl,%edx
f0102071:	89 f9                	mov    %edi,%ecx
f0102073:	89 54 24 04          	mov    %edx,0x4(%esp)
f0102077:	8b 54 24 0c          	mov    0xc(%esp),%edx
f010207b:	d3 e8                	shr    %cl,%eax
f010207d:	89 e9                	mov    %ebp,%ecx
f010207f:	89 c6                	mov    %eax,%esi
f0102081:	d3 e3                	shl    %cl,%ebx
f0102083:	89 f9                	mov    %edi,%ecx
f0102085:	89 d0                	mov    %edx,%eax
f0102087:	d3 e8                	shr    %cl,%eax
f0102089:	89 e9                	mov    %ebp,%ecx
f010208b:	09 d8                	or     %ebx,%eax
f010208d:	89 d3                	mov    %edx,%ebx
f010208f:	89 f2                	mov    %esi,%edx
f0102091:	f7 34 24             	divl   (%esp)
f0102094:	89 d6                	mov    %edx,%esi
f0102096:	d3 e3                	shl    %cl,%ebx
f0102098:	f7 64 24 04          	mull   0x4(%esp)
f010209c:	39 d6                	cmp    %edx,%esi
f010209e:	89 5c 24 08          	mov    %ebx,0x8(%esp)
f01020a2:	89 d1                	mov    %edx,%ecx
f01020a4:	89 c3                	mov    %eax,%ebx
f01020a6:	72 08                	jb     f01020b0 <__umoddi3+0x110>
f01020a8:	75 11                	jne    f01020bb <__umoddi3+0x11b>
f01020aa:	39 44 24 08          	cmp    %eax,0x8(%esp)
f01020ae:	73 0b                	jae    f01020bb <__umoddi3+0x11b>
f01020b0:	2b 44 24 04          	sub    0x4(%esp),%eax
f01020b4:	1b 14 24             	sbb    (%esp),%edx
f01020b7:	89 d1                	mov    %edx,%ecx
f01020b9:	89 c3                	mov    %eax,%ebx
f01020bb:	8b 54 24 08          	mov    0x8(%esp),%edx
f01020bf:	29 da                	sub    %ebx,%edx
f01020c1:	19 ce                	sbb    %ecx,%esi
f01020c3:	89 f9                	mov    %edi,%ecx
f01020c5:	89 f0                	mov    %esi,%eax
f01020c7:	d3 e0                	shl    %cl,%eax
f01020c9:	89 e9                	mov    %ebp,%ecx
f01020cb:	d3 ea                	shr    %cl,%edx
f01020cd:	89 e9                	mov    %ebp,%ecx
f01020cf:	d3 ee                	shr    %cl,%esi
f01020d1:	09 d0                	or     %edx,%eax
f01020d3:	89 f2                	mov    %esi,%edx
f01020d5:	83 c4 1c             	add    $0x1c,%esp
f01020d8:	5b                   	pop    %ebx
f01020d9:	5e                   	pop    %esi
f01020da:	5f                   	pop    %edi
f01020db:	5d                   	pop    %ebp
f01020dc:	c3                   	ret    
f01020dd:	8d 76 00             	lea    0x0(%esi),%esi
f01020e0:	29 f9                	sub    %edi,%ecx
f01020e2:	19 d6                	sbb    %edx,%esi
f01020e4:	89 74 24 04          	mov    %esi,0x4(%esp)
f01020e8:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f01020ec:	e9 18 ff ff ff       	jmp    f0102009 <__umoddi3+0x69>
