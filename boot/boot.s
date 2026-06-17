/*
 * boot.s - ARM bootloader для MOS
 * Архитектура: ARMv7-A (Cortex-A9)
 */

.section ".text.boot"

.global _start

_start:
    cpsid if

    mrc p15, 0, r5, c0, c0, 5
    and r5, r5, #3
    cmp r5, #0
    bne hang

    // FIQ mode stack
    msr cpsr_c, #0xD1
    ldr sp, =__fiq_stack_top

    // IRQ mode stack
    msr cpsr_c, #0xD2
    ldr sp, =__irq_stack_top

    // Supervisor mode stack
    msr cpsr_c, #0xD3
    ldr sp, =__svc_stack_top

    // Очистка BSS
    ldr r4, =__bss_start
    ldr r9, =__bss_end
    mov r5, #0
    mov r6, #0
    mov r7, #0
    mov r8, #0

bss_loop:
    cmp r4, r9
    bge bss_done
    stmia r4!, {r5-r8}
    b bss_loop

bss_done:
    // В SVC режиме разрешаем IRQ (сбрасываем бит I в CPSR)
    cpsie i

    bl kernel_main

hang:
    wfi
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
irq_handler_addr:       .word irq_handler_asm
fiq_handler_addr:       .word fiq_handler

undefined_handler:
    b undefined_handler

swi_handler:
    b swi_handler

prefetch_handler:
    b prefetch_handler

data_handler:
    b data_handler

/*
 * irq_handler_asm - обработчик IRQ exception
 *
 * При входе сюда CPU уже переключился в IRQ mode.
 * lr (link register) в IRQ mode = адрес возврата + 4 (нужно скорректировать).
 *
 * Сохраняем контекст, переходим в gic_dispatch_irq() (C функция),
 * восстанавливаем контекст, возвращаемся через subs pc, lr, #4.
 */
irq_handler_asm:
    // Корректируем lr для возврата (IRQ: lr = адрес_прерванной_инструкции + 4)
    sub lr, lr, #4

    // Сохраняем регистры r0-r12 и lr в стек IRQ mode
    push {r0-r12, lr}

    // Вызываем C-диспетчер
    bl gic_dispatch_irq

    // Восстанавливаем регистры
    pop {r0-r12, lr}

    // Возврат из прерывания: восстанавливает CPSR из SPSR и переходит по lr
    subs pc, lr, #0

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