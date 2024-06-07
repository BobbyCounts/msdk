# This file can be used to set build configuration
# variables.  These variables are defined in a file called 
# "Makefile" that is located next to this one.

# For instructions on how to use this system, see
# https://analogdevicesinc.github.io/msdk/USERGUIDE/#build-system

# **********************************************************

# Add your config here!

# TrustZone project with secure and non-secure code.
TRUSTZONE=1

# This is a secure project.
MSECURITY_MODE=SECURE

# Add path to Non-Secure project.
SECURE_CODE_DIR=./
NONSECURE_CODE_DIR=../NonSecure

# Variable LINKER_GEN_FLAGS sets the options for the linker file generator
#  --sram_exe            Run code in SRAM instead of flash
#  --secure_flip         Put the secure section at the 2nd half of flash
#                        instead of the 1st
#  --nsc_size NSC_SIZE   Set the size of the non-secure callable section in kB.
#                        Default=8kB
#  --flash_size FLASH_SIZE
#                        Set the size of the flash in kB. Default=1024kB
#  --sram_size SRAM_SIZE
#                        Set the size of the SRAM in kB. Default=256kB
#  --print_result        Print linker calculation results to console
LINKER_GEN_FLAGS= --flash_size 512 #Reducing flash size to run on emulator
