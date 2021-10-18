local dbg = {}

dbg.check_log = function()
    check.check = true

    local line = log_file:read()
    if line ~= nil then
        check.a = tonumber(line:sub(4, 5), 16)
        check.f = tonumber(line:sub(10, 11), 16)
        check.b = tonumber(line:sub(16, 17), 16)
        check.c = tonumber(line:sub(22, 23), 16)
        check.d = tonumber(line:sub(28, 29), 16)
        check.e = tonumber(line:sub(34, 35), 16)
        check.h = tonumber(line:sub(40, 41), 16)
        check.l = tonumber(line:sub(46, 47), 16)
        check.sp = tonumber(line:sub(53, 56), 16)
        check.pc = tonumber(line:sub(65, 68), 16)
        check.hex0 = tonumber(line:sub(71, 72), 16)
        check.hex1 = tonumber(line:sub(74, 75), 16)
        check.hex2 = tonumber(line:sub(77, 78), 16)
        check.hex3 = tonumber(line:sub(80, 81), 16)
        if check.a ~= regs.get_A() or check.f ~= util.get_lo16(regs.get_AF()) or
            check.b ~= regs.get_B() or check.c ~= regs.get_C() or check.d ~=
            regs.get_D() or check.e ~= regs.get_E() or check.h ~= regs.get_H() or
            check.l ~= regs.get_L() or check.sp ~= regs.get_SP() or check.pc ~=
            regs.get_PC() or check.hex0 ~= memory.get(regs.get_PC()) or
            check.hex1 ~= memory.get(regs.get_PC() + 1) or check.hex2 ~=
            memory.get(regs.get_PC() + 2) or check.hex3 ~=
            memory.get(regs.get_PC() + 3) then
            print("Mismatch found!")
            is_debug = true
        end
    end
end

dbg.print_vram = function()
    local scrolly = memory[0xFF42]
    local scrollx = memory[0xFF43]

    local file = io.open("out.txt", "w")

    file:write("scrolly:  " .. scrolly .. "\n")
    file:write("scrollx:  " .. scrollx .. "\n")

    local addr = 0x8000
    for i = addr, 0x83FF, 1 do
        if i % 2 == 0 then file:write("\n" .. hex4:format(i) .. ":  ") end
        file:write(util.to_bits(memory[i]):gsub("0", " ") .. " ")
    end

    addr = 0x9800
    for i = addr, 0x9BFF, 1 do
        if i % 32 == 0 then file:write("\n" .. hex4:format(i) .. ":  ") end
        file:write(hex2:format(memory[i]) .. " ")
    end

    file:close()
end

dbg.debug_log = function()
    print("----------------------------------------")
    if debug_msg ~= "" then print(debug_msg) end
    print("")
    print("AF: " .. (regs.AF ~= nil and hex4:format(regs.AF) or "nil"))
    print("BC: " .. (regs.BC ~= nil and hex4:format(regs.BC) or "nil"))
    print("DE: " .. (regs.DE ~= nil and hex4:format(regs.DE) or "nil"))
    print("HL: " .. (regs.HL ~= nil and hex4:format(regs.HL) or "nil"))
    print("SP: " .. (regs.SP ~= nil and hex4:format(regs.SP) or "nil"))
    print("PC: " .. (regs.PC ~= nil and hex4:format(regs.PC) or "nil"))

    print("")

    print("HEX: " .. hex2:format(memory.get(regs.get_PC())) .. " " ..
              hex2:format(memory.get(regs.get_PC() + 1)) .. " " ..
              hex2:format(memory.get(regs.get_PC() + 2)) .. " " ..
              hex2:format(memory.get(regs.get_PC() + 3)) .. "\n")

    if not use_bios and log_file ~= nil then
        print("CHECK AF: " .. (hex4:format(util.set_hilo16(check.a, check.f))))
        print("CHECK BC: " .. (hex4:format(util.set_hilo16(check.b, check.c))))
        print("CHECK DE: " .. (hex4:format(util.set_hilo16(check.d, check.e))))
        print("CHECK HL: " .. (hex4:format(util.set_hilo16(check.h, check.l))))
        print("CHECK SP: " .. (hex4:format(check.sp)))
        print("CHECK PC: " .. (hex4:format(check.pc)))

        print("")

        print("CHECK HEX: " .. hex2:format(check.hex0) .. " " ..
                  hex2:format(check.hex1) .. " " .. hex2:format(check.hex2) ..
                  " " .. hex2:format(check.hex3) .. "\n")
    end

    print("FF00: " .. hex2:format(memory.get(0xFF00)))
    print("FF0F: " .. hex2:format(memory.get(0xFF0F)))
    print("FF40: " .. hex2:format(memory.get(0xFF40)))
    print("FF44: " .. hex2:format(memory.get(0xFF44)))
    print("FFFF: " .. hex2:format(memory.get(0xFFFF)))

    print("")
    print("Instructions: " .. inst_count)
    print("Scan count: " .. scancount)

    if inst_count > 5 then
        print("Prev opcodes:")
        print(hex4:format(prev_opcodes[#prev_opcodes - 1][1]) .. ": " ..
                  hex2:format(prev_opcodes[#prev_opcodes - 1][2]))
        print(hex4:format(prev_opcodes[#prev_opcodes - 2][1]) .. ": " ..
                  hex2:format(prev_opcodes[#prev_opcodes - 2][2]))
        print(hex4:format(prev_opcodes[#prev_opcodes - 3][1]) .. ": " ..
                  hex2:format(prev_opcodes[#prev_opcodes - 3][2]))
        print(hex4:format(prev_opcodes[#prev_opcodes - 4][1]) .. ": " ..
                  hex2:format(prev_opcodes[#prev_opcodes - 4][2]))
    end

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
        io.write(hex2:format(memory.get(i)) .. ", ")
    end

    print("\n\nSTACK:")
    for i = regs.SP, math.min(regs.SP + 5, 0xFFFD), 1 do
        print(hex4:format(i) .. ": " .. hex2:format(memory[i]))
    end

    print("\n" .. debug.traceback())
end

return dbg
