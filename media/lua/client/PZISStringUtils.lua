local PZISStringUtils = {};

PZISStringUtils.endsWith = function(str, ending)
    return ending == "" or str:sub(-#ending) == ending;
end

PZISStringUtils.startsWith = function(str, starting)
    return starting == "" or str:sub(1, #starting) == starting;
end

return PZISStringUtils;