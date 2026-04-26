--@name wordle/v2/cl_tile
--@author Smiggy
--@client

local WordleUtil = require("sh_wordle.lua")
local Sounds = WordleUtil.Sounds

---@class WordleTile
local WordleTile = class("wordletile")

local Animations, Colors, FeedbackStates = WordleUtil.Animations, WordleUtil.Colors, WordleUtil.FeedbackStates
local invFlipDuration = 1 / Animations.flipDuration
local invPopDuration = 1 / Animations.popDuration
local invBounceDuration = 1 / Animations.bounceDuration

local outlineColors = {
    empty = Colors.outlineEmpty,
    filled = Colors.outlineFilled,
}

local tileColors = {
    empty = Colors.tileEmpty,
    filled = Colors.tileFilled,
    absent = Colors.tileAbsent,
    present = Colors.tilePresent,
    correct = Colors.tileCorrect,
}

function WordleTile:initialize(letter, x, y, w, h)
    self.x, self.y, self.w, self.h = x, y, w, h
    self.cx, self.cy = x + w / 2, y + h / 2
    self:reset()
    self.letter = letter
end

local function refreshColor(tile)
    local s = tile.displayState or tile.state
    tile.color = tileColors[s]
end

function WordleTile:reset()
    self.letter = ""
    self.state = "empty"
    self.pendingState = nil
    self.displayState = nil
    self.flipStart = nil
    self.flipScaleY = 1
    self.popScale = 1
    self.popStart = nil
    self.bounceY = 0
    self.bounceStart = nil
    self.animating = false
    refreshColor(self)
end

function WordleTile:startFlip(rawState, col)
    self.pendingState = FeedbackStates[rawState]
    self.flipStart = timer.systime()
    self.animating = true
    Sounds.PlaySound(Sounds.tileFlip, 90 + col * 4)
end

function WordleTile:startPop()
    self.popScale = 1
    self.popStart = timer.systime()
    self.animating = true
end

function WordleTile:startBounce(startAt, col)
    startAt = startAt or timer.systime()
    self.bounceY = 0
    self.bounceStart = startAt
    self.animating = true

    local when = math.max(0, startAt - timer.systime())
    timer.simple(when, function()
        Sounds.PlaySound(Sounds.rowWin, 90 + col * 4)
    end)
end

function WordleTile:setLetter(char)
    self.letter = char
    self.state = "filled"
    refreshColor(self)
    self:startPop()
end

function WordleTile:clearLetter()
    self.letter = ""
    self.state = "empty"
    refreshColor(self)
end

function WordleTile:update(now)
    if not self.animating then
        return
    end

    local stillBusy = false

    if self.flipStart then
        local t = (now - self.flipStart) * invFlipDuration
        if t >= 1 then
            self.state = self.pendingState
            self.pendingState = nil
            self.displayState = nil
            self.flipStart = nil
            refreshColor(self)
        else
            self.flipScaleY = math.abs(math.cos(t * math.pi))

            local newDisplayState = t >= 0.5 and self.pendingState or "empty"
            if newDisplayState ~= self.displayState then
                self.displayState = newDisplayState
                refreshColor(self)
            end
            stillBusy = true
        end
    end

    if self.popStart then
        local pt = (now - self.popStart) * invPopDuration
        if pt >= 1 then
            self.popScale = 1
            self.popStart = nil
        else
            self.popScale = 1.15 - 0.3 * math.abs(pt - 0.5)
            stillBusy = true
        end
    end

    if self.bounceStart then
        if now < self.bounceStart then
            stillBusy = true
        else
            local bt = (now - self.bounceStart) * invBounceDuration
            if bt >= 1 then
                self.bounceY = 0
                self.bounceStart = nil
            else
                self.bounceY = -math.sin(bt * math.pi) * Animations.bounceHeight
                stillBusy = true
            end
        end
    end

    self.animating = stillBusy
end

render.setFont(WordleUtil.Fonts.subtitle)
local _, subtitleH = render.getTextSize("A")

function WordleTile:renderTile(state, xOffset)
    local sx = self.x + xOffset

    if self.color.a ~= 0 then
        render.setColor(self.color)
        render.drawRectFast(sx, self.y, self.w, self.h)
    end

    local outline = outlineColors[state]

    if outline then
        render.setColor(outline)
        render.drawRectOutline(sx, self.y, self.w, self.h, 2)
    end

    if self.letter ~= "" then
        render.setColor(Colors.offWhite)
        render.drawText(self.cx + xOffset, self.cy - subtitleH / 2, self.letter, TEXT_ALIGN.CENTER)
    end
end

local tileMatrix = Matrix()
local tmpVec = Vector()

function WordleTile:draw(xOffset)
    if not self.animating then
        self:renderTile(self.state, xOffset)
        return
    end

    local popScale, flipScaleY, bounceY = self.popScale, self.flipScaleY, self.bounceY

    if popScale == 1 and flipScaleY == 1 and bounceY == 0 then
        self:renderTile(self.displayState or self.state, xOffset)
        return
    end

    local cx = self.cx + xOffset
    local cy = self.cy

    tileMatrix:setIdentity()

    tmpVec.x, tmpVec.y, tmpVec.z = cx, cy + bounceY, 0
    tileMatrix:translate(tmpVec)

    tmpVec.x, tmpVec.y, tmpVec.z = popScale, flipScaleY * popScale, 1
    tileMatrix:scale(tmpVec)

    tmpVec.x, tmpVec.y, tmpVec.z = -cx, -cy, 0
    tileMatrix:translate(tmpVec)

    render.pushMatrix(tileMatrix, false)
    self:renderTile(self.displayState or self.state, xOffset)
    render.popMatrix()
end

return WordleTile
