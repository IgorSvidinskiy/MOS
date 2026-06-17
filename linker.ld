/*
 * linker.ld - Linker script для MOS
 */

ENTRY(_start)

MEMORY
{
    RAM : ORIGIN = 0x60000000, LENGTH = 512M
}

SECTIONS
{
    . = 0x60000000;
    
    .text.vectors : {
        *(.text.vectors)
    } > RAM
    
    .text.boot : {
        *(.text.boot)
    } > RAM
    
    .text : {
        *(.text)
        *(.text.*)
    } > RAM
    
    .rodata : {
        *(.rodata)
        *(.rodata.*)
    } > RAM
    
    .data : {
        *(.data)
        *(.data.*)
    } > RAM
    
    .bss : {
        __bss_start = .;
        *(.bss)
        *(.bss.*)
        *(COMMON)
        __bss_end = .;
    } > RAM
    
    . = ALIGN(4096);
    __end = .;
    
    /DISCARD/ : {
        *(.ARM.exidx)
        *(.ARM.extab)
        *(.comment)
        *(.note.*)
    }
}
