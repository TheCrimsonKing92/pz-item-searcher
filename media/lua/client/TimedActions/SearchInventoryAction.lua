require "TimedActions/ISBaseTimedAction"

SearchInventoryAction = ISBaseTimedAction:derive("SearchInventoryAction");

-- The PutItemInBag FMOD event duration is 10 seconds long, which stops it playing too frequently.
SearchInventoryAction.searchSoundDelay = 9.5;
SearchInventoryAction.searchSoundTime = 0;
-- keep only one instance of this action so we can queue item to transfer and avoid ton of instance when moving lot of items.

SearchInventoryAction.similarTypes = { "SearchInventoryAction", "SearchRoomAction", "SearchBuildingAction" };

local stringUtil = require("PZISStringUtils");

local endsWith = stringUtil.endsWith;
local startsWith = stringUtil.startsWith;

function SearchInventoryAction:clearAdditionalSearches()
    -- Pretty much hocked logic from ISInventoryTransferAction:checkQueueList
    local actionQueue = ISTimedActionQueue.getTimedActionQueue(self.character);
    local indexSelf = actionQueue:indexOf(self);

    -- local index = 1;
    local index = #actionQueue.queue;

    while index > 0 do
        if index ~= indexSelf then
            local action = actionQueue.queue[index];
            if self:isSimilarSearch(action) then
                table.remove(actionQueue.queue, index);
                table.wipe(action);
            end
        end        
        index = index - 1;
    end
end

function SearchInventoryAction:findItem(inventory, displayNameSearch, nameSearch, fullTypeSearch)
    local containerType = inventory:getType();
    print("Searching locally in " .. containerType .. " type container");

    local items = inventory:getItems();
    for i = 0, items:size() - 1 do
        local item = items:get(i);

        local displayName = item:getDisplayName();
        local name = item:getName();
        local fullType = item:getFullType();

        if displayNameSearch == displayName and (nameSearch == name or fullTypeSearch == fullType) then
            -- Ask the InventoryContainer for the count, not including items that can be drained, recursing through inventory container items
            local count = inventory:getNumberOfItem(fullType, false, true);
            return count;
        end
    end

    return nil;
end

function SearchInventoryAction:formatMessage(count, displayName, inventoryType)
    local messageParts = { self:getPrefix(inventoryType, displayName, count), self:getName(displayName, count > 1), self:getSuffix(inventoryType) };
    return table.concat(messageParts, " ");
end

function SearchInventoryAction:getName(displayName, isPlural)
    if isPlural then
        return self:pluralize(displayName);
    else
        return displayName;
    end
end

function SearchInventoryAction:getPrefix(inventoryType, displayName, count)
    local isPlural = count > 1;
    local prefixParts = {};

    if self:isPlayerHeld(inventoryType) then
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

    return table.concat(prefixParts, " ");
end

function SearchInventoryAction:getSuffix(inventoryType)
    print("Getting suffix with inventory type: " .. inventoryType);
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

    return table.concat(suffixParts, " ");
end

function SearchInventoryAction:isPlayerHeld(inventoryType)
    return inventoryType == "backpack" or inventoryType == "inventory";
end

function SearchInventoryAction:isSimilarSearch(action)
    local isSimilarType = function(actionType)
        for _, v in ipairs(self.similarTypes) do
            if v == actionType then
                return true;
            end
        end

        return false;
    end

    if action == nil then
        return false;
    end

    if not isSimilarType(action.Type) then
        return false;
    end

    return action.searchTarget == self.searchTarget;
end

function SearchInventoryAction:isValid()
    -- Not valid if we're doing anything else, basically
    return true;
end

function SearchInventoryAction:perform()
    -- TODO: Move reporting of results to this (or a new) function instead of keeping it embedded in the search
    local found = self:searchInventory();

    if found then
        self:clearAdditionalSearches();
    end

    ISBaseTimedAction.perform(self);
end

function SearchInventoryAction:pluralize(original)
    if endsWith(original, "y") then
        local parts = {};
        table.insert(parts, original:sub(1, #original - 1));
        table.insert(parts, "ies");

        return table.concat(parts);
    end

    if not endsWith(original, "s") then
        local parts = {};
        table.insert(parts, original);
        table.insert(parts, "s");

        return table.concat(parts);
    else
        return original;
    end
end

function SearchInventoryAction:say(message)
    self.character:Say(message);
end

function SearchInventoryAction:sayFailure(displayName)
    local suffix = nil;

    if self.isNearby then
        suffix = "nearby";
    else
        suffix = "in my inventory";
    end

    local msg = "I couldn't find a " .. displayName .. " " .. suffix;
    self:say(msg);
end

function SearchInventoryAction:sayResult(displayNameSearch, count, inventoryType)
    local message = self:formatMessage(count, displayNameSearch, inventoryType);

    self:say(message);
end

function SearchInventoryAction:searchInventory()
    local inventory = self.inventory;
    local searchTarget = self.searchTarget;
    local displayName = searchTarget.displayName;
    local name = searchTarget.name;
    local fullType = searchTarget.fullType;

    for i,v in ipairs(inventory.inventoryPane.inventoryPage.backpacks) do
        local localInventory = v.inventory;
        local containerType = localInventory:getType();

        if containerType == "none" then
            containerType = "inventory";
        elseif startsWith(containerType, "Bag") then
            containerType = "backpack";
        end

        if self.isNearby then
            local square = nil;
            local parent = localInventory:getParent();
            local source = localInventory:getSourceGrid();

            if parent ~= nil then
                square = parent:getSquare();
            elseif source ~= nil then
                square = source;
            else
                print("Could not find a square for the inventory!");
            end

            if square ~= nil then
                local x = square:getX();
                local y = square:getY();
                self.character:faceLocation(x, y);
            end            
        end        

        local count = self:findItem(localInventory, displayName, name, fullType);

        if count ~= nil then
            self:sayResult(displayName, count, containerType);
            return true;
        end
    end

    self:sayFailure(displayName);
    return false;
end

function SearchInventoryAction:start()
    local toSay = "Let me check ";

    if self.isNearby then
        toSay = toSay .. "nearby...";
    else
        toSay = toSay .. "my inventory...";
    end

    self:say(toSay);

    if not SearchInventoryAction.searchSound or not self.character:getEmitter():isPlaying(SearchInventoryAction.searchSound) then
        if SearchInventoryAction.searchSoundTime + SearchInventoryAction.searchSoundDelay < getTimestamp() then
            SearchInventoryAction.searchSoundTime = getTimestamp();
            SearchInventoryAction.searchSound = self.character:getEmitter():playSound("PutItemInBag");
        end
    end

    self:setActionAnim("TransferItemOnSelf");
end

function SearchInventoryAction:new(playerNum, character, searchTarget, isNearby)
    local o = ISBaseTimedAction.new(self, character);
    o.forceProgressBar = true;
    o.isNearby = isNearby or false;

    if isNearby then
        o.inventory = getPlayerLoot(playerNum);
    else
        o.inventory = getPlayerInventory(playerNum);
    end    

    local itemCount = 0;

    for i, v in ipairs(o.inventory.inventoryPane.inventoryPage.backpacks) do
        local inventory = v.inventory;
        itemCount  = itemCount + inventory:getItems():size();
    end

    if itemCount == 0 then
        o.maxTime = 2;
    elseif itemCount > 0 then
        o.maxTime = itemCount * 4 + 3;
    elseif o.character:isTimedActionInstant() then
        o.maxTime = 1;
    end

    o.playerNum = playerNum;
    o.searchTarget = searchTarget;
    o.stopOnWalk = true;
    o.stopOnRun = true;

    return o;
end