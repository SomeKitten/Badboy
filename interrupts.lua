local interrupts = {}

-- clock_main = 0
-- clock_sub = 0
-- clock_div = 0

-- -- https://emudev.de/gameboy-emulator/interrupts-and-timers/
-- -- http://imrannazar.com/GameBoy-Emulation-in-JavaScript:-Timers
-- interrupts.run_timer = function()
--     clock_sub = clock_sub + inst_cycles

--     if clock_sub >= 4 then
--         clock_main = clock_main + 1
--         clock_sub = clock_sub - 4

--         clock_div = clock_div + 1
--         if clock_div == 16 then
--             memory.set(0xFF04, bit.band((memory.get(0xFF04) + 1), 0xFF))
--             clock_div = 0;
--         end
--     end

--     interrupts.check_timer();

--     -- 

--     -- div_clocksum = div_clocksum + instcycles
--     -- if div_clocksum > 0xFF then
--     --     div_clocksum = div_clocksum - 0xFF
--     --     memory.inc(0xFF04)
--     -- end

--     -- if get_bit(memory[0xFF07], 2) == 1 then
--     --     timer_clocksum = timer_clocksum + instcycles * 4

--     --     local freq = 0x1000
--     --     if bit.band(memory[0xFF07], 0x3) == 1 then
--     --         freq = 0x40000
--     --     elseif bit.band(memory[0xFF07], 0x3) == 2 then
--     --         freq = 0x10000
--     --     elseif bit.band(memory[0xFF07], 0x3) == 3 then
--     --         freq = 0x4000
--     --     end

--     --     while timer_clocksum > 0x40000 do
--     --         memory.inc(0xFF05)
--     --         if memory.get(0xFF05) == 0x00 then
--     --             memory.set_IF(3, 1)
--     --             memory.set(0xFF05, memory.get(0xFF06))
--     --         end

--     --         timer_clocksum = timer_clocksum - 0x40000 / freq
--     --     end
--     -- end
-- end

-- interrupts.check_timer = function()
--     if util.get_bit(memory.get(0xFF07), 3) == 1 then
--         local test_value = bit.band(memory.get(0xFF07), 3)
--         if test_value == 0 then
--             threshold = 64
--         elseif test_value == 1 then
--             threshold = 1
--         elseif test_value == 2 then
--             threshold = 4
--         elseif test_value == 3 then
--             threshold = 16
--         end

--         if clock_main >= threshold then interrupts.step_timer() end
--     end
-- end

-- interrupts.step_timer = function()
--     clock_main = 0
--     memory.inc(0xFF05)

--     if memory.get(0xFF05) > 255 then
--         memory.set(0xFF05, 0xFF06)

--         memory.set_IF(3, 1)
--     end
-- end

interrupts.run_interrupts = function()
    if regs.IME == 1 then
        local requested = memory.get(0xFF0F)
        local enabled = memory.get(0xFFFF)

        if requested > 0 then
            for i = 0, 4 do
                if util.get_bit(requested, i) == 1 and util.get_bit(enabled, i) ==
                    1 then
                    regs.IME = 0
                    memory.set_IF(i, 0)

                    if not (halt and regs.IME == 0) then
                        local stack_PC = 0
                        stack_PC = regs.get_PC()

                        regs.dec_SP()
                        memory.set(regs.get_SP(), util.get_hi16(stack_PC))
                        regs.dec_SP()
                        memory.set(regs.get_SP(), util.get_lo16(stack_PC))

                        regs.set_PC(interrupt_locations[i + 1])
                    end

                    if halt then halt = false end
                end
            end
        end
    end
end

interrupts.lcd_status = function()
    local status = memory[0xFF41]

    -- TODO LCD ENABLE/DISABLE

    local currentline = memory[0xFF44]
    local currentmode = bit.band(status, 0x3)

    local mode = 0
    local req_int = 0

    if currentline >= 144 then
        mode = 1
        status = util.set_bit(status, 1, 0)
        status = util.set_bit(status, 0, 1)
        req_int = util.get_bit(status, 4)
    else
        local mode2_bounds = 456 - 80
        local mode3_bounds = mode2_bounds - 172

        if scancount >= mode2_bounds then
            mode = 2
            status = util.set_bit(status, 0, 0)
            status = util.set_bit(status, 1, 1)
            req_int = util.get_bit(status, 5)
        elseif scancount >= mode3_bounds then
            mode = 3
            status = util.set_bit(status, 1, 0)
            status = util.set_bit(status, 1, 1)
        else
            mode = 0
            status = util.set_bit(status, 0, 0)
            status = util.set_bit(status, 0, 1)
            req_int = util.get_bit(status, 3)
        end
    end

    if req_int == 1 and mode ~= currentmode then memory.set_IF(1, 1) end

    if memory.get(0xFF44) == memory.get(0xFF44) then
        status = util.set_bit(status, 1, 2)
        if util.get_bit(status, 6) == 1 then memory.set_IF(1, 1) end
    else
        status = util.set_bit(status, 0, 2)
    end

    memory.set(0xFF41, status)
end

return interrupts
