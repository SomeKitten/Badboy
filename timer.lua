local t = {}

t.ticks = 0

t.emu_cycles = function(cpu_cycles)
    local n = cpu_cycles * 4

    i = 0
    while i < n do
        t.ticks = t.ticks + 1
        t.timer_tick()
        i = i + 1
    end
end

t.timer_tick = function()
    local prev_div = regs.get_DIV()
    regs.inc_DIV()

    local timer_update = false

    local lower_tac = bit.band(memory.get_TAC(), 0x03)

    if lower_tac == 0x00 then
        timer_update = util.get_bit(prev_div, 9) == 1 and
                           util.get_bit(regs.get_DIV(), 9) == 0
    elseif lower_tac == 0x01 then
        timer_update = util.get_bit(prev_div, 3) == 1 and
                           util.get_bit(regs.get_DIV(), 3) == 0
    elseif lower_tac == 0x02 then
        timer_update = util.get_bit(prev_div, 5) == 1 and
                           util.get_bit(regs.get_DIV(), 5) == 0
    elseif lower_tac == 0x03 then
        timer_update = util.get_bit(prev_div, 7) == 1 and
                           util.get_bit(regs.get_DIV(), 7) == 0
    end

    if timer_update and util.get_bit(memory.get_TAC(), 2) == 1 then
        memory.inc_TIMA()

        if memory.get_TIMA() == 0xFF then
            memory.set_TIMA(memory.get_TMA())

            memory.set_IF(2, 1)
        end
    end
end

return t
