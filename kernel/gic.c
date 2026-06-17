/*
 * gic.c - Generic Interrupt Controller (GICv1/v2) драйвер
 * Платформа: QEMU vexpress-a9 (Cortex-A9 MPCore)
 */

#include "../include/gic.h"
#include "../include/uart.h"

// Базовые адреса GIC для vexpress-a9
#define GIC_DIST_BASE   0x1E001000   // Distributor
#define GIC_CPU_BASE    0x1E000100   // CPU Interface

// === Distributor регистры (смещения от GIC_DIST_BASE) ===
#define GICD_CTLR           (GIC_DIST_BASE + 0x000)  // Control register
#define GICD_ISENABLER(n)   (GIC_DIST_BASE + 0x100 + 4 * (n))  // Set-enable
#define GICD_ICENABLER(n)   (GIC_DIST_BASE + 0x180 + 4 * (n))  // Clear-enable
#define GICD_IPRIORITYR(n)  (GIC_DIST_BASE + 0x400 + 4 * (n))  // Priority
#define GICD_ITARGETSR(n)   (GIC_DIST_BASE + 0x800 + 4 * (n))  // CPU targets
#define GICD_ICFGR(n)       (GIC_DIST_BASE + 0xC00 + 4 * (n))  // Config (level/edge)

// === CPU Interface регистры (смещения от GIC_CPU_BASE) ===
#define GICC_CTLR    (GIC_CPU_BASE + 0x00)  // Control register
#define GICC_PMR     (GIC_CPU_BASE + 0x04)  // Priority mask
#define GICC_IAR     (GIC_CPU_BASE + 0x0C)  // Interrupt acknowledge
#define GICC_EOIR    (GIC_CPU_BASE + 0x10)  // End of interrupt

#define MMIO_READ(addr)  (*(volatile uint32_t*)(addr))
#define MMIO_WRITE(addr, value) (*(volatile uint32_t*)(addr) = (value))

#define MAX_IRQS 96   // Достаточно для vexpress-a9 (используется ~64)

// Таблица зарегистрированных обработчиков
static irq_handler_t irq_handlers[MAX_IRQS];

/*
 * gic_init - инициализация Distributor и CPU Interface
 */
void gic_init(void) {
    // Очищаем таблицу обработчиков
    for (int i = 0; i < MAX_IRQS; i++) {
        irq_handlers[i] = NULL;
    }

    // Запрещаем все прерывания на старте (banks по 32 IRQ на регистр)
    for (int i = 0; i < MAX_IRQS / 32; i++) {
        MMIO_WRITE(GICD_ICENABLER(i), 0xFFFFFFFF);
    }

    // Приоритет по умолчанию для всех IRQ (среднее значение)
    for (int i = 0; i < MAX_IRQS / 4; i++) {
        MMIO_WRITE(GICD_IPRIORITYR(i), 0xA0A0A0A0);
    }

    // Включаем Distributor (бит 0 = Enable)
    MMIO_WRITE(GICD_CTLR, 1);

    // Настраиваем CPU Interface:
    // Priority Mask = 0xFF -> пропускать прерывания любого приоритета
    MMIO_WRITE(GICC_PMR, 0xFF);

    // Включаем CPU Interface (бит 0 = Enable)
    MMIO_WRITE(GICC_CTLR, 1);

    uart_puts("  [GIC] Distributor and CPU Interface enabled\n");
}

/*
 * gic_enable_irq - разрешить конкретное прерывание
 */
void gic_enable_irq(uint32_t irq_id) {
    uint32_t reg = irq_id / 32;
    uint32_t bit = irq_id % 32;
    MMIO_WRITE(GICD_ISENABLER(reg), (1U << bit));
}

/*
 * gic_disable_irq - запретить конкретное прерывание
 */
void gic_disable_irq(uint32_t irq_id) {
    uint32_t reg = irq_id / 32;
    uint32_t bit = irq_id % 32;
    MMIO_WRITE(GICD_ICENABLER(reg), (1U << bit));
}

/*
 * gic_set_priority - установить приоритет прерывания
 */
void gic_set_priority(uint32_t irq_id, uint8_t priority) {
    uint32_t reg_addr = GIC_DIST_BASE + 0x400 + irq_id;
    *(volatile uint8_t*)reg_addr = priority;
}

/*
 * gic_get_active_irq - читает номер активного прерывания из IAR
 */
uint32_t gic_get_active_irq(void) {
    return MMIO_READ(GICC_IAR) & 0x3FF;  // Биты [9:0] - Interrupt ID
}

/*
 * gic_end_irq - сигнализирует GIC что прерывание обработано
 */
void gic_end_irq(uint32_t irq_id) {
    MMIO_WRITE(GICC_EOIR, irq_id);
}

/*
 * gic_register_handler - регистрирует обработчик для IRQ ID
 */
void gic_register_handler(uint32_t irq_id, irq_handler_t handler) {
    if (irq_id < MAX_IRQS) {
        irq_handlers[irq_id] = handler;
    }
}

/*
 * gic_dispatch_irq - главный диспетчер, вызывается из ассемблерного
 * обработчика irq_handler (boot.s) при возникновении IRQ exception
 */
void gic_dispatch_irq(void) {
    uint32_t irq_id = gic_get_active_irq();

    // 1023 = "spurious interrupt" (нет реального прерывания)
    if (irq_id >= 1022) {
        return;
    }

    if (irq_id < MAX_IRQS && irq_handlers[irq_id] != NULL) {
        irq_handlers[irq_id]();
    }

    gic_end_irq(irq_id);
}