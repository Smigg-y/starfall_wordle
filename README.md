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

## Changing the Language

Edit the top of `sh_wordle.txt`. You must update **both** the `@includedir` directive and the `Language` variable to the same language code, otherwise the script will error.

```lua
--@name wordle/v2/sh_wordle
--@author Smiggy
--@shared

-- Supported languages: en (English), es (Spanish), fr (French), it (Italian), nl (Dutch), pt (Portuguese), ru (Russian)

-- EDIT THIS TO YOUR LANGUAGE
--@includedir wordle/data/ru/
-- ^^^^^^^^^^^^^^^^^^^^^^^^^^
-- AND THIS
local Language = "ru"
-- ^^^^^^^^^^^^^^^^^^
-- THE SCRIPT WILL ERROR IF THEY ARE NOT THE SAME
```
