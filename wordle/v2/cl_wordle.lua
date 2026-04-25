--@name wordle/v2/cl_wordle
--@author Smiggy
--@client

--@include wordle/v2/sh_wordle.lua
--@include wordle/v2/cl_input.lua
--@include wordle/v2/cl_logo.lua
--@include wordle/v2/cl_grid.lua
--@include wordle/v2/cl_keyboard.lua

local WordleUtil                                                             = require("wordle/v2/sh_wordle.lua")
local WordleInput                                                            = require("wordle/v2/cl_input.lua")
local WordleLogo                                                             = require("wordle/v2/cl_logo.lua")
local WordleGrid                                                             = require("wordle/v2/cl_grid.lua")
local WordleKeyboard                                                         = require("wordle/v2/cl_keyboard.lua")

local Config, States, Animations, NetNames, Colors, Fonts, Materials, Sounds = WordleUtil.Config, WordleUtil.States,
		WordleUtil.Animations, WordleUtil.NetNames, WordleUtil.Colors, WordleUtil.Fonts, WordleUtil.Materials,
		WordleUtil.Sounds
local wordLength, maxGuesses, ScrW, ScrH                                     = Config.wordLength, Config.maxGuesses,
		Config.ScrW, Config.ScrH

local nextFrame                                                              = 0
local FPSDelta                                                               = 1 / Config.FPS
render.createRenderTarget("wordleui_rt")
render.createRenderTarget("wordlekeyboard_rt")

local WordleUI = class("wordleui")

function WordleUI:initialize()
	self.state = States.waiting
	self.player = nil
	self.guesses = 0

	self.layout = self:performLayout()

	self.grid = WordleGrid:new(self.layout.grid.x, self.layout.grid.y)

	self.inputManager = WordleInput.InputManager:new()
	self.keyboard = WordleKeyboard:new(WordleUtil.KeyboardLayout, self.inputManager, function(_, letter)
		self:onKeyPressed(letter)
	end)
	self:initializeInputs()

	self.gameTransitionTime = 1 + Animations.bounceDuration + Animations.bounceDelay * (wordLength - 1)
end

function WordleUI:start()
	net.start(NetNames.StartGame)
	net.send()
end

function WordleUI:_resetState()
	self.state = States.waiting
	self.pendingState = nil
	self.player = nil
	self.guesses = 0
	self.endMessage = nil

	self.grid:reset()
	self.keyboard:reset()

	self.inputManager:setOwner(nil)
	self.inputManager:clearGroup("ui")
	self.inputManager:register("ui", self.playButton)
end

function WordleUI:reset()
	net.start(NetNames.ResetGame)
	net.send()
	self:_resetState()
end

function WordleUI:onStart(ply)
	self.state = States.active
	self.pendingState = nil
	self.endMessage = nil
	self.player = ply
	self.guesses = 0

	self.grid:reset()
	self.keyboard:reset()

	self.inputManager:setOwner(ply)
	self.inputManager:clearGroup("ui")
	self.inputManager:register("ui", self.homeButton)
end

function WordleUI:onKeyPressed(label)
	if self.state ~= States.active then return end

	if label == "ENTER" then
		self:submitGuess()
	elseif label == "BKSP" then
		self.grid:deleteLastKey()
		Sounds.PlaySound(Sounds.keyBack)

		net.start(NetNames.KeyDeleted)
		net.send()
	else
		self.grid:typeKey(label)
		net.start(NetNames.KeyTyped)
		net.writeUInt(string.byte(label) - 65, 5) -- 'A' -> 0
		net.send()
	end
end

function WordleUI:submitGuess()
	if self.grid.locked then return end
	if self.grid.currentCol <= wordLength then
		self.grid:shakeRow()
		Sounds.PlaySound(Sounds.invalid)
		return
	end

	self.grid.locked = true
	Sounds.PlaySound(Sounds.keyEnter)

	net.start(NetNames.NewGuess)
	WordleUtil.Net.WriteWord(self.grid:getCurrentGuess():lower())
	net.send()
end

function WordleUI:onGuessResult(feedback, state, answer)
	local guess = self.grid:getCurrentGuess()
	local isEnd = state == States.won or state == States.lost

	if isEnd then
		self.pendingState = state
	else
		self.state = state
	end

	self.guesses = self.guesses + 1

	self.grid:applyFeedback(guess, feedback, isEnd, function()
		self.keyboard:applyFeedback(guess, feedback)

		if state == States.won then
			self.grid:bounceRow()
		end

		timer.simple(self.gameTransitionTime, function()
			if self.state == States.waiting then return end

			if self.pendingState then
				self.state = self.pendingState
				self.pendingState = nil
			end

			local isLocalPlayer = player() == self.player

			if state == States.won then
				self.endMessage = WordleUtil.WinMessages[self.guesses]
				if isLocalPlayer then
					Sounds.PlaySound(Sounds.win)
				end
			elseif state == States.lost then
				self.endMessage = "THE WORD WAS - " .. string.upper(answer or "?")
				if isLocalPlayer then
					Sounds.PlaySound(Sounds.lose)
				end
			end

			if isEnd then
				self.inputManager:setOwner(nil)
				self.inputManager:clearGroup("ui")
				self.inputManager:register("ui", self.playButton)
				self.inputManager:register("ui", self.homeButton)
			end
		end)
	end)
end

function WordleUI:performLayout()
	local out = {}

	for name, el in pairs(WordleUtil.Layout) do
		local x, y = el.x, el.y
		local fn = WordleUtil.Anchors[el.anchor]
		if fn then
			x, y = fn(el, ScrW, ScrH)
		end

		out[name] = {
			x = x - (el.w and el.w * 0.5 or 0),
			y = y - (el.h and el.h * 0.5 or 0),
			w = el.w,
			h = el.h
		}
	end

	return out
end

function WordleUI:initializeInputs()
	self.playButton = WordleInput.Button:new(self.layout.playButton, function()
		self:start()
	end)

	self.homeButton = WordleInput.Button:new(self.layout.homeButton, function()
		self:reset()
	end)

	self.inputManager:register("ui", self.playButton)
end

render.setFont(Fonts.subtitle)
local _, subtitleH = render.getTextSize("A")

local function drawPlayButton(bounds, hovered)
	render.setColor(hovered and Colors.lightGrey or Colors.white)
	render.drawRoundedBox(64, bounds.x, bounds.y, bounds.w, bounds.h)

	render.setColor(Colors.darkGrey)
	render.setFont(Fonts.title)
	render.drawText(bounds.x + (bounds.w / 2), bounds.y, "PLAY", TEXT_ALIGN.CENTER)
end

local function drawHomeButton(bounds, hovered)
	local col = hovered and Colors.lightGrey or Colors.white
	render.setColor(col)
	render.drawRoundedBox(16, bounds.x, bounds.y, bounds.w, bounds.h)

	render.setColor(Colors.darkGrey)
	render.setMaterial(Materials.HomeButton)
	render.drawTexturedRect(bounds.x, bounds.y, bounds.w, bounds.h)
end

local subtextOne = "GET " .. maxGuesses .. " CHANCES TO GUESS"
local subtextTwo = "A " .. wordLength .. " LETTER WORD"

function WordleUI:drawHomeScreen()
	WordleLogo(self.layout.wordleLogo)
	drawPlayButton(self.layout.playButton, self.playButton.hovered)

	local bounds = self.layout.subtitle
	render.setColor(Colors.white)
	render.setFont(Fonts.subtitle)
	render.drawText(bounds.x, bounds.y - subtitleH / 2, subtextOne, TEXT_ALIGN.CENTER)
	render.drawText(bounds.x, bounds.y + subtitleH / 2, subtextTwo, TEXT_ALIGN.CENTER)
end

function WordleUI:drawPlayScreen(now)
	if not isValid(self.player) then
		self:_resetState()
		return
	end

	drawHomeButton(self.layout.homeButton, self.homeButton.hovered)

	self.grid:update(now)
	self.grid:draw()

	local bounds = self.layout.activePlayer
	render.setColor(Colors.white)
	render.setFont(Fonts.small)
	render.drawText(bounds.x + 48, bounds.y - 16, self.player:getName() .. " is playing", TEXT_ALIGN.LEFT)
end

function WordleUI:drawResultScreen()
	drawPlayButton(self.layout.playButton, self.playButton.hovered)
	drawHomeButton(self.layout.homeButton, self.homeButton.hovered)

	local didWin = self.state == States.won
	local col = didWin and Colors.green or Colors.yellow
	local resultText = didWin and "YOU WON!" or "YOU LOST"

	local bounds = self.layout.resultText
	render.setColor(col)
	render.setFont(Fonts.title)
	render.drawText(bounds.x, bounds.y, resultText, TEXT_ALIGN.CENTER)

	render.setColor(Colors.white)
	render.drawText(bounds.x, bounds.y + 96, self.endMessage or "", TEXT_ALIGN.CENTER)

	if didWin then
		render.setFont(Fonts.subtitle)
		render.drawText(bounds.x, bounds.y + 256, "Solved in " .. self.guesses .. "/" .. maxGuesses, TEXT_ALIGN.CENTER)
	end
end

function WordleUI:render()
	local now = timer.systime()
	if nextFrame > now then return end
	nextFrame = now + FPSDelta

	render.selectRenderTarget("wordleui_rt")
	render.clear()

	render.setColor(Colors.darkGrey)
	render.drawRect(0, 0, ScrW, ScrH)

	if self.state == States.waiting then
		self:drawHomeScreen()
	elseif self.state == States.active then
		self:drawPlayScreen(now)
	else
		self:drawResultScreen()
	end

	render.selectRenderTarget("wordlekeyboard_rt")
	render.clear(Colors.transparent)

	if self.state == States.active then
		self.keyboard:draw()
	end
end

--<<--------------<<-- Entry

local ui = WordleUI:new()

net.receive(NetNames.StartGame, function()
	local ply = net.readEntity()
	ui:onStart(ply)
end)

net.receive(NetNames.GuessResult, function()
	local feedbackBits = net.readUInt(2 * wordLength)
	local state = net.readUInt(3)

	local answer
	if state == States.won or state == States.lost then
		answer = WordleUtil.Net.ReadWord()
	end

	local feedback = WordleUtil.Bit.Unpack(feedbackBits, wordLength, 2)
	ui:onGuessResult(feedback, state, answer)
end)

net.receive(NetNames.Error, function()
	local errCode = net.readUInt(3)
	print(WordleUtil.ErrorMessages[errCode])

	if errCode == WordleUtil.ErrorCodes.invalidGuess then
		ui.grid.locked = false
		ui.grid:shakeRow()
		Sounds.PlaySound(Sounds.invalid)
	end
end)

--<<-- Sync

net.receive(NetNames.KeyTyped, function()
	if player() == ui.player then return end
	local key = net.readUInt(5)
	ui.grid:typeKey(string.char(key + 97))
end)

net.receive(NetNames.KeyDeleted, function()
	if player() == ui.player then return end
	ui.grid:deleteLastKey()
end)

net.receive(NetNames.ResetGame, function()
	if ui.state == States.waiting then return end
	ui:_resetState()
end)

--<<-- UI

hook.add("RenderOffscreen", "wordleui_render", function()
	ui:render()
end)

local mainScreen, keyboardScreen
hook.add("ComponentLinked", "wordleui_screen_setup", function(ent)
	if not ent or ent:getClass() ~= "starfall_screen" then return end

	if not mainScreen then
		mainScreen = ent
	else
		keyboardScreen = ent
		hook.remove("ComponentLinked", "wordleui_screen_setup")
	end
end)

hook.add("Render", "wordleui_draw", function()
	local scr = render.getScreenEntity()
	local w, h = render.getResolution()

	if scr == mainScreen then
		ui.inputManager:update("ui")
		render.setRenderTargetTexture("wordleui_rt")
	elseif scr == keyboardScreen then
		ui.inputManager:update("keyboard")
		render.setBackgroundColor(Colors.transparent)
		render.setRenderTargetTexture("wordlekeyboard_rt")
	else
		return
	end

	render.drawTexturedRect(0, 0, w, h)
end)
