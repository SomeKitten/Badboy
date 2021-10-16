local util = {}

util.file_to_bytes = function(file, byte_array, start)
    local byte = file:read(1)
    local i = 0
    while byte do
        byte_array[start + i] = byte:byte()

        byte = file:read(1)

        i = i + 1
    end
end

function print(text)
    local file = io.open("debug.log", "a+")

    file:write(text ~= nil and (text .. "\n") or "nil\n")

    file:close()
end

function io.write(text)
    local file = io.open("debug.log", "a+")

    file:write(text ~= nil and (text) or "nil")

    file:close()
end

function util.get_arg(value) return memory.get(regs.get_PC() + 1 + value) end

function util.to_bits(n)
    local t = {}
    for i = 1, 32 do
        n = bit.rol(n, 1)
        if i > 16 then table.insert(t, bit.band(n, 1)) end
    end
    return table.concat(t)
end

function util.to_signed(unsigned, size)
    local max = bit.lshift(1, size)

    return util.wrap(unsigned, -max / 2, max / 2 - 1)
end

function util.wrap(value, min, max)
    if value < min then return max - (min - value - 1) end
    if value > max then return min + (value - max - 1) end
    return value
end

function util.set_bit(value, b, i)
    b = bit.lshift(b, i)
    value = bit.bor(bit.band(value, bit.bnot(bit.lshift(1, i))), b)

    return value
end

function util.get_bit(value, i)
    return bit.rshift(bit.band(value, bit.lshift(1, i)), i)
end

-- bit.band(xyz, 0x00FF) limits numbers to up to 0x00FF

-- get upper 4 bits of 8 bit value
function util.get_hi8(value) return bit.band(bit.rshift(value, 4), 0x0F) end

-- get lower 4 bits of 8 bit value
function util.get_lo8(value) return bit.band(value, 0x0F) end

-- set hi and low 4 bits of 8 bit value
function util.set_hilo8(hi, lo)
    hi = bit.band(hi, 0x0F)
    lo = bit.band(lo, 0x0F)
    return bit.lshift(hi, 4) + lo
end

-- set upper 8 bits of 16 bit value
function util.set_hi16(value, hi)
    hi = bit.band(hi, 0x00FF)
    return bit.lshift(hi, 8) + util.get_lo16(value)
end

-- set lower 8 bits of 16 bit value
function util.set_lo16(value, lo)
    lo = bit.band(lo, 0x00FF)
    return bit.lshift(util.get_hi16(value), 8) + lo
end

-- get upper 8 bits of 16 bit value
function util.get_hi16(value)
    value = bit.band(bit.rshift(value, 8), 0x00FF)
    return value
end

-- get lower 8 bits of 16 bit value
function util.get_lo16(value) return bit.band(value, 0x00FF) end

-- set hi and low 8 bits of 16 bit value
function util.set_hilo16(hi, lo)
    hi = bit.band(hi, 0x00FF)
    lo = bit.band(lo, 0x00FF)
    return bit.lshift(hi, 8) + lo
end

function util.init_array(arr, bytes) for i = 0, bytes - 1, 1 do arr[i] = 0x00 end end

return util
