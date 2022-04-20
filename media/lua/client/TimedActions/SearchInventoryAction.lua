require "TimedActions/ISBaseTimedAction"

SearchInventoryAction = ISBaseTimedAction:derive("SearchInventoryAction");

-- The PutItemInBag FMOD event duration is 10 seconds long, which stops it playing too frequently.
SearchInventoryAction.searchSoundDelay = 9.5;
SearchInventoryAction.searchSoundTime = 0;

local collectionUtil = require("PZISCollectionUtils");
local Set = collectionUtil.Set;
local playerUtil = require("PZISPlayerUtils");
local stringUtil = require("PZISStringUtils");

SearchInventoryAction.exclusionTypes = Set:new({ "KeyRing" });

local print = function(...)
    print("[ItemSearcher (SearchInventoryAction)] - ", ...);
end

function SearchInventoryAction:clearAdditionalSearches()
    ISTimedActionQueue.clear(self.character);
end

function SearchInventoryAction:findItem(inventory, displayNameSearch, nameSearch, fullTypeSearch)
    local containerType = inventory:getType();
    print("Searching locally in '" .. containerType .. "' type container");

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

function SearchInventoryAction:isPlayerHeld(inventoryType)
    return inventoryType == "backpack" or inventoryType == "inventory";
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
    if stringUtil:endsWith(original, "y") then
        local parts = {};
        table.insert(parts, original:sub(1, #original - 1));
        table.insert(parts, "ies");

        return table.concat(parts);
    end

    if not stringUtil:endsWith(original, "s") then
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

function SearchInventoryAction:searchInventory()
    local inventory = self.inventory;
    local searchTarget = self.searchTarget;
    local displayName = searchTarget.displayName;
    local name = searchTarget.name;
    local fullType = searchTarget.fullType;

    local exclusionTypes = SearchInventoryAction.exclusionTypes;

    for i,v in ipairs(inventory.inventoryPane.inventoryPage.backpacks) do
        local localInventory = v.inventory;
        local containerType = localInventory:getType();

        if not exclusionTypes:contains(containerType) then
            if containerType == "none" then
                containerType = "inventory";
            elseif stringUtil:startsWith(containerType, "Bag") then
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
            playerUtil.sayResult(self.character, containerType, displayName, count);
    
            if count ~= nil then
                return true;
            end
        end
    end

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

    local exclusionTypes = SearchInventoryAction.exclusionTypes;
    local itemCount = 0;

    for i, v in ipairs(o.inventory.inventoryPane.inventoryPage.backpacks) do
        local inventory = v.inventory;
        if not exclusionTypes:contains(inventory:getType()) then
            itemCount  = itemCount + inventory:getItems():size();
        end
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