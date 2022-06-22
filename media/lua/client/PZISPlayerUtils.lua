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
    local message = "I couldn't find";

    if not stringUtil:endsWith(displayName, "s") then
        message = message .. " a";
    end

    return message;
end

PZISPlayerUtils.getFailureSuffix = function(inventoryType)
    if PZISPlayerUtils.isPlayerHeld(inventoryType) then
        return "in my " .. inventoryType;
    elseif inventoryType == "floor" then
        return "on the " .. inventoryType;
    else
        return "in the " .. inventoryType;
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

PZISPlayerUtils.getSuccessMessage = function(inventoryType, displayName, count)
    local messageParts = {};
    table.insert(messageParts, getText("IGUI_IS_Search_Success_Exclamation"));

    local isPlayerHeld = PZISPlayerUtils.isPlayerHeld(inventoryType);
    local isPlural = count > 1;

    local trueDisplayName;

    if isPlural then
        trueDisplayName = stringUtil:pluralize(displayName);
    else
        if stringUtil:startsWithAny(displayName, {"a", "e", "i", "o", "u"}) then
            trueDisplayName = "an " .. displayName;
        else
            trueDisplayName = "a " .. displayName;
        end 
    end

    if isPlayerHeld and isPlural then
        -- Player holds items in their base inventory or backpack
        local isInventory = inventoryType == "inventory";

        if isInventory then
            table.insert(messageParts, getText("IGUI_IS_Search_Success_Inventory_Plural", count, trueDisplayName));
        else
            table.insert(messageParts, getText("IGUI_IS_Search_Success_Backpack_Plural", count, trueDisplayName))
        end
    elseif isPlayerHeld then        
        local isInventory = inventoryType == "inventory";

        if isInventory then
            table.insert(messageParts, getText("IGUI_IS_Search_Success_Inventory_Singular"), trueDisplayName);
        else
            table.insert(messageParts, getText("IGUI_IS_Search_Success_Backpack_Singular"), trueDisplayName);
        end
    elseif isPlural then
        if inventoryType == "floor" then
            table.insert(messageParts, getText("IGUI_IS_Search_Success_Floor_Plural", count, trueDisplayName));
        else
            table.insert(messageParts, getText("IGUI_IS_Search_Success_Container_Plural", count, trueDisplayName));
        end
    else
        if inventoryType == "floor" then
            table.insert(messageParts, getText("IGUI_IS_Search_Success_Floor_Singular", trueDisplayName));
        else
            table.insert(messageParts, getText("IGUI_IS_Search_Success_Container_Singular", trueDisplayName));
        end
    end

    return spaceConcat(messageParts);
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

    local playerHeld = PZISPlayerUtils.isPlayerHeld(containerType);

    if containerItemCount > 0 then
        message = "Hm, let's see what's in this " .. containerType;
    else
        message = "I don't think there's anything in this " .. containerType;
    end

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