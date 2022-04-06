local stringUtil = require("PZISStringUtils");

local PZISPlayerUtils = {};

local spaceConcat = function(parts)
    return table.concat(parts, " ");
return

PZISPlayerUtils.getFailureBody = function(displayName)
    return displayName;
end

PZISPlayerUtils.getFailurePrefix = function()
    return "I couldn't find a";
end

PZISPlayerUtils.getFailureMessage = function(inventoryType, displayName)
    local messageParts = {};

    table.insert(messageParts, PZISPlayerUtils.getFailurePrefix());
    table.insert(messageParts, PZISPlayerUtils.getFailureBody(displayName));
    table.insert(messageParts, PZISPlayerUtils.getFailureSuffix());

    return spaceConcat(messageParts);
end

PZISPlayerUtils.getFailureSuffix = function(inventoryType)
    if PZISPlayerUtils.isPlayerHeld(inventoryType) then
        return "in my " .. inventoryType;
    elseif inventoryType == "floor"
        return "on the " .. inventoryType;
    end
end

PZISPlayerUtils.getSuccessBody = function(displayName, count)
    local isPlural = count > 1;

    if isPlural then
        return stringUtil:pluralize(displayName);
    else
        return displayName;
    end
end

PZISPlayerUtils.getSuccessMessage = function(inventoryType, displayName, count)
    local messageParts = {};

    table.insert(messageParts, PZISPlayerUtils.getSuccessPrefix(inventoryType, count));
    table.insert(messageParts, PZISPlayerUtils.getSuccessBody(displayName, count));
    table.insert(messageParts, PZISPlayerUtils.getSuccessSuffix());
end

PZISPlayerUtils.getSuccessPrefix = function(inventoryType, count)
    local isPlural = count > 1;
    local prefixParts = {};

    if PZISPlayerUtils.isPlayerHeld(inventoryType) then
        table.insert(prefixParts, "I have");
    else
        if isPlural then
            table.insert(prefixParts, "There are");
        else
            table.insert(prefixParts, "There is");
        end
    end

    if isPlural then
        table.insert(prefixParts, count);
    else
        table.insert(prefixParts, "a");
    end

    return spaceConcat(prefixParts);
end

PZISPlayerUtils.getSuccessSuffix = function(inventoryType)
    local suffixParts = {};

    if inventoryType == "floor" then
        table.insert(suffixParts, "on");
    else
        table.insert(suffixParts, "in");
    end

    if inventoryType == "backpack" or inventoryType == "inventory" then
        table.insert(suffixParts, "my");
    else
        table.insert(suffixParts, "the");
    end

    table.insert(suffixParts, inventoryType);

    return spaceConcat(suffixParts);
end

PZISPlayerUtils.isPlayerHeld = function(inventoryType)
    return inventoryType ~= nil and inventoryType == "backpack" or inventoryType == "inventory";
end

PZISPlayerUtils.say = function(character, message)
    character:Say(message);
end

PZISPlayerUtils.sayResult = function(character, inventoryType, displayName, count)
    local message;

    if count > 0 then
        message = PZISPlayerUtils.getSuccessMessage(inventoryType, displayName, count);
    else
        message = PZISPlayerUtils.getFailureMessage(inventoryType, displayName);
    end

    PSISPlayerUtils.say(character, message);
end