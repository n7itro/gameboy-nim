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
    memory: array[0xFFFF, uint8]
    reg: array[8, uint8] # B C D E H L _ A
    stackPointer, pc, cycles: uint16 = 0
    flags: Flags

proc nextByte: uint8 = 
    inc pc
    uint8 memory[pc]

proc getPair (high, low: int): uint16 = 
    (reg[high] shl 8) or reg[low]

proc setPair (firstReg, secondReg: int, value: uint16) =
    reg[firstReg] = uint8(value shr 8)
    reg[secondReg] = uint8(value and 0xFF)
