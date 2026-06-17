/*
 * gic.h - Generic Interrupt Controller (GICv1/v2) интерфейс
 * Платформа: QEMU vexpress-a9
 */

#ifndef GIC_H
#define GIC_H

#include "types.h"

// Инициализация GIC (Distributor + CPU Interface)
void gic_init(void);

// Разрешить конкретный IRQ (interrupt ID)
void gic_enable_irq(uint32_t irq_id);

// Запретить конкретный IRQ
void gic_disable_irq(uint32_t irq_id);

// Установить приоритет для IRQ (0 = наивысший, 255 = низший)
void gic_set_priority(uint32_t irq_id, uint8_t priority);

// Получить номер активного прерывания (читает из CPU interface)
uint32_t gic_get_active_irq(void);

// Подтвердить обработку прерывания (End Of Interrupt)
void gic_end_irq(uint32_t irq_id);

// Тип обработчика прерывания
typedef void (*irq_handler_t)(void);

// Зарегистрировать обработчик для конкретного IRQ ID
void gic_register_handler(uint32_t irq_id, irq_handler_t handler);

// Главный диспетчер прерываний - вызывается из irq_handler в boot.s
void gic_dispatch_irq(void);

#endif // GIC_H