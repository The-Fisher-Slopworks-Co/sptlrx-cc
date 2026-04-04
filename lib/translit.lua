-- Cyrillic UTF-8 → Latin transliteration.
--
-- CC:Tweaked terminals cannot display Cyrillic glyphs, so this converts
-- two-byte UTF-8 Cyrillic sequences to their Latin equivalents.
--
-- This is a stopgap — the intended long-term fix is a pixel-level renderer
-- with a custom font. When that exists, remove this module and swap the
-- renderer's text_filter.

local MAP = {}

-- Build the mapping from two-byte UTF-8 strings to Latin strings.
-- Uppercase А-Я (D0 90 - D0 AF)
local upper = {
    [0x90] = "A",  [0x91] = "B",  [0x92] = "V",  [0x93] = "G",
    [0x94] = "D",  [0x95] = "E",  [0x96] = "Zh", [0x97] = "Z",
    [0x98] = "I",  [0x99] = "Y",  [0x9A] = "K",  [0x9B] = "L",
    [0x9C] = "M",  [0x9D] = "N",  [0x9E] = "O",  [0x9F] = "P",
    [0xA0] = "R",  [0xA1] = "S",  [0xA2] = "T",  [0xA3] = "U",
    [0xA4] = "F",  [0xA5] = "Kh", [0xA6] = "Ts", [0xA7] = "Ch",
    [0xA8] = "Sh", [0xA9] = "Sch",[0xAA] = "",   [0xAB] = "Y",
    [0xAC] = "",   [0xAD] = "E",  [0xAE] = "Yu", [0xAF] = "Ya",
}

-- Lowercase а-п (D0 B0 - D0 BF)
local lower_d0 = {
    [0xB0] = "a",  [0xB1] = "b",  [0xB2] = "v",  [0xB3] = "g",
    [0xB4] = "d",  [0xB5] = "e",  [0xB6] = "zh", [0xB7] = "z",
    [0xB8] = "i",  [0xB9] = "y",  [0xBA] = "k",  [0xBB] = "l",
    [0xBC] = "m",  [0xBD] = "n",  [0xBE] = "o",  [0xBF] = "p",
}

-- Lowercase р-я (D1 80 - D1 8F)
local lower_d1 = {
    [0x80] = "r",  [0x81] = "s",  [0x82] = "t",  [0x83] = "u",
    [0x84] = "f",  [0x85] = "kh", [0x86] = "ts", [0x87] = "ch",
    [0x88] = "sh", [0x89] = "sch",[0x8A] = "",   [0x8B] = "y",
    [0x8C] = "",   [0x8D] = "e",  [0x8E] = "yu", [0x8F] = "ya",
}

-- Register all in MAP keyed by two-byte string
for b2, latin in pairs(upper) do
    MAP[string.char(0xD0, b2)] = latin
end
for b2, latin in pairs(lower_d0) do
    MAP[string.char(0xD0, b2)] = latin
end
for b2, latin in pairs(lower_d1) do
    MAP[string.char(0xD1, b2)] = latin
end

-- Ё / ё
MAP[string.char(0xD0, 0x81)] = "Yo"
MAP[string.char(0xD1, 0x91)] = "yo"

-- Match any two-byte sequence starting with D0 or D1
local pattern = "([\208\209])([\128-\191])"

local function translit(text)
    if text == "" then return "" end
    return text:gsub(pattern, function(b1, b2)
        return MAP[b1 .. b2] or (b1 .. b2)
    end)
end

return translit
