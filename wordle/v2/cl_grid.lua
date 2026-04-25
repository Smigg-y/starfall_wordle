--@name wordle/v2/cl_grid
--@author Smiggy
--@client

--@include wordle/v2/sh_wordle.lua
--@include wordle/v2/cl_tile.lua

local WordleUtil = require("wordle/v2/sh_wordle.lua")
local WordleTile = require("wordle/v2/cl_tile.lua")

local Config, Animations, Fonts = WordleUtil.Config, WordleUtil.Animations, WordleUtil.Fonts
local wordLength, maxGuesses = Config.wordLength, Config.maxGuesses

local WordleGrid = class("wordle_grid")

function WordleGrid:initialize(x, y, tileW, tileH, pad)
	self.tiles         = {}
	self.tileW         = tileW or 100
	self.tileH         = tileH or 100
	self.pad           = pad or 12

	self.currentRow    = 1
	self.currentCol    = 1

	self.locked        = false

	self.shakingRow    = nil
	self.shakeStart    = nil
	self.shakeOffset   = nil

	self._generation   = 0
	self._anyAnimating = false

	local gridW        = wordLength * (self.tileW + self.pad) - self.pad
	local gridH        = maxGuesses * (self.tileH + self.pad) - self.pad
	local ogx, ogy     = x - gridW / 2, y - gridH / 2

	for row = 1, maxGuesses do
		self.tiles[row] = {}
		for col = 1, wordLength do
			local tx = ogx + (col - 1) * (self.tileW + self.pad)
			local ty = ogy + (row - 1) * (self.tileH + self.pad)
			self.tiles[row][col] = WordleTile:new("", tx, ty, self.tileW, self.tileH)
		end
	end
end

function WordleGrid:reset()
	self._generation = self._generation + 1

	for _, row in ipairs(self.tiles) do
		for _, tile in ipairs(row) do
			tile:reset()
		end
	end

	self.currentRow    = 1
	self.currentCol    = 1
	self.locked        = false
	self.shakingRow    = nil
	self.shakeStart    = nil
	self.shakeOffset   = nil
	self._anyAnimating = false
end

function WordleGrid:shakeRow(row)
	self.shakingRow = row or self.currentRow
	self.shakeStart = timer.systime()
end

function WordleGrid:bounceRow(row)
	row = row or self.currentRow - 1
	local tiles = self.tiles[row]
	if not tiles then return end

	self._anyAnimating = true
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

	char = char:upper():match("^%a$")
	if not char then return end

	self._anyAnimating = true
	self:getCurrentTile():setLetter(char)
	self.currentCol = self.currentCol + 1
end

function WordleGrid:deleteLastKey()
	if self.locked then return end
	if self.currentCol <= 1 then return end

	self.currentCol = self.currentCol - 1
	self:getCurrentTile():clearLetter()
end

function WordleGrid:applyFeedback(guess, feedback, keepLocked, onComplete)
	if self.currentCol ~= wordLength + 1 then return end
	if #guess ~= wordLength then return end

	self.locked        = true
	self._anyAnimating = true

	local row          = self.tiles[self.currentRow]
	local gen          = self._generation

	for i = 1, #guess do
		row[i].letter = guess:sub(i, i)
		timer.simple((i - 1) * Animations.flipDelay, function()
			if self._generation ~= gen then return end
			self._anyAnimating = true
			row[i]:startFlip(feedback[i], i)
		end)
	end

	local seqEnd = (#guess - 1) * Animations.flipDelay + Animations.flipDuration
	timer.simple(seqEnd, function()
		if self._generation ~= gen then return end
		self.currentRow = self.currentRow + 1
		self.currentCol = 1
		if not keepLocked then
			self.locked = false
		end
		if onComplete then onComplete() end
	end)
end

function WordleGrid:update(now)
	if self._anyAnimating then
		local stillAnimating = false
		for _, row in ipairs(self.tiles) do
			for _, tile in ipairs(row) do
				if tile.animating then
					tile:update(now)
					if tile.animating then stillAnimating = true end
				end
			end
		end
		self._anyAnimating = stillAnimating
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
