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
