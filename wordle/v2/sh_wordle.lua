--@name wordle/v2/sh_wordle
--@author Smiggy
--@shared

local Config         = {
	autoScreenSetup = true, -- should we automatically spawn, place and setup screens?

	wordLength      = 5,
	maxGuesses      = 6,
	ScrW            = 1024,
	ScrH            = 1024,
	FPS             = 60
}

local Animations     = {
	flipDelay      = 0.3,
	shakeDuration  = 0.4,
	shakeMagnitude = 12,
	shakeFrequency = 6,
	bounceDelay    = 0.1,
	flipDuration   = 0.4,
	popDuration    = 0.1,
	bounceDuration = 0.5,
	bounceHeight   = 96
}

local Sounds         = {
	keyType  = "ui/clickback_02_01.wav",
	keyEnter = "buttons/button14.wav",
	keyBack  = "garrysmod/ui_click.wav",
	invalid  = "common/warning.wav",
	tileFlip = "ui/hint.wav",
	rowWin   = "garrysmod/balloon_pop_cute.wav",
	win      = { "garrysmod/save_load1.wav", "garrysmod/save_load2.wav", "garrysmod/save_load3.wav" },
	lose     = "common/bugreporter_failed.wav"
}

Sounds.PlaySound     = function(snd, pitch, volume)
	if type(snd) == "table" then snd = snd[math.random(#snd)] end
	chip():emitSound(snd, 75, pitch or math.random(95, 105), volume or 1)
end

local Layout         = {
	-- main screen
	wordleLogo = {
		anchor  = "top",
		offsetY = 32,
		w       = 256,
		h       = 256,
	},
	subtitle = {
		anchor  = "center",
		offsetY = -16
	},

	-- main screen and result screen
	playButton = {
		anchor  = "center",
		offsetY = 240,
		w       = 400,
		h       = 130
	},

	-- playing screen and result screen
	homeButton = {
		x = 64,
		y = 64,
		w = 64,
		h = 64
	},

	-- result screen
	resultText = {
		anchor = "center",
		offsetY = -384
	},

	-- playing screen
	grid = {
		anchor = "center"
	},
	activePlayer = {
		x = 64,
		y = 64
	}
}

local Anchors        = {
	center = function(el, sw, sh)
		return sw * 0.5, sh * 0.5 + (el.offsetY or 0)
	end,
	top = function(el, sw, sh)
		local half_h = el.h and el.h / 2 or 0
		return sw * 0.5, half_h + (el.offsetY or 0)
	end
}

local Fonts          = SERVER and {} or {
	title = render.createFont("Roboto Mono", 128, 1000, true),
	subtitle = render.createFont("Roboto Mono", 64, 1000, true),
	subtitleSmall = render.createFont("Roboto Mono", 48, 1000, true),
	small = render.createFont("Roboto Mono", 32, 400, true),
}

local _green         = Color(83, 141, 78)
local _yellow        = Color(181, 159, 59)
local _grey          = Color(60, 60, 60)
local _lgrey         = Color(132, 132, 132)
local _trans         = Color(255, 255, 255, 0)
local Colors         = {
	white         = Color(255, 255, 255),
	offWhite      = Color(245, 245, 245),
	darkGrey      = Color(18, 18, 19),
	grey          = _grey,
	lightGrey     = _lgrey,
	red           = Color(242, 60, 60),
	green         = _green,
	yellow        = _yellow,
	black         = Color(0, 0, 0),
	transparent   = Color(0, 0, 0, 0),

	keyDefault    = _lgrey,
	keyHovered    = Color(90, 90, 90),
	keyPressed    = Color(155, 155, 155),
	keyCorrect    = _green,
	keyPresent    = _yellow,
	keyAbsent     = _grey,

	tileEmpty     = _trans,
	tileFilled    = _trans,
	tileCorrect   = _green,
	tilePresent   = _yellow,
	tileAbsent    = _grey,

	outlineEmpty  = Color(58, 58, 60),
	outlineFilled = Color(86, 87, 88)
}

local Materials      = SERVER and {} or {
	HomeButton = render.createMaterial("gui/html/home", function(_, _, _, _, layout)
		layout(0, 0, 1024, 1024)
	end) or nil
}

local KeyboardLayout = {
	{ "Q",     "W", "E", "R", "T", "Y", "U", "I", "O",   "P" },
	{ "A",     "S", "D", "F", "G", "H", "J", "K", "L" },
	{ "ENTER", "Z", "X", "C", "V", "B", "N", "M", "BKSP" }
}

local FeedbackStates = {
	[0] = "absent",
	[1] = "present",
	[2] = "correct"
}

local WinMessages    = {
	"GENIUS!",
	"MAGNIFICENT",
	"IMPRESSIVE",
	"SPLENDID",
	"GREAT",
	"PHEW"
}

local States         = {
	waiting = 1,
	active  = 2,
	won     = 3,
	lost    = 4
}

local ErrorCodes     = {
	notActive      = 1,
	invalidGuess   = 2,
	gameInProgress = 3,
}

local ErrorMessages  = {
	[ErrorCodes.notActive]      = "No game in progress",
	[ErrorCodes.invalidGuess]   = "Not in word list",
	[ErrorCodes.gameInProgress] = "Game already active"
}

local NetNames       = {
	Error       = "wordle_error",
	StartGame   = "wordle_start",
	ResetGame   = "wordle_reset",
	NewGuess    = "wordle_guess",
	GuessResult = "wordle_result",
	KeyTyped    = "wordle_type_key",
	KeyDeleted  = "wordle_delete_key"
}

local Bit            = {
	Pack = function(len, bitsPerItem, fn)
		local result = 0
		for i = 1, len do
			local state = fn(i)
			result = bit.bor(result, bit.lshift(state, (i - 1) * bitsPerItem))
		end
		return result
	end,
	Unpack = function(value, len, bitsPerItem)
		local out = {}
		local mask = bit.lshift(1, bitsPerItem) - 1

		for i = 1, len do
			local offset = (i - 1) * bitsPerItem
			out[i] = bit.band(bit.rshift(value, offset), mask)
		end

		return out
	end
}

local BitsPerChar    = 5
local CharsPerChunk  = 6 -- fits in UInt (6*5=30)

local function encodeChunk(str, startIdx, len)
	local n = 0
	for i = 0, len - 1 do
		local c = string.byte(str, startIdx + i) - 97 -- 'a' -> 0
		n = n + bit.lshift(c, i * BitsPerChar)
	end
	return n
end

local function decodeChunk(n, len, out, outIdx)
	for i = 0, len - 1 do
		local c = bit.band(bit.rshift(n, i * BitsPerChar), 31)
		out[outIdx + i] = string.char(c + 97)
	end
end

-- only works for LOWERCASE a-z
local Net = {
	WriteWord = function(word)
		local len = Config.wordLength

		local i = 1
		while i <= len do
			local chunkLen = math.min(CharsPerChunk, len - i + 1)
			local encoded = encodeChunk(word, i, chunkLen)

			net.writeUInt(encoded, chunkLen * BitsPerChar)
			i = i + chunkLen
		end
	end,
	ReadWord = function()
		local len = Config.wordLength

		local out = {}
		local i = 1

		while i <= len do
			local chunkLen = math.min(CharsPerChunk, len - i + 1)
			local encoded = net.readUInt(chunkLen * BitsPerChar)
			decodeChunk(encoded, chunkLen, out, i)

			i = i + chunkLen
		end

		return table.concat(out)
	end
}

return {
	Config         = Config,
	Animations     = Animations,
	Layout         = Layout,
	Anchors        = Anchors,
	Fonts          = Fonts,
	Colors         = Colors,
	Sounds         = Sounds,
	Materials      = Materials,
	KeyboardLayout = KeyboardLayout,
	WinMessages    = WinMessages,
	FeedbackStates = FeedbackStates,
	States         = States,
	ErrorCodes     = ErrorCodes,
	ErrorMessages  = ErrorMessages,
	NetNames       = NetNames,
	Net            = Net,
	Bit            = Bit
}
