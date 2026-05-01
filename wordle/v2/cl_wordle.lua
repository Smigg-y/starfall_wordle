--@name wordle/v2/cl_wordle
--@author Smiggy
--@client

--@include wordle/v2/sh_wordle.lua
--@include wordle/v2/cl_input.lua
--@include wordle/v2/cl_logo.lua
--@include wordle/v2/cl_grid.lua
--@include wordle/v2/cl_keyboard.lua
--@include wordle/v2/cl_background.lua

local WordleUtil = require("wordle/v2/sh_wordle.lua")
local WordleInput = require("wordle/v2/cl_input.lua")
local WordleLogo = require("wordle/v2/cl_logo.lua")
local WordleGrid = require("wordle/v2/cl_grid.lua")
local WordleKeyboard = require("wordle/v2/cl_keyboard.lua")
local WordleBackground = require("wordle/v2/cl_background.lua")

local Config, States, Animations, NetNames, Colors, Fonts, Materials, Sounds =
    WordleUtil.Config,
    WordleUtil.States,
    WordleUtil.Animations,
    WordleUtil.NetNames,
    WordleUtil.Colors,
    WordleUtil.Fonts,
    WordleUtil.Materials,
    WordleUtil.Sounds
local wordLength, maxGuesses, ScrW, ScrH = Config.wordLength, Config.maxGuesses, Config.ScrW, Config.ScrH
local Lang = WordleUtil.Lang
local l10n = Lang.localization

local nextFrame = 0
local FPSDelta = 1 / Config.FPS
render.createRenderTarget("wordleui_rt")
render.createRenderTarget("wordlekeyboard_rt")

---@class WordleUI
local WordleUI = class("wordleui")

function WordleUI:initialize()
    self.state = States.waiting
    self.player = nil
    self.guesses = 0

    self:markDirty()
    self.layout = self:performLayout()

    self.grid = WordleGrid:new(self, self.layout.grid.x, self.layout.grid.y)

    self.inputManager = WordleInput.InputManager:new()
    self.keyboard = WordleKeyboard:new(Lang.keyboard, self.inputManager, function(_, letter)
        self:onKeyPressed(letter)
    end)
    self._kbWasActive = true -- clear rt on first render
    self:initializeInputs()

    self.gameTransitionTime = 0.5 + Animations.bounceDuration + Animations.bounceDelay * (wordLength - 1)
    self.logoRT = WordleLogo()
    self.bgRTs = WordleBackground()

    self.timers = {}
end

function WordleUI:schedule(delay, fn)
    self.timers[#self.timers + 1] = {
        time = timer.systime() + delay,
        fn = fn
    }
end

function WordleUI:updateTimers(now)
    local q = self.timers
    for i = #q, 1, -1 do
        if now >= q[i].time then
            local fn = q[i].fn
            q[i] = q[#q]
            q[#q] = nil
            fn()
        end
    end
end

function WordleUI:markDirty()
    self.dirty = true
end

function WordleUI:start()
    net.start(NetNames.StartGame)
    net.send()
end

function WordleUI:_resetState()
    self:markDirty()
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
    self.timers = {}
end

function WordleUI:reset()
    net.start(NetNames.ResetGame)
    net.send()
    self:_resetState()
end

function WordleUI:onStart(ply)
    self:markDirty()
    self.state = States.active
    self.pendingState = nil
    self.endMessage = nil
    self.player = ply
    self.curPlayerText = l10n.is_playing:format(ply:getName())
    self.guesses = 0

    self.grid:reset()
    self.keyboard:reset()

    self.inputManager:setOwner(ply)
    self.inputManager:clearGroup("ui")
    self.inputManager:register("ui", self.homeButton)
    self.timers = {}
end

function WordleUI:onKeyPressed(label)
    if self.state ~= States.active then
        return
    end

    if label == "ENTER" then
        self:submitGuess()
    elseif label == "BKSP" then
        self:markDirty()
        self.grid:deleteLastKey()
        Sounds.PlaySound(Sounds.keyBack)

        net.start(NetNames.KeyDeleted)
        net.send()
    else
        self.grid:typeKey(label)
        net.start(NetNames.KeyTyped)
        net.writeUInt(Lang.charToIndex[label] or 0, Lang.bitsPerChar)
        net.send()
    end
end

function WordleUI:submitGuess()
    if self.grid.locked then
        return
    end
    if self.grid.currentCol <= wordLength then
        self.grid:shakeRow()
        Sounds.PlaySound(Sounds.invalid)
        return
    end

    self.grid.locked = true
    Sounds.PlaySound(Sounds.keyEnter)

    net.start(NetNames.NewGuess)
    WordleUtil.Net.WriteWord(self.grid:getCurrentGuess())
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

        local didWin = state == States.won
        if didWin then
            self.grid:bounceRow()
        end

        self:schedule(didWin and self.gameTransitionTime or 0.5, function()
            if self.state == States.waiting then
                return
            end

            self:markDirty()

            if self.pendingState then
                self.state = self.pendingState
                self.pendingState = nil
            end

            local isLocalPlayer = player() == self.player

            if didWin then
                self.endMessage = l10n.win_messages[self.guesses]
                self.solvedInText = l10n.solved_in:format(self.guesses, maxGuesses)
                if isLocalPlayer then
                    Sounds.PlaySound(Sounds.win)
                end
            elseif isEnd and not didWin then
                self.endMessage = l10n.so_close
                if isLocalPlayer then
                    Sounds.PlaySound(Sounds.lose)
                end
            end

            if isEnd then
                render.setFont(Fonts.subtitleLarge)
                self.answerChars = WordleUtil.utf8chars(answer)
                self.endMessageWidth, self.endMessageHeight = render.getTextSize(self.endMessage)
                self.endMessageWidth = self.endMessageWidth + 64
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
            h = el.h,
        }
    end

    return out
end

function WordleUI:initializeInputs()
    self.playButton = WordleInput.Button:new(self.layout.playButton, function()
        self:start()
    end)
    self.playButton.onHover = function(btn, state)
        if btn.hovered ~= state then
            btn.hovered = state
            self:markDirty()
        end
    end

    self.homeButton = WordleInput.Button:new(self.layout.homeButton, function()
        self:reset()
    end)
    self.homeButton.onHover = function(btn, state)
        if btn.hovered ~= state then
            btn.hovered = state
            self:markDirty()
        end
    end

    self.inputManager:register("ui", self.playButton)
end

render.setFont(Fonts.subtitle)
local _, playTxtH = render.getTextSize("A")

local playTxt, playAgainTxt = l10n.play, l10n.play_again
local function drawPlayButton(bounds, hovered, state)
    render.setColor(hovered and Colors.darkGreen or Colors.green)
    render.drawRoundedBox(48, bounds.x, bounds.y, bounds.w, bounds.h)

    render.setColor(Colors.white)
    render.setFont(Fonts.subtitle)
    render.drawText(bounds.x + bounds.w / 2, bounds.y + bounds.h / 2 - playTxtH / 2,
        (state == States.won or state == States.lost) and playAgainTxt or playTxt, TEXT_ALIGN.CENTER)
end

local function drawHomeButton(bounds, hovered)
    local col = hovered and Colors.lightGrey or Colors.white
    render.setColor(col)
    render.drawRoundedBox(16, bounds.x, bounds.y, bounds.w, bounds.h)

    render.setColor(Colors.darkGrey)
    render.setMaterial(Materials.HomeButton)
    render.drawTexturedRect(bounds.x, bounds.y, bounds.w, bounds.h)
end

render.setFont(Fonts.subtitleMedium)
local _, subtitleH = render.getTextSize("A")
local subtitleOne = l10n.chances:format(maxGuesses)
local subtitleTwo = l10n.letter_word:format(wordLength)

function WordleUI:drawHomeScreen()
    render.setColor(Colors.white)
    render.setRenderTargetTexture(self.bgRTs.waiting)
    render.drawTexturedRect(0, 0, ScrW, ScrH)

    local logoBounds = self.layout.wordleLogo
    render.setRenderTargetTexture(self.logoRT)
    render.drawTexturedRect(logoBounds.x, logoBounds.y, logoBounds.w, logoBounds.h)

    local subBounds = self.layout.subtitle
    render.setFont(Fonts.subtitle)
    render.drawText(subBounds.x, subBounds.y - subtitleH / 2, subtitleOne, TEXT_ALIGN.CENTER)
    render.setFont(Fonts.small)
    render.setColor(Colors.lightGrey)
    render.drawText(subBounds.x, subBounds.y + subtitleH / 2, subtitleTwo, TEXT_ALIGN.CENTER)

    local playBounds, playHovered = self.layout.playButton, self.playButton.hovered
    drawPlayButton(playBounds, playHovered, self.state)
end

function WordleUI:drawPlayScreen(now)
    if not isValid(self.player) then
        self:_resetState()
        return
    end

    render.setColor(Colors.white)
    render.setRenderTargetTexture(self.bgRTs.active)
    render.drawTexturedRect(0, 0, ScrW, ScrH)
    local homeBounds, homeHovered = self.layout.homeButton, self.homeButton.hovered
    drawHomeButton(homeBounds, homeHovered)

    self.grid:update(now)
    self.grid:draw()

    local bounds = self.layout.activePlayer
    render.setColor(Colors.lightGrey)
    render.setFont(Fonts.small)
    render.drawText(bounds.x + 48, bounds.y - 16, self.curPlayerText, TEXT_ALIGN.LEFT)
end

local function drawResultTile(x, y, didWin, letter)
    render.setColor(didWin and Colors.green or Colors.grey)
    render.drawRect(x - 50, y - 50, 100, 100)

    if letter then
        render.setColor(Colors.white)
        render.setFont(Fonts.subtitle)
        render.drawSimpleText(x, y, letter, TEXT_ALIGN.CENTER, TEXT_ALIGN.CENTER)
    end
end
function WordleUI:drawResultScreen()
    render.setColor(Colors.white)
    render.setRenderTargetTexture(self.bgRTs.result)
    render.drawTexturedRect(0, 0, ScrW, ScrH)
    local playBounds, playHovered = self.layout.playButton, self.playButton.hovered
    drawPlayButton(playBounds, playHovered, self.state)

    local homeBounds, homeHovered = self.layout.homeButton, self.homeButton.hovered
    drawHomeButton(homeBounds, homeHovered)

    local didWin = self.state == States.won
    local endMsgBounds = self.layout.endMessage
    render.setColor(didWin and Colors.green or Colors.grey)
    render.drawRoundedBox(16, endMsgBounds.x - self.endMessageWidth / 2, endMsgBounds.y, self.endMessageWidth, 100)
    render.setColor(Colors.white)
    render.setFont(Fonts.subtitleLarge)
    render.drawText(endMsgBounds.x, endMsgBounds.y + (100 - self.endMessageHeight) / 2,
        self.endMessage, TEXT_ALIGN.CENTER)

    local bounds = self.layout.resultText
    render.setColor(Colors.white)
    render.setFont(Fonts.titleMedium)
    render.drawText(bounds.x, bounds.y, didWin and l10n.won or l10n.lost, TEXT_ALIGN.CENTER)

    render.setFont(Fonts.subtitleLight)
    render.setColor(Colors.lightGrey)
    render.drawText(endMsgBounds.x, endMsgBounds.y + 250, didWin and self.solvedInText or l10n.word_was,
        TEXT_ALIGN.CENTER)

    for i = 1, wordLength do
        local letter = self.answerChars[i]
        drawResultTile(bounds.x - (wordLength * 100 + (wordLength - 1) * 12) / 2 + (i - 1) * (100 + 12) + 50,
            bounds.y + 270, didWin, letter)
    end
end

function WordleUI:render()
    local now = timer.systime()
    if nextFrame > now then
        return
    end

    self:updateTimers(now)
    local grid = self.grid
    local mainNeedsRedraw = self.dirty or #grid._activeTiles > 0 or grid.shakeStart
    local kbActive = self.state == States.active
    local kbNeedsRedraw = (kbActive and self.keyboard.dirty) or (not kbActive and self._kbWasActive)

    if not mainNeedsRedraw and not kbNeedsRedraw then
        return
    end

    nextFrame = now + FPSDelta

    if mainNeedsRedraw then
        render.selectRenderTarget("wordleui_rt")
        render.clear(Colors.transparent)

        render.setColor(Colors.darkGrey)
        render.drawRoundedBox(32, 0, 0, ScrW, ScrH)

        if self.state == States.waiting then
            self:drawHomeScreen()
        elseif self.state == States.active then
            self:drawPlayScreen(now)
        else
            self:drawResultScreen()
        end

        self.dirty = false
    end

    if kbActive then
        if self.keyboard.dirty then
            render.selectRenderTarget("wordlekeyboard_rt")
            render.clear(Colors.transparent)
            self.keyboard:draw()
            self.keyboard.dirty = false
        end
    elseif self._kbWasActive then
        render.selectRenderTarget("wordlekeyboard_rt")
        render.clear(Colors.transparent)
    end
    self._kbWasActive = kbActive
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
    if player() == ui.player then
        return
    end
    local key = net.readUInt(Lang.bitsPerChar)
    ui.grid:typeKey(Lang.alphabet[key + 1])
end)

net.receive(NetNames.KeyDeleted, function()
    if player() == ui.player then
        return
    end
    ui.grid:deleteLastKey()
end)

net.receive(NetNames.ResetGame, function()
    if ui.state == States.waiting then
        return
    end
    ui:_resetState()
end)

--<<-- UI

hook.add("RenderOffscreen", "wordleui_render", function()
    ui:render()
end)

local mainScreen, keyboardScreen
local mainRatio, keyboardRatio
hook.add("ComponentLinked", "wordleui_screen_setup", function(ent)
    if not ent or ent:getClass() ~= "starfall_screen" then
        return
    end

    if not mainScreen then
        mainScreen = ent
        mainRatio = render.getScreenInfo(mainScreen).RatioX
    else
        keyboardScreen = ent
        keyboardRatio = render.getScreenInfo(keyboardScreen).RatioX
        if mainRatio ~= keyboardRatio then
            print("Warning: Wordle UI screens have different aspect ratios. Cursor will be misaligned.")
        end
        ui.inputManager:setCursorScale(mainRatio and mainRatio or keyboardRatio)
        hook.remove("ComponentLinked", "wordleui_screen_setup")
    end
end)

hook.add("Render", "wordleui_draw", function()
    local scr = render.getScreenEntity()
    local w, h = render.getResolution()

    render.setBackgroundColor(Colors.transparent)
    if scr == mainScreen then
        ui.inputManager:update("ui")
        render.setRenderTargetTexture("wordleui_rt")
    elseif scr == keyboardScreen then
        if ui.state == States.active then
            ui.inputManager:update("keyboard")
        end
        render.setRenderTargetTexture("wordlekeyboard_rt")
    else
        return
    end

    render.drawTexturedRect(0, 0, w, h)
end)
