--@name wordle/v2/cl_input
--@author Smiggy
--@client

--@include wordle/v2/sh_wordle.lua

local WordleUtil = require("wordle/v2/sh_wordle.lua")
local Sounds = WordleUtil.Sounds

---@class Button
local Button = class("button")

function Button:initialize(bounds, onPressed)
    self.x, self.y, self.w, self.h = bounds.x, bounds.y, bounds.w, bounds.h
    self.onPressed = onPressed
    self.hovered = false
end

function Button:containsPoint(x, y)
    return x >= self.x and x <= self.x + self.w and y >= self.y and y <= self.y + self.h
end

function Button:onHover(state)
    self.hovered = state
end

function Button:onPress()
    if self.onPressed then
        Sounds.PlaySound(Sounds.keyType)
        self.onPressed(self)
    end
end

---@class InputManager
local InputManager = class("inputmanager")

function InputManager:initialize()
    self.groups = {}

    self.owner = nil
    self.hovered = nil
    self.keyHeld = false
    self.cursorScaleX = 1
    self.cursorScaleY = 1
end

function InputManager:register(group, clickable)
    self.groups[group] = self.groups[group] or {}

    clickable.hovered = false
    table.insert(self.groups[group], clickable)
end

function InputManager:unregister(group, clickable)
    local list = self.groups[group]
    if not list then
        return
    end

    for i = 1, #list do
        if list[i] == clickable then
            table.remove(list, i)
            return
        end
    end
end

function InputManager:clearGroup(group)
    self.groups[group] = nil
end

function InputManager:setOwner(owner)
    self.owner = owner
end

local function findHovered(group, cx, cy)
    for i = 1, #group do
        local c = group[i]
        if c:containsPoint(cx, cy) then
            return c
        end
    end
end

function InputManager:setCursorScale(ratio)
    if not ratio or ratio <= 0 then
        ratio = 1
    end

    self.cursorScaleX = WordleUtil.Config.ScrW / 512 * ratio
    self.cursorScaleY = WordleUtil.Config.ScrH / 512
end

function InputManager:update(activeGroup)
    local keyDown = input.isKeyDown(KEY.E)
    if keyDown and not self.keyHeld then
        self.pressed = true
    elseif not keyDown then
        self.pressed = false
    end
    self.keyHeld = keyDown

    if self.owner and player() ~= self.owner then
        self.pressed = false
        return
    end

    local cx, cy = render.cursorPos()
    if not cx then
        return
    end
    cx, cy = cx * self.cursorScaleX, cy * self.cursorScaleY

    local hovered
    if activeGroup then
        local group = self.groups[activeGroup]
        if group then
            hovered = findHovered(group, cx, cy)
        end
    else
        for _, group in pairs(self.groups) do
            hovered = findHovered(group, cx, cy)
            if hovered then
                break
            end
        end
    end

    if hovered ~= self.hovered then
        if self.hovered then
            self.hovered:onHover(false)
        end
        if hovered then
            hovered:onHover(true)
        end
        self.hovered = hovered
    end

    if hovered and self.pressed then
        hovered:onPress()
        self.pressed = false
    end
end

return { Button = Button, InputManager = InputManager }
