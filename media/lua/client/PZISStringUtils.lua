local collectionUtil = require("PZISCollectionUtils");
local Set = collectionUtil.Set;

local PZISStringUtils = {};

local alphas = {"a", "A", "b", "B", "c", "C", "d", "D", "e", "E", "f", "F", "g", "G", "h", "H", "i", "I", "j", "J", "k", "K", "l", 'L', 'm', 'M', 'n', 'N', 'o', 'O', 'p', 'P', 'q', 'Q', 'r', 'R', 's', 'S', 't', 'T', 'u', 'U', 'v', 'V', 'w', 'W', 'x', 'X', 'y', 'Y', 'z', 'Z'};
local patternMagics = {"-"};
local vowels = {"a", "A", "e", "E", "i", "I", "o", "O", "u", "U"};
local ALPHA_SET = Set:new(alphas);
local MAGIC_SET = Set:new(patternMagics);
local VOWEL_SET = Set:new(vowels);

function PZISStringUtils:createSearchPattern(input)
    local patternTable = {};

    for i = 1, #input do
        local char = input:sub(i, i);

        if ALPHA_SET:contains(char) then
            local charPattern = {"[", char:lower(), char:upper(), "]"};
            patternTable[#patternTable + 1] = table.concat(charPattern, "")
        elseif MAGIC_SET:contains(char) then
            patternTable[#patternTable + 1] = "%" .. char;
        else
            patternTable[#patternTable + 1] = char;
        end
    end
    
    return table.concat(patternTable, "");
end

function PZISStringUtils:endsWith(str, ending)
    return ending == "" or str:sub(-#ending) == ending;
end

function PZISStringUtils:pascalize(input)
    local results = {};
    local parts = self:split(input);

    for _, word in ipairs(parts) do
        table.insert(results, table.concat({ word:sub(1, 1):upper(), word:sub(2) }));
    end

    return table.concat(results, " ");
end

function PZISStringUtils:pluralize(input)
    if self:endsWith(input, "y") then
        local parts = {};
        table.insert(parts, input:sub(1, #input - 1));
        table.insert(parts, "ies");

        return table.concat(parts);
    end

    if not self:endsWith(input, "s") then
        local parts = {};
        table.insert(parts, input);
        table.insert(parts, "s");

        return table.concat(parts);
    else
        return input;
    end
end

function PZISStringUtils:split(input, separator)
    local t = {};
    separator = separator or '%s';

    for str in string.gmatch(input, "([^" .. separator .. "]+)") do
        table.insert(t, str);
    end

    return t;    
end

function PZISStringUtils:startsWith(str, starting)
    return starting == "" or str:sub(1, #starting) == starting;
end

function PZISStringUtils:startsWithVowel(str)
    return VOWEL_SET:contains(str:sub(1, 1));    
end

return PZISStringUtils;
