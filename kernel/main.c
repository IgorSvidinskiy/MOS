/*
 * main.c - MOS Kernel with interactive shell
 */

#include "../include/uart.h"
#include "../include/types.h"
#include "../include/gic.h"

#define KERNEL_VERSION "0.1.0"
#define KERNEL_NAME "MOS"

void kernel_main(void) __attribute__((noreturn));
void print_banner(void);
void kernel_init(void);
void shell_loop(void);
int strcmp(const char *s1, const char *s2);
int strlen(const char *s);
int strncmp(const char *s1, const char *s2, int n);
void qemu_poweroff(void);

void kernel_main(void) {
    uart_init();
    print_banner();

    uart_puts("[ OK ] Initializing kernel subsystems...\n");
    kernel_init();

    uart_puts("[ OK ] Kernel started successfully!\n");
    uart_puts("[ ** ] Starting interactive shell...\n\n");

    shell_loop();

    while(1);
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
    gic_init();
    uart_puts("  [ OK ] GIC initialized\n");

    uart_puts("  [..] Timer initialization... ");
    uart_puts("SKIPPED (todo - WIP, causes hang on IRQ return, needs debugging)\n");

    uart_puts("  [..] Virtual File System... ");
    uart_puts("SKIPPED (todo)\n");
}

/*
 * qemu_poweroff - корректное выключение QEMU через ARM семихостинг
 */
void qemu_poweroff(void) {
    register uint32_t r0 = 0x18;        // SYS_EXIT
    register uint32_t r1 = 0x20026;     // ADP_Stopped_ApplicationExit

    asm volatile (
        "mov r0, %0\n"
        "mov r1, %1\n"
        "svc #0x123456\n"
        :
        : "r" (r0), "r" (r1)
        : "r0", "r1"
    );

    while(1) {
        asm volatile ("wfi");
    }
}

void shell_loop(void) {
    char buffer[128];
    int pos = 0;

    uart_puts("Welcome to MOS Shell!\n");
    uart_puts("Type 'help' for available commands\n\n");

    while(1) {
        uart_puts("MOS> ");
        pos = 0;

        while(1) {
            char c = uart_getc();

            if (c == '\r' || c == '\n') {
                buffer[pos] = '\0';
                uart_puts("\n");
                break;
            } else if (c == 127 || c == 8) {
                if (pos > 0) {
                    pos--;
                    uart_puts("\b \b");
                }
            } else if (c >= 32 && c < 127 && pos < 127) {
                buffer[pos++] = c;
                uart_putc(c);
            }
        }

        if (strlen(buffer) == 0) {
            continue;
        }

        if (strcmp(buffer, "help") == 0) {
            uart_puts("\nAvailable commands:\n");
            uart_puts("  help     - Show this help message\n");
            uart_puts("  version  - Show OS version\n");
            uart_puts("  info     - Show system information\n");
            uart_puts("  uname    - Print system information\n");
            uart_puts("  clear    - Clear screen\n");
            uart_puts("  echo     - Echo a message\n");
            uart_puts("  uptime   - Show how long system has been running\n");
            uart_puts("  free     - Display memory information\n");
            uart_puts("  ps       - Show running processes\n");
            uart_puts("  ls       - List devices\n");
            uart_puts("  pwd      - Print working directory\n");
            uart_puts("  whoami   - Print current user\n");
            uart_puts("  date     - Show current date (placeholder)\n");
            uart_puts("  reboot   - Reboot system\n");
            uart_puts("  halt     - Halt system (CPU stop)\n");
            uart_puts("  poweroff - Power off QEMU\n");
            uart_puts("\n");
        }
        else if (strcmp(buffer, "version") == 0 || strcmp(buffer, "uname") == 0) {
            uart_puts("\nMOS v");
            uart_puts(KERNEL_VERSION);
            uart_puts(" ARMv7-A Cortex-A9\n");
            uart_puts("Build: ");
            uart_puts(__DATE__);
            uart_puts(" ");
            uart_puts(__TIME__);
            uart_puts("\n\n");
        }
        else if (strcmp(buffer, "info") == 0) {
            uart_puts("\nSystem Information:\n");
            uart_puts("  OS:           MOS (Mobile Operating System)\n");
            uart_puts("  Architecture: ARMv7-A Cortex-A9\n");
            uart_puts("  Cores:        1\n");
            uart_puts("  Memory:       512 MB\n");
            uart_puts("  Platform:     QEMU vexpress-a9\n");
            uart_puts("  Kernel Size:  ~4 KB\n");
            uart_puts("\n");
        }
        else if (strcmp(buffer, "clear") == 0 || strcmp(buffer, "cls") == 0) {
            uart_puts("\033[2J\033[H");
            uart_puts("MOS v");
            uart_puts(KERNEL_VERSION);
            uart_puts(" - Screen cleared\n\n");
        }
        else if (strncmp(buffer, "echo", 4) == 0 && (buffer[4] == '\0' || buffer[4] == ' ')) {
            const char *arg = buffer + 4;
            while (*arg == ' ') arg++;

            uart_puts("\n");

            int len = strlen(arg);
            if (len >= 2 && arg[0] == '"' && arg[len - 1] == '"') {
                for (int i = 1; i < len - 1; i++) {
                    uart_putc(arg[i]);
                }
            } else {
                uart_puts(arg);
            }

            uart_puts("\n\n");
        }
        else if (strcmp(buffer, "uptime") == 0) {
            uart_puts("\nSystem uptime: unknown\n");
            uart_puts("(Timer not yet implemented - WIP)\n\n");
        }
        else if (strcmp(buffer, "free") == 0) {
            uart_puts("\nMemory Information:\n");
            uart_puts("              total        used        free\n");
            uart_puts("  Mem:        512M         ~4K         ~512M\n");
            uart_puts("  (Simplified - MMU not implemented yet)\n\n");
        }
        else if (strcmp(buffer, "ps") == 0) {
            uart_puts("\nPID    COMMAND\n");
            uart_puts("  1    kernel\n");
            uart_puts("  2    shell\n");
            uart_puts("(Process management not yet implemented)\n\n");
        }
        else if (strcmp(buffer, "date") == 0) {
            uart_puts("\nCurrent date: Unknown\n");
            uart_puts("(RTC not yet implemented)\n\n");
        }
        else if (strcmp(buffer, "ls") == 0) {
            uart_puts("\n/dev:\n");
            uart_puts("  ttyS0    (UART console)\n");
            uart_puts("  fb0      (Framebuffer - not implemented)\n");
            uart_puts("  mem      (Memory - not implemented)\n");
            uart_puts("\n(VFS not yet implemented)\n\n");
        }
        else if (strcmp(buffer, "pwd") == 0) {
            uart_puts("\n/\n\n");
        }
        else if (strcmp(buffer, "whoami") == 0) {
            uart_puts("\nroot\n\n");
        }
        else if (strcmp(buffer, "reboot") == 0) {
            uart_puts("\nRebooting system...\n\n");
            volatile uint32_t *sys_cfgdata  = (uint32_t *)(0x10000000 + 0xA0);
            volatile uint32_t *sys_cfgctrl  = (uint32_t *)(0x10000000 + 0xA4);

            *sys_cfgdata = 0;
            *sys_cfgctrl = (1U << 31) | (1U << 30) | (0x09 << 20);

            while(1) {
                asm volatile ("wfi");
            }
        }
        else if (strcmp(buffer, "halt") == 0) {
            uart_puts("\nHalting CPU...\n");
            uart_puts("System halted. CPU is now idle (WFI loop).\n");
            uart_puts("You can close QEMU manually (Ctrl+A, X).\n\n");
            while(1) {
                asm volatile ("wfi");
            }
        }
        else if (strcmp(buffer, "poweroff") == 0 || strcmp(buffer, "shutdown") == 0) {
            uart_puts("\nPowering off system...\n");
            uart_puts("Goodbye!\n\n");
            qemu_poweroff();
        }
        else {
            uart_puts("\nCommand not found: ");
            uart_puts(buffer);
            uart_puts("\nType 'help' for available commands\n\n");
        }
    }
}

int strcmp(const char *s1, const char *s2) {
    while (*s1 && (*s1 == *s2)) {
        s1++;
        s2++;
    }
    return *(unsigned char *)s1 - *(unsigned char *)s2;
}

int strlen(const char *s) {
    int len = 0;
    while (*s++) len++;
    return len;
}

int strncmp(const char *s1, const char *s2, int n) {
    while (n > 0 && *s1 && (*s1 == *s2)) {
        s1++;
        s2++;
        n--;
    }
    if (n == 0) return 0;
    return *(unsigned char *)s1 - *(unsigned char *)s2;
}