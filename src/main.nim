#[
    GNU General Public License v3.0
]#

include instructions, ppu

proc loadRom (filePath: string) =
    try: 
        rom = readFile filePath
        #title = rom[0x134..0x143]
    
    except: 
        echo getCurrentExceptionMsg()
        quit 0 

loadRom "roms/d.gb"

while pc <= uint16 len rom:
    let opcode = int rom[pc]

    execute opcode
    inc cycles
    inc pc
