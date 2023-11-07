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

var
    title, rom: string
    memory: array[8192, uint8]
    reg: array[8, uint8] # B C D E H L _ A
    stackPointer, pc, cycles: uint16 = 0
    zero, negative, halfCarry, carry = false


proc nextByte: uint8 = 
    inc pc
    uint8 rom[pc]

proc getRegisterPair (high, low: int): uint16 = 
    uint16(reg[high] shl 8) + reg[low]

proc setRegisterPair (value: uint16, firstReg, secondReg: int) =
    discard

proc setFlags (z,n,h,c = false) = 
    (zero, negative, halfCarry, carry) = (z,n,h,c)

