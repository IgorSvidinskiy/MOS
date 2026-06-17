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

ASFLAGS = 

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
	qemu-system-arm -M vexpress-a9 -m 512M -nographic -kernel $(KERNEL_ELF) -semihosting

.PHONY: run-gui
run-gui: $(KERNEL_ELF)
	@echo "$(COLOR_GREEN)Starting QEMU with display...$(COLOR_RESET)"
	qemu-system-arm -M vexpress-a9 -m 512M -kernel $(KERNEL_ELF) -serial stdio

.PHONY: debug
debug: $(KERNEL_ELF)
	@echo "$(COLOR_GREEN)Starting QEMU in debug mode...$(COLOR_RESET)"
	@echo "$(COLOR_YELLOW)GDB server on localhost:1234$(COLOR_RESET)"
	@echo "$(COLOR_YELLOW)In another terminal run:$(COLOR_RESET)"
	@echo "  arm-none-eabi-gdb $(KERNEL_ELF)"
	@echo "  (gdb) target remote localhost:1234"
	@echo "  (gdb) continue"
	@echo ""
	qemu-system-arm -M vexpress-a9 -m 512M -nographic -kernel $(KERNEL_ELF) -s -S -semihosting

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
