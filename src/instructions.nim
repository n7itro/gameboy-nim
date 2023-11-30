#[
    Glossary
        u8/i8   8-bit (un)signed integer
        u16     16-bit unsigned integer
        r8      Any of the 8-bit registers (A, B, C, D, E, H, L)
        r16     Any of the general-purpose 16-bit registers (BC, DE, HL)
        pc      Program counter   

    
    Opcode reference:
        https://rgbds.gbdev.io/docs/v0.6.1/gbz80.7/
        https://izik1.github.io/gbops/
]#

import std/strutils
include cpu


proc execute (opcode: int) =
    var
        value = reg[opcode and 7]   # Value of the register we are taking a value from 
        target = opcode shr 3 and 7 # Register that will be assigned to


    if (opcode and 7) == HL: 
        if target == HL: 
            return

        value = memory[getPair(H, L)]

    case opcode
    of 0x00, 0x10: 
        # No Operation - NOP
        # Enter CPU low power mode - STOP
        discard 


    of 0x20, 0x30: 
        # Relative Jump by i8 if condition is set - JR CC i8
        if 
            (opcode == 0x20 and not flags.zero) or 
            (opcode == 0x30 and not flags.carry):

            inc cycles
            pc = nextByte 2
            
        else:
            inc pc
        
        inc cycles


    of 0x03, 0x13, 0x23, 0x33, 0x0B, 0x1B, 0x2B, 0x3B: 
        # INC/DEC r16
        inc cycles

        if opcode == 0x33:
            inc(stackPointer)
            return
                
        elif opcode == 0x3B: 
            dec(stackPointer)
            return

        var value = getPair(target, target+1)

        if target mod 2 == 0: 
            inc value
        else: 
            dec value

        setPair(value, target, target+1)
        

    of 0x04, 0x14, 0x24, 0x34, 0x0C, 0x1C, 0x2C, 0x3C: 
        # INC r8
        inc reg[target]
        
        flags = (
            reg[target] == 0, 
            false, 
            (reg[target] and 0xF0) != (reg[value] - 1 and 0xF0), 
            false) 


    of 0x05, 0x15, 0x25, 0x35, 0x0D, 0x1D, 0x2D, 0x3D: 
        # DEC r8
        dec reg[target]

        flags = (
            reg[target] == 0, 
            true, 
            (reg[target] and 0xF0) != (reg[value] + 1 and 0xF0), 
            false) 


    of 0x01, 0x11, 0x21, 31: 
        # Load u16 value into register r16 - LD n16,u16
        case target
        of B, D, H:
            reg[target] = nextByte()
            reg[target+1] = nextByte()

        else: stackPointer = nextByte() + nextByte()

        inc cycles, 2


    of 0x02, 0x12, 0x22, 0x32: 
        # Store value in register A into the byte pointed to by any 16 bit register - LD r16, A
        case target
        of B, D:
            memory[getPair(target, target+1)] = value
        else: # Increment HL afterwards - LD HL+/-, A 
            memory[getPair(H, L)] = value

            var newValue = getPair(H, L)
            if target == HL: 
                inc newValue 
            else: 
                dec newValue

            setPair(newValue, H, L)

        inc cycles


    of 0x06, 0x16, 0x26, 0x36: # LD r8, u8
        inc cycles
        inc(reg[target], nextByte())


    of 0x40..0x7F: 
        # LD r8,r8
        if target == HL: 
            memory[getPair(H, L)] = value
        else: 
            reg[target] = value


    of 0x80..0x8F:
        # ADD/ADC A,r8
        var result = reg[A] + value

                
        if opcode in 0x88..0x8F:
            inc(result, int flags.carry)

        # https://robdor.com/2016/08/10/gameboy-emulator-half-carry-flag
        flags = (
            reg[A] == 0, 
            false, 
            (((value and 0xF) + (reg[A] and 0xF)) and 0x10) == 0x10, 
            result > 255,)

            
        reg[A] = result


    of 0x90..0x9F, 0xB8..0xBF: 
        let result = reg[A] - value
        
        if opcode in 0x98..0x9F:
            inc(value, int flags.carry)

        flags = (
            result == 0,
            true,
            (((value and 0xF) - (reg[A] and 0xF)) and 0x10) == 0x10,
            value > reg[A],)
        
        # Subtract the value in r8 from A (with carry) - SUB/SBC A,r8
        if opcode in 0x90..0x9F:
            reg[A] = result
        
        # Subtract value in r8 from A and set the flags, 
        # but don't store the result - CP A,r8
        else: discard


    of 0xA0..0xB7:  
        # Bitwise AND/XOR/OR between the value in r8 and A - AND/XOR/OR A,r8
        reg[A] = case target
        of 4: reg[A] and value
        of 5: reg[A] xor value
        else: reg[A] or value

        flags = (
            reg[A] == 0, false,
            reg[A] == 4, false)


    else:
        echo toHex opcode, " yet to be implemented"
        quit 0