#!/bin/bash
# setup_project.sh - Автоматическое создание проекта MOS (Mobile Operating System)

set -e

echo "=========================================="
echo "  MOS - Mobile Operating System"
echo "  Project Setup Script"
echo "=========================================="
echo ""

# Создаём структуру директорий
echo "[1/8] Creating directory structure..."
mkdir -p boot
mkdir -p kernel
mkdir -p include
mkdir -p build
mkdir -p docs

# ============================================
# boot/boot.s
# ============================================
echo "[2/8] Creating boot/boot.s..."
cat > boot/boot.s << 'EOF'
/*
 * boot.s - ARM bootloader для MOS
 * Архитектура: ARMv7-A (Cortex-A9)
 */

.section ".text.boot"

.global _start

_start:
    // Отключаем прерывания
    cpsid if
    
    // Получаем ID процессора
    mrc p15, 0, r5, c0, c0, 5
    and r5, r5, #3
    cmp r5, #0
    bne hang            // Если не CPU 0, переходим в hang
    
    // Настройка стека для разных режимов процессора
    
    // FIQ mode stack
    msr cpsr_c, #0xD1   // FIQ mode, IRQ/FIQ disabled
    ldr sp, =__fiq_stack_top
    
    // IRQ mode stack
    msr cpsr_c, #0xD2   // IRQ mode, IRQ/FIQ disabled
    ldr sp, =__irq_stack_top
    
    // Supervisor mode stack (основной режим ядра)
    msr cpsr_c, #0xD3   // SVC mode, IRQ/FIQ disabled
    ldr sp, =__svc_stack_top
    
    // Очистка BSS секции (неинициализированные данные)
    ldr r4, =__bss_start
    ldr r9, =__bss_end
    mov r5, #0
    mov r6, #0
    mov r7, #0
    mov r8, #0
    
bss_loop:
    cmp r4, r9
    bge bss_done
    
    // Очищаем по 16 байт за раз для скорости
    stmia r4!, {r5-r8}
    b bss_loop
    
bss_done:
    // Включаем VFP/NEON (если есть)
    mrc p15, 0, r0, c1, c0, 2
    orr r0, r0, #0x300000   // Single precision
    orr r0, r0, #0xC00000   // Double precision
    mcr p15, 0, r0, c1, c0, 2
    mov r0, #0x40000000
    fmxr fpexc, r0
    
    // Переход в kernel_main (C код)
    bl kernel_main
    
    // Если kernel_main вернётся (не должно произойти)
hang:
    wfi                 // Wait For Interrupt
    b hang

// Векторная таблица прерываний
.section ".text.vectors"
.global _vectors

_vectors:
    ldr pc, reset_handler_addr
    ldr pc, undefined_handler_addr
    ldr pc, swi_handler_addr
    ldr pc, prefetch_handler_addr
    ldr pc, data_handler_addr
    nop
    ldr pc, irq_handler_addr
    ldr pc, fiq_handler_addr

reset_handler_addr:     .word _start
undefined_handler_addr: .word undefined_handler
swi_handler_addr:       .word swi_handler
prefetch_handler_addr:  .word prefetch_handler
data_handler_addr:      .word data_handler
irq_handler_addr:       .word irq_handler
fiq_handler_addr:       .word fiq_handler

undefined_handler:
    b undefined_handler

swi_handler:
    b swi_handler

prefetch_handler:
    b prefetch_handler

data_handler:
    b data_handler

irq_handler:
    b irq_handler

fiq_handler:
    b fiq_handler

// BSS секция для стеков
.section ".bss"

.align 4
__fiq_stack:
    .skip 4096
__fiq_stack_top:

.align 4
__irq_stack:
    .skip 4096
__irq_stack_top:

.align 4
__svc_stack:
    .skip 8192
__svc_stack_top:
EOF

# ============================================
# include/types.h
# ============================================
echo "[3/8] Creating include/types.h..."
cat > include/types.h << 'EOF'
/*
 * types.h - Базовые типы данных
 */

#ifndef TYPES_H
#define TYPES_H

// Беззнаковые типы
typedef unsigned char      uint8_t;
typedef unsigned short     uint16_t;
typedef unsigned int       uint32_t;
typedef unsigned long long uint64_t;

// Знаковые типы
typedef signed char        int8_t;
typedef signed short       int16_t;
typedef signed int         int32_t;
typedef signed long long   int64_t;

// Размеры
typedef unsigned long      size_t;
typedef signed long        ssize_t;

// NULL
#ifndef NULL
#define NULL ((void*)0)
#endif

// Булевы значения
typedef enum {
    false = 0,
    true = 1
} bool;

#endif // TYPES_H
EOF

# ============================================
# include/uart.h
# ============================================
echo "[4/8] Creating include/uart.h..."
cat > include/uart.h << 'EOF'
/*
 * uart.h - UART драйвер интерфейс
 */

#ifndef UART_H
#define UART_H

#include "types.h"

void uart_init(void);
void uart_putc(char c);
char uart_getc(void);
void uart_puts(const char *str);
void uart_put_hex(uint32_t value);
void uart_put_dec(uint32_t value);

#endif // UART_H
EOF

# ============================================
# kernel/uart.c
# ============================================
echo "[5/8] Creating kernel/uart.c..."
cat > kernel/uart.c << 'EOF'
/*
 * uart.c - UART драйвер для PL011 (ARM PrimeCell UART)
 */

#include "../include/uart.h"
#include "../include/types.h"

#define UART0_BASE 0x10009000

#define UART_DR     (UART0_BASE + 0x00)
#define UART_FR     (UART0_BASE + 0x18)
#define UART_IBRD   (UART0_BASE + 0x24)
#define UART_FBRD   (UART0_BASE + 0x28)
#define UART_LCRH   (UART0_BASE + 0x2C)
#define UART_CR     (UART0_BASE + 0x30)

#define UART_FR_TXFF (1 << 5)
#define UART_FR_RXFE (1 << 4)

#define MMIO_READ(addr)  (*(volatile uint32_t*)(addr))
#define MMIO_WRITE(addr, value) (*(volatile uint32_t*)(addr) = (value))

void uart_init(void) {
    MMIO_WRITE(UART_CR, 0);
    MMIO_WRITE(UART_IBRD, 13);
    MMIO_WRITE(UART_FBRD, 1);
    MMIO_WRITE(UART_LCRH, (3 << 5) | (1 << 4));
    MMIO_WRITE(UART_CR, (1 << 0) | (1 << 8) | (1 << 9));
}

void uart_putc(char c) {
    while (MMIO_READ(UART_FR) & UART_FR_TXFF);
    MMIO_WRITE(UART_DR, c);
}

char uart_getc(void) {
    while (MMIO_READ(UART_FR) & UART_FR_RXFE);
    return MMIO_READ(UART_DR) & 0xFF;
}

void uart_puts(const char *str) {
    while (*str) {
        if (*str == '\n') {
            uart_putc('\r');
        }
        uart_putc(*str++);
    }
}

void uart_put_hex(uint32_t value) {
    const char hex_chars[] = "0123456789ABCDEF";
    uart_puts("0x");
    for (int i = 28; i >= 0; i -= 4) {
        uart_putc(hex_chars[(value >> i) & 0xF]);
    }
}

void uart_put_dec(uint32_t value) {
    if (value == 0) {
        uart_putc('0');
        return;
    }
    
    char buffer[10];
    int i = 0;
    
    while (value > 0) {
        buffer[i++] = '0' + (value % 10);
        value /= 10;
    }
    
    while (i > 0) {
        uart_putc(buffer[--i]);
    }
}
EOF

# ============================================
# kernel/main.c
# ============================================
echo "[6/8] Creating kernel/main.c..."
cat > kernel/main.c << 'EOF'
/*
 * main.c - MOS Kernel
 */

#include "../include/uart.h"
#include "../include/types.h"

#define KERNEL_VERSION "0.1.0"
#define KERNEL_NAME "MOS"

void kernel_main(void) __attribute__((noreturn));
void print_banner(void);
void kernel_init(void);

void kernel_main(void) {
    uart_init();
    print_banner();
    
    uart_puts("[ OK ] Initializing kernel subsystems...\n");
    kernel_init();
    
    uart_puts("[ OK ] Kernel started successfully!\n");
    uart_puts("[ ** ] Entering main loop...\n\n");
    
    uint32_t counter = 0;
    while(1) {
        if (counter % 10000000 == 0) {
            uart_puts("Kernel heartbeat: ");
            uart_put_hex(counter);
            uart_puts("\n");
        }
        counter++;
    }
}

void print_banner(void) {
    uart_puts("\n");
    uart_puts("===========================================\n");
    uart_puts("  __  __  ___  ____  \n");
    uart_puts(" |  \\/  |/ _ \\/ ___| \n");
    uart_puts(" | |\\/| | | | \\___ \\ \n");
    uart_puts(" | |  | | |_| |___) |\n");
    uart_puts(" |_|  |_|\\___/|____/ \n");
    uart_puts("\n");
    uart_puts("===========================================\n");
    uart_puts("  Mobile Operating System v");
    uart_puts(KERNEL_VERSION);
    uart_puts("\n");
    uart_puts("  A Unix-like OS for ARM devices\n");
    uart_puts("  No Google, No Bloat, Just Unix.\n");
    uart_puts("===========================================\n\n");
    
    uart_puts("Boot information:\n");
    uart_puts("  Architecture: ARMv7-A (Cortex-A9)\n");
    uart_puts("  CPU Count:    1 core\n");
    uart_puts("  Memory:       512 MB\n");
    uart_puts("  Platform:     QEMU vexpress-a9\n");
    uart_puts("\n");
}

void kernel_init(void) {
    uart_puts("  [..] MMU initialization... ");
    uart_puts("SKIPPED (todo)\n");
    
    uart_puts("  [..] Interrupt controller... ");
    uart_puts("SKIPPED (todo)\n");
    
    uart_puts("  [..] Timer initialization... ");
    uart_puts("SKIPPED (todo)\n");
    
    uart_puts("  [..] Virtual File System... ");
    uart_puts("SKIPPED (todo)\n");
}
EOF

# ============================================
# linker.ld
# ============================================
echo "[7/8] Creating linker.ld..."
cat > linker.ld << 'EOF'
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
EOF

# ============================================
# Makefile
# ============================================
echo "[8/8] Creating Makefile..."
cat > Makefile << 'EOF'
# Makefile для MOS (Mobile Operating System)

CROSS = arm-none-eabi-
CC = $(CROSS)gcc
AS = $(CROSS)as
LD = $(CROSS)ld
OBJCOPY = $(CROSS)objcopy
OBJDUMP = $(CROSS)objdump

CFLAGS = -Wall -Wextra -O2 -nostdlib -nostartfiles -ffreestanding
CFLAGS += -mcpu=cortex-a9 -marm
CFLAGS += -fno-builtin -fno-common
CFLAGS += -I./include

ASFLAGS = -mcpu=cortex-a9 -marm

LDFLAGS = -T linker.ld -nostdlib

BUILD_DIR = build
BOOT_DIR = boot
KERNEL_DIR = kernel

ASM_SOURCES = $(BOOT_DIR)/boot.s
C_SOURCES = $(KERNEL_DIR)/main.c $(KERNEL_DIR)/uart.c

ASM_OBJECTS = $(patsubst $(BOOT_DIR)/%.s, $(BUILD_DIR)/%.o, $(ASM_SOURCES))
C_OBJECTS = $(patsubst $(KERNEL_DIR)/%.c, $(BUILD_DIR)/%.o, $(C_SOURCES))

OBJECTS = $(ASM_OBJECTS) $(C_OBJECTS)

KERNEL_ELF = $(BUILD_DIR)/kernel.elf
KERNEL_BIN = $(BUILD_DIR)/kernel.bin

COLOR_RESET = \033[0m
COLOR_GREEN = \033[32m
COLOR_YELLOW = \033[33m
COLOR_BLUE = \033[34m

.PHONY: all
all: $(KERNEL_ELF) $(KERNEL_BIN)
	@echo "$(COLOR_GREEN)✓ Build complete!$(COLOR_RESET)"
	@echo "$(COLOR_BLUE)Kernel size:$(COLOR_RESET)"
	@ls -lh $(KERNEL_BIN) | awk '{print "  " $$9 ": " $$5}'
	@echo ""
	@echo "$(COLOR_YELLOW)To run:$(COLOR_RESET) make run"
	@echo "$(COLOR_YELLOW)To debug:$(COLOR_RESET) make debug"

$(BUILD_DIR):
	@mkdir -p $(BUILD_DIR)

$(BUILD_DIR)/%.o: $(BOOT_DIR)/%.s | $(BUILD_DIR)
	@echo "$(COLOR_BLUE)[AS]$(COLOR_RESET) $<"
	@$(AS) $(ASFLAGS) $< -o $@

$(BUILD_DIR)/%.o: $(KERNEL_DIR)/%.c | $(BUILD_DIR)
	@echo "$(COLOR_BLUE)[CC]$(COLOR_RESET) $<"
	@$(CC) $(CFLAGS) -c $< -o $@

$(KERNEL_ELF): $(OBJECTS)
	@echo "$(COLOR_BLUE)[LD]$(COLOR_RESET) $@"
	@$(LD) $(LDFLAGS) $(OBJECTS) -o $@

$(KERNEL_BIN): $(KERNEL_ELF)
	@echo "$(COLOR_BLUE)[OBJCOPY]$(COLOR_RESET) $@"
	@$(OBJCOPY) -O binary $< $@

.PHONY: run
run: $(KERNEL_ELF)
	@echo "$(COLOR_GREEN)Starting QEMU...$(COLOR_RESET)"
	@echo "$(COLOR_YELLOW)Press Ctrl+A then X to exit QEMU$(COLOR_RESET)"
	@echo ""
	qemu-system-arm -M vexpress-a9 -m 512M -nographic -kernel $(KERNEL_ELF)

.PHONY: debug
debug: $(KERNEL_ELF)
	@echo "$(COLOR_GREEN)Starting QEMU in debug mode...$(COLOR_RESET)"
	@echo "$(COLOR_YELLOW)GDB server on localhost:1234$(COLOR_RESET)"
	@echo "$(COLOR_YELLOW)In another terminal run:$(COLOR_RESET)"
	@echo "  arm-none-eabi-gdb $(KERNEL_ELF)"
	@echo "  (gdb) target remote localhost:1234"
	@echo "  (gdb) continue"
	@echo ""
	qemu-system-arm -M vexpress-a9 -m 512M -nographic -kernel $(KERNEL_ELF) -s -S

.PHONY: clean
clean:
	@echo "$(COLOR_YELLOW)Cleaning build files...$(COLOR_RESET)"
	@rm -rf $(BUILD_DIR)
	@echo "$(COLOR_GREEN)✓ Clean complete$(COLOR_RESET)"

.PHONY: info
info:
	@echo "$(COLOR_BLUE)MOS Build System$(COLOR_RESET)"
	@echo ""
	@echo "Source files:"
	@echo "  ASM: $(ASM_SOURCES)"
	@echo "  C:   $(C_SOURCES)"

.DEFAULT_GOAL := all
EOF

# ============================================
# README.md
# ============================================
cat > README.md << 'EOF'
# MOS - Mobile Operating System

Минималистичная Unix-подобная операционная система для ARM устройств.

## Быстрый старт

```bash
# Сборка
make all

# Запуск в QEMU
make run

# Выход из QEMU: Ctrl+A, затем X
```

## Структура проекта

```
MOS/
├── boot/           # Загрузочный код (ARM ассемблер)
├── kernel/         # Ядро системы
├── include/        # Заголовочные файлы
├── build/          # Скомпилированные файлы
├── linker.ld       # Linker script
├── Makefile        # Система сборки
└── README.md       # Этот файл
```

## Цели проекта

- Чистая Unix философия
- Без Google зависимостей
- Минимальный размер
- Максимальная производительность
- Поддержка старых ARM устройств

## Лицензия

MIT License
EOF

echo ""
echo "=========================================="
echo "  ✓ Project created successfully!"
echo "=========================================="
echo ""
echo "Project structure:"
tree -L 2 2>/dev/null || ls -R
echo ""
echo "Next steps:"
echo "  1. cd into project directory"
echo "  2. make all"
echo "  3. make run"
echo ""
echo "Happy coding! 🚀"
EOF

chmod +x setup_project.sh
echo ""
echo "✓ Script created: setup_project.sh"
echo ""
echo "Run it with: ./setup_project.sh"
