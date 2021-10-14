function love.load()
    print("Starting!")

    breakpoints = {}
    -- breakpoints[0x0100] = true
    -- breakpoints[0xC018] = true
    -- breakpoints[0xC062] = true
    -- breakpoints[0xC17C] = true

    -- breakpoints[0xC31D] = true

    -- breakpoints[0xC418] = true
    -- breakpoints[0xC481] = true

    -- breakpoints[0xC491] = true
    -- breakpoints[0xC34A] = true
    -- breakpoints[0xC34D] = true
    -- breakpoints[0xC352] = true

    -- breakpoints[0xC31A] = true

    -- breakpoints[0xC659] = true
    -- breakpoints[0xC67C] = true
    -- breakpoints[0xC687] = true
    -- breakpoints[0xC68D] = true
    -- breakpoints[0xC693] = true
    -- breakpoints[0xC6AB] = true

    run = true
    halt = false
    dbg = false

    scale = 1

    love.window.setMode(160 * scale, 144 * scale)
    -- love.window.setMode(160 * 4, 144 * 4)
    love.graphics.setDefaultFilter("nearest", "nearest")
    canvas = love.graphics.newCanvas(256, 256)
    love.graphics.setCanvas(canvas)
    love.graphics.clear(1, 1, 1)
    love.graphics.setCanvas()

    hex1 = "0x%01X"
    hex2 = "0x%02X"
    hex4 = "0x%04X"
    oct3 = "%03o"

    memory = {}
    memory.get = function(index)
        local value = memory[index]
        if value == nil then
            print("index: " .. hex4:format(index))
            debug_log()
        end
        return value
    end
    memory.set = function(index, value)
        if value == nil then debug_log() end
        -- if index == 0xDD02 then dbg = true end
        if index == 0xFF04 then memory[index] = 0 end
        if index == 0xFF0F and value ~= 0xE1 then
            value = bit.bor(value, 0xE0)
            -- dbg = true
            -- run = false
            -- debug_log()
        end
        if index == 0xFF44 then memory[index] = 0 end
        if index == 0xFF50 and value == 1 then
            -- unmap boot rom
            file_to_bytes(io.open(rom_file, "rb"), memory, 0x0000)
        end
        -- if index == 0xFF42 then print("scrolly: " .. hex2:format(value)) end

        while value > 0xFF do value = value - 0x100 end

        memory[index] = value
    end
    memory.inc = function(index)
        local value = memory.get(index) + 1
        while value > 0xFF do value = value - 0x100 end
        memory.set(index, value)
    end
    memory.dec = function(index) memory.set(index, memory.get(index) - 1) end

    memory.set_IF = function(index, value)
        memory.set(0xFF0F, set_bit(memory.get(0xFF0F), value, index))
    end
    memory.set_IE = function(index, value)
        memory.set(0xFFFF, set_bit(memory.get(0xFFFF), value, index))
    end

    colours = {1, 0.66, 0.33, 0}

    interrupts = {0x40, 0x48, 0x50, 0x58, 0x60}

    scancount = 456
    instlen = 0
    instcycles = 0
    div_clocksum = 0
    timer_clocksum = 0

    print("Initializing memory!")
    init_array(memory, 64 * 1024)

    print("Initializing Registers!")
    regs = {}
    -- only value that is initialized before boot rom is PC
    -- F reg:
    -- 7: Zero Flag
    -- 6: Add/Sub Flag (BCD)
    -- 5: Half Carry Flag (BCD)
    -- 4: Carry Flag
    -- 3-0: NOT USED / ALWAYS ZERO
    regs.AF = 0x0000
    regs.BC = 0x0000
    regs.DE = 0x0000
    regs.HL = 0x0000
    regs.SP = 0x0000 -- stack pointer
    regs.PC = 0x0000 -- program counter
    regs.IME = 0
    -- inc program counter
    regs.inc_PC = function(n)
        regs.set_PC(regs.get_PC() + n)
        instlen = instlen + 1
    end

    -- set A, B, C, D, E, H, and L registers

    regs.set_A = function(value)
        if value == nil then debug_log() end
        regs.set_AF(set_hi16(regs.AF, value))
    end
    regs.set_B = function(value) regs.set_BC(set_hi16(regs.BC, value)) end
    regs.set_C = function(value) regs.set_BC(set_lo16(regs.BC, value)) end
    regs.set_D = function(value) regs.set_DE(set_hi16(regs.DE, value)) end
    regs.set_E = function(value) regs.set_DE(set_lo16(regs.DE, value)) end
    regs.set_H = function(value) regs.set_HL(set_hi16(regs.HL, value)) end
    regs.set_L = function(value) regs.set_HL(set_lo16(regs.HL, value)) end
    regs["set_(HL)"] = function(value) memory.set(regs.HL, value) end

    -- get A, B, C, D, E, H, and L registers

    regs.get_A = function() return get_hi16(regs.get_AF()) end
    regs.get_B = function() return get_hi16(regs.get_BC()) end
    regs.get_C = function() return get_lo16(regs.get_BC()) end
    regs.get_D = function() return get_hi16(regs.get_DE()) end
    regs.get_E = function() return get_lo16(regs.get_DE()) end
    regs.get_H = function() return get_hi16(regs.get_HL()) end
    regs.get_L = function() return get_lo16(regs.get_HL()) end
    regs["get_(HL)"] = function() return memory.get(regs.HL) end

    regs.set_AF = function(value) regs.AF = bit.band(value, 0xFFF0) end
    regs.set_BC = function(value) regs.BC = value end
    regs.set_DE = function(value) regs.DE = value end
    regs.set_HL = function(value) regs.HL = value end
    regs.set_PC = function(value) regs.PC = value end
    regs.set_SP = function(value) regs.SP = value end

    regs.get_AF = function() return regs.AF end
    regs.get_BC = function() return regs.BC end
    regs.get_DE = function() return regs.DE end
    regs.get_HL = function() return regs.HL end
    regs.get_PC = function() return regs.PC end
    regs.get_SP = function() return regs.SP end

    regs.set_flag = function(b, i) regs.set_AF(set_bit(regs.AF, b, i)) end
    regs.set_z = function(value) regs.set_flag(value, 7) end
    regs.set_n = function(value) regs.set_flag(value, 6) end
    regs.set_h = function(value) regs.set_flag(value, 5) end
    regs.set_c = function(value) regs.set_flag(value, 4) end

    regs.get_flag = function(i) return get_bit(regs.AF, i) end
    regs.get_z = function() return regs.get_flag(7) end
    regs.get_n = function() return regs.get_flag(6) end
    regs.get_h = function() return regs.get_flag(5) end
    regs.get_c = function() return regs.get_flag(4) end

    regs.get_NZF = function() return regs.get_z() == 0 end
    regs.get_ZF = function() return regs.get_z() == 1 end
    regs.get_NCF = function() return regs.get_c() == 0 end
    regs.get_CF = function() return regs.get_c() == 1 end

    regs.set_IME = function(value) regs.IME = value end
    regs.get_IME = function() return regs.IME end

    print("Loading boot rom!")
    -- 01-special.gb -- FAILED -- POP AF FAILED #5
    -- 02-interrupts.gb -- FAILED -- TIMER DOESNT WORK FAILED #4
    -- 03-op sp,hl.gb -- FAILED -- OVERFLOW
    -- 04-op r,imm.gb -- FAILED -- CE DE
    -- 05-op rp.gb -- PASSED
    -- 06-ld r,r.gb -- PASSED
    -- 07-jr,jp,call,ret,rst.gb -- FAILED -- INF LOOP
    -- 08-misc instrs.gb -- FAILED -- INF LOOP
    -- 09-op r,r.gb -- FAILED -- -LOTS OF HEX-
    -- 10-bit ops.gb -- PASSED
    -- 11-op a,(hl).gb -- FAILED
    -- tetris -- FAILED
    -- drmario -- FAILED
    -- pkred -- FAILED
    rom_file = "tests/03-op sp,hl.gb"
    file_to_bytes(io.open(rom_file, "rb"), memory, 0x0000)
    file_to_bytes(io.open("tests/bios.gb", "rb"), memory, 0x0000)

    print("Loading opcode tables!")
    lookups = {}
    lookups.r = {}
    lookups.r[0] = "B"
    lookups.r[1] = "C"
    lookups.r[2] = "D"
    lookups.r[3] = "E"
    lookups.r[4] = "H"
    lookups.r[5] = "L"
    lookups.r[6] = "(HL)"
    lookups.r[7] = "A"

    lookups.rp = {}
    lookups.rp[0] = "BC"
    lookups.rp[1] = "DE"
    lookups.rp[2] = "HL"
    lookups.rp[3] = "SP"

    lookups.rp2 = {}
    lookups.rp2[0] = "BC"
    lookups.rp2[1] = "DE"
    lookups.rp2[2] = "HL"
    lookups.rp2[3] = "AF"

    lookups.cc = {}
    lookups.cc[0] = regs.get_NZF
    lookups.cc[1] = regs.get_ZF
    lookups.cc[2] = regs.get_NCF
    lookups.cc[3] = regs.get_CF

    lookups.alu = {}
    lookups.alu[0] = "ADD A"
    lookups.alu[1] = "ADC A"
    lookups.alu[2] = "SUB"
    lookups.alu[3] = "SBC A"
    lookups.alu[4] = "AND"
    lookups.alu[5] = "XOR"
    lookups.alu[6] = "OR"
    lookups.alu[7] = "CP"

    lookups.rot = {}
    lookups.rot[0] = "RLC"
    lookups.rot[1] = "RRC"
    lookups.rot[2] = "RL"
    lookups.rot[3] = "RR"
    lookups.rot[4] = "SLA"
    lookups.rot[5] = "SRA"
    lookups.rot[6] = "SWAP"
    lookups.rot[7] = "SRL"

    insts = {}
    insts.NOP = function()
        instcycles = 1
        -- print("NOP")
        -- debug_log()
    end
    insts.STOP = function()
        instcycles = 0
        print("STOP")
    end
    insts.JR = function(relative)
        instcycles = 3
        regs.set_PC(regs.get_PC() + relative)
    end
    insts.JRC = function(condition, relative)
        if condition then
            instcycles = 3
            regs.set_PC(regs.get_PC() + relative)
        else
            instcycles = 2
        end
    end
    insts.INC8 = function(value)
        instcycles = 1

        value = bit.band(value + 1, 0xFF)

        regs.set_z(value == 0 and 1 or 0)
        regs.set_n(0)
        regs.set_h(bit.band(value, 0xF) == 0 and 1 or 0)

        return value
    end
    insts.DEC8 = function(value)
        instcycles = 1

        value = bit.band(value - 1, 0xFF)

        regs.set_z(value == 0 and 1 or 0)
        regs.set_n(1)
        regs.set_h(bit.band(value, 0xF) == 0xF and 1 or 0)

        return value
    end
    insts.RLCA = function()
        instcycles = 1

        shifted = get_bit(regs.get_A(), 7)
        regs.set_A(bit.band(bit.lshift(regs.get_A(), 1) + shifted, 0xFF))
        regs.set_z(0)
        regs.set_n(0)
        regs.set_h(0)
        regs.set_c(shifted)
    end
    insts.RRCA = function()
        instcycles = 1

        shifted = get_bit(regs.get_A(), 0)
        regs.set_A(bit.rshift(regs.get_A(), 1))
        regs.set_z(0)
        regs.set_n(0)
        regs.set_h(0)
        regs.set_c(shifted)
    end
    insts.RRA = function()
        instcycles = 1

        shifted = get_bit(regs.get_A(), 0)
        regs.set_A(bit.rshift(regs.get_A(), 1))
        regs.set_A(set_bit(regs.get_A(), regs.get_c(), 7))
        regs.set_z(0)
        regs.set_n(0)
        regs.set_h(0)
        regs.set_c(shifted)
    end
    insts.RLA = function()
        instcycles = 1

        shifted = get_bit(regs.get_A(), 7)
        regs.set_A(bit.band(bit.lshift(regs.get_A(), 1) + regs.get_c(), 0xFF))
        regs.set_z(0)
        regs.set_n(0)
        regs.set_h(0)
        regs.set_c(shifted)
    end
    -- https://ehaskins.com/2018-01-30%20Z80%20DAA/
    insts.DAA = function()
        instcycles = 1

        local correction = 0

        local c_flag = 0

        local value = regs.get_A()

        if regs.get_h() or (not regs.get_n() and bit.band(value, 0xF) > 9) then
            correction = 0x6
        end

        if regs.get_c() or (not regs.get_n() and value > 0x99) then
            correction = bit.bor(correction, 0x60)
            c_flag = regs.get_c()
        end

        value = value + regs.get_n() and -correction or correction

        value = bit.band(value, 0xff)

        regs.set_z(value == 0 and regs.get_z() or 0)
        regs.set_h(0)
        regs.set_c(c_flag)
    end
    insts.CPL = function()
        instcycles = 1

        regs.set_A(bit.bnot(regs.get_A()))
        regs.set_n(1)
        regs.set_h(1)
    end
    insts.SCF = function()
        instcycles = 1

        regs.set_n(0)
        regs.set_h(0)
        regs.set_c(1)
    end
    insts.CCF = function()
        instcycles = 1

        regs.set_n(0)
        regs.set_h(0)
        regs.set_c(bit.bnot(regs.get_c()))
    end
    insts.HALT = function()
        instcycles = 0
        halt = true
    end
    insts["ADD A"] = function(value)
        if type(value) == "string" then
            instcycles = 1
            value = regs["get_" .. value]()
        else
            instcycles = 2
        end

        overflow3 = get_bit(get_lo8(regs.get_A()) + get_lo8(value), 4)

        value = regs.get_A() + value

        overflow7 = get_bit(value, 8)

        value = bit.band(value, 0xFF)

        regs.set_A(value)

        regs.set_z(value == 0 and 1 or 0)
        regs.set_n(0)
        regs.set_h(overflow3)
        regs.set_c(overflow7)
    end
    insts["ADC A"] = function(value)
        if type(value) == "string" then
            instcycles = 1
            value = regs["get_" .. value]()
        else
            instcycles = 2
        end

        value = value + regs.get_c()

        overflow3 = get_bit(get_lo8(regs.get_A()) + get_lo8(value), 4)

        value = regs.get_A() + value

        overflow7 = get_bit(value, 8)

        value = bit.band(value, 0xFF)

        regs.set_A(value)

        regs.set_z(value == 0 and 1 or 0)
        regs.set_n(0)
        regs.set_h(overflow3)
        regs.set_c(overflow7)
    end
    insts["SUB"] = function(value)
        if type(value) == "string" then
            instcycles = 1
            value = regs["get_" .. value]()
        else
            instcycles = 2
        end

        regs.set_c(value > regs.get_A() and 1 or 0)
        regs.set_h(get_lo8(value) > get_lo8(regs.get_A()) and 1 or 0)

        value = regs.get_A() - value

        regs.set_A(value)

        regs.set_z(value == 0 and 1 or 0)
        regs.set_n(1)
    end
    insts["SBC A"] = function(value)
        if type(value) == "string" then
            instcycles = 1
            value = regs["get_" .. value]()
        else
            instcycles = 2
        end

        value = value + regs.get_c()

        regs.set_c(value > regs.get_A() and 1 or 0)
        regs.set_h(get_lo8(value) > get_lo8(regs.get_A()) and 1 or 0)

        value = regs.get_A() - value

        regs.set_A(value)

        regs.set_z(value == 0 and 1 or 0)
        regs.set_n(1)
    end
    insts["AND"] = function(value)
        if type(value) == "string" then
            instcycles = 1
            value = regs["get_" .. value]()
        else
            instcycles = 2
        end

        value = bit.band(regs.get_A(), value)

        regs.set_A(value)

        regs.set_z(value == 0 and 1 or 0)
        regs.set_n(0)
        regs.set_h(1)
        regs.set_c(0)
    end
    insts["XOR"] = function(value)
        if type(value) == "string" then
            instcycles = 1
            value = regs["get_" .. value]()
        else
            instcycles = 2
        end

        value = bit.bxor(regs.get_A(), value)

        regs.set_A(value)

        regs.set_z(value == 0 and 1 or 0)
        regs.set_n(0)
        regs.set_h(0)
        regs.set_c(0)
    end
    insts["OR"] = function(value)
        if type(value) == "string" then
            instcycles = 1
            value = regs["get_" .. value]()
        else
            instcycles = 2
        end

        value = bit.bor(regs.get_A(), value)

        regs.set_A(value)

        regs.set_z(value == 0 and 1 or 0)
        regs.set_n(0)
        regs.set_h(0)
        regs.set_c(0)
    end
    insts["CP"] = function(value)
        if type(value) == "string" then
            instcycles = 1
            value = regs["get_" .. value]()
        else
            instcycles = 2
        end

        regs.set_c(value > regs.get_A() and 1 or 0)
        regs.set_h(get_lo8(value) > get_lo8(regs.get_A()) and 1 or 0)

        value = regs.get_A() - value

        regs.set_z(value == 0 and 1 or 0)
        regs.set_n(1)
    end
    insts.RET = function()
        instcycles = 4

        local low = memory.get(regs.get_SP())
        regs.set_SP(regs.get_SP() + 1)
        local high = memory.get(regs.get_SP())
        regs.set_SP(regs.get_SP() + 1)

        regs.set_PC(set_hilo16(high, low))
    end
    insts.RETC = function(condition)
        if condition then
            instcycles = 5

            local low = memory.get(regs.get_SP())
            regs.set_SP(regs.get_SP() + 1)
            local high = memory.get(regs.get_SP())
            regs.set_SP(regs.get_SP() + 1)

            regs.set_PC(set_hilo16(high, low))
        else
            instcycles = 2
        end
    end
    insts.RETI = function()
        instcycles = 4

        local low = memory.get(regs.get_SP())
        regs.set_SP(regs.get_SP() + 1)
        local high = memory.get(regs.get_SP())
        regs.set_SP(regs.get_SP() + 1)

        regs.set_PC(set_hilo16(high, low))

        regs.set_IME(1)
    end
    insts.JP = function(address)
        -- instcycles = ? (determined on whether its HL or not)
        regs.set_PC(address)
    end
    insts.JPC = function(condition, address)
        if condition then
            instcycles = 4
            regs.set_PC(address)
        else
            instcycles = 3
        end
    end
    insts.ADD = function(register, value)
        -- instcycles = ? 
        threequaterreg = bit.band(register, 0x0FFF)
        threequaterval = bit.band(value, 0x0FFF)

        value = register + value

        regs.set_n(0)
        regs.set_h(bit.rshift(threequaterreg + threequaterval, 12))
        regs.set_c(bit.rshift(value, 16))

        return bit.band(value, 0xFFFF)
    end
    insts.ADDSPD = function(value)
        overflow3 = get_bit(get_lo8(regs.get_SP()) + get_lo8(value), 4)

        value = regs.get_SP() + value

        overflow7 = get_bit(value, 8)

        regs.set_z(value == 0 and 1 or 0)
        regs.set_n(0)
        regs.set_h(overflow3)
        regs.set_c(overflow7)

        return value
    end
    insts.POP = function()
        instcycles = 3

        local low = memory.get(regs.get_SP())
        regs.set_SP(regs.get_SP() + 1)
        local high = memory.get(regs.get_SP())
        regs.set_SP(regs.get_SP() + 1)

        return set_hilo16(high, low)
    end
    insts.DI = function()
        instcycles = 1

        regs.set_IME(0)
    end
    insts.EI = function()
        instcycles = 1

        regs.set_IME(1)
    end
    insts.CALL = function(address)
        instcycles = 6

        regs.set_SP(regs.get_SP() - 1)
        memory.set(regs.get_SP(), get_hi16(regs.get_PC()))
        regs.set_SP(regs.get_SP() - 1)
        memory.set(regs.get_SP(), get_lo16(regs.get_PC()))

        regs.set_PC(address)
    end
    insts.CALLC = function(condition, address)
        if condition then
            instcycles = 6

            regs.set_SP(regs.get_SP() - 1)
            memory.set(regs.get_SP(), get_hi16(regs.get_PC()))
            regs.set_SP(regs.get_SP() - 1)
            memory.set(regs.get_SP(), get_lo16(regs.get_PC()))

            regs.set_PC(address)
        else
            instcycles = 3
        end
    end
    insts.PUSH = function(value)
        instcycles = 4

        regs.set_SP(regs.get_SP() - 1)
        memory.set(regs.get_SP(), get_hi16(value))
        regs.set_SP(regs.get_SP() - 1)
        memory.set(regs.get_SP(), get_lo16(value))
    end
    insts.RST = function(value)
        instcycles = 4

        regs.set_SP(regs.get_SP() - 1)
        memory.set(regs.get_SP(), get_hi16(regs.get_PC()))
        regs.set_SP(regs.get_SP() - 1)
        memory.set(regs.get_SP(), get_lo16(regs.get_PC()))

        regs.set_PC(value)
    end
    insts.RLC = function(register)
        if register == "(HL)" then
            instcycles = 4
        else
            instcycles = 2
        end

        shifted = get_bit(regs["get_" .. register](), 7)

        local value = bit.band(bit.lshift(regs["get_" .. register](), 1) +
                                   shifted, 0xFF)
        regs["set_" .. register](value)

        regs.set_z(value == 0 and 1 or 0)
        regs.set_n(0)
        regs.set_h(0)
        regs.set_c(shifted)
    end
    insts.RRC = function(register)
        if register == "(HL)" then
            instcycles = 4
        else
            instcycles = 2
        end

        shifted = get_bit(regs["get_" .. register](), 0)

        local value = bit.rshift(regs["get_" .. register](), 1)
        regs["set_" .. register](value)

        regs.set_z(value == 0 and 1 or 0)
        regs.set_n(0)
        regs.set_h(0)
        regs.set_c(shifted)
    end
    insts.RL = function(register)
        if register == "(HL)" then
            instcycles = 4
        else
            instcycles = 2
        end

        shifted = get_bit(regs["get_" .. register](), 7)

        local value = bit.band(bit.lshift(regs["get_" .. register](), 1) +
                                   regs.get_c(), 0xFF)
        regs["set_" .. register](value)

        regs.set_z(value == 0 and 1 or 0)
        regs.set_n(0)
        regs.set_h(0)
        regs.set_c(shifted)
    end
    insts.RR = function(register)
        if register == "(HL)" then
            instcycles = 4
        else
            instcycles = 2
        end

        local reg_val = regs["get_" .. register]()

        shifted = get_bit(reg_val, 0)

        local value = bit.rshift(reg_val, 1)
        value = set_bit(value, regs.get_c(), 7)
        regs["set_" .. register](value)

        regs.set_z(value == 0 and 1 or 0)
        regs.set_n(0)
        regs.set_h(0)
        regs.set_c(shifted)
    end
    insts.SLA = function(register)
        if register == "(HL)" then
            instcycles = 4
        else
            instcycles = 2
        end

        shifted = get_bit(regs["get_" .. register](), 7)
        local value = bit.band(bit.lshift(regs["get_" .. register](), 1), 0xFF)
        regs["set_" .. register](value)
        regs.set_z(value == 0 and 1 or 0)
        regs.set_n(0)
        regs.set_h(0)
        regs.set_c(shifted)
    end
    insts.SRA = function(register)
        if register == "(HL)" then
            instcycles = 4
        else
            instcycles = 2
        end

        shifted = get_bit(regs["get_" .. register](), 0)
        bit7 = get_bit(regs["get_" .. register](), 7)
        local value = bit.rshift(regs["get_" .. register](), 1)
        value = set_bit(regs["get_" .. register](), bit7, 7)
        regs["set_" .. register](value)
        regs.set_z(value == 0 and 1 or 0)
        regs.set_n(0)
        regs.set_h(0)
        regs.set_c(shifted)
    end
    insts.SWAP = function(register)
        if register == "(HL)" then
            instcycles = 4
        else
            instcycles = 2
        end

        local value = regs["get_" .. register]()
        value = set_hilo8(get_lo8(value), get_hi8(value))

        regs["set_" .. register](value)

        regs.set_z(value == 0 and 1 or 0)
        regs.set_n(0)
        regs.set_h(0)
        regs.set_c(shifted)
    end
    insts.SRL = function(register)
        if register == "(HL)" then
            instcycles = 4
        else
            instcycles = 2
        end

        shifted = get_bit(regs["get_" .. register](), 0)
        local value = bit.rshift(regs["get_" .. register](), 1)
        regs["set_" .. register](value)
        regs.set_z(value == 0 and 1 or 0)
        regs.set_n(0)
        regs.set_h(0)
        regs.set_c(shifted)
    end
    insts.BIT = function(i, register)
        if register == "(HL)" then
            instcycles = 3
        else
            instcycles = 2
        end

        local value = get_bit(regs["get_" .. register](), i)

        regs.set_z(value == 0 and 1 or 0)

        regs.set_n(0)
        regs.set_h(1)
    end
    insts.RES = function(i, register)
        if register == "(HL)" then
            instcycles = 4
        else
            instcycles = 2
        end

        regs["set_" .. register](set_bit(regs["get_" .. register](), 0, i))
    end
    insts.SET = function(i, register)
        if register == "(HL)" then
            instcycles = 4
        else
            instcycles = 2
        end

        regs["set_" .. register](set_bit(regs["get_" .. register](), 1, i))
    end

    -- DEBUG

    memory.set(0xFF0F, 0xE1)

    print("Booting!")
end

function debug_log()
    print()
    print()
    print("AF: " .. (regs.AF ~= nil and hex4:format(regs.AF) or "nil"))
    print("BC: " .. (regs.BC ~= nil and hex4:format(regs.BC) or "nil"))
    print("DE: " .. (regs.DE ~= nil and hex4:format(regs.DE) or "nil"))
    print("HL: " .. (regs.HL ~= nil and hex4:format(regs.HL) or "nil"))
    print("SP: " .. (regs.SP ~= nil and hex4:format(regs.SP) or "nil"))
    print("PC: " .. (regs.PC ~= nil and hex4:format(regs.PC) or "nil"))

    print("FF0F: " .. hex2:format(memory.get(0xFF0F)))
    print("FFFF: " .. hex2:format(memory.get(0xFFFF)))

    local start = math.max(regs.PC - (regs.PC % 8) - 8, 0)
    for i = start, start + 31 do
        if i % 8 == 0 then
            if regs.PC >= i and regs.PC <= i + 7 then
                io.write("\n        ")
                for j = 1, regs.PC % 8 do io.write("      ") end
                io.write("____")
            end
            io.write("\n" .. hex4:format(i) .. ": ")
        end
        io.write(hex2:format(memory[i]) .. ", ")
    end

    print("\n\nSTACK:")
    for i = regs.SP, math.min(regs.SP + 5, 0xFFFD), 1 do
        print(hex4:format(i) .. ": " .. hex2:format(memory[i]))
    end

    print("\n" .. debug.traceback())
end

function love.update(dt)
    while run do
        instlen = 0
        instcycles = -1

        if not halt then
            run_inst()
        else
            instcycles = 1
        end

        if instcycles == -1 then
            print("unset instcycles")
            debug_log()
        end

        if run_graphics() then break end

        run_timer()

        run_interrupts()
    end

    love.graphics.setCanvas(canvas)

    love.graphics.clear(1, 0, 0)
    love.graphics.setColor(1, 1, 1, 1)

    local tile_vram = 0x8000
    local map_vram = 0x9800

    local points = {}
    for i = 0, 1023 do
        local tx = (i % 32) * 8
        local ty = math.floor(i / 32) * 8
        local tile = tile_vram + memory[map_vram + i] * 16
        for y = 0, 7 do
            for x = 0, 7 do draw_tile(points, tx, ty, tile, x, y) end
        end
    end

    love.graphics.points(points)

    love.graphics.setCanvas()

    -- local scrolly = memory[0xFF42]
    -- local scrollx = memory[0xFF43]
    -- print("Vertical blank!")
    -- print(hex2:format(scrollx))
    -- print(hex2:format(scrolly))
    -- print()
    -- print()
end

-- https://emudev.de/gameboy-emulator/interrupts-and-timers/
function run_timer()
    div_clocksum = div_clocksum + instcycles
    if div_clocksum > 0xFF then
        div_clocksum = div_clocksum - 0xFF
        memory.inc(0xFF04)
    end

    if get_bit(memory[0xFF07], 2) == 1 then
        timer_clocksum = timer_clocksum + instcycles * 4

        local freq = 0x1000
        if bit.band(memory[0xFF07], 0x3) == 1 then
            freq = 0x40000
        elseif bit.band(memory[0xFF07], 0x3) == 2 then
            freq = 0x10000
        elseif bit.band(memory[0xFF07], 0x3) == 3 then
            freq = 0x4000
        end

        while timer_clocksum > 0x40000 do
            memory.inc(0xFF05)
            if memory.get(0xFF05) == 0x00 then
                memory.set_IF(3, 1)
                memory.set(0xFF05, memory.get(0xFF06))
            end

            timer_clocksum = timer_clocksum - 0x40000 / freq
        end
    end
end

function run_interrupts()
    if regs.IME == 1 then
        local requested = memory.get(0xFF0F)
        local enabled = memory.get(0xFFFF)

        if requested > 0 then
            for i = 0, 4 do
                if get_bit(requested, i) == 1 and get_bit(enabled, i) == 1 then
                    regs.IME = 0
                    memory.set_IF(i, 0)

                    if not (halt and regs.IME == 0) then
                        local stack_PC = 0
                        stack_PC = regs.get_PC()

                        regs.set_SP(regs.get_SP() - 1)
                        memory.set(regs.get_SP(), get_hi16(stack_PC))
                        regs.set_SP(regs.get_SP() - 1)
                        memory.set(regs.get_SP(), get_lo16(stack_PC))

                        regs.set_PC(interrupts[i + 1])
                    end

                    if halt then halt = false end
                end
            end
        end
    end
end

function run_graphics()
    lcd_status()

    scancount = scancount - instlen

    if scancount <= 0 then
        memory.inc(0xFF44)
        currentline = memory.get(0xFF44)

        scancount = 456

        if currentline == 144 then
            memory.set_IF(0, 1)
            return true
        end

        if currentline > 153 then
            -- memory.set_IF(0, 0)
            memory.set(0xFF44, 0)
        end

        if currentline < 144 then draw_scanline() end
    end

    return false
end

function lcd_status()
    local status = memory[0xFF41]

    -- TODO LCD ENABLE/DISABLE

    local currentline = memory[0xFF44]
    local currentmode = bit.band(status, 0x3)

    local mode = 0
    local req_int = 0

    if currentline >= 144 then
        mode = 1
        status = set_bit(status, 1, 0)
        status = set_bit(status, 0, 1)
        req_int = get_bit(status, 4)
    else
        local mode2_bounds = 456 - 80
        local mode3_bounds = mode2_bounds - 172

        if scancount >= mode2_bounds then
            mode = 2
            status = set_bit(status, 0, 0)
            status = set_bit(status, 1, 1)
            req_int = get_bit(status, 5)
        elseif scancount >= mode3_bounds then
            mode = 3
            status = set_bit(status, 1, 0)
            status = set_bit(status, 1, 1)
        else
            mode = 0
            status = set_bit(status, 0, 0)
            status = set_bit(status, 0, 1)
            req_int = get_bit(status, 3)
        end
    end

    if req_int == 1 and mode ~= currentmode then memory.set_IF(1, 1) end

    if memory.get(0xFF44) == memory.get(0xFF44) then
        status = set_bit(status, 1, 2)
        if get_bit(status, 6) == 1 then memory.set_IF(1, 1) end
    else
        status = set_bit(status, 0, 2)
    end

    memory.set(0xFF41, status)
end

function draw_tile(points, tx, ty, tile_addr, x, y)
    local sx = bit.lshift(1, 7 - x)

    local palette = memory[0xFF47]
    palette = {
        bit.band(palette, 1), bit.band(palette, bit.lshift(1, 1)),
        bit.band(palette, bit.lshift(1, 2)),
        bit.band(palette, bit.lshift(1, 3)),
        bit.band(palette, bit.lshift(1, 4)),
        bit.band(palette, bit.lshift(1, 5)),
        bit.band(palette, bit.lshift(1, 6)), bit.band(palette, bit.lshift(1, 7))
    }
    palette[0] = palette[1] + palette[2]
    palette[1] = bit.rshift(palette[3] + palette[4], 2)
    palette[2] = bit.rshift(palette[5] + palette[6], 4)
    palette[3] = bit.rshift(palette[7] + palette[8], 6)

    local bit0 = bit.band(memory[tile_addr + y * 2], sx) == 0 and 0 or 1
    local bit1 = bit.band(memory[tile_addr + y * 2 + 1], sx) == 0 and 0 or 2
    local point = bit0 + bit1

    -- TODO PALETTE CURRENTLY DISABLED

    points[#points + 1] = {
        x + tx + 0.5, y + ty + 0.5, colours[palette[point]],
        colours[palette[point]], colours[palette[point]], 1
    }
end

function print_vram()
    local scrolly = memory[0xFF42]
    local scrollx = memory[0xFF43]

    local file = io.open("out.txt", "w")

    file:write("scrolly:  " .. scrolly .. "\n")
    file:write("scrollx:  " .. scrollx .. "\n")

    local addr = 0x8000
    for i = addr, 0x83FF, 1 do
        if i % 2 == 0 then file:write("\n" .. hex4:format(i) .. ":  ") end
        file:write(to_bits(memory[i]):gsub("0", " ") .. " ")
    end

    addr = 0x9800
    for i = addr, 0x9BFF, 1 do
        if i % 32 == 0 then file:write("\n" .. hex4:format(i) .. ":  ") end
        file:write(hex2:format(memory[i]) .. " ")
    end

    file:close()
end

function sleep(n)
    if n > 0 then
        os.execute("ping -n " .. tonumber(n + 1) .. " localhost > NUL")
    end
end

function love.draw()
    love.graphics.setCanvas()
    love.graphics.clear(0, 0, 0)

    local scrolly = memory[0xFF42]
    local scrollx = memory[0xFF43]

    local width = 160 * scale
    local height = 144 * scale

    love.graphics.setColor(1, 0, 1)
    love.graphics.rectangle("fill", 0, 0, width, height)

    local bgsize = 255 * scale

    love.graphics.setColor(1, 1, 1)
    -- love.graphics.draw(canvas, 0, 0, 0, scale)
    love.graphics.draw(canvas, -scrollx * scale - bgsize,
                       -scrolly * scale - bgsize, 0, scale)
    love.graphics.draw(canvas, -scrollx * scale, -scrolly * scale - bgsize, 0,
                       scale)
    love.graphics.draw(canvas, -scrollx * scale + bgsize,
                       -scrolly * scale - bgsize, 0, scale)

    love.graphics.draw(canvas, -scrollx * scale - bgsize, -scrolly * scale, 0,
                       scale)
    love.graphics.draw(canvas, -scrollx * scale, -scrolly * scale, 0, scale)
    love.graphics.draw(canvas, -scrollx * scale + bgsize, -scrolly * scale, 0,
                       scale)

    love.graphics.draw(canvas, -scrollx * scale - bgsize,
                       -scrolly * scale + bgsize, 0, scale)
    love.graphics.draw(canvas, -scrollx * scale, -scrolly * scale + bgsize, 0,
                       scale)
    love.graphics.draw(canvas, -scrollx * scale + bgsize,
                       -scrolly * scale + bgsize, 0, scale)
end

function love.keypressed(key, scancode, isrepeat)
    if key == "f9" then
        dbg = false
        run = true
    elseif key == "f7" then
        run = true
    end
end

function draw_scanline()
    local scrolly = memory[0xFF42]
    local scrollx = memory[0xFF43]
    local windowy = memory[0xFF4A]
    local windowx = memory[0xFF4B] - 7
end

function get_arg(value) return memory.get(regs.get_PC() + 1 + value) end

function to_bits(n)
    local t = {}
    for i = 1, 32 do
        n = bit.rol(n, 1)
        if i > 16 then table.insert(t, bit.band(n, 1)) end
    end
    return table.concat(t)
end

function to_signed(unsigned, size)
    local max = bit.lshift(1, size)

    return wrap(unsigned, -max / 2, max / 2 - 1)
end

function wrap(value, min, max)
    if value < min then return max - (min - value - 1) end
    if value > max then return min + (value - max - 1) end
    return value
end

function set_bit(value, b, i)
    b = bit.lshift(b, i)
    value = bit.bor(bit.band(value, bit.bnot(bit.lshift(1, i))), b)

    return value
end

function get_bit(value, i)
    return bit.rshift(bit.band(value, bit.lshift(1, i)), i)
end

-- bit.band(xyz, 0x00FF) limits numbers to up to 0x00FF

-- get upper 4 bits of 8 bit value
function get_hi8(value) return bit.band(bit.rshift(value, 4), 0x0F) end

-- get lower 4 bits of 8 bit value
function get_lo8(value) return bit.band(value, 0x0F) end

-- set hi and low 4 bits of 8 bit value
function set_hilo8(hi, lo)
    hi = bit.band(hi, 0x0F)
    lo = bit.band(lo, 0x0F)
    return bit.lshift(hi, 4) + lo
end

-- set upper 8 bits of 16 bit value
function set_hi16(value, hi)
    hi = bit.band(hi, 0x00FF)
    return bit.lshift(hi, 8) + get_lo16(value)
end

-- set lower 8 bits of 16 bit value
function set_lo16(value, lo)
    lo = bit.band(lo, 0x00FF)
    return bit.lshift(get_hi16(value), 8) + lo
end

-- get upper 8 bits of 16 bit value
function get_hi16(value)
    value = bit.band(bit.rshift(value, 8), 0x00FF)
    return value
end

-- get lower 8 bits of 16 bit value
function get_lo16(value) return bit.band(value, 0x00FF) end

-- set hi and low 8 bits of 16 bit value
function set_hilo16(hi, lo)
    hi = bit.band(hi, 0x00FF)
    lo = bit.band(lo, 0x00FF)
    return bit.lshift(hi, 8) + lo
end

function init_array(arr, bytes) for i = 0, bytes - 1, 1 do arr[i] = 0x00 end end

-- function boot() end

function is_debug() return regs.get_PC() >= 0x64 and regs.get_PC() <= 0x90 end

function run_inst()
    local opcode = memory.get(regs.get_PC())

    if dbg or breakpoints[regs.get_PC()] ~= nil then
        dbg = true
        debug_log()
    end
    if dbg then run = false end

    -- print(hex4:format(regs.PC))
    -- print(hex2:format(opcode))

    regs.inc_PC(1)

    if opcode ~= 0xCB then
        local oct_code = oct3:format(opcode)

        -- TODO do individually
        local x = tonumber(oct_code:sub(1, 1))
        local y = tonumber(oct_code:sub(2, 2))
        local z = tonumber(oct_code:sub(3, 3))
        local p = bit.rshift(y, 1)
        local q = y % 2

        local d = to_signed(memory.get(regs.get_PC()), 8)
        local n = memory.get(regs.get_PC())
        local nn = set_hilo16(memory.get(regs.get_PC() + 1),
                              memory.get(regs.get_PC()))

        if x == 0 then
            if z == 0 then
                if y == 0 then
                    insts.NOP()
                elseif y == 1 then
                    regs.inc_PC(2)
                    instcycles = 5
                    memory.set(nn, regs.get_SP())
                elseif y == 2 then
                    regs.inc_PC(1)
                    insts.STOP()
                elseif y == 3 then
                    regs.inc_PC(1)
                    insts.JR(d)
                elseif y >= 4 and y <= 7 then
                    regs.inc_PC(1)
                    insts.JRC(lookups.cc[y - 4](), d)
                end
            elseif z == 1 then
                if q == 0 then
                    regs.inc_PC(2)
                    instcycles = 3
                    regs["set_" .. lookups.rp[p]](nn)
                elseif q == 1 then
                    instcycles = 2
                    regs.set_HL(insts.ADD(regs.get_HL(), regs[lookups.rp[p]]))
                end
            elseif z == 2 then
                if q == 0 then
                    if p == 0 then
                        instcycles = 2
                        memory.set(regs.get_BC(), regs.get_A())
                    end
                    if p == 1 then
                        instcycles = 2
                        memory.set(regs.get_DE(), regs.get_A())
                    end
                    if p == 2 then
                        instcycles = 2
                        memory.set(regs.get_HL(), regs.get_A())
                        regs.set_HL(regs.get_HL() + 1)
                    end
                    if p == 3 then
                        instcycles = 2
                        memory.set(regs.get_HL(), regs.get_A())
                        regs.set_HL(regs.get_HL() - 1)
                    end
                elseif q == 1 then
                    if p == 0 then
                        instcycles = 2
                        regs.set_A(memory.get(regs.get_BC()))
                    end
                    if p == 1 then
                        instcycles = 2
                        regs.set_A(memory.get(regs.get_DE()))
                    end
                    if p == 2 then
                        instcycles = 2
                        regs.set_A(memory.get(regs.get_HL()))
                        regs.set_HL(regs.get_HL() + 1)
                    end
                    if p == 3 then
                        instcycles = 2
                        regs.set_A(memory.get(regs.get_HL()))
                        regs.set_HL(regs.get_HL() - 1)
                    end
                end
            elseif z == 3 then
                if q == 0 then
                    instcycles = 2
                    regs[lookups.rp[p]] = regs[lookups.rp[p]] + 1
                elseif q == 1 then
                    instcycles = 2
                    regs[lookups.rp[p]] = regs[lookups.rp[p]] - 1
                end
            elseif z == 4 then
                regs["set_" .. lookups.r[y]](
                    insts.INC8(regs["get_" .. lookups.r[y]]()))
            elseif z == 5 then
                regs["set_" .. lookups.r[y]](
                    insts.DEC8(regs["get_" .. lookups.r[y]]()))
            elseif z == 6 then
                regs.inc_PC(1)
                instcycles = 2
                regs["set_" .. lookups.r[y]](n)
            elseif z == 7 then
                if y == 0 then
                    insts.RLCA()
                elseif y == 1 then
                    insts.RRCA()
                elseif y == 2 then
                    insts.RLA()
                elseif y == 3 then
                    insts.RRA()
                elseif y == 4 then
                    insts.DAA()
                elseif y == 5 then
                    insts.CPL()
                elseif y == 6 then
                    insts.SCF()
                elseif y == 7 then
                    insts.CCF()
                end
            end
        elseif x == 1 then
            if z == 6 and y == 6 then
                insts.HALT()
            else
                if lookups.r[y] == "(HL)" or lookups.r[z] == "(HL)" then
                    instcycles = 2
                else
                    instcycles = 1
                end
                regs["set_" .. lookups.r[y]](regs["get_" .. lookups.r[z]]())
            end
        elseif x == 2 then
            insts[lookups.alu[y]](lookups.r[z])
        elseif x == 3 then
            if z == 0 then
                if y >= 0 and y <= 3 then
                    insts.RETC(lookups.cc[y]())
                elseif y == 4 then
                    instcycles = 3
                    regs.inc_PC(1)
                    memory.set(0xFF00 + n, regs.get_A())
                elseif y == 5 then
                    instcycles = 4
                    regs.inc_PC(1)
                    regs.set_SP(insts.ADDSPD(d))
                elseif y == 6 then
                    instcycles = 3
                    regs.inc_PC(1)
                    regs.set_A(memory.get(0xFF00 + n))
                elseif y == 7 then
                    instcycles = 3
                    regs.inc_PC(1)

                    regs.set_HL(insts.ADDSPD(d))
                end
            elseif z == 1 then
                if q == 0 then
                    instcycles = 3
                    regs["set_" .. lookups.rp2[p]](insts.POP())
                elseif q == 1 then
                    if p == 0 then
                        insts.RET()
                    elseif p == 1 then
                        insts.RETI()
                    elseif p == 2 then
                        instcycles = 1
                        insts.JP(regs.get_HL())
                    elseif p == 3 then
                        instcycles = 2
                        regs.set_SP(regs.get_HL())
                    end
                end
            elseif z == 2 then
                if y >= 0 and y <= 3 then
                    regs.inc_PC(2)
                    insts.JPC(lookups.cc[y](), nn)
                elseif y == 4 then
                    instcycles = 2
                    memory.set(0xFF00 + regs.get_C(), regs.get_A())
                elseif y == 5 then
                    instcycles = 4
                    regs.inc_PC(2)
                    memory.set(nn, regs.get_A())
                elseif y == 6 then
                    instcycles = 2
                    regs.set_A(memory.get(0xFF00 + regs.get_C()))
                elseif y == 7 then
                    instcycles = 4
                    regs.inc_PC(2)
                    regs.set_A(memory.get(nn))
                end
            elseif z == 3 then
                if y == 0 then
                    instcycles = 4
                    regs.inc_PC(2)
                    insts.JP(nn)
                elseif y == 1 then
                    -- CB prefix
                elseif y == 6 then
                    insts.DI()
                elseif y == 7 then
                    insts.EI()
                end
            elseif z == 4 then
                if y >= 0 and y <= 3 then
                    regs.inc_PC(2)
                    insts.CALLC(lookups.cc[y](), nn)
                end
            elseif z == 5 then
                if q == 0 then
                    insts.PUSH(regs["get_" .. lookups.rp2[p]]())
                elseif q == 1 then
                    if p == 0 then
                        regs.inc_PC(2)
                        insts.CALL(nn)
                    end
                end
            elseif z == 6 then
                regs.inc_PC(1)
                insts[lookups.alu[y]](n)
            elseif z == 7 then
                insts.RST(y * 8)
            end
        end
    else -- do CB prefix stuff
        opcode = memory.get(regs.get_PC())

        -- print(hex4:format(regs.PC))
        -- print(hex2:format(opcode))

        regs.inc_PC(1)

        local oct_code = oct3:format(opcode)

        local x = tonumber(oct_code:sub(1, 1))
        local y = tonumber(oct_code:sub(2, 2))
        local z = tonumber(oct_code:sub(3, 3))

        if x == 0 then
            insts[lookups.rot[y]](lookups.r[z])
        elseif x == 1 then
            insts.BIT(y, lookups.r[z])
        elseif x == 2 then
            insts.RES(y, lookups.r[z])
        elseif x == 3 then
            insts.SET(y, lookups.r[z])
        end
    end
end

function file_to_bytes(file, byte_array, start)
    local byte = file:read(1)
    local i = 0
    while byte do
        byte_array[start + i] = byte:byte()

        byte = file:read(1)

        i = i + 1
    end
end