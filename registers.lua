local regs = {}

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
regs.DIV = 0x0000

-- inc program counter
regs.inc_PC = function(n)
    regs.set_PC(regs.get_PC() + n)
    instlen = instlen + 1
end
regs.inc_HL = function()
    local value = regs.get_HL() + 1
    while value > 0xFFFF do value = value - 0x10000 end
    regs.set_HL(value)
end
regs.dec_HL = function()
    local value = regs.get_HL() - 1
    while value < 0 do value = value + 0x10000 end
    regs.set_HL(value)
end
regs.inc_SP = function()
    local value = regs.get_SP() + 1
    while value > 0xFFFF do value = value - 0x10000 end
    regs.set_SP(value)
end
regs.dec_SP = function()
    local value = regs.get_SP() - 1
    while value < 0 do value = value + 0x10000 end
    regs.set_SP(value)
end

-- set A, B, C, D, E, H, and L registers

regs.set_A = function(value)
    if value == nil then
        print("Tried to set A to nil")
        dbg.debug_log()
    end
    regs.set_AF(util.set_hi16(regs.AF, value))
end
regs.set_B = function(value) regs.set_BC(util.set_hi16(regs.BC, value)) end
regs.set_C = function(value) regs.set_BC(util.set_lo16(regs.BC, value)) end
regs.set_D = function(value) regs.set_DE(util.set_hi16(regs.DE, value)) end
regs.set_E = function(value) regs.set_DE(util.set_lo16(regs.DE, value)) end
regs.set_H = function(value) regs.set_HL(util.set_hi16(regs.HL, value)) end
regs.set_L = function(value) regs.set_HL(util.set_lo16(regs.HL, value)) end
regs["set_(HL)"] = function(value) memory.set(regs.HL, value) end

-- get A, B, C, D, E, H, and L registers

regs.get_A = function() return util.get_hi16(regs.get_AF()) end
regs.get_B = function() return util.get_hi16(regs.get_BC()) end
regs.get_C = function() return util.get_lo16(regs.get_BC()) end
regs.get_D = function() return util.get_hi16(regs.get_DE()) end
regs.get_E = function() return util.get_lo16(regs.get_DE()) end
regs.get_H = function() return util.get_hi16(regs.get_HL()) end
regs.get_L = function() return util.get_lo16(regs.get_HL()) end
regs["get_(HL)"] = function() return memory.get(regs.get_HL()) end

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

regs.set_flag = function(b, i) regs.set_AF(util.set_bit(regs.AF, b, i)) end
regs.set_z = function(value) regs.set_flag(value, 7) end
regs.set_n = function(value) regs.set_flag(value, 6) end
regs.set_h = function(value) regs.set_flag(value, 5) end
regs.set_c = function(value) regs.set_flag(value, 4) end

regs.get_flag = function(i) return util.get_bit(regs.AF, i) end
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

regs.get_DIV = function() return regs.DIV end
regs.set_DIV = function(value) regs.DIV = value end
regs.inc_DIV = function(value)
    local value = memory[0xFF04] + 1
    while value > 0xFF do value = value - 0x100 end
    memory[0xFF04] = value
end

return regs
