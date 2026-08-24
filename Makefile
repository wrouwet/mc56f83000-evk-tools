# Build/flash for the MC56F83000-EVK, driving CodeWarrior's 56800E
# compiler/assembler/linker directly - no Eclipse project file, no IDE.
# There's no GCC/LLVM backend for this DSC core (see
# docs/ARCHITECTURE.md), so the compiler itself has to stay
# CodeWarrior's - but nothing here needs Eclipse or a GUI.
#
# One-time setup: tools/Detect-Toolchain.ps1 -CwRoot <...> -SdkRoot <...>
# generates config/toolchain.mk (gitignored, machine-specific). After
# that, everything is `make <target>`.

# config/toolchain.mk also sets SHELL to a POSIX shell (Git for Windows'
# bash). Without it GNU Make on Windows runs recipes through cmd.exe,
# which has no mkdir -p / rm -rf.
include config/toolchain.mk

.SHELLFLAGS := -c

CONFIG    ?= flash_ldm_lpm_debug
BUILD_DIR := build/$(CONFIG)
ELF       := $(BUILD_DIR)/hello_world.elf

# Only flash_ldm_lpm_debug (large data model, debug) is implemented -
# it's the one config we have real, working compiler/linker flags for
# (transcribed from an actual successful build's .args files, not
# guessed - see docs/ARCHITECTURE.md). sdm/release variants would need
# their own flags confirmed the same way before adding them here.
ifneq ($(CONFIG),flash_ldm_lpm_debug)
$(error Only CONFIG=flash_ldm_lpm_debug is implemented right now - see the comment above this error in the Makefile)
endif

SDK_DEVICE := $(SDK_ROOT)/devices/MC56F83789
SDK_APP    := $(SDK_ROOT)/boards/mc56f83000evk/demo_apps/hello_world
CW_SUPPORT := $(CW_ROOT)/MCU/DSP56800x_EABI_Tools/M56800E Support

# --- sources -----------------------------------------------------------
# Our own application sources live in src/. Device driver / runtime
# sources stay in the externally-installed MCUXpresso SDK, referenced by
# path (not vendored into this repo - see README.md).

C_SRCS := \
  hello_world.c board.c clock_config.c hardware_init.c peripherals.c pin_mux.c \
  fsl_clock.c fsl_common.c fsl_common_dsc.c fsl_flash.c fsl_gpio.c fsl_qsci.c \
  Flash_config.c MC56F83789_Vectors.c \
  fsl_assert_min.c fsl_debug_console.c fsl_str.c \
  fsl_adapter_qsci.c

ASM_SRCS := MC56F83xxx_init.asm

vpath %.c src
vpath %.c $(SDK_DEVICE)/drivers
vpath %.c $(SDK_DEVICE)/codewarrior
vpath %.c $(SDK_DEVICE)/utilities/debug_console_lite
vpath %.c $(SDK_DEVICE)/utilities/str
vpath %.c $(SDK_ROOT)/components/uart
vpath %.asm $(SDK_DEVICE)/codewarrior

OBJS := $(patsubst %.c,$(BUILD_DIR)/%.obj,$(C_SRCS)) \
        $(patsubst %.asm,$(BUILD_DIR)/%.obj,$(ASM_SRCS))

# --- compiler flags ------------------------------------------------------
# Reproduced verbatim from the .args response files a real, successful
# `flash_ldm_lpm_debug` build actually produced - not guessed.

DEFINES := \
  -DDEBUG -D__LDM__ -D__LPM__ -DPRINTF_ADVANCED_ENABLE=1 -D__DSC__ \
  -D__CW__ -D__CORE_56800EX__ -DSDK_DEBUGCONSOLE=1 -DMCUX_META_BUILD \
  -DMCUXPRESSO_SDK -DCPU_MC56F83789VLL -DMC56F83789_SERIES

INCLUDES := \
  -i "$(CURDIR)/src" \
  -i "$(SDK_DEVICE)/drivers" \
  -i "$(SDK_DEVICE)" \
  -i "$(SDK_DEVICE)/periph" \
  -i "$(SDK_DEVICE)/codewarrior" \
  -i "$(SDK_DEVICE)/utilities/str" \
  -i "$(SDK_DEVICE)/utilities/debug_console_lite" \
  -i "$(SDK_ROOT)/components/uart" \
  -I- \
  -i "$(CW_SUPPORT)/runtime_56800E/include" \
  -I- \
  -i "$(CW_SUPPORT)/msl/MSL_C/MSL_Common/Include" \
  -I- \
  -i "$(CW_SUPPORT)/msl/MSL_C/DSP_56800E/prefix" \
  -I- \
  -ir "$(CW_SUPPORT)"

CFLAGS := \
  -msgstyle parseable -g $(DEFINES) $(INCLUDES) \
  -w illpragmas -w possible -w extended -w extracomma -w emptydecl -w structclass -w notinlined \
  -opt speed -ldata -globalsInLowerMemory -v3 -requireprotos -lang c99 \
  -Duintptr_t=unsigned \
  -include "$(CURDIR)/src/mcuxsdk_version.h" -include "$(CURDIR)/src/mcux_config.h"

ASFLAGS := \
  -msgstyle parseable -debug -nosyspath \
  -i "$(CURDIR)/src" -i "$(SDK_DEVICE)/drivers" -i "$(SDK_DEVICE)" \
  -i "$(SDK_DEVICE)/periph" -i "$(SDK_DEVICE)/codewarrior" \
  -i "$(SDK_DEVICE)/utilities/str" -i "$(SDK_DEVICE)/utilities/debug_console_lite" \
  -i "$(SDK_ROOT)/components/uart" \
  -v3 -data 24 -prog 19

LDFLAGS := -msgstyle parseable -g -main F_EntryPoint -ldata -v3 -map

LIBS := \
  "$(CW_ROOT)/MCU/DSP56800x_EABI_Tools/lib/lpm/ldm/o4p/librt.lib" \
  "$(CW_ROOT)/MCU/DSP56800x_EABI_Tools/lib/lpm/ldm/o4p/libc.lib"

# --- rules ---------------------------------------------------------------

.PHONY: all build flash clean

all: build

build: $(ELF)

$(ELF): $(OBJS) linker/MC56F83789_Internal_PFlash_LDM.cmd | $(BUILD_DIR)
	"$(LD)" -o $@ $(LDFLAGS) linker/MC56F83789_Internal_PFlash_LDM.cmd $(LIBS) $(OBJS)
	@echo "Build OK -> $@"

$(BUILD_DIR)/%.obj: %.c | $(BUILD_DIR)
	"$(CC)" -c $(CFLAGS) -o $@ $<

$(BUILD_DIR)/%.obj: %.asm | $(BUILD_DIR)
	"$(AS)" -c $(ASFLAGS) -o $@ $<

$(BUILD_DIR):
	mkdir -p $@

# -gdi= is load-bearing, and its absence is why FFLASH.exe looks
# "silently broken": without it, fflash falls back to a default GDI
# driver that can't talk to this board's on-board OSJTAG probe, and
# bails with a bare non-zero exit code and no diagnostic text at all -
# no stderr, no -l<file> log, nothing in the Event Log. Naming P&E's DSC
# GDI explicitly is what makes it work. ($(GDI) comes from
# config/toolchain.mk.)
flash: $(ELF)
	"$(FFLASH)" flash/flash.cfg -USB "-gdi=$(GDI)" "$(ELF)"
	@echo ""
	@echo "Flashed. fflash leaves the target HALTED - press the board's reset"
	@echo "button to start the new firmware (confirmed on hardware; fflash has"
	@echo "no documented reset-and-run flag)."

clean:
	rm -rf build
