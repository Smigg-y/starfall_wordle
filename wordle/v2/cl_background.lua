--@name wordle/v2/cl_background
--@author Smiggy
--@client

local WordleUtil = ...

local Colors, Fonts = WordleUtil.Colors, WordleUtil.Fonts

local rtNames = {
    waiting = "wordle_bg_waiting",
    active  = "wordle_bg_active",
    result  = "wordle_bg_result",
}
for _, v in pairs(rtNames) do
    if not render.renderTargetExists(v) then
        render.createRenderTarget(v)
    end
end

local TileW, TileH = 64, 64
local HalfW, HalfH = TileW * 0.5, TileH * 0.5

local function withAlpha(c, a)
    return Color(c.r, c.g, c.b, a)
end

local fillByType = {
    correct = withAlpha(Colors.tileCorrect, 56),
    present = withAlpha(Colors.tilePresent, 56),
    absent  = withAlpha(Colors.tileAbsent, 56),
}
local letterColor = withAlpha(Colors.white, 46)
local outlineColor = Color(30, 30, 30)

local tiles = {
    waiting = {
        { x = 61,  y = 100, rot = -12, type = "correct", scale = 2.70, letter = "W" },
        { x = 972, y = 165, rot = 10,  type = "present", scale = 2.40, letter = "O" },
        { x = 53,  y = 885, rot = 8,   type = "absent",  scale = 2.10, letter = "R" },
        { x = 956, y = 890, rot = -7,  type = "correct", scale = 2.88, letter = "D" },
        { x = 180, y = 60,  rot = 18,  type = "blank",   scale = 0.90 },
        { x = 855, y = 75,  rot = -8,  type = "blank",   scale = 0.66 },
        { x = 240, y = 280, rot = -18, type = "blank",   scale = 0.60 },
        { x = 910, y = 600, rot = 12,  type = "blank",   scale = 0.84 },
        { x = 840, y = 770, rot = -14, type = "blank",   scale = 1.10 },
        { x = 140, y = 950, rot = 22,  type = "blank",   scale = 0.78 },
        { x = 260, y = 50,  rot = 25,  type = "present", scale = 0.42 },
        { x = 75,  y = 370, rot = 5,   type = "absent",  scale = 0.36 },
        { x = 915, y = 320, rot = -10, type = "correct", scale = 0.54 },
        { x = 790, y = 470, rot = 18,  type = "present", scale = 0.30 },
        { x = 155, y = 690, rot = -12, type = "correct", scale = 0.45 },
        { x = 760, y = 990, rot = 0,   type = "absent",  scale = 0.30 },
    },
    active = {
        { x = 985, y = 180, rot = -12, type = "present", scale = 1.65 },
        { x = 35,  y = 130, rot = 15,  type = "correct", scale = 1.80 },
        { x = 970, y = 780, rot = -15, type = "correct", scale = 1.50 },
        { x = 60,  y = 720, rot = 8,   type = "absent",  scale = 1.35 },
        { x = 870, y = 60,  rot = -10, type = "blank",   scale = 0.66 },
        { x = 195, y = 55,  rot = 18,  type = "blank",   scale = 0.78 },
        { x = 905, y = 380, rot = 12,  type = "blank",   scale = 0.72 },
        { x = 145, y = 290, rot = -15, type = "blank",   scale = 0.54 },
        { x = 940, y = 580, rot = -8,  type = "blank",   scale = 0.84 },
        { x = 90,  y = 540, rot = 20,  type = "blank",   scale = 0.60 },
        { x = 825, y = 250, rot = -18, type = "present", scale = 0.36 },
        { x = 260, y = 160, rot = 22,  type = "absent",  scale = 0.30 },
        { x = 870, y = 700, rot = 15,  type = "absent",  scale = 0.33 },
        { x = 175, y = 460, rot = 5,   type = "correct", scale = 0.27 },
    },
    result = {
        { x = 40,  y = 95,  rot = -10, type = "correct", scale = 2.10 },
        { x = 985, y = 145, rot = 14,  type = "correct", scale = 1.80 },
        { x = 85,  y = 880, rot = 8,   type = "present", scale = 1.95 },
        { x = 940, y = 895, rot = -12, type = "correct", scale = 2.25 },
        { x = 175, y = 55,  rot = 15,  type = "blank",   scale = 0.78 },
        { x = 870, y = 70,  rot = -10, type = "blank",   scale = 0.90 },
        { x = 235, y = 295, rot = 20,  type = "blank",   scale = 0.60 },
        { x = 845, y = 720, rot = -18, type = "blank",   scale = 1.05 },
        { x = 155, y = 770, rot = 12,  type = "blank",   scale = 0.72 },
        { x = 280, y = 100, rot = 25,  type = "correct", scale = 0.36 },
        { x = 815, y = 245, rot = -15, type = "present", scale = 0.42 },
        { x = 905, y = 410, rot = 18,  type = "correct", scale = 0.30 },
        { x = 85,  y = 480, rot = -8,  type = "present", scale = 0.39 },
        { x = 870, y = 550, rot = 22,  type = "correct", scale = 0.45 },
        { x = 220, y = 660, rot = -20, type = "absent",  scale = 0.27 },
        { x = 760, y = 970, rot = 10,  type = "correct", scale = 0.33 },
        { x = 305, y = 945, rot = -12, type = "present", scale = 0.30 },
    }
}

local function renderTile(tile)
    if tile.type == "blank" then
        render.setColor(outlineColor)
        render.drawRectOutline(-HalfW, -HalfH, TileW, TileH, 4)
        return
    end

    render.setColor(fillByType[tile.type])
    render.drawRect(-HalfW, -HalfH, TileW, TileH)

    if tile.letter then
        render.setColor(letterColor)
        render.drawSimpleText(0, 0, tile.letter, TEXT_ALIGN.CENTER, TEXT_ALIGN.CENTER)
    end
end

local tileMatrix = Matrix()
local tmpVec = Vector()
local tmpAng = Angle()

local function drawTile(tile)
    tileMatrix:setIdentity()

    tmpVec.x, tmpVec.y, tmpVec.z = tile.x, tile.y, 0
    tileMatrix:translate(tmpVec)

    tmpAng.p, tmpAng.y, tmpAng.r = 0, tile.rot, 0
    tileMatrix:rotate(tmpAng)

    tmpVec.x, tmpVec.y, tmpVec.z = tile.scale, tile.scale, 1
    tileMatrix:scale(tmpVec)

    render.pushMatrix(tileMatrix, false)
    renderTile(tile)
    render.popMatrix()
end

return function()
    hook.add("RenderOffscreen", "WordleBackground", function()
        for state, rtName in pairs(rtNames) do
            render.selectRenderTarget(rtName)
            render.clear(Colors.transparent)

            render.setFont(Fonts.subtitleSmall)
            for i = 1, #tiles[state] do
                drawTile(tiles[state][i])
            end
        end

        hook.remove("RenderOffscreen", "WordleBackground")
    end)

    return rtNames
end
