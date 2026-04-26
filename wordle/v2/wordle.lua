--@name Wordle
--@author Smiggy
--@shared

--@include https://raw.githubusercontent.com/Smigg-y/starfall_wordle/refs/heads/ease-of-use/wordle/v2/sh_wordle.lua as sh_wordle.lua
--@include https://raw.githubusercontent.com/Smigg-y/starfall_wordle/refs/heads/ease-of-use/wordle/v2/sv_wordle.lua as sv_wordle.lua
--@include https://raw.githubusercontent.com/Smigg-y/starfall_wordle/refs/heads/ease-of-use/wordle/v2/cl_wordle.lua as cl_wordle.lua

-- EDIT the 'en' part FOR BOTH includes to change the language of the game. You can find more languages here:
--https://github.com/Smigg-y/starfall_wordle/tree/main#supported-languages

--@include https://raw.githubusercontent.com/Smigg-y/starfall_wordle/refs/heads/ease-of-use/wordle/data/en/choices.lua as answers.lua
--@include https://raw.githubusercontent.com/Smigg-y/starfall_wordle/refs/heads/ease-of-use/wordle/data/en/valid.lua as guesses.lua

-- AND THIS
local Language = "en"

local WordleUtil = require("sh_wordle.lua", { Language = Language })

if SERVER then
    require("sv_wordle.lua", WordleUtil)
else
    require("cl_wordle.lua", WordleUtil)
end
