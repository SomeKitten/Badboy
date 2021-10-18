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

    file:write(text ~= nil and (tostring(text) .. "\n") or "nil\n")

    file:close()
end

function io.write(text)
    local file = io.open("debug.log", "a+")

    file:write(text ~= nil and tostring(text) or "nil")

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

function util.get_name()
    local name = ""
    for i = 0x0134, 0x0143 do
        if memory.get(i) == 0 then break end
        name = name .. string.char(memory.get(i))
    end
    return name
end

--   00h  ROM ONLY                 13h  MBC3+RAM+BATTERY
--   01h  MBC1                     15h  MBC4
--   02h  MBC1+RAM                 16h  MBC4+RAM
--   03h  MBC1+RAM+BATTERY         17h  MBC4+RAM+BATTERY
--   05h  MBC2                     19h  MBC5
--   06h  MBC2+BATTERY             1Ah  MBC5+RAM
--   08h  ROM+RAM                  1Bh  MBC5+RAM+BATTERY
--   09h  ROM+RAM+BATTERY          1Ch  MBC5+RUMBLE
--   0Bh  MMM01                    1Dh  MBC5+RUMBLE+RAM
--   0Ch  MMM01+RAM                1Eh  MBC5+RUMBLE+RAM+BATTERY
--   0Dh  MMM01+RAM+BATTERY        FCh  POCKET CAMERA
--   0Fh  MBC3+TIMER+BATTERY       FDh  BANDAI TAMA5
--   10h  MBC3+TIMER+RAM+BATTERY   FEh  HuC3
--   11h  MBC3                     FFh  HuC1+RAM+BATTERY
--   12h  MBC3+RAM
util.rom_types = {}
util.rom_types[0x00] = "ROM ONLY"
util.rom_types[0x01] = "MBC1"
util.rom_types[0x02] = "MBC1+RAM"
util.rom_types[0x03] = "MBC1+RAM+BATTERY"
util.rom_types[0x05] = "MBC2"
util.rom_types[0x06] = "MBC2+BATTERY"
util.rom_types[0x08] = "ROM+RAM"
util.rom_types[0x09] = "ROM+RAM+BATTERY"
util.rom_types[0x0B] = "MMM01"
util.rom_types[0x0C] = "MMM01+RAM"
util.rom_types[0x0D] = "MMM01+RAM+BATTERY"
util.rom_types[0x0F] = "MBC3+TIMER+BATTERY"
util.rom_types[0x10] = "MBC3+TIMER+RAM+BATTERY"
util.rom_types[0x11] = "MBC3"
util.rom_types[0x12] = "MBC3+RAM"
util.rom_types[0x13] = "MBC3+RAM+BATTERY"
util.rom_types[0x15] = "MBC4"
util.rom_types[0x16] = "MBC4+RAM"
util.rom_types[0x17] = "MBC4+RAM+BATTERY"
util.rom_types[0x19] = "MBC5"
util.rom_types[0x1A] = "MBC5+RAM"
util.rom_types[0x1B] = "MBC5+RAM+BATTERY"
util.rom_types[0x1C] = "MBC5+RUMBLE"
util.rom_types[0x1D] = "MBC5+RUMBLE+RAM"
util.rom_types[0x1E] = "MBC5+RUMBLE+RAM+BATTERY"
util.rom_types[0xFC] = "POCKET CAMERA"
util.rom_types[0xFD] = "BANDAI TAMA5"
util.rom_types[0xFE] = "HuC3"
util.rom_types[0xFF] = "HuC1+RAM+BATTERY"
function util.get_type()
    return util.rom_types[memory.get(0x0147)]
    -- return util.rom_types[0]
end

--   00h -  32KByte (no ROM banking)
--   01h -  64KByte (4 banks)
--   02h - 128KByte (8 banks)
--   03h - 256KByte (16 banks)
--   04h - 512KByte (32 banks)
--   05h -   1MByte (64 banks)  - only 63 banks used by MBC1
--   06h -   2MByte (128 banks) - only 125 banks used by MBC1
--   07h -   4MByte (256 banks)
--   52h - 1.1MByte (72 banks)
--   53h - 1.2MByte (80 banks)
--   54h - 1.5MByte (96 banks)
function util.get_rom_size() return bit.lshift(32 * 1024, memory.get(0x0148)) end

-- RAM SIZE 0x0149
--   00h - None
--   01h - 2 KBytes
--   02h - 8 Kbytes
--   03h - 32 KBytes (4 banks of 8KBytes each)

return util
