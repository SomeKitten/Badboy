function love.load()
    local file = io.open("debug.log", "w")
    file:close()

    insts = require("instructions")
    graphics = require("graphics")
    dbg = require("debug")
    util = require("util")
    interrupts = require("interrupts")
    regs = require("registers")

    print("Starting!")

    breakpoints = {}
    -- breakpoints[0x0100] = true
    -- breakpoints[0xC304] = true

    max_inst_amount = 2676369

    prev_opcodes = {}

    run = true
    halt = false
    is_debug = false
    debug_msg = ""
    check = {}
    check.check = false

    inst_count = 0

    scale = 4

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
            print("This was nil: " .. hex4:format(index))
            dbg.debug_log()
        end
        -- if index == 0xFF44 then return 0x90 end
        return value
    end
    memory.set = function(index, value)
        if value == nil then
            print("Tried to set to nil: " .. hex4:format(index))
            dbg.debug_log()
        end
        if index == 0xFF04 then memory[index] = 0 end
        if index == 0xFF0F and value ~= 0xE1 then
            value = bit.bor(value, 0xE0)
        end
        if index == 0xFF44 then memory[index] = 0 end
        if index == 0xFF50 and value == 1 then
            -- unmap boot rom
            util.file_to_bytes(io.open(rom_file, "rb"), memory, 0x0000)
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
        memory.set(0xFF0F, util.set_bit(memory.get(0xFF0F), value, index))
    end
    memory.set_IE = function(index, value)
        memory.set(0xFFFF, util.set_bit(memory.get(0xFFFF), value, index))
    end

    colours = {1, 0.66, 0.33, 0}

    interrupt_locations = {0x40, 0x48, 0x50, 0x58, 0x60}

    scancount = 456
    instlen = 0
    inst_cycles = 0
    -- clock_main = 0
    -- clock_sub = 0
    -- clock_div = 0
    -- clock_m = 0
    -- clock_t = 0
    -- div_clocksum = 0
    -- timer_clocksum = 0

    print("Initializing memory!")
    util.init_array(memory, 64 * 1024)

    print("Initializing Registers!")
    regs = require("registers")

    print("Loading boot rom!")
    -- 01-special.gb -- PASSED
    -- 02-interrupts.gb -- FAILED -- TIMER DOESNT WORK FAILED #4
    -- 03-op sp,hl.gb -- PASSED
    -- 04-op r,imm.gb -- PASSED
    -- 05-op rp.gb -- PASSED
    -- 06-ld r,r.gb -- PASSED
    -- 07-jr,jp,call,ret,rst.gb -- PASSED
    -- 08-misc instrs.gb -- PASSED
    -- 09-op r,r.gb -- PASSED
    -- 10-bit ops.gb -- PASSED
    -- 11-op a,(hl).gb -- PASSED
    -- tetris -- FAILED
    -- drmario -- FAILED
    -- pkred -- FAILED
    rom_file = "./tests/blargg/cpu_instrs/cpu_instrs.gb"
    -- rom_file = "./tests/blargg/cpu_instrs/individual/11-op a,(hl).gb"
    -- log_file = io.open("./tests/blargg/cpu_instrs/individual/11.txt", "r")
    util.file_to_bytes(io.open(rom_file, "rb"), memory, 0x0000)
    util.file_to_bytes(io.open("tests/bios.gb", "rb"), memory, 0x0000)

    print("Loading opcode tables!")
    lookups = require("lookups")

    memory.set(0xFF0F, 0xE1)

    print("Booting!")
end

function love.update(dt)
    while run do
        instlen = 0
        inst_cycles = -1

        if not halt then
            run_inst()
        else
            inst_cycles = 1

            break
        end

        if log_file ~= nil and (check.check or regs.get_PC() == 0x100) then
            dbg.check_log()
        end

        if inst_cycles == -1 then
            print("Unset instcycles")
            dbg.debug_log()
        end

        if graphics.run_graphics() then break end

        -- run_timer()

        interrupts.run_interrupts()

        -- if inst_count >= max_inst_amount then debug_log() end
    end

    if not halt then graphics.update_graphics() end
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

    love.graphics.setColor(0.4, 0.7, 0.3)
    love.graphics.print(hex4:format(regs.get_PC()))
    love.graphics.print(inst_count, 0, 10)
    love.graphics.print(run and "Running" or "Stopped", 0, 20)
end

function love.keypressed(key, scancode, isrepeat)
    if key == "f9" then
        is_debug = false
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

-- function boot() end

function run_inst()
    local opcode = memory.get(regs.get_PC())

    prev_opcodes[#prev_opcodes + 1] = {regs.get_PC(), opcode}

    if #prev_opcodes > 100 then
        prev_opcodes = {
            prev_opcodes[#prev_opcodes - 4], prev_opcodes[#prev_opcodes - 3],
            prev_opcodes[#prev_opcodes - 2], prev_opcodes[#prev_opcodes - 1],
            prev_opcodes[#prev_opcodes]
        }
    end

    inst_count = inst_count + 1

    -- print(hex4:format(regs.PC))
    -- print(hex2:format(opcode))

    if is_debug or breakpoints[regs.get_PC()] ~= nil then
        is_debug = true
        print("Breakpoint!")
        dbg.debug_log()
    end
    if is_debug then run = false end

    regs.inc_PC(1)

    if opcode ~= 0xCB then
        local oct_code = oct3:format(opcode)

        -- TODO do individually
        local x = tonumber(oct_code:sub(1, 1))
        local y = tonumber(oct_code:sub(2, 2))
        local z = tonumber(oct_code:sub(3, 3))
        local p = bit.rshift(y, 1)
        local q = y % 2

        local d = util.to_signed(memory.get(regs.get_PC()), 8)
        local n = memory.get(regs.get_PC())
        local nn = util.set_hilo16(memory.get(regs.get_PC() + 1),
                                   memory.get(regs.get_PC()))

        if x == 0 then
            if z == 0 then
                if y == 0 then
                    insts.NOP()
                elseif y == 1 then
                    regs.inc_PC(2)
                    inst_cycles = 5
                    memory.set(nn, util.get_lo16(regs.get_SP()))
                    memory.set(nn + 1, util.get_hi16(regs.get_SP()))
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
                    inst_cycles = 3
                    regs["set_" .. lookups.rp[p]](nn)
                elseif q == 1 then
                    inst_cycles = 2
                    regs.set_HL(insts.ADD(regs.get_HL(), regs[lookups.rp[p]]))
                end
            elseif z == 2 then
                if q == 0 then
                    if p == 0 then
                        inst_cycles = 2
                        memory.set(regs.get_BC(), regs.get_A())
                    end
                    if p == 1 then
                        inst_cycles = 2
                        memory.set(regs.get_DE(), regs.get_A())
                    end
                    if p == 2 then
                        inst_cycles = 2
                        memory.set(regs.get_HL(), regs.get_A())
                        regs.inc_HL()
                    end
                    if p == 3 then
                        inst_cycles = 2
                        memory.set(regs.get_HL(), regs.get_A())
                        regs.dec_HL()
                    end
                elseif q == 1 then
                    if p == 0 then
                        inst_cycles = 2
                        regs.set_A(memory.get(regs.get_BC()))
                    end
                    if p == 1 then
                        inst_cycles = 2
                        regs.set_A(memory.get(regs.get_DE()))
                    end
                    if p == 2 then
                        inst_cycles = 2
                        regs.set_A(memory.get(regs.get_HL()))
                        regs.inc_HL()
                    end
                    if p == 3 then
                        inst_cycles = 2
                        regs.set_A(memory.get(regs.get_HL()))
                        regs.dec_HL()
                    end
                end
            elseif z == 3 then
                if q == 0 then
                    inst_cycles = 2
                    local value = regs[lookups.rp[p]] + 1
                    while value > 0xFFFF do
                        value = value - 0x10000
                    end
                    regs[lookups.rp[p]] = value
                elseif q == 1 then
                    inst_cycles = 2
                    local value = regs[lookups.rp[p]] - 1
                    while value < 0 do
                        value = value + 0x10000
                    end
                    regs[lookups.rp[p]] = value
                end
            elseif z == 4 then
                regs["set_" .. lookups.r[y]](
                    insts.INC8(regs["get_" .. lookups.r[y]]()))
            elseif z == 5 then
                regs["set_" .. lookups.r[y]](
                    insts.DEC8(regs["get_" .. lookups.r[y]]()))
            elseif z == 6 then
                regs.inc_PC(1)
                inst_cycles = 2
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
                    inst_cycles = 2
                else
                    inst_cycles = 1
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
                    inst_cycles = 3
                    regs.inc_PC(1)
                    memory.set(0xFF00 + n, regs.get_A())
                elseif y == 5 then
                    inst_cycles = 4
                    regs.inc_PC(1)
                    regs.set_SP(insts.ADDSPD(d))
                elseif y == 6 then
                    inst_cycles = 3
                    regs.inc_PC(1)
                    regs.set_A(memory.get(0xFF00 + n))
                elseif y == 7 then
                    inst_cycles = 3
                    regs.inc_PC(1)

                    regs.set_HL(insts.ADDSPD(d))
                end
            elseif z == 1 then
                if q == 0 then
                    inst_cycles = 3
                    regs["set_" .. lookups.rp2[p]](insts.POP())
                elseif q == 1 then
                    if p == 0 then
                        insts.RET()
                    elseif p == 1 then
                        insts.RETI()
                    elseif p == 2 then
                        inst_cycles = 1
                        insts.JP(regs.get_HL())
                    elseif p == 3 then
                        inst_cycles = 2
                        regs.set_SP(regs.get_HL())
                    end
                end
            elseif z == 2 then
                if y >= 0 and y <= 3 then
                    regs.inc_PC(2)
                    insts.JPC(lookups.cc[y](), nn)
                elseif y == 4 then
                    inst_cycles = 2
                    memory.set(0xFF00 + regs.get_C(), regs.get_A())
                elseif y == 5 then
                    inst_cycles = 4
                    regs.inc_PC(2)
                    memory.set(nn, regs.get_A())
                elseif y == 6 then
                    inst_cycles = 2
                    regs.set_A(memory.get(0xFF00 + regs.get_C()))
                elseif y == 7 then
                    inst_cycles = 4
                    regs.inc_PC(2)
                    regs.set_A(memory.get(nn))
                end
            elseif z == 3 then
                if y == 0 then
                    inst_cycles = 4
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
