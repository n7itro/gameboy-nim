#[
    Glossary
        u8/i8   8-bit (un)signed integer
        u16     16-bit unsigned integer
        r8      Any of the 8-bit registers (A, B, C, D, E, H, L)
        r16     Any of the general-purpose 16-bit registers (BC, DE, HL)
        pc      Program counter   
]#

const 
    (B, C, D, E, H, L, HL, A) = (0, 1, 2, 3, 4, 5, 6, 7)

type
    Flags = tuple
        zero, negative, halfCarry, carry = false
    
var
    memory: array[8192, uint8]
    reg: array[8, uint8] # B C D E H L _ A
    stackPointer, pc, cycles: uint16 = 0
    rom: string
    flags: Flags


proc nextByte(amount: int = 1): uint8 = 
    inc(pc, amount)
    uint8 rom[pc]


proc getPair (high, low: int): uint16 = 
    uint16(reg[high] shl 8) + reg[low]


proc setPair (value: uint16, firstReg, secondReg: int) =
    discard
