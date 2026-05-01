--@name wordle/v2/sh_wordle
--@author Smiggy
--@shared

local Language = (...).Language or "invalid"

local Config = {
    autoScreenSetup = true, -- should we automatically spawn, place and setup screens?
    language = Language,

    wordLength = 5,
    maxGuesses = 6,
    ScrW = 1024,
    ScrH = 1024,
    FPS = 60
}
local function utf8chars(s)
    local out, i, n = {}, 1, #s
    while i <= n do
        local b = string.byte(s, i)
        local len = b < 0x80 and 1 or b < 0xE0 and 2 or b < 0xF0 and 3 or 4
        out[#out + 1] = string.sub(s, i, i + len - 1)
        i = i + len
    end
    return out
end

local function makeProfile(alphabet, keyboard, localization)
    local toIndex = {}
    for i, ch in ipairs(alphabet) do toIndex[ch] = i - 1 end
    local bits = math.max(1, math.ceil(math.log(#alphabet) / math.log(2)))
    return {
        alphabet = alphabet,
        charToIndex = toIndex,
        bitsPerChar = bits,
        charsPerChunk = math.floor(30 / bits),
        keyboard = keyboard,
        localization = localization,
    }
end

local enAlphabet = {
    "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N",
    "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z"
}

local enKeyboard = {
    { "Q",     "W", "E", "R", "T", "Y", "U", "I", "O",   "P" },
    { "A",     "S", "D", "F", "G", "H", "J", "K", "L" },
    { "ENTER", "Z", "X", "C", "V", "B", "N", "M", "BKSP" }
}

local Languages = {
    en = makeProfile(enAlphabet, enKeyboard, {
        word_was     = "THE WORD WAS",
        so_close     = "SO CLOSE",
        play         = "PLAY",
        play_again   = "PLAY AGAIN",
        chances      = "GET %d CHANCES",
        letter_word  = "to guess a %d-letter word",
        is_playing   = "%s is playing",
        won          = "YOU WIN!",
        lost         = "YOU LOSE",
        solved_in    = "SOLVED IN %d / %d",
        win_messages = {
            "GENIUS!",
            "MAGNIFICENT",
            "IMPRESSIVE",
            "SPLENDID",
            "GREAT",
            "PHEW",
        },
    }),
    es = makeProfile({
        "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M",
        "N", "Ñ", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z"
    }, {
        { "Q",     "W", "E", "R", "T", "Y", "U", "I", "O",   "P" },
        { "A",     "S", "D", "F", "G", "H", "J", "K", "L",   "Ñ" },
        { "ENTER", "Z", "X", "C", "V", "B", "N", "M", "BKSP" }
    }, {
        word_was     = "LA PALABRA ERA",
        so_close     = "TAN CERCA",
        play         = "JUGAR",
        play_again   = "JUGAR DE NUEVO",
        chances      = "CONSIGUE %d INTENTOS",
        letter_word  = "para adivinar una palabra de %d letras",
        is_playing   = "%s está jugando",
        won          = "¡GANAS!",
        lost         = "PIERDES",
        solved_in    = "RESUELTO EN %d / %d",
        win_messages = {
            "¡GENIO!",
            "MAGNÍFICO",
            "IMPRESIONANTE",
            "ESPLÉNDIDO",
            "GENIAL",
            "¡UF!",
        },
    }),
    fr = makeProfile(enAlphabet, {
        { "A",     "Z", "E", "R", "T", "Y", "U", "I",   "O", "P" },
        { "Q",     "S", "D", "F", "G", "H", "J", "K",   "L", "M" },
        { "ENTER", "W", "X", "C", "V", "B", "N", "BKSP" }
    }, {
        word_was     = "LE MOT ÉTAIT",
        so_close     = "SI PRÈS",
        play         = "JOUER",
        play_again   = "REJOUER",
        chances      = "OBTENEZ %d ESSAIS",
        letter_word  = "pour deviner un mot de %d lettres",
        is_playing   = "%s joue",
        won          = "VOUS GAGNEZ !",
        lost         = "VOUS PERDEZ",
        solved_in    = "RÉSOLU EN %d / %d",
        win_messages = {
            "GÉNIE !",
            "MAGNIFIQUE",
            "IMPRESSIONNANT",
            "SUPERBE",
            "BRAVO",
            "OUF !",
        },
    }),
    it = makeProfile(enAlphabet, enKeyboard, {
        word_was     = "LA PAROLA ERA",
        so_close     = "COSÌ VICINO",
        play         = "GIOCA",
        play_again   = "GIOCA DI NUOVO",
        chances      = "OTTIENI %d TENTATIVI",
        letter_word  = "per indovinare una parola di %d lettere",
        is_playing   = "%s sta giocando",
        won          = "VINCI!",
        lost         = "PERDI",
        solved_in    = "RISOLTO IN %d / %d",
        win_messages = {
            "GENIO!",
            "MAGNIFICO",
            "IMPRESSIONANTE",
            "SPLENDIDO",
            "BRAVO",
            "PER UN PELO!",
        },
    }),
    nl = makeProfile(enAlphabet, enKeyboard, {
        word_was     = "HET WOORD WAS",
        so_close     = "ZO DICHTBIJ",
        play         = "SPELEN",
        play_again   = "OPNIEUW SPELEN",
        chances      = "KRIJG %d KANSEN",
        letter_word  = "om een woord van %d letters te raden",
        is_playing   = "%s speelt",
        won          = "JE WINT!",
        lost         = "JE VERLIEST",
        solved_in    = "OPGELOST IN %d / %d",
        win_messages = {
            "GENIAAL!",
            "SCHITTEREND",
            "INDRUKWEKKEND",
            "PRACHTIG",
            "GOED",
            "PFOEW!",
        },
    }),
    pt = makeProfile(enAlphabet, enKeyboard, {
        word_was     = "A PALAVRA ERA",
        so_close     = "TÃO PERTO",
        play         = "JOGAR",
        play_again   = "JOGAR DE NOVO",
        chances      = "OBTÉM %d TENTATIVAS",
        letter_word  = "para adivinhar uma palavra de %d letras",
        is_playing   = "%s está a jogar",
        won          = "GANHAS!",
        lost         = "PERDES",
        solved_in    = "RESOLVIDO EM %d / %d",
        win_messages = {
            "GÉNIO!",
            "MAGNÍFICO",
            "IMPRESSIONANTE",
            "ESPLÊNDIDO",
            "ÓTIMO",
            "UFA!",
        },
    }),
    ru = makeProfile({
        "А", "Б", "В", "Г", "Д", "Е", "Ж", "З", "И", "Й", "К", "Л",
        "М", "Н", "О", "П", "Р", "С", "Т", "У", "Ф", "Х", "Ц", "Ч",
        "Ш", "Щ", "Ъ", "Ы", "Ь", "Э", "Ю", "Я"
    }, {
        { "Й", "Ц", "У", "К", "Е", "Н", "Г", "Ш", "Щ", "З", "Х", "Ъ" },
        { "Ф", "Ы", "В", "А", "П", "Р", "О", "Л", "Д", "Ж", "Э" },
        { "ENTER", "Я", "Ч", "С", "М", "И", "Т", "Ь", "Б", "Ю", "BKSP" }
    }, {
        word_was     = "ЗАГАДАННОЕ СЛОВО",
        so_close     = "ТАК БЛИЗКО",
        play         = "ИГРАТЬ",
        play_again   = "ИГРАТЬ СНОВА",
        chances      = "У ВАС %d ПОПЫТОК",
        letter_word  = "чтобы угадать слово из %d букв",
        is_playing   = "%s играет",
        won          = "ВЫ ВЫИГРЫВАЕТЕ!",
        lost         = "ВЫ ПРОИГРЫВАЕТЕ",
        solved_in    = "РЕШЕНО ЗА %d / %d",
        win_messages = {
            "ГЕНИАЛЬНО!",
            "ВЕЛИКОЛЕПНО",
            "ВПЕЧАТЛЯЮЩЕ",
            "ПРЕВОСХОДНО",
            "ОТЛИЧНО",
            "ФУХ!",
        },
    })
}

local Lang = Languages[Config.language]
assert(Lang, "Unknown language: " .. tostring(Config.language))

local Animations = {
    flipDelay = 0.3,
    shakeDuration = 0.4,
    shakeMagnitude = 12,
    shakeFrequency = 6,
    bounceDelay = 0.1,
    flipDuration = 0.4,
    popDuration = 0.1,
    bounceDuration = 0.5,
    bounceHeight = 96
}

local Sounds = {
    keyType = "ui/clickback_02_01.wav",
    keyEnter = "buttons/button14.wav",
    keyBack = "garrysmod/ui_click.wav",
    invalid = "common/warning.wav",
    tileFlip = "ui/hint.wav",
    rowWin = "garrysmod/balloon_pop_cute.wav",
    win = {
        "garrysmod/save_load1.wav", "garrysmod/save_load2.wav",
        "garrysmod/save_load3.wav"
    },
    lose = "common/bugreporter_failed.wav"
}

Sounds.PlaySound = function(snd, pitch, volume)
    if type(snd) == "table" then snd = snd[math.random(#snd)] end
    chip():emitSound(snd, 75, pitch or math.random(95, 105), volume or 1)
end

local Layout = {
    -- main screen
    wordleLogo = { anchor = "top", offsetY = 32, w = 384, h = 384 },
    subtitle = { anchor = "center", offsetY = -16 },

    -- main screen and result screen
    playButton = { anchor = "center", offsetY = 240, w = 560, h = 94 },

    -- playing screen and result screen
    homeButton = { x = 64, y = 64, w = 64, h = 64 },

    -- result screen
    resultText = { anchor = "center", offsetY = -256 },
    endMessage = { anchor = "center", offsetY = -384 },

    -- playing screen
    grid = { anchor = "center" },
    activePlayer = { x = 64, y = 64 }
}

local Anchors = {
    center = function(el, sw, sh)
        return sw * 0.5, sh * 0.5 + (el.offsetY or 0)
    end,
    top = function(el, sw, sh)
        local half_h = el.h and el.h / 2 or 0
        return sw * 0.5, half_h + (el.offsetY or 0)
    end
}

local Fonts = SERVER and {} or {
    titleLarge = render.createFont("Roboto Mono", 256, 1000, true),
    title = render.createFont("Roboto Mono", 128, 1000, true),
    titleMedium = render.createFont("Roboto Mono", 96, 1000, true),
    subtitle = render.createFont("Roboto Mono", 64, 1000, true),
    subtitleLarge = render.createFont("Roboto Mono", 80, 1000, true),
    subtitleSmall = render.createFont("Roboto Mono", 48, 1000, true),
    subtitleMedium = render.createFont("Roboto Mono", 56, 1000, true),
    subtitleLight = render.createFont("Roboto Mono", 48, 10, true),
    small = render.createFont("Roboto Mono", 32, 400, true)
}

local _green = Color(80, 160, 80)
local _yellow = Color(212, 178, 50)
local _grey = Color(60, 60, 60)
local _lgrey = Color(132, 132, 132)
local _trans = Color(255, 255, 255, 0)
local Colors = {
    white = Color(255, 255, 255),
    offWhite = Color(245, 245, 245),
    darkGrey = Color(18, 18, 19),
    grey = _grey,
    lightGrey = _lgrey,
    red = Color(242, 60, 60),
    green = _green,
    darkGreen = Color(50, 100, 50),
    yellow = _yellow,
    black = Color(0, 0, 0),
    transparent = Color(0, 0, 0, 0),

    keyDefault = _lgrey,
    keyHovered = Color(90, 90, 90),
    keyPressed = Color(155, 155, 155),
    keyCorrect = _green,
    keyPresent = _yellow,
    keyAbsent = _grey,

    tileEmpty = _trans,
    tileFilled = _trans,
    tileCorrect = _green,
    tilePresent = _yellow,
    tileAbsent = _grey,

    outlineEmpty = Color(58, 58, 60),
    outlineFilled = Color(86, 87, 88)
}

local Materials = SERVER and {} or {
    HomeButton = render.createMaterial("gui/html/home", function(_, _, _, _, layout)
        layout(0, 0, 1024, 1024)
    end)
}

local FeedbackStates = { [0] = "absent", [1] = "present", [2] = "correct" }

local States = { waiting = 1, active = 2, won = 3, lost = 4 }

local ErrorCodes = { notActive = 1, invalidGuess = 2, gameInProgress = 3 }

local ErrorMessages = {
    [ErrorCodes.notActive] = "No game in progress",
    [ErrorCodes.invalidGuess] = "Not in word list",
    [ErrorCodes.gameInProgress] = "Game already active"
}

local NetNames = {
    Error = "wordle_error",
    StartGame = "wordle_start",
    ResetGame = "wordle_reset",
    NewGuess = "wordle_guess",
    GuessResult = "wordle_result",
    KeyTyped = "wordle_type_key",
    KeyDeleted = "wordle_delete_key"
}

local Bit = {
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

local function encodeChunk(chars, startIdx, len)
    local n = 0
    local bpc = Lang.bitsPerChar
    for i = 0, len - 1 do
        local idx = Lang.charToIndex[chars[startIdx + i]] or 0
        n = bit.bor(n, bit.lshift(idx, i * bpc))
    end
    return n
end

local function decodeChunk(n, len, out, outIdx)
    local bpc = Lang.bitsPerChar
    local mask = bit.lshift(1, bpc) - 1
    for i = 0, len - 1 do
        local idx = bit.band(bit.rshift(n, i * bpc), mask)
        out[outIdx + i] = Lang.alphabet[idx + 1]
    end
end

local Net = {
    WriteWord = function(word)
        local chars = utf8chars(word)
        local len = Config.wordLength
        local bpc = Lang.bitsPerChar
        local cpc = Lang.charsPerChunk

        local i = 1
        while i <= len do
            local chunkLen = math.min(cpc, len - i + 1)
            net.writeUInt(encodeChunk(chars, i, chunkLen), chunkLen * bpc)
            i = i + chunkLen
        end
    end,
    ReadWord = function()
        local len = Config.wordLength
        local bpc = Lang.bitsPerChar
        local cpc = Lang.charsPerChunk

        local out = {}
        local i = 1
        while i <= len do
            local chunkLen = math.min(cpc, len - i + 1)
            local encoded = net.readUInt(chunkLen * bpc)
            decodeChunk(encoded, chunkLen, out, i)
            i = i + chunkLen
        end

        return table.concat(out)
    end
}

return {
    Config = Config,
    Lang = Lang,
    utf8chars = utf8chars,
    Animations = Animations,
    Layout = Layout,
    Anchors = Anchors,
    Fonts = Fonts,
    Colors = Colors,
    Sounds = Sounds,
    Materials = Materials,
    FeedbackStates = FeedbackStates,
    States = States,
    ErrorCodes = ErrorCodes,
    ErrorMessages = ErrorMessages,
    NetNames = NetNames,
    Net = Net,
    Bit = Bit
}
