#[
    GNU General Public License v3.0
]#

include cpu

proc loadRom (filePath: string) =
    try:
        rom = readFile filePath
        title = rom[0x134..0x143]

    except:
        echo "Failed to read ROM: ", getCurrentExceptionMsg()
        quit 0

loadRom "roms/tetris.gb"

while pc <= uint16 len rom:
    cpu()
