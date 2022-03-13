require "TimedActions/ISBaseTimedAction"

SearchInventoryAction = ISBaseTimedAction:derive("ISBaseTimedAction");

-- The PutItemInBag FMOD event duration is 10 seconds long, which stops it playing too frequently.
SearchInventoryAction.searchSoundDelay = 9.5;
SearchInventoryAction.searchSoundTime = 0;
-- keep only one instance of this action so we can queue item to transfer and avoid ton of instance when moving lot of items.

local function startsWith(str, starting)
    return starting == "" or string.sub(str, 1, #starting) == starting;
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

        print("Comparing item's display name: " .. displayName .. " to: " .. displayNameSearch .. " and name: " .. name .. " to: " .. nameSearch);
        print("Item's full type: " .. fullType .. ", search full type: " .. fullTypeSearch);

        if displayNameSearch == displayName and (nameSearch == name or fullTypeSearch == fullType) then
            -- Ask the InventoryContainer for the count, not including items that can be drained, recursing through inventory container items
            local count = inventory:getNumberOfItem(fullType, false, true);
            return count;
        end
    end

    return nil;
end

function SearchInventoryAction:formatMessage(count, displayName, inventoryType)
    local getPrefix = function(inventoryType, displayName, count)
        local isPlural = count > 1;
        local prefixParts = {};

        table.insert(prefixParts, "I have");

        if isPlural then
            table.insert(prefixParts, count);
        else
            table.insert(prefixParts, "a");
        end

        return table.concat(prefixParts, " ");
    end

    local getName = function(displayName, isPlural)
        if isPlural then
            return self:pluralize(displayName);
        else
            return displayName;
        end
    end

    local getSuffix = function(inventoryType)
        local suffixParts = {};

        table.insert(suffixParts, "in");
        table.insert(suffixParts, "my");
        table.insert(suffixParts, inventoryType);

        return table.concat(suffixParts, " ");
    end

    local messageParts = { getPrefix(inventoryType, displayName, count), getName(displayName, count > 1), getSuffix(inventoryType) };
    return table.concat(messageParts, " ");
end

function SearchInventoryAction:isValid()
    -- Not valid if we're doing anything else, basically
    return true;
end

function SearchInventoryAction:perform()
    -- TODO: Move reporting of results to this (or a new) function instead of keeping it embedded in the search
    local found = self:searchInventory();
    ISBaseTimedAction.perform(self);
end

function SearchInventoryAction:say(message)
    self.character:Say(message);
end

function SearchInventoryAction:sayFailure(displayName, containerType)
    self:say("I couldn't find a " .. displayName .. " in my inventory");
end

function SearchInventoryAction:sayResult(displayNameSearch, count, inventoryType)
    local message = self:formatMessage(count, displayNameSearch, inventoryType);

    self:say(message);
end

function SearchInventoryAction:searchInventory()
    -- TODO: Figure out some sort of shuffling through container animation, trigger it, and submit this as a short search action
    -- ISInventoryTransferAction:startActionAnim(), for source container character inventory, queues action anim "TransferItemOnSelf"
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

        local count = self:findItem(localInventory, displayName, name, fullType);

        if count ~= nil then
            self:sayResult(displayName, count, containerType);
            return true;
        end
    end

    self:sayFailure(displayName, containerType);
    return false;
end

function SearchInventoryAction:start()
    print("Starting search inventory action");
    self:say("Let me check my inventory...");

    if not SearchInventoryAction.searchSound or not self.character:getEmitter():isPlaying(SearchInventoryAction.searchSound) then
        if SearchInventoryAction.searchSoundTime + SearchInventoryAction.searchSoundDelay < getTimestamp() then
            SearchInventoryAction.searchSoundTime = getTimestamp();
            SearchInventoryAction.searchSound = self.character:getEmitter():playSound("PutItemInBag");
        end
    end

    self:setActionAnim("TransferItemOnSelf");
end

function SearchInventoryAction:update()
    print("Updating search inventory action");
end

function SearchInventoryAction:new(playerNum, character, searchTarget)
    local o = ISBaseTimedAction.new(self, character);
    o.forceProgressBar = true;
    o.inventory = getPlayerInventory(playerNum);

    -- TODO count items in inventory and set a max time based on how much we're rummaging through
    o.maxTime = 5;

    if o.character:isTimedActionInstant() then
        o.maxTime = 1;
    end

    o.playerNum = playerNum;
    o.searchTarget = searchTarget;
    o.stopOnWalk = true;
    o.stopOnRun = true;

    return o;
end