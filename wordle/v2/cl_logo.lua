--@name wordle/v2/cl_logo
--@author Smiggy
--@client

--@include wordle/v2/sh_wordle.lua

local WordleUtil = require("wordle/v2/sh_wordle.lua")

local rtName = "wordlelogo_rt"
render.createRenderTarget(rtName)

local W, Y, G, B = WordleUtil.Colors.white, WordleUtil.Colors.yellow, WordleUtil.Colors.green, WordleUtil.Colors.black
local Font = WordleUtil.Fonts.titleLarge
local function drawCell(x, y, w, h, r, color, tl, tr, bl, br)
    render.setColor(color)
    render.drawRoundedBoxEx(r, x, y, w, h, tl, tr, bl, br)
end

render.setFont(Font)
local _, titleH = render.getTextSize("WORDLE")

local function renderWordleLogo()
    local w, h = 768, 768
    local pad, r = 14, 18

    local bw = (w - 4 * pad) / 3
    local bh = (h - 4 * pad) / 3

    local sw, sh = render.getResolution()
    local x = (sw - w) / 2
    local y = (sh - h - titleH) / 2

    -- column positions
    local lx = x + pad
    local cx = lx + bw + pad
    local rx = cx + bw + pad
    -- row positions
    local ty = y + pad
    local my = ty + bh + pad
    local by = my + bh + pad

    render.setColor(B)
    render.drawRoundedBox(r, x, y, w, h)

    drawCell(lx, ty, bw, bh, r, W, true, false, false, false)
    drawCell(cx, ty, bw, bh, r, W, false, false, false, false)
    drawCell(rx, ty, bw, bh, r, W, false, true, false, false)

    drawCell(lx, my, bw, bh, r, W, false, false, false, false)
    drawCell(cx, my, bw, bh, r, Y, false, false, false, false)
    drawCell(rx, my, bw, bh, r, G, false, false, false, false)

    drawCell(lx, by, bw, bh, r, G, false, false, true, false)
    drawCell(cx, by, bw, bh, r, G, false, false, false, false)
    drawCell(rx, by, bw, bh, r, G, false, false, false, true)

    render.setColor(W)
    render.setFont(Font)
    render.drawText(x + (w / 2), y + h, "WORDLE", TEXT_ALIGN.CENTER)
end

return function()
    hook.add("RenderOffscreen", "renderWordleLogo", function()
        render.selectRenderTarget(rtName)
        render.clear(Color(0, 0, 0, 0))
        renderWordleLogo()
        render.selectRenderTarget()

        hook.remove("RenderOffscreen", "renderWordleLogo")
    end)

    return rtName
end
