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
