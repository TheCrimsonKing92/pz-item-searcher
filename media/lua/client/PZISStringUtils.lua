local PZISStringUtils = {};

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
    if self:endsWith(original, "y") then
        local parts = {};
        table.insert(parts, original:sub(1, #original - 1));
        table.insert(parts, "ies");

        return table.concat(parts);
    end

    if not self:endsWith(original, "s") then
        local parts = {};
        table.insert(parts, original);
        table.insert(parts, "s");

        return table.concat(parts);
    else
        return original;
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

function PZISStringUtils:startsWithAny(str, possibilities)
    for _, v in ipairs(possibilities) do
        if PZISStringUtils:startsWith(v) then
            return true;
        end
    end

    return false;
end

return PZISStringUtils;