<div align="center">

![Wordle](https://github.com/Smigg-y/starfall_wordle/blob/main/assets/wordle_combined.jpg "Wordle")

# Wordle

**A Starfall implementation of Wordle for Garry's Mod.**

</div>

---

## 🌍 Supported Languages

| Code | Language   |
| :--: | :--------- |
| `en` | English    |
| `es` | Spanish    |
| `fr` | French     |
| `it` | Italian    |
| `nl` | Dutch      |
| `pt` | Portuguese |
| `ru` | Russian    |

> The English word list was sourced from [this gist](https://gist.github.com/scholtes/94f3c0303ba6a7768b47583aff36654d).
> All other languages were scraped from a variety of online dictionaries.

---

## 🛠️ Changing the Language

Open `sh_wordle.lua` and update **both** the `@includedir` directive **and** the `Language` variable to the same language code.

> ⚠️ Heads up: both values must match. `@includedir` controls which files get uploaded to the chip; `Language` controls which ones the code requires at runtime. A mismatch means requiring a file that isn't there - which errors.

```lua
--@name wordle/v2/sh_wordle
--@author Smiggy
--@shared

-- Supported: en, es, fr, it, nl, pt, ru

--                        👇 EDIT THIS TO YOUR LANGUAGE
--@includedir wordle/data/en/
--                        ^^

--                👇 AND THIS
local Language = "en"
--                ^^

-- THE SCRIPT WILL ERROR IF THEY ARE NOT THE SAME
```

---

## ⚡ Ease of Use Script

Don't want to download every file manually? Drop this single script into Starfall and you're good to go.

```lua
--@name Wordle
--@author Smiggy
--@shared

--@include https://raw.githubusercontent.com/Smigg-y/starfall_wordle/refs/heads/ease-of-use/wordle/v2/sh_wordle.lua as sh_wordle.lua
--@include https://raw.githubusercontent.com/Smigg-y/starfall_wordle/refs/heads/ease-of-use/wordle/v2/sv_wordle.lua as sv_wordle.lua
--@include https://raw.githubusercontent.com/Smigg-y/starfall_wordle/refs/heads/ease-of-use/wordle/v2/cl_wordle.lua as cl_wordle.lua

-- 👉 Full list: https://github.com/Smigg-y/starfall_wordle/tree/main#supported-languages

-- EDIT the 'en' in BOTH includes below to change the language.                                         👇
--@include https://raw.githubusercontent.com/Smigg-y/starfall_wordle/refs/heads/ease-of-use/wordle/data/en/choices.lua as answers.lua
--@include https://raw.githubusercontent.com/Smigg-y/starfall_wordle/refs/heads/ease-of-use/wordle/data/en/valid.lua as guesses.lua
--                                                                                                      ^^
--                👇 AND CHANGE THIS TO MATCH
local Language = "en"
--                ^^

local WordleUtil = require("sh_wordle.lua", { Language = Language })

if SERVER then
    require("sv_wordle.lua", WordleUtil)
else
    require("cl_wordle.lua", WordleUtil)
end
```
