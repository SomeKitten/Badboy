local graphics = {}

graphics.update_graphics = function()
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
            for x = 0, 7 do
                graphics.draw_tile(points, tx, ty, tile, x, y)
            end
        end
    end

    love.graphics.points(points)

    love.graphics.setCanvas()
end

graphics.run_graphics = function()
    interrupts.lcd_status()

    scancount = scancount - instlen

    if scancount <= 0 then
        memory[0xFF44] = memory[0xFF44] + 1
        currentline = memory[0xFF44]

        scancount = scancount + 456

        if currentline == 144 then memory.set_IF(0, 1) end

        if currentline > 153 then
            memory[0xFF44] = 0
            return true
        end

        if currentline < 144 then draw_scanline() end
    end

    return false
end

graphics.draw_tile = function(points, tx, ty, tile_addr, x, y)
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

    points[#points + 1] = {
        x + tx + 0.5, y + ty + 0.5, colours[palette[point]],
        colours[palette[point]], colours[palette[point]], 1
    }
end

return graphics
