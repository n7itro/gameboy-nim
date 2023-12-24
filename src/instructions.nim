#[  
    Reference(s):
        https://rgbds.gbdev.io/docs/v0.6.1/gbz80.7
        https://izik1.github.io/gbops
]#

import std/[strutils, tables]
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
    of 0x00, 0x10: discard # STOP/NOP

    of 0x20, 0x30:
        # JR CC i8 (Relative Jump by 8 bit integer if condition is set)
        let condition = toTable {
            0x20: not flags.zero,
            0x30: not flags.carry}
        
        if condition[opcode]:
            inc cycles, 2
            inc pc, nextByte() + 2
        else: 
            inc cycles
            inc pc

    of 0x08: 
        # LD u16, SP
        inc cycles, 4
        let adress: uint16 = (nextByte() shl 8) or nextByte()
        memory[adress] = uint8 (stackPointer and 0xFF)
        memory[adress+1] = uint8 ((stackPointer shr 8) and 0xFF)

    of 0xC2, 0xD2, 0xC3, 0xCA, 0xDA, 0xE9:
        # JP CC n16 (Jump to 16 bit address if condition is set)
        let condition = toTable {
            0xC2: not flags.zero,
            0xD2: not flags.carry,
            0xCA: flags.zero,
            0xDA: flags.carry,
            0xC3: true
        }
        if opcode == 0xE9:
            pc = getPair(H, L)

        elif condition[opcode]:
            inc cycles, 3
            pc = (nextByte() shl 8) or nextByte()

        else:
            inc pc, 2
            inc cycles, 2
    
    of 0x03, 0x13, 0x23, 0x33, 0x0B, 0x1B, 0x2B, 0x3B: 
        # INC/DEC r16
        inc cycles

        if opcode == 0x33:
            inc stackPointer
            return 
        elif opcode == 0x3B: 
            dec stackPointer
            return

        var value = getPair(target, target+1)

        if target mod 2 == 0: 
            inc value
        else: 
            dec value

        setPair target, target+1, value

    of 0x04, 0x14, 0x24, 0x34, 0x0C, 0x1C, 0x2C, 0x3C: 
        # INC r8
        inc reg[target]
        
        flags = (
            reg[target] == 0, 
            false, 
            (reg[target] and 0xF0) != (reg[target] - 1 and 0xF0), 
            false) 

    of 0x05, 0x15, 0x25, 0x35, 0x0D, 0x1D, 0x2D, 0x3D: 
        # DEC r8
        dec reg[target]

        flags = (
            reg[target] == 0, 
            true, 
            (reg[target] and 0xF0) != (reg[target] + 1 and 0xF0), 
            false) 

    of 0x01, 0x11, 0x21, 0x31: 
        # LD n16,u16 (Load 16 bit unsigned integer into 16 bit register)
        case target
        of B, D, H:
            reg[target] = nextByte()
            reg[target+1] = nextByte()

        else: stackPointer = nextByte() + nextByte()

        inc cycles, 2

    of 0x02, 0x12, 0x22, 0x32: 
        # Store value in register A into the byte pointed to by a 16 bit register 
        inc cycles

        # LD r16, A
        if target == B or target == D:
            memory[getPair(target, target+1)] = value
            return

        # LD HL+/-, A
        memory[getPair(H, L)] = value

        var newValue = getPair(H, L)
        if target == HL: 
            inc newValue 
        else: 
            dec newValue

        setPair H, L, newValue

    of 0x0A, 0x1A, 0x2A, 0x3A:
        # Load value from the byte pointed to by a 16 bit register into register A
        inc cycles
        
        if target == B or target == D:
            reg[A] = memory[getPair(target, target+1)]
            return

        value = memory[getPair(H, L)]
        if target == HL: inc value else: dec value
        reg[A] = value

    of 0x06, 0x16, 0x26, 0x36, 0x0E, 0x1E, 0x2E, 0x3E: 
        # LD r8, u8
        if target == HL:
            memory[getPair(H, L)] = nextByte()
        else: 
            reg[target] = nextByte()
        inc cycles

    of 0x40..0x7F: 
        # LD r8,r8
        if target == HL: 
            memory[getPair(H, L)] = value
        else: 
            reg[target] = value
        
    of 0x80..0x8F, 0xC6, 0xCE:
        # ADD/ADC A,u8/r8
        var result: uint8
        case opcode
        of 0xC6, 0xCE: 
            result = reg[A] + nextByte()
            inc cycles
        else: 
            result = reg[A] + value

        if opcode in 0x88..0x8F or opcode == 0xCE:
            inc result, int(flags.carry)

        # https://robdor.com/2016/08/10/gameboy-emulator-half-carry-flag
        flags = (
            reg[A] == 0, 
            false, 
            (((value and 0xF) + (reg[A] and 0xF)) and 0x10) == 0x10, 
            result > 255,)
            
        reg[A] = result

    of 0x90..0x9F, 0xB8..0xBF, 0xD6, 0xDE, 0xFE: 
        # SUB/SBC A,r8/u8
        var result: uint8
        case opcode
        of 0xD6, 0xDE, 0xFE: 
            result = reg[A] - nextByte()
            inc cycles
        else: 
            result = reg[A] - value
        
        if opcode in 0x98..0x9F or opcode in [0xD6, 0xDE]:
            inc(result, int flags.carry)

        flags = (
            result == 0,
            true,
            (((value and 0xF) - (reg[A] and 0xF)) and 0x10) == 0x10,
            value > reg[A])
        
        if opcode notin 0xB8..0xBF and opcode != 0xFE:
            reg[A] = result

    of 0xA0..0xB7, 0xE6, 0xEE, 0xF6:  
        # AND/XOR/OR A,r8 (Bitwise operation between the value in register and A)
        if opcode in 0xA0..0xB7:
            reg[A] = case opcode
            of 4: reg[A] and value
            of 5: reg[A] xor value
            else: reg[A] or value
            
        else:
            reg[A] = case opcode
            of 4: reg[A] and nextByte()
            of 5: reg[A] xor nextByte()
            else: reg[A] or nextByte()
            inc cycles

        flags = (
            reg[A] == 0, false,
            target == 4, false)

    of 0xC0, 0xD0, 0xC8, 0xD8, 0xC9:
        # RET CC (Return from subroutine if condition is set)
        proc ret =
            inc cycles, 2
            inc stackPointer, 2
            pc = stackPointer
        
        let condition = toTable {
            0xC0: not flags.zero,
            0xD0: not flags.carry,
            0xC8: flags.zero,
            0xD8: flags.carry
        }
        if opcode == 0xC9: ret()

        elif condition[opcode]:
            ret()
            inc cycles

        inc cycles

    of 0xC1, 0xD1, 0xE1:
        # POP 16 bit register into the stack
        setPair B, C, stackPointer
        inc stackPointer, 2
        inc cycles, 2
    
    of 0xC5, 0xD5, 0xE5:
        # PUSH 16 bit register onto the stack
        dec stackPointer, 2
        inc cycles, 3
        stackPointer = getPair(B, C)

    of 0xC7, 0xD7, 0xE7, 0xF7, 0xCF, 0xDF, 0xEF, 0xFF:
        # RST (Call subroutine)
        stackPointer = pc + 1
        inc cycles, 3
        pc = uint16 @[0x0, 0x8, 0x10, 0x18, 0x20, 0x28, 0x30, 0x38][target]
     
    of 0xC4, 0xD4, 0xCC, 0xDC, 0xCD:
        # Call cc, n16 (Call address n16 if condition cc is met)
        let condition = toTable {
            0xC4: not flags.zero,
            0xD4: not flags.carry,
            0xCC: flags.zero,
            0xDC: flags.carry,
            0xCD: true,
        }

        if condition[opcode]:
            inc cycles, 5
            dec stackPointer, 2
            stackPointer = (nextByte() shl 8) or nextByte()

        else:
            inc cycles, 2
            inc pc, 2

    else:
        echo toHex opcode, " yet to be implemented"
        quit 0
