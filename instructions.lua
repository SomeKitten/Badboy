local insts = {}

insts.NOP = function()
    inst_cycles = 1
    -- print("NOP")
    -- debug_log()
end
insts.STOP = function()
    inst_cycles = 1

    halt = true

    print("STOP")
end
insts.JR = function(relative)
    inst_cycles = 3
    regs.set_PC(regs.get_PC() + relative)
end
insts.JRC = function(condition, relative)
    if condition then
        inst_cycles = 3
        regs.set_PC(regs.get_PC() + relative)
    else
        inst_cycles = 2
    end
end
insts.INC8 = function(value)
    inst_cycles = 1

    value = value + 1

    while value > 0xFF do value = value - 0x100 end

    regs.set_z(value == 0 and 1 or 0)
    regs.set_n(0)
    regs.set_h(bit.band(value, 0xF) == 0 and 1 or 0)

    return value
end
insts.DEC8 = function(value)
    inst_cycles = 1

    value = value - 1

    while value < 0 do value = value + 0x100 end

    regs.set_z(value == 0 and 1 or 0)
    regs.set_n(1)
    regs.set_h(bit.band(value, 0xF) == 0xF and 1 or 0)

    return value
end
insts.RLCA = function()
    inst_cycles = 1

    local shifted = util.get_bit(regs.get_A(), 7)
    regs.set_A(bit.band(bit.lshift(regs.get_A(), 1) + shifted, 0xFF))

    regs.set_z(0)
    regs.set_n(0)
    regs.set_h(0)
    regs.set_c(shifted)
end
insts.RRCA = function()
    inst_cycles = 1

    local shifted = util.get_bit(regs.get_A(), 0)
    regs.set_A(bit.bor(bit.rshift(regs.get_A(), 1), bit.lshift(shifted, 7)))

    regs.set_z(0)
    regs.set_n(0)
    regs.set_h(0)
    regs.set_c(shifted)
end
insts.RRA = function()
    inst_cycles = 1

    local shifted = util.get_bit(regs.get_A(), 0)
    regs.set_A(bit.rshift(regs.get_A(), 1))
    regs.set_A(util.set_bit(regs.get_A(), regs.get_c(), 7))

    regs.set_z(0)
    regs.set_n(0)
    regs.set_h(0)
    regs.set_c(shifted)
end
insts.RLA = function()
    inst_cycles = 1

    local shifted = util.get_bit(regs.get_A(), 7)
    regs.set_A(bit.band(bit.lshift(regs.get_A(), 1) + regs.get_c(), 0xFF))

    regs.set_z(0)
    regs.set_n(0)
    regs.set_h(0)
    regs.set_c(shifted)
end
-- https://archive.nes.science/nesdev-forums/f20/t15944.xhtml
insts.DAA = function()
    inst_cycles = 1
    local a = regs.get_A()
    if regs.get_n() == 0 then
        if regs.get_c() == 1 or a > 0x99 then
            a = a + 0x60
            regs.set_c(1)
        end
        if regs.get_h() == 1 or bit.band(a, 0x0f) > 0x09 then a = a + 0x6 end
    else
        if regs.get_c() == 1 then a = a - 0x60 end
        if regs.get_h() == 1 then a = a - 0x6 end
    end

    while a > 0xFF do a = a - 0x100 end
    regs.set_A(a)

    regs.set_z(a == 0 and 1 or 0)
    regs.set_h(0)
end
insts.CPL = function()
    inst_cycles = 1

    regs.set_A(bit.bnot(regs.get_A()))
    regs.set_n(1)
    regs.set_h(1)
end
insts.SCF = function()
    inst_cycles = 1

    regs.set_n(0)
    regs.set_h(0)
    regs.set_c(1)
end
insts.CCF = function()
    inst_cycles = 1

    regs.set_n(0)
    regs.set_h(0)
    regs.set_c((regs.get_c() == 1) and 0 or 1)
end
insts.HALT = function()
    inst_cycles = 0
    halt = true
end
insts["ADD A"] = function(value)
    if type(value) == "string" then
        inst_cycles = 1
        value = regs["get_" .. value]()
    else
        inst_cycles = 2
    end

    overflow3 =
        (util.get_lo8(regs.get_A()) + util.get_lo8(value) > 0xF) and 1 or 0

    value = regs.get_A() + value

    overflow7 = (value > 0xFF) and 1 or 0

    while value > 0xFF do value = value - 0x100 end

    regs.set_A(value)

    regs.set_z(value == 0 and 1 or 0)
    regs.set_n(0)
    regs.set_h(overflow3)
    regs.set_c(overflow7)
end
insts["ADC A"] = function(value)
    if type(value) == "string" then
        inst_cycles = 1
        value = regs["get_" .. value]()
    else
        inst_cycles = 2
    end

    value3 = util.get_lo8(value) + regs.get_c()
    value = value + regs.get_c()

    overflow3 = (util.get_lo8(regs.get_A()) + value3 > 0xF) and 1 or 0
    overflow7 = (regs.get_A() + value > 0xFF) and 1 or 0

    value = regs.get_A() + value

    while value > 0xFF do value = value - 0x100 end

    regs.set_A(value)

    regs.set_z(value == 0 and 1 or 0)
    regs.set_n(0)
    regs.set_h(overflow3)
    regs.set_c(overflow7)
end
insts["SUB"] = function(value)
    if type(value) == "string" then
        inst_cycles = 1
        value = regs["get_" .. value]()
    else
        inst_cycles = 2
    end

    regs.set_c(value > regs.get_A() and 1 or 0)
    regs.set_h(util.get_lo8(value) > util.get_lo8(regs.get_A()) and 1 or 0)

    value = regs.get_A() - value

    regs.set_A(value)

    regs.set_z(value == 0 and 1 or 0)
    regs.set_n(1)
end
insts["SBC A"] = function(value)
    if type(value) == "string" then
        inst_cycles = 1
        value = regs["get_" .. value]()
    else
        inst_cycles = 2
    end

    value3 = util.get_lo8(value) + regs.get_c()
    value = value + regs.get_c()

    regs.set_c(value > regs.get_A() and 1 or 0)
    regs.set_h(value3 > util.get_lo8(regs.get_A()) and 1 or 0)

    value = regs.get_A() - value

    while value < 0 do value = value + 0x100 end

    regs.set_A(value)

    regs.set_z(value == 0 and 1 or 0)
    regs.set_n(1)
end
insts["AND"] = function(value)
    if type(value) == "string" then
        inst_cycles = 1
        value = regs["get_" .. value]()
    else
        inst_cycles = 2
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
        inst_cycles = 1
        value = regs["get_" .. value]()
    else
        inst_cycles = 2
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
        inst_cycles = 1
        value = regs["get_" .. value]()
    else
        inst_cycles = 2
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
        inst_cycles = 1
        value = regs["get_" .. value]()
    else
        inst_cycles = 2
    end

    regs.set_c(value > regs.get_A() and 1 or 0)
    regs.set_h(util.get_lo8(value) > util.get_lo8(regs.get_A()) and 1 or 0)

    value = regs.get_A() - value

    regs.set_z(value == 0 and 1 or 0)
    regs.set_n(1)
end
insts.RET = function()
    inst_cycles = 4

    local low = memory.get(regs.get_SP())
    regs.inc_SP()
    local high = memory.get(regs.get_SP())
    regs.inc_SP()

    regs.set_PC(util.set_hilo16(high, low))
end
insts.RETC = function(condition)
    if condition then
        inst_cycles = 5

        local low = memory.get(regs.get_SP())
        regs.inc_SP()
        local high = memory.get(regs.get_SP())
        regs.inc_SP()

        regs.set_PC(util.set_hilo16(high, low))
    else
        inst_cycles = 2
    end
end
insts.RETI = function()
    inst_cycles = 4

    local low = memory.get(regs.get_SP())
    regs.inc_SP()
    local high = memory.get(regs.get_SP())
    regs.inc_SP()

    regs.set_PC(util.set_hilo16(high, low))

    regs.set_IME(1)
end
insts.JP = function(address)
    -- instcycles = ? (determined on whether its HL or not)
    regs.set_PC(address)
end
insts.JPC = function(condition, address)
    if condition then
        inst_cycles = 4
        regs.set_PC(address)
    else
        inst_cycles = 3
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

    while value > 0xFFFF do value = value - 0x10000 end

    return value
end
insts.ADDSPD = function(value)
    overflow3 =
        (util.get_lo8(regs.get_SP()) + util.get_lo8(value) > 0xF) and 1 or 0
    overflow7 = (util.get_lo16(regs.get_SP()) + util.get_lo16(value) > 0xFF) and
                    1 or 0

    value = regs.get_SP() + value

    while value > 0xFFFF do value = value - 0x10000 end
    while value < 0 do value = value + 0x10000 end

    regs.set_z(0)
    regs.set_n(0)
    regs.set_h(overflow3)
    regs.set_c(overflow7)

    return value
end
insts.POP = function()
    inst_cycles = 3

    local low = memory.get(regs.get_SP())
    regs.inc_SP()
    local high = memory.get(regs.get_SP())
    regs.inc_SP()

    return util.set_hilo16(high, low)
end
insts.DI = function()
    inst_cycles = 1

    regs.set_IME(0)
end
insts.EI = function()
    inst_cycles = 1

    regs.set_IME(1)
end
insts.CALL = function(address)
    inst_cycles = 6

    regs.dec_SP()
    memory.set(regs.get_SP(), util.get_hi16(regs.get_PC()))
    regs.dec_SP()
    memory.set(regs.get_SP(), util.get_lo16(regs.get_PC()))

    regs.set_PC(address)
end
insts.CALLC = function(condition, address)
    if condition then
        inst_cycles = 6

        regs.dec_SP()
        memory.set(regs.get_SP(), util.get_hi16(regs.get_PC()))
        regs.dec_SP()
        memory.set(regs.get_SP(), util.get_lo16(regs.get_PC()))

        regs.set_PC(address)
    else
        inst_cycles = 3
    end
end
insts.PUSH = function(value)
    inst_cycles = 4

    regs.dec_SP()
    memory.set(regs.get_SP(), util.get_hi16(value))
    regs.dec_SP()
    memory.set(regs.get_SP(), util.get_lo16(value))
end
insts.RST = function(value)
    inst_cycles = 4

    regs.dec_SP()
    memory.set(regs.get_SP(), util.get_hi16(regs.get_PC()))
    regs.dec_SP()
    memory.set(regs.get_SP(), util.get_lo16(regs.get_PC()))

    regs.set_PC(value)
end
insts.RLC = function(register)
    if register == "(HL)" then
        inst_cycles = 4
    else
        inst_cycles = 2
    end

    local shifted = util.get_bit(regs["get_" .. register](), 7)

    local value = bit.band(bit.lshift(regs["get_" .. register](), 1) + shifted,
                           0xFF)
    regs["set_" .. register](value)

    regs.set_z(value == 0 and 1 or 0)
    regs.set_n(0)
    regs.set_h(0)
    regs.set_c(shifted)
end
insts.RRC = function(register)
    if register == "(HL)" then
        inst_cycles = 4
    else
        inst_cycles = 2
    end

    local shifted = util.get_bit(regs["get_" .. register](), 0)

    local value = bit.rshift(regs["get_" .. register](), 1)
    value = bit.bor(value, bit.lshift(shifted, 7))
    regs["set_" .. register](value)

    regs.set_z(value == 0 and 1 or 0)
    regs.set_n(0)
    regs.set_h(0)
    regs.set_c(shifted)
end
insts.RL = function(register)
    if register == "(HL)" then
        inst_cycles = 4
    else
        inst_cycles = 2
    end

    local shifted = util.get_bit(regs["get_" .. register](), 7)

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
        inst_cycles = 4
    else
        inst_cycles = 2
    end

    local reg_val = regs["get_" .. register]()

    local shifted = util.get_bit(reg_val, 0)

    local value = bit.rshift(reg_val, 1)
    value = util.set_bit(value, regs.get_c(), 7)
    regs["set_" .. register](value)

    regs.set_z(value == 0 and 1 or 0)
    regs.set_n(0)
    regs.set_h(0)
    regs.set_c(shifted)
end
insts.SLA = function(register)
    if register == "(HL)" then
        inst_cycles = 4
    else
        inst_cycles = 2
    end

    local shifted = util.get_bit(regs["get_" .. register](), 7)
    local value = bit.band(bit.lshift(regs["get_" .. register](), 1), 0xFF)
    regs["set_" .. register](value)
    regs.set_z(value == 0 and 1 or 0)
    regs.set_n(0)
    regs.set_h(0)
    regs.set_c(shifted)
end
insts.SRA = function(register)
    if register == "(HL)" then
        inst_cycles = 4
    else
        inst_cycles = 2
    end

    local shifted = util.get_bit(regs["get_" .. register](), 0)
    bit7 = util.get_bit(regs["get_" .. register](), 7)
    local value = bit.rshift(regs["get_" .. register](), 1)
    value = util.set_bit(value, bit7, 7)

    regs["set_" .. register](value)

    regs.set_z(value == 0 and 1 or 0)
    regs.set_n(0)
    regs.set_h(0)
    regs.set_c(shifted)
end
insts.SWAP = function(register)
    if register == "(HL)" then
        inst_cycles = 4
    else
        inst_cycles = 2
    end

    local value = regs["get_" .. register]()
    value = util.set_hilo8(util.get_lo8(value), util.get_hi8(value))

    regs["set_" .. register](value)

    regs.set_z(value == 0 and 1 or 0)
    regs.set_n(0)
    regs.set_h(0)
    regs.set_c(0)
end
insts.SRL = function(register)
    if register == "(HL)" then
        inst_cycles = 4
    else
        inst_cycles = 2
    end

    local shifted = util.get_bit(regs["get_" .. register](), 0)
    local value = bit.rshift(regs["get_" .. register](), 1)
    regs["set_" .. register](value)
    regs.set_z(value == 0 and 1 or 0)
    regs.set_n(0)
    regs.set_h(0)
    regs.set_c(shifted)
end
insts.BIT = function(i, register)
    if register == "(HL)" then
        inst_cycles = 3
    else
        inst_cycles = 2
    end

    local value = util.get_bit(regs["get_" .. register](), i)

    regs.set_z(value == 0 and 1 or 0)

    regs.set_n(0)
    regs.set_h(1)
end
insts.RES = function(i, register)
    if register == "(HL)" then
        inst_cycles = 4
    else
        inst_cycles = 2
    end

    regs["set_" .. register](util.set_bit(regs["get_" .. register](), 0, i))
end
insts.SET = function(i, register)
    if register == "(HL)" then
        inst_cycles = 4
    else
        inst_cycles = 2
    end

    regs["set_" .. register](util.set_bit(regs["get_" .. register](), 1, i))
end

return insts
