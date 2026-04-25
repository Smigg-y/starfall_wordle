--@name wordle/v2/cl_keyboard
--@author Smiggy
--@client

--@include wordle/v2/sh_wordle.lua
--@include wordle/v2/cl_input.lua

local WordleUtil = require("wordle/v2/sh_wordle.lua")
local WordleInput = require("wordle/v2/cl_input.lua")

local KeyW, KeyH, KeyPad = 86, 116, 12
local WideKeys = { ENTER = 130, BKSP = 130 }
local StatePriority = { default = 0, absent = 1, present = 2, correct = 3 }

local Config, Fonts, Colors, FeedbackStates, Sounds = WordleUtil.Config, WordleUtil.Fonts, WordleUtil.Colors,
		WordleUtil.FeedbackStates, WordleUtil.Sounds
local ScrW, ScrH = Config.ScrW, Config.ScrH

local WordleKey = class("wordlekey", WordleInput.Button)

function WordleKey:initialize(letter, bounds, wide)
	WordleInput.Button.initialize(self, bounds, nil)
	self.letter     = letter
	self.wide       = wide
	self.state      = "default"
	self.stateColor = nil
	self.pressed    = false
	self.font       = wide and Fonts.subtitleSmall or Fonts.subtitle
	self.fontOffset = wide and 24 or 32
end

function WordleKey:onPress()
	self.pressed = true
	timer.simple(0.1, function() self.pressed = false end)
	WordleInput.Button.onPress(self)
end

local stateBgColors = {
	absent  = Colors.keyAbsent,
	present = Colors.keyPresent,
	correct = Colors.keyCorrect
}

function WordleKey:setState(newState)
	if (StatePriority[newState] or 0) > StatePriority[self.state] then
		self.state = newState
		self.stateColor = stateBgColors[newState]
	end
end

function WordleKey:getColor()
	if self.stateColor then return self.stateColor end
	if self.pressed then return Colors.keyPressed end
	if self.hovered then return Colors.keyHovered end
	return Colors.keyDefault
end

function WordleKey:drawBackground()
	render.setColor(self:getColor())
	render.drawRoundedBox(8, self.x, self.y, self.w, self.h)
end

function WordleKey:drawLabel()
	render.drawText(self.x + self.w / 2, (self.y + self.h / 2) - self.fontOffset, self.letter, TEXT_ALIGN.CENTER)
end

local function rowWidth(row)
	local w = 0
	for i, letter in ipairs(row) do
		w = w + (WideKeys[letter] or KeyW)
		if i > 1 then w = w + KeyPad end
	end
	return w
end

local WordleKeyboard = class("wordlekeyboard")

function WordleKeyboard:initialize(layout, inputManager, onKeyPressed, w, y)
	self.w = w or ScrW
	self.y = y or ScrH / 2

	self.inputManager = inputManager
	self.onKeyPressed = onKeyPressed

	self.keys = {}
	self.narrowKeys = {}
	self.wideKeys = {}
	self.keysByLabel = {}

	self:buildLayout(layout)
end

function WordleKeyboard:buildLayout(layout)
	self.inputManager:clearGroup("keyboard")
	self.keys = {}
	self.narrowKeys = {}
	self.wideKeys = {}
	self.keysByLabel = {}

	self.keyboardHeight = ((KeyH + KeyPad) * #layout)

	for rowI, row in ipairs(layout) do
		local x = math.floor((self.w - rowWidth(row)) / 2)
		local y = math.floor(self.y + (rowI - 1) * (KeyH + KeyPad))

		for _, letter in ipairs(row) do
			local wideW = WideKeys[letter]
			local w = wideW or KeyW
			local key = WordleKey:new(letter, { x = x, y = y, w = w, h = KeyH }, wideW ~= nil)

			key.onPressed = function() self.onKeyPressed(self, letter) end

			table.insert(self.keys, key)
			if wideW then
				table.insert(self.wideKeys, key)
			else
				table.insert(self.narrowKeys, key)
			end
			self.keysByLabel[letter] = key
			self.inputManager:register("keyboard", key)

			x = x + w + KeyPad
		end
	end
end

function WordleKeyboard:getHeight()
	return self.keyboardHeight or 0
end

function WordleKeyboard:applyFeedback(guess, feedback)
	for i = 1, #guess do
		local letter = guess:sub(i, i)
		local newState = FeedbackStates[feedback[i]]
		local key = self.keysByLabel[letter]
		if key and newState then key:setState(newState) end
	end
end

function WordleKeyboard:reset()
	for _, key in ipairs(self.keys) do
		key.state = "default"
		key.hovered = false
		key.pressed = false
		key.stateColor = nil
	end
end

function WordleKeyboard:draw()
	render.setColor(Colors.darkGrey)

	local offset = (KeyPad * 4)
	render.drawRoundedBox(8, offset / 2, self.y - (KeyPad / 2), self.w - offset, self:getHeight())

	for _, key in ipairs(self.keys) do
		key:drawBackground()
	end
	render.setColor(Colors.offWhite)
	render.setFont(Fonts.subtitle)
	for _, key in ipairs(self.narrowKeys) do
		key:drawLabel()
	end
	render.setFont(Fonts.subtitleSmall)
	for _, key in ipairs(self.wideKeys) do
		key:drawLabel()
	end
end

return WordleKeyboard
