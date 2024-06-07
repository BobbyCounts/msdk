###############################################################################
 #
 # Copyright (C) 2024 Analog Devices, Inc.
 #
 # Licensed under the Apache License, Version 2.0 (the "License");
 # you may not use this file except in compliance with the License.
 # You may obtain a copy of the License at
 #
 #     http://www.apache.org/licenses/LICENSE-2.0
 #
 # Unless required by applicable law or agreed to in writing, software
 # distributed under the License is distributed on an "AS IS" BASIS,
 # WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 # See the License for the specific language governing permissions and
 # limitations under the License.
 #
 ##############################################################################

ifeq "$(CMSIS_ROOT)" ""
# If CMSIS_ROOT is not specified, this Makefile will calculate CMSIS_ROOT relative to itself.
GCC_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
CMSIS_ROOT := $(abspath $(GCC_DIR)../../../../..)
endif

TARGET_UC:=MAX32657
TARGET_LC:=max32657

# The build directory
ifeq "$(BUILD_DIR)" ""
BUILD_DIR=$(CURDIR)/build
endif

STARTUPFILE ?= startup_$(TARGET_LC).S

################################################################################
# Detect target OS
# windows : native windows
# windows_msys : MSYS2 on windows
# windows_cygwin : Cygwin on windows (legacy config from old sdk)
# linux : Any linux distro
# macos : MacOS
ifeq "$(OS)" "Windows_NT"
_OS = windows

UNAME_RESULT := $(shell uname -s 2>&1)
# MSYS2 may be present on Windows.  In this case,
# linux utilities should be used.  However, the OS environment
# variable will still be set to Windows_NT since we configure
# MSYS2 to inherit from Windows by default.
# Here we'll attempt to call uname (only present on MSYS2)
# while routing stderr -> stdout to avoid throwing an error 
# if uname can't be found.
ifneq ($(findstring CYGWIN, $(UNAME_RESULT)), )
CYGWIN=True
_OS = windows_cygwin
endif

ifneq ($(findstring MSYS, $(UNAME_RESULT)), )
MSYS=True
_OS = windows_msys
endif
ifneq ($(findstring MINGW, $(UNAME_RESULT)), )
MSYS=True
_OS = windows_msys
endif

else # OS

UNAME_RESULT := $(shell uname -s)
ifeq "$(UNAME_RESULT)" "Linux"
_OS = linux
endif
ifeq "$(UNAME_RESULT)" "Darwin"
_OS = macos
endif

endif

################################################################################

# Default entry-point
ENTRY ?= Reset_Handler

# Default TARGET_REVISION
# "A1" in ASCII
ifeq "$(TARGET_REV)" ""
TARGET_REV=0x4131
endif

# Add target specific CMSIS source files
ifneq (${MAKECMDGOALS},lib)
SRCS += ${STARTUPFILE}
SRCS += heap.c
SRCS += system_$(TARGET_LC).c
endif

# Compile both Secure and Non-Secure projects and link them into a combined
# image.
# Configuration Variables:
# - TRUSTZONE      : Set to 1 to build and combine both Secure and Non-Secure projects.
# - MSECURITY_MODE : Set the security context of the project.
################################################################################
ifeq ($(TRUSTZONE),1)
ifeq "$(MSECURITY_MODE)" "SECURE"
ifeq "$(GEN_CMSE_IMPLIB_OBJ)" ""

LOADER_SCRIPT := $(CMSIS_ROOT)/Device/Maxim/$(TARGET_UC)/Source/GCC/nonsecure_load.S

# This might be dangerous, might pick the default directory with the user being aware
# Directory for Non-Secure code, defaults to Hello_World_TZ/NonSecure
# NONSECURE_CODE_DIR ?= $(CMSIS_ROOT)/../../Examples/$(TARGET_UC)/Hello_World_TZ/NonSecure
# SECURE_CODE_DIR ?= $(CMSIS_ROOT)/../../Examples/$(TARGET_UC)/Hello_World_TZ/Secure

# Build the Secure and Non-Secure project inside of the Secure project so that
# "make clean" will catch it automatically.
NONSECURE_BUILD_DIR := $(CURDIR)/build/build_ns
SECURE_BUILD_DIR := $(CURDIR)/build/build_s

# Binary name for Non-Secure code.
NONSECURE_CODE_BIN = $(NONSECURE_BUILD_DIR)/nonsecure.bin
NONSECURE_CODE_OBJ = $(NONSECURE_BUILD_DIR)/nonsecure.o

SECURE_IMPLIB_OBJ := $(SECURE_BUILD_DIR)/secure_implib.o

# Add the Non-Secure project object to the build.  This is the critical
# line that will get the linker to bring it into the .elf file.
PROJ_OBJS = ${NONSECURE_CODE_OBJ}
# PROJ_OBJS = ${SECURE_IMPLIB_OBJ}

# Recipe to build the secure code importlib object file
.PHONY: secure_implib_obj
secure_implib_obj:
	@echo ""
	@echo "****************************************************************************"
	@echo "* Building Secure Code and generating a CMSE importlib object file"
	@echo "* with empty definitions of Secure symbols at the right locations."
	@echo "*"
	@echo "* The generated CMSE importlib object file needs to be linked with"
	@echo "* Non-Secure Code image."
	@echo "****************************************************************************"
	$(MAKE) -C ${SECURE_CODE_DIR} BUILD_DIR=$(SECURE_BUILD_DIR) PROJECT=secure GEN_CMSE_IMPLIB_OBJ=1

# Recipe to build the non-secure code image binary
$(NONSECURE_CODE_BIN): secure_implib_obj
# Run linker to generate
	@echo ""
	@echo "****************************************************************************"
	@echo "* Building Non-Secure Code with generated CMSE importlib object file."
	@echo "****************************************************************************"
	$(MAKE) -C ${NONSECURE_CODE_DIR} BUILD_DIR=$(NONSECURE_BUILD_DIR) PROJECT=nonsecure
	$(MAKE) -C ${NONSECURE_CODE_DIR} BUILD_DIR=$(NONSECURE_BUILD_DIR) $(NONSECURE_CODE_BIN)
	@echo ""
	@echo "****************************************************************************"
	@echo "* Linking Secure and Non-Secure images together."
	@echo "****************************************************************************"

${NONSECURE_CODE_OBJ}: $(LOADER_SCRIPT) ${NONSECURE_CODE_BIN}
	@${CC} ${AFLAGS} -o ${@} -c $(LOADER_SCRIPT)

endif # GEN_CMSE_IMPLIB_OBJ
SECURE_BUILD_DIR := $(CURDIR)/build/build_s
endif
ifeq "$(MSECURITY_MODE)" "NONSECURE"
SECURE_BUILD_DIR := $(CURDIR)/../Secure/build/build_s
SECURE_IMPLIB_OBJ := $(SECURE_BUILD_DIR)/secure_implib.o

PROJ_OBJS += $(SECURE_IMPLIB_OBJ)

endif # MSECURITY_MODE
endif # TRUSTZONE

# Use proper linker files as a Secure-only vs Secure/Non-Secure-combined project.
ifeq "$(LINKERFILE)" ""
ifeq ($(TRUSTZONE),1)
# Auto generate linkers
COMMON_DIR=$(abspath $(SECURE_BUILD_DIR)/..)
SECURE_PROJ_MK=$(abspath $(COMMON_DIR)/../project.mk)
LINKER_DIR=$(CMSIS_ROOT)/Device/Maxim/$(TARGET_UC)/Source/GCC
LINKER_DEPS=$(LINKER_DIR)/create_linkers.py $(wildcard $(LINKER_DIR)/linker_templates/*.template) $(SECURE_PROJ_MK)
$(COMMON_DIR)/$(TARGET_LC)_secure.ld $(COMMON_DIR)/$(TARGET_LC)_nonsecure.ld: $(LINKER_DEPS)
	python3 $(LINKER_DIR)/create_linkers.py $(TARGET_LC) $(COMMON_DIR) $(LINKER_GEN_FLAGS)
ifeq "$(MSECURITY_MODE)" "SECURE"
LINKERFILE=$(COMMON_DIR)/$(TARGET_LC)_secure.ld
else # MSECURITY_MODE=NONSECURE
LINKERFILE=$(COMMON_DIR)/$(TARGET_LC)_nonsecure.ld
endif # MSECURITY_MODE
else # TRUSTZONE=0
# Default linkerfile
LINKERFILE ?= $(CMSIS_ROOT)/Device/Maxim/$(TARGET_UC)/Source/GCC/$(TARGET_LC).ld
endif # TRUSTZONE
endif # LINKERFILE

################################################################################

# Add target specific CMSIS source directories
VPATH += $(CMSIS_ROOT)/Device/Maxim/$(TARGET_UC)/Source/GCC
VPATH += $(CMSIS_ROOT)/Device/Maxim/$(TARGET_UC)/Source

# Add target specific CMSIS include directories
IPATH += $(CMSIS_ROOT)/Device/Maxim/$(TARGET_UC)/Include

# Add CMSIS Core files
CMSIS_VER ?= 5.9.0
IPATH += $(CMSIS_ROOT)/$(CMSIS_VER)/Core/Include

# Add directory with linker include file
LIBPATH += $(CMSIS_ROOT)/Device/Maxim/$(TARGET_UC)/Source/GCC

# Set target architecture
MCPU := cortex-m33

# Set FPU architecture
# (See Arm Cortex M33 Technical Reference Manual Chapter B5
# Armv8-M Floating-Point extension with FPv5 architecture
# Single-precision with 16 double-word registers
MFPU := fpv5-sp-d16

# Include the rules and goals for building
include $(CMSIS_ROOT)/Device/Maxim/GCC/gcc.mk

# Include rules for flashing
include $(CMSIS_ROOT)/../../Tools/Flash/flash.mk
