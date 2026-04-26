![Wordle](https://github.com/Smigg-y/starfall_wordle/blob/main/assets/wordle_playing_2.jpg "Wordle")
# Wordle

A Starfall implementation of Wordle for Garry's Mod.

## Supported Languages

- `en` — English
- `es` — Spanish
- `fr` — French
- `it` — Italian
- `nl` — Dutch
- `pt` — Portuguese
- `ru` — Russian

English was sourced from [here](https://gist.github.com/scholtes/94f3c0303ba6a7768b47583aff36654d "Here").
Everything else is scraped from a multitude of online dictionaries.

## Changing the Language

Edit the top of `sh_wordle.lua`. You must update **both** the `@includedir` directive and the `Language` variable to the same language code, otherwise the script will error.

```lua
--@name wordle/v2/sh_wordle
--@author Smiggy
--@shared

-- Supported languages: en (English), es (Spanish), fr (French), it (Italian), nl (Dutch), pt (Portuguese), ru (Russian)

-- EDIT THIS TO YOUR LANGUAGE
--@includedir wordle/data/en/
-- ^^^^^^^^^^^^^^^^^^^^^^^^^^
-- AND THIS
local Language = "en"
-- ^^^^^^^^^^^^^^^^^^
-- THE SCRIPT WILL ERROR IF THEY ARE NOT THE SAME
```

## Ease of Use Script

If you don't want to download all the files you can use this script instead.

```lua
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

-- NO TOUCHY
local WordleUtil = require("sh_wordle.lua", { Language = Language } )
if SERVER then
    require("sv_wordle.lua", WordleUtil)
else
    require("cl_wordle.lua", WordleUtil)
end
```
