--@name wordle/v2/cl_grid
--@author Smiggy
--@client

--@include wordle/v2/sh_wordle.lua
--@include wordle/v2/cl_tile.lua

local WordleUtil = require("wordle/v2/sh_wordle.lua")
local WordleTile = require("wordle/v2/cl_tile.lua")

local Config, Lang, Animations, Fonts = WordleUtil.Config, WordleUtil.Lang, WordleUtil.Animations, WordleUtil.Fonts
local wordLength, maxGuesses = Config.wordLength, Config.maxGuesses

---@class WordleGrid
local WordleGrid = class("wordle_grid")

function WordleGrid:initialize(ui, x, y, tileW, tileH, pad)
    self.tiles = {}
    self.tileW = tileW or 100
    self.tileH = tileH or 100
    self.pad = pad or 12

    self.currentRow = 1
    self.currentCol = 1

    self.locked = false

    self.shakingRow = nil
    self.shakeStart = nil
    self.shakeOffset = nil

    self.ui = ui
    self._activeTiles = {}

    local gridW = wordLength * (self.tileW + self.pad) - self.pad
    local gridH = maxGuesses * (self.tileH + self.pad) - self.pad
    local ogx, ogy = x - gridW / 2, y - gridH / 2

    for row = 1, maxGuesses do
        self.tiles[row] = {}
        for col = 1, wordLength do
            local tx = ogx + (col - 1) * (self.tileW + self.pad)
            local ty = ogy + (row - 1) * (self.tileH + self.pad)
            self.tiles[row][col] = WordleTile:new(tx, ty, self)
        end
    end
end

function WordleGrid:reset()
    for _, row in ipairs(self.tiles) do
        for _, tile in ipairs(row) do
            tile:reset()
        end
    end

    self.currentRow = 1
    self.currentCol = 1
    self.locked = false
    self.shakingRow = nil
    self.shakeStart = nil
    self.shakeOffset = nil
    self._activeTiles = {}
end

function WordleGrid:_addActive(tile)
    if tile._inActive then return end
    tile._inActive = true
    self._activeTiles[#self._activeTiles + 1] = tile
end

function WordleGrid:shakeRow()
    self.shakingRow = self.currentRow
    self.shakeStart = timer.systime()
end

function WordleGrid:bounceRow()
    local tiles = self.tiles[self.currentRow - 1]
    if not tiles then
        return
    end

    local now = timer.systime()
    for i, tile in ipairs(tiles) do
        tile:startBounce(now + (i - 1) * Animations.bounceDelay, i)
    end
end

function WordleGrid:getCurrentTile()
    return self.tiles[self.currentRow][self.currentCol]
end

function WordleGrid:getCurrentGuess()
    local guess = {}
    for i = 1, wordLength do
        guess[i] = self.tiles[self.currentRow][i].letter
    end
    return table.concat(guess)
end

function WordleGrid:typeKey(char)
    if self.locked then return end
    if self.currentRow > maxGuesses then return end
    if self.currentCol > wordLength then return end

    if not char or not Lang.charToIndex[char] then return end

    self:getCurrentTile():setLetter(char)
    self.currentCol = self.currentCol + 1
end

function WordleGrid:deleteLastKey()
    if self.locked then
        return
    end
    if self.currentCol <= 1 then
        return
    end

    self.currentCol = self.currentCol - 1
    self:getCurrentTile():clearLetter()
end

function WordleGrid:applyFeedback(guess, feedback, keepLocked, onComplete)
    if self.currentCol ~= wordLength + 1 then
        return
    end

    local guessChars = WordleUtil.utf8chars(guess)
    if #guessChars ~= wordLength then return end

    self.locked = true

    local row = self.tiles[self.currentRow]

    local now = timer.systime()
    for i = 1, wordLength do
        row[i].letter = guessChars[i]
        row[i]:startFlip(feedback[i], i, now + (i - 1) * Animations.flipDelay)
    end

    local seqEnd = (wordLength - 1) * Animations.flipDelay + Animations.flipDuration
    self.ui:schedule(seqEnd, function()
        self.currentRow = self.currentRow + 1
        self.currentCol = 1
        if not keepLocked then
            self.locked = false
        end
        if onComplete then
            onComplete()
        end
    end)
end

function WordleGrid:update(now)
    local active = self._activeTiles
    for i = #active, 1, -1 do
        local tile = active[i]
        tile:update(now)
        if not tile.animating then
            tile._inActive = false
            active[i] = active[#active]
            active[#active] = nil
        end
    end

    if self.shakeStart and self.shakingRow then
        local t = (now - self.shakeStart) / Animations.shakeDuration
        if t >= 1 then
            self.shakingRow = nil
            self.shakeStart = nil
        else
            self.shakeOffset = math.sin(t * math.pi * Animations.shakeFrequency) * Animations.shakeMagnitude * (1 - t)
        end
    end
end

function WordleGrid:draw()
    render.setFont(Fonts.subtitle)

    for rowI, row in ipairs(self.tiles) do
        local ox = (rowI == self.shakingRow) and self.shakeOffset or 0
        for _, tile in ipairs(row) do
            tile:draw(ox)
        end
    end
end

return WordleGrid
