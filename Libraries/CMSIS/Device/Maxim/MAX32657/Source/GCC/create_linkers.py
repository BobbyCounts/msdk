import argparse
from string import Template
import pathlib

# Resolve relative path
rel_path = pathlib.Path(__file__).parent.resolve()

# Parse command line args
parser = argparse.ArgumentParser(
    prog='create_linkers',
    description='Generate configurable linkers for ME30')
parser.add_argument("device_name", help="Device name of the target micro")
parser.add_argument("output_dir", help="Directory to write linker scripts to")
parser.add_argument("--sram_exe", help="Run code in SRAM instead of flash", action="store_true")
parser.add_argument(
    "--secure_flip",
    help="Put the secure section at the 2nd half of flash instead of the 1st",
    action="store_true"
)
parser.add_argument(
    "--nsc_size",
    help="Set the size of the non-secure callable section in kB. Default=8kB",
    type=int,
    default=8
)
parser.add_argument(
    "--flash_size",
    help="Set the size of the flash in kB. Default=1024kB",
    type=int,
    default=1024
)
parser.add_argument(
    "--sram_size",
    help="Set the size of the SRAM in kB. Default=256kB",
    type=int,
    default=256
)
parser.add_argument(
    "--print_result",
    help="Print linker calculation results to console",
    action="store_true"
)
args = parser.parse_args()

# Select SRAM or FLash
if args.sram_exe:
    exe_mem = 'SRAM'
else:
    exe_mem = 'FLASH'

# Address calculation
ns_flash_origin = 0x01000000 + ((args.flash_size // 2) * 1024 * (not args.secure_flip))
ns_flash_length = args.flash_size * 1024 // 2

s_flash_origin = 0x11000000 + ((args.flash_size // 2) * 1024 * (args.secure_flip))
s_flash_length = ns_flash_length - (args.nsc_size * 1024 * (not args.sram_exe))

ns_sram_origin = 0x20000000 + ((args.sram_size // 2) * 1024 * (not args.secure_flip))
ns_sram_length = args.sram_size * 1024 // 2

s_sram_origin = 0x30000000 + ((args.sram_size // 2) * 1024 * (args.secure_flip))
s_sram_length = ns_sram_length - (args.nsc_size * 1024 * args.sram_exe)

# Non-secure callable memory calculations
if args.sram_exe:
    nsc_code_origin = s_sram_origin + s_sram_length
else:
    nsc_code_origin = s_flash_origin + s_flash_length
nsc_code_length = args.nsc_size * 1024

# Alias the non secure sections to the secure region so loads are easier
ns_flash_origin_a = ns_flash_origin + 0x10000000
ns_sram_origin_a = ns_sram_origin + 0x10000000

# Template dictionary
params = {
    'ns_exe_mem': f"NS_{exe_mem}",
    's_exe_mem': f"S_{exe_mem}",
    'ns_flash_origin': hex(ns_flash_origin),
    'ns_flash_origin_a': hex(ns_flash_origin_a),
    'ns_flash_length': hex(ns_flash_length),
    'ns_sram_origin': hex(ns_sram_origin),
    'ns_sram_origin_a': hex(ns_sram_origin_a),
    'ns_sram_length': hex(ns_sram_length),
    's_flash_origin': hex(s_flash_origin),
    's_flash_length': hex(s_flash_length),
    's_sram_origin': hex(s_sram_origin),
    's_sram_length': hex(s_sram_length),
    'nsc_code_origin': hex(nsc_code_origin),
    'nsc_code_length': hex(nsc_code_length)
}

with open(f"{rel_path}/templates/max32657_ns.template", 'r') as f:
    with open(f"{args.output_dir}/{args.device_name}_nonsecure.ld", 'w') as output:
        source = Template(f.read())
        result = source.substitute(params)
        output.write(result)

with open(f"{rel_path}/templates/max32657_s.template", 'r') as f:
    with open(f"{args.output_dir}/{args.device_name.lower()}_secure.ld", 'w') as output:
        source = Template(f.read())
        result = source.substitute(params)
        output.write(result)


if args.print_result:
    print(f"Code Execution: {exe_mem}")
    print(f"Secure Flash @ {params['s_flash_origin']}, length={params['s_flash_length']}")
    print(f"Non Secure Flash @ {params['ns_flash_origin']}, length={params['ns_flash_length']}")
    print(f"Secure SRAM @ {params['s_sram_origin']}, length={params['s_sram_length']}")
    print(f"Non Secure SRAM @ {params['ns_sram_origin']}, length={params['ns_sram_length']}")
    print(f"Non Secure Callable @ {params['nsc_code_origin']}, length={params['nsc_code_length']}")
