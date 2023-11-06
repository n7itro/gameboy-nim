#[
    Glossary
        u8/i8   8-bit (un)signed integer
        u16     16-bit unsigned integer
        r8      Any of the 8-bit registers (A, B, C, D, E, H, L)
        r16     Any of the general-purpose 16-bit registers (BC, DE, HL)   
]#

import std/strutils

const 
    (B, C, D, E, H, L, HL, A) = (0, 1, 2, 3, 4, 5, 6, 7)

var
    title, rom: string
    ram: array[8192, uint8]
    reg: array[8, uint8] # B C D E H L _ A
    pc, sp, cycles: uint16 = 0
    zero, negative, halfCarry, carry = false

proc registerPair (high, low: int): uint16 = 
    reg[high] + reg[low]

proc setFlags (z,n,h,c = false) = 
    (zero, negative, halfCarry, carry) = (z,n,h,c)

proc execute (opcode: int) =
    var
        value = reg[opcode and 7]   # Register we are taking a value from 
        target = opcode shr 3 and 7 # Register that will be assigned to

    case opcode and 7
    of HL: 
        if target == HL: return
        value = ram[registerPair(H, L)]
    else: discard

    case opcode
    of 0x00: discard 
    # NOP
    # No Operation

    of 0x02, 0x12, 0x22, 0x32: 
    #    LD r16, A
    #   Store value in register A into the byte pointed to by register r16 
        if target == HL: 
            ram[registerPair(H, L)] = value
        else: 
            ram[registerPair(target, target+1)] = value


    of 0x40..0x7F: 
    #   LD r8,r8
    #   Load value from one register to another
        if target == HL: 
            ram[registerPair(H, L)] = value
        else: 
            reg[target] = value


    of 0x80..0x8F:
    #   ADD/ADC A,r8
    #   Add the value in r8 to A (with carry)
        let result = reg[A] + value
        reg[A] = uint8 result

        setFlags(z = reg[A] == 0, c = result > 255)

    #    Half-Carry Algorithm Explained: 
    #    https://robdor.com/2016/08/10/gameboy-emulator-half-carry-flag
        halfCarry = (((value and 0xF) + (reg[A] and 0xF)) and 0x10) == 0x10

    of 0x90..0x9F: 
    #   ADD/ADC A,r8
    #   Subtract the value in r8 from A (with carry)
        let result = reg[A] - value

        setFlags(h = value > reg[A], z = result == 0)
        halfCarry = (((value and 0xF) - (reg[A] and 0xF)) and 0x10) == 0x10

        reg[A] = result

    of 0xA0..0xB7: 
    #   AND/XOR/OR A,r8
    #   Bitwise AND/XOR/OR between the value in r8 and A 
        reg[A] = case target
        of 4: reg[A] and value
        of 5: reg[A] xor value
        else: reg[A] or value

        setFlags(z = reg[A] == 0, h = reg[A] == 4)

    else:
        echo toHex($rom[pc]), " yet to be implemented"
        quit 0

proc cpu =
    let opcode = int rom[pc]
    execute opcode
    inc cycles
    inc pc
