--@name wordle/v2/sv_wordle
--@author Smiggy
--@server

--@include https://raw.githubusercontent.com/Smigg-y/starfall_wordle/refs/heads/ease-of-use/wordle/v2/sh_wordle.lua as sh_wordle.lua

if not SERVER then return end

local WordleUtil = require("sh_wordle.lua")

local Config, States, NetNames, ErrorCodes = WordleUtil.Config,
    WordleUtil.States,
    WordleUtil.NetNames,
    WordleUtil.ErrorCodes
local wordLength, maxGuesses, autoScreenSetup = Config.wordLength,
    Config.maxGuesses,
    Config.autoScreenSetup
local Lang, utf8chars = WordleUtil.Lang, WordleUtil.utf8chars

local WordleGuesses = require("guesses.lua")
local WordleAnswers = require("answers.lua")

---@class Wordle
local Wordle = class("wordle")

function Wordle:initialize()
    self:reset()

    local winMask = 0
    for i = 1, wordLength do
        winMask = bit.bor(winMask, bit.lshift(2, (i - 1) * 2))
    end
    self.winMask = winMask
end

function Wordle:reset()
    self.answer = ""
    self.answerChars = nil
    self.guesses = {}
    self.state = States.waiting
    self.player = nil
end

function Wordle:sendError(err)
    net.start(NetNames.Error)
    net.writeUInt(err, 3)
    net.send()
end

function Wordle:start(ply)
    if self.state == States.active and isValid(self.player) then
        self:sendError(ErrorCodes.gameInProgress)
        return
    end

    self:reset()

    self.answer = table.random(WordleAnswers)
    print(self.answer)
    self.answerChars = utf8chars(self.answer)
    self.player = ply
    self.state = States.active

    net.start(NetNames.StartGame)
    net.writeEntity(ply)
    net.send()
end

-- 0 = absent, 1 = present, 2 = correct
-- 2-bit packed (LSB first)
-- state << ((i-1)*2)
function Wordle:evaluateGuess(guess)
    local gchars = utf8chars(guess)
    local achars = self.answerChars

    local remaining = {}

    for i = 1, wordLength do
        local g, a = gchars[i], achars[i]
        if g ~= a then remaining[a] = (remaining[a] or 0) + 1 end
    end

    return WordleUtil.Bit.Pack(wordLength, 2, function(i)
        local g, a = gchars[i], achars[i]

        if g == a then return 2 end

        local count = remaining[g]
        if count and count > 0 then
            remaining[g] = count - 1
            return 1
        end

        return 0
    end)
end

function Wordle:submitGuess(guess)
    if self.state ~= States.active then
        self:sendError(ErrorCodes.notActive)
        return
    end

    if not WordleGuesses[guess] then
        self:sendError(ErrorCodes.invalidGuess)
        return
    end

    local numGuesses = #self.guesses
    if numGuesses >= maxGuesses then return end
    self.guesses[numGuesses + 1] = guess

    local feedback = self:evaluateGuess(guess)

    if feedback == self.winMask then
        self.state = States.won
    elseif numGuesses + 1 >= maxGuesses then
        self.state = States.lost
    end

    net.start(NetNames.GuessResult)
    net.writeUInt(feedback, 2 * wordLength)
    net.writeUInt(self.state, 3)
    if self.state == States.won or self.state == States.lost then
        WordleUtil.Net.WriteWord(self.answer)
    end
    net.send()
end

-- <<--------------<<-- Entry

local wordle = Wordle:new()

net.receive(NetNames.StartGame,
    function(_, ply) if isValid(ply) then wordle:start(ply) end end)

net.receive(NetNames.NewGuess, function(_, ply)
    if ply ~= wordle.player then return end

    local guess = WordleUtil.Net.ReadWord()
    wordle:submitGuess(guess)
end)

net.receive(NetNames.ResetGame, function(_, ply)
    if wordle.state == States.active and ply ~= wordle.player then return end

    wordle:reset()
    net.start(NetNames.ResetGame)
    net.send()
end)

net.receive(NetNames.KeyTyped, function(_, ply)
    if ply ~= wordle.player then return end

    net.start(NetNames.KeyTyped)
    net.writeUInt(net.readUInt(Lang.bitsPerChar), Lang.bitsPerChar)
    net.send()
end)

net.receive(NetNames.KeyDeleted, function(_, ply)
    if ply ~= wordle.player then return end

    net.start(NetNames.KeyDeleted)
    net.send()
end)

hook.add("PlayerDisconnected", "wordle_player_left", function(ply)
    if wordle.state == States.active and ply == wordle.player then
        wordle:reset()
        net.start(NetNames.ResetGame)
        net.send()
    end
end)

if autoScreenSetup then
    local ch = chip()

    local function createScreen(origin, angle, cb)
        local scr = prop.createComponent(origin, angle, "starfall_screen",
            "models/hunter/plates/plate2x2.mdl",
            true)
        cb(scr)
    end

    local function setupScreen(scr, r_mode)
        scr:linkComponent(ch)
        scr:setMaterial("models/debug/debugwhite")
        scr:setColor(Color(0, 0, 0, 1))
        if r_mode then scr:setRenderMode(r_mode) end
    end

    local ch_up = ch:getUp()
    local screen_origin = ch:localToWorld(Vector(0, 0, 64))
    local screen_angle = (owner():getEyePos() - screen_origin):getNormalized()
        :getAngleEx(ch_up)

    screen_angle.p = 75

    if ch_up:dot(Vector(0, 0, 1)) <= 0.7 then screen_angle.r = 0 end

    -- hooked via ComponentLinked in cl_wordle, screens need to be setup IN ORDER (main screen then keyboard)
    createScreen(screen_origin, screen_angle, function(scr)
        setupScreen(scr)
        createScreen(scr:localToWorld(Vector(36, 0, 4)),
            scr:localToWorldAngles(Angle(-45, 0, 0)), function(kb)
                setupScreen(kb, RENDERMODE.GLOW)
                kb:setParent(scr)
            end)
    end)
end
