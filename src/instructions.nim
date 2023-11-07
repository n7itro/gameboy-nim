#[
    Glossary
        u8/i8   8-bit (un)signed integer
        u16     16-bit unsigned integer
        r8      Any of the 8-bit registers (A, B, C, D, E, H, L)
        r16     Any of the general-purpose 16-bit registers (BC, DE, HL)
        pc      Program counter   
]#

include cpu
import std/strutils

proc execute (opcode: int) {.inline.} =
    var
        value = reg[opcode and 7]   # Register we are taking a value from 
        target = opcode shr 3 and 7 # Register that will be assigned to

    case opcode and 7
    of HL: 
        if target == HL: return
        value = memory[getRegisterPair(H, L)]
    else: discard

    case opcode
    of 0x00: discard # No Operation - NOP
    of 0x10: quit 0 # Enter CPU low power mode - STOP

    of 0x20: discard
    # Relative Jump by i8 (-127,127) if the Zero-Flag is set - JR NZ i8

    of 0x30: discard
    # Relative Jump by i8 with No Carry - JR NC i8

    of 0x03, 0x13, 0x23, 0x33, 0x0B, 0x1B, 0x2B, 0x3B: discard # INC/DEC r16
    of 0x04, 0x14, 0x24, 0x34, 0x0C, 0x1C, 0x2C, 0x3C: discard # INC r8
    of 0x05, 0x15, 0x25, 0x35, 0x0D, 0x1D, 0x2D, 0x3D: discard # DEC r8

  
    of 0x01, 0x11, 0x21, 31: 
    # Load u16 value into register r16 - LD n16,u16
        case target
        of B, D, H:
            reg[target] = nextByte()
            reg[target+1] = nextByte()

        else: stackPointer = nextByte() + nextByte()

        inc cycles, 2


    of 0x02, 0x12, 0x22, 0x32: 
    # Store value in register A into the byte pointed to by register r16  - LD r16, A
        if target == HL: 
            memory[getRegisterPair(H, L)] = value
        else: 
            memory[getRegisterPair(target, target+1)] = value
        
        case target
        of B, D:
            memory[getRegisterPair(target, target+1)] = value
        else: # Increment HL afterwards - LD HL+/-, A 
            memory[getRegisterPair(H, L)] = value

            var newValue = getRegisterPair(H, L)
            if target == HL: inc newValue else: dec newValue

            setRegisterPair(newValue, H, L)

        inc cycles


    of 0x06, 0x16, 0x26, 0x36: 
    # Load value u8 into register r8 - LD r8, u8
        inc cycles
        discard


    of 0x40..0x7F: 
    # Load value from one register to another - LD r8,r8
        if target == HL: 
            memory[getRegisterPair(H, L)] = value
        else: 
            reg[target] = value


    of 0x80..0x8F:
    # Add the value in r8 to A (with carry) - ADD/ADC A,r8
        let result = reg[A] + value

        #   Half-Carry Algorithm Explained: 
        #   https://robdor.com/2016/08/10/gameboy-emulator-half-carry-flag
        setFlags(c = result > 255, z = reg[A] == 0,
        h = (((value and 0xF) + (reg[A] and 0xF)) and 0x10) == 0x10)

        reg[A] = result


    of 0x90..0x9F: 
    # Subtract the value in r8 from A (with carry) - SUB/SUBC A,r8
        let result = reg[A] - value

        setFlags(c = value > reg[A], z = result == 0,
        h = (((value and 0xF) - (reg[A] and 0xF)) and 0x10) == 0x10)

        reg[A] = result


    of 0xA0..0xB7:  
    # Bitwise AND/XOR/OR between the value in r8 and A - AND/XOR/OR A,r8
        reg[A] = case target
        of 4: reg[A] and value
        of 5: reg[A] xor value
        else: reg[A] or value

        setFlags(z = reg[A] == 0, h = reg[A] == 4)


    of 0xB8..0xBF:
    # Subtract value in r8 from A and set the flags, 
    # but don't store the result - CP A,r8
        let result = reg[A] - value

        setFlags(h = value > reg[A], z = result == 0)
        halfCarry = (((value and 0xF) - (reg[A] and 0xF)) and 0x10) == 0x10


    else:
        echo toHex opcode, " yet to be implemented"
        quit 0


proc cpu =
    let opcode = int rom[pc]

    execute opcode
    inc cycles
    inc pc
