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
