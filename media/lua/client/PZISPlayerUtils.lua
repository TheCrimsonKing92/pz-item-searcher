local objectUtil = require("PZISObjectUtils");
local stringUtil = require("PZISStringUtils");

local PZISPlayerUtils = {};

local print = function(...)
    print("[ItemSearcher (PZISPlayerUtils)] - ", ...);
end

local spaceConcat = function(parts)
    return table.concat(parts, " ");
end

PZISPlayerUtils.getFailureBody = function(displayName)
    return displayName;
end

PZISPlayerUtils.getFailureMessage = function(inventoryType, displayName)
    local messageParts = {};

    table.insert(messageParts, PZISPlayerUtils.getFailurePrefix(displayName));
    table.insert(messageParts, PZISPlayerUtils.getFailureBody(displayName));
    table.insert(messageParts, PZISPlayerUtils.getFailureSuffix(inventoryType));

    return spaceConcat(messageParts);
end

PZISPlayerUtils.getFailurePrefix = function(displayName)
    local textId = "IGUI_PZIS_SearchResult_Failure_Prefix_";

    if stringUtil:endsWith(displayName, "s") then
        textId = textId .. "Plural";
        return getText(textId);
    else
        textId = textId .. "Singular";
        local article;

        if stringUtil:startsWithVowel(displayName) then
            article = "an";
        else
            article = "a";
        end

        return getText(textId, article);
    end
end

PZISPlayerUtils.getFailureSuffix = function(inventoryType)
    local textId = "IGUI_PZIS_SearchResult_Failure_Suffix_";

    if PZISPlayerUtils.isPlayerHeld(inventoryType) then
        textId = textId .. "Player";
        return getText(textId, inventoryType);
    elseif inventoryType == "floor" then
        textId = textId .. "Floor";
        return getText(textId);
    else
        textId = textId .. "Container";
        return getText(textId, objectUtil:getContainerNameByType(inventoryType));
    end
end

PZISPlayerUtils.getStartMessage = function(containerType)
    local messageParts = {
        PZISPlayerUtils.getStartPrefix(),
        PZISPlayerUtils.getStartSuffix(containerType)
    };

    return spaceConcat(containerType);
end

PZISPlayerUtils.getStartPrefix = function()
    local message = "Hm, let me check";
end

PZISPlayerUtils.getStartSuffix = function(containerType, isNearby)
    local isNearby = isNearby or false;

    if isNearby then
        return "nearby";
    end

    local suffixParts = {};
    local playerHeld = PZISPlayerUtils.isPlayerHeld(containerType);

    if playerHeld then
        table.insert(suffixParts, "my");
    else
        table.insert(suffixParts, "this");
    end

    table.insert(suffixParts, containerType);
    table.insert(suffixParts, "...");

    return spaceConcat(suffixParts);
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

    table.insert(messageParts, PZISPlayerUtils.getSuccessPrefix(inventoryType, displayName, count));
    table.insert(messageParts, PZISPlayerUtils.getSuccessBody(displayName, count));
    table.insert(messageParts, PZISPlayerUtils.getSuccessSuffix(inventoryType, count));

    return spaceConcat(messageParts);
end

PZISPlayerUtils.getSuccessPrefix = function(inventoryType, displayName, count)
    local textId = "IGUI_PZIS_SearchResult_Success_Prefix_";
    local isPlural = count > 1;

    if isPlural then
        textId = textId .. "Plural";
    else
        textId = textId .. "Singular";
    end

    -- Treat as plural if the count is 1 but the display name ends with "s"
    local effectivelyPlural = isPlural or stringUtil:endsWith(displayName, "s");
    local successSource = PZISPlayerUtils.getSuccessPrefixSource(inventoryType, effectivelyPlural);
    local article = PZISPlayerUtils.getSuccessPrefixArticle(effectivelyPlural, count, displayName);

    return getText(textId, successSource, article);
end

PZISPlayerUtils.getSuccessPrefixArticle = function(isPlural, count, displayName)
    if isPlural then
        return count;
    end

    if stringUtil:startsWithVowel(displayName) then
        return "an";
    else
        return "a";
    end
end

PZISPlayerUtils.getSuccessPrefixSource = function(inventoryType, isPlural)
    local textId = "IGUI_PZIS_SearchResult_Success_Prefix_Source_";

    if PZISPlayerUtils.isPlayerHeld(inventoryType) then
        textId = textId .. "Player";
    else
        if isPlural then
            textId = textId .. "Container_Plural";
        else
            textId = textId .. "Container_Singular";
        end
    end

    return getText(textId);
end

PZISPlayerUtils.getSuccessSuffix = function(inventoryType)
    local textId = "IGUI_PZIS_SearchResult_Success_Suffix_";

    if "floor" == inventoryType then
        textId = textId .. "Floor";
        return getText(textId);
    elseif PZISPlayerUtils.isPlayerHeld(inventoryType) then
        textId = textId .. "Player";
        return getText(textId, inventoryType);
    else
        textId = textId .. "Container";
        return getText(textId, objectUtil:getContainerNameByType(inventoryType));
    end
end

PZISPlayerUtils.isPlayerHeld = function(inventoryType)
    return inventoryType ~= nil and inventoryType == "backpack" or inventoryType == "inventory";
end

PZISPlayerUtils.say = function(character, message)
    character:Say(message);
end

PZISPlayerUtils.sayResult = function(character, inventoryType, displayName, count)
    local message;

    if count ~= nil and count > 0 then
        message = PZISPlayerUtils.getSuccessMessage(inventoryType, displayName, count);
    else
        message = PZISPlayerUtils.getFailureMessage(inventoryType, displayName);
    end

    PZISPlayerUtils.say(character, message);
end

PZISPlayerUtils.sayStart = function(character, containerType, containerItemCount)
    local message;

    local containerName = objectUtil:getContainerNameByType(containerType);
    local playerHeld = PZISPlayerUtils.isPlayerHeld(containerType);

    local textId = "IGUI_PZIS_StartSearch_RoomContainer";

    if containerItemCount > 0 then
        textId = textId .. "WithItems";
    else
        textId = textId .. "Empty";
    end
    
    message = getText(textId, containerName);

    PZISPlayerUtils.say(character, message);
end

-- Cribbed from luautils *except* it doesn't cancel queued actions
PZISPlayerUtils.walkToContainer = function(character, container)
    if container:getType() == "floor" then
        return true
    end
    
    if container:getParent() and container:getParent():getSquare():DistToProper(character:getCurrentSquare()) < 2 then
        return true;
    end

    if container:isInCharacterInventory(character) then
        return true
    end
    local isoObject = container:getParent()
    if not isoObject or not isoObject:getSquare() then
        return true
    end
    if instanceof(isoObject, "BaseVehicle") then
        if character:getVehicle() == isoObject then
            return true
        end
        if character:getVehicle() then
            error "luautils.walkToContainer()"
        end
        local part = container:getVehiclePart()
        if part and part:getArea() then
            if part:getVehicle():canAccessContainer(part:getIndex(), character) then
                return true
            end
            if part:getDoor() and part:getInventoryItem() then
                -- TODO: open the door if needed
            end
            ISTimedActionQueue.add(ISPathFindAction:pathToVehicleArea(character, part:getVehicle(), part:getArea()))
            return true
        end
        error "luautils.walkToContainer()"
    end
    if instanceof(isoObject, "IsoDeadBody") then
        return true
    end

    local adjacent = AdjacentFreeTileFinder.Find(isoObject:getSquare(), character)
    if not adjacent then
        return false
    end
    if adjacent == character:getCurrentSquare() then
        return true
    end
    
    ISTimedActionQueue.add(ISWalkToTimedAction:new(character, adjacent))
    return true
end

return PZISPlayerUtils;