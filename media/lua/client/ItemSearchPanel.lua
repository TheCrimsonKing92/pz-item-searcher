require "ISUI/ISCollapsableWindow"
require "ISUI/ISPanel"

local textManager = getTextManager();
local SMALL_FONT = textManager:getFontHeight(UIFont.Small)

local alphas = {"a", "A", "b", "B", "c", "C", "d", "D", "e", "E", "f", "F", "g", "G", "h", "H", "i", "I", "j", "J", "k", "K", "l", 'L', 'm', 'M', 'n', 'N', 'o', 'O', 'p', 'P', 'q', 'Q', 'r', 'R', 's', 'S', 't', 'T', 'u', 'U', 'v', 'V', 'w', 'W', 'x', 'X', 'y', 'Y', 'z', 'Z'};
local patternMagics = {"-"};
local ALPHA_SET = {};
local MAGIC_SET = {};
for _, v in ipairs(alphas) do
    ALPHA_SET[v] = true;
end

for _, v in ipairs(patternMagics) do
    MAGIC_SET[v] = true;
end

ITEMSEARCH_PERSISTENT_DATA = {};
ITEMSEARCH_PERSISTENT_DATA.searchLocations = {
    inventory = false,
    nearby = false,
    room = false,
    building = false
};
ITEMSEARCH_PERSISTENT_DATA.searchTarget = nil;

local ui = null;
local uiOpen = false;

ItemSearchPanel = ISCollapsableWindow:derive("ItemSearchPanel");

local function addTo(set, key)
    set[key] = true;
end

local function endsWith(str, ending)
    return ending == "" or str:sub(-#ending) == ending;
end

local function findBestMatch(originalLength, searchPattern)
    local nameSet = ITEMSEARCH_PERSISTENT_DATA.displayNameSet;
    local result = nil;

    local potentialMatchBegin = nil;
    local potentialMatchEnd = nil;
    local potentialMatchLength = nil;
    local thisBegin = nil;
    local thisEnd = nil;

    local isBetterMatch = function(newBegin, newEnd, newLength)
        if result == nil then
            return true;
        end

        if newBegin > potentialMatchBegin then
            return false;
        elseif newBegin < potentialMatchBegin then
            return true;
        end
        
        return newLength < potentialMatchLength;
    end

    for k, _ in pairs(nameSet) do
        print("Checking match against: " .. k);
        thisBegin, thisEnd = string.find(k, searchPattern);

        local thisLength = string.len(k);
        if thisBegin ~= nil then
            if thisBegin == 1 and thisLength == originalLength then
                return k;
            end

            if isBetterMatch(thisBegin, thisEnd, thisLength) then
                result = k;
                potentialMatchBegin = thisBegin;
                potentialMatchEnd = thisEnd;
                potentialMatchLength = thisLength;
            end;
        end
    end

    return result;
end

local print = function(...)
    print("[ItemSearcher (ItemSearchPanel)] - ", ...);
end

local function setContains(set, key)
    return set[key] ~= nil;
end

local function splitString(input, separator)
    separator = separator or "%s";

    local t = {};

    for str in string.gmatch(input, "([^" .. separator .. "]+)") do
        table.insert(t, str);
    end

    return t;
end

local function startsWith(str, starting)
    return starting == "" or string.sub(str, 1, #starting) == starting;
end

function ItemSearchPanel:close()
    ITEMSEARCH_PERSISTENT_DATA.searchTarget = nil;
    ui = null;
    uiOpen = false;
    self:removeFromUIManager();
end

function ItemSearchPanel:createChildren()
    ISCollapsableWindow.createChildren(self);
    self:setTitle("Item Searcher");

    local buttonHeight = SMALL_FONT + 2 * 4;
    local buttonWidth = 75;
    local padBottom = 10;

    local textSize = textManager:MeasureStringX(UIFont.Small, "Search for what item?");

    local id = "Input";    
    -- 10 is our left-margin, 8 to separate the box from the label, the rest from the text itself
    self.itemEntry = ISTextEntryBox:new("", 18 + textSize, 40, 150, buttonHeight);
    self.itemEntry.id = id;
    self.itemEntry:initialise();
    self.itemEntry:instantiate();
    self.itemEntry.onCommandEntered = function () self:getMatch() end;
    self:addChild(self.itemEntry);

    -- x, y, width, height, name, changeOptionTarget, changeOptionMethod, changeOptionArg1, changeOptionArg2
    self.searchInventoryTick = ISTickBox:new(10, 65, 10, 10, "", nil, nil);
    self.searchInventoryTick:initialise();
    self.searchInventoryTick:instantiate();
    self.searchInventoryTick.selected[1] = true;
    self.searchInventoryTick:addOption("Search Inventory");
    self:addChild(self.searchInventoryTick);

    local searchInventoryWidth = textManager:MeasureStringX(UIFont.Small, "Search Inventory");

    -- 10 is our leftPad, searchInventoryWidth is the text length of the leftward tick, 10 is the size of the leftward tick itself, then we need some additional padding
    local secondTickX = 10 + searchInventoryWidth + 10 + 13;
    self.searchNearbyTick = ISTickBox:new(secondTickX, 65, 10, 10, "", nil, nil);
    self.searchNearbyTick:initialise();
    self.searchNearbyTick:instantiate();
    self.searchNearbyTick.selected[1] = true;
    self.searchNearbyTick:addOption("Search Nearby");
    self:addChild(self.searchNearbyTick);

    self.searchRoomTick = ISTickBox:new(10, 90, 10, 10, "", nil, nil);
    self.searchRoomTick:initialise();
    self.searchRoomTick:instantiate();
    self.searchRoomTick.selected[1] = true;
    self.searchRoomTick:addOption("Search Room");
    self:addChild(self.searchRoomTick);

    self.searchBuildingTick = ISTickBox:new(secondTickX, 90, 10, 10, "", nil, nil);
    self.searchBuildingTick:initialise();
    self.searchBuildingTick:instantiate();
    self.searchBuildingTick.selected[1] = true;
    self.searchBuildingTick:addOption("Search Building");
    self:addChild(self.searchBuildingTick);

    -- x, y, width, height, callback
    local tableCallback = function(item)
        self:setSearchTarget(item);
    end

    self.searchChoices = SearchChoiceTable:new(10, 110, 800, 200, tableCallback);
    self.searchChoices:initialise();
    self.searchChoices:setVisible(false);
    self:addChild(self.searchChoices);

    local buttonCallback = function()
        self:startSearch();
    end

    self.startSearchButton = ISButton:new(10, self.height - (buttonHeight + 10), 70, buttonHeight, "Start Searching", self, buttonCallback);
    self.startSearchButton.enable = false;
    self.startSearchButton:initialise();
    self.startSearchButton:instantiate();
    self:addChild(self.startSearchButton);
end

function ItemSearchPanel:createSearchPattern(input)
    local patternTable = {};
    local setContains = setContains;

    local function isAlpha(char)
        return setContains(ALPHA_SET, char);
    end

    local function isMagic(char)
        return setContains(MAGIC_SET, char);
    end

    for i = 1, #input do
        local char = input:sub(i, i);

        if isAlpha(char) then
            local charPattern = {"[", char:lower(), char:upper(), "]"};
            patternTable[#patternTable + 1] = table.concat(charPattern, "")
        elseif isMagic(char) then
            patternTable[#patternTable + 1] = "%" .. char;
        else
            patternTable[#patternTable + 1] = char;
        end
    end
    
    return table.concat(patternTable, "");
end

function ItemSearchPanel:endMatch(matches)
    if #matches > 1 then
        -- Populate into SearchChoiceTable so user can select the search target
        self:populateChoices(matches);
    else
        -- Future feature: Allow the player to search for only the display name, allowing any variation to resolve the search
        self:setSearchTarget(matches[1]);
    end
end

function ItemSearchPanel:findItem(container, displayNameSearch, nameSearch, fullTypeSearch)
    local containerType = container:getType();
    print("Searching locally in " .. containerType .. " container");
    local items = container:getItems();

    for i = 0, items:size() - 1 do
        local item = items:get(i);

        local displayName = item:getDisplayName();
        local name = item:getName();
        local fullType = item:getFullType();

        print("Comparing item's display name: " .. displayName .. " to: " .. displayNameSearch .. " and name: " .. name .. " to: " .. nameSearch);
        print("Item's full type: " .. fullType .. ", search full type: " .. fullTypeSearch);

        if displayNameSearch == displayName and (nameSearch == name or fullTypeSearch == fullType) then
            -- Ask the InventoryContainer for the count, not including items that can be drained, recursing through inventory container items
            local count = container:getNumberOfItem(fullType, false, true);
            return count;
        end
    end

    return nil;
end

function ItemSearchPanel:formatMessage(count, displayName, inventoryType)
    local getPrefix = function(inventoryType, displayName, count)
        local isPlural = count > 1;
        local prefixParts = {};

        local isPlayerHeld = function(inventoryType)
            return inventoryType == "backpack" or inventoryType == "inventory";
        end

        if isPlayerHeld(inventoryType) then
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

    local getName = function(displayName, isPlural)
        if isPlural then
            return self:pluralize(displayName);
        else
            return displayName;
        end
    end

    local getSuffix = function(inventoryType)
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

    local messageParts = { getPrefix(inventoryType, displayName, count), getName(displayName, count > 1), getSuffix(inventoryType) };
    return table.concat(messageParts, " ");
end

function ItemSearchPanel:getExactMatches(searchText, itemsByDisplay, nameSet)
    local searchText = self:pascalize(searchText);

    if setContains(nameSet, searchText) then
        return itemsByDisplay[searchText];
    else
        return nil;
    end
end

function ItemSearchPanel:getMatch()
    local ipairs = ipairs;
    local pairs = pairs;

    local itemsByDisplay = ITEMSEARCH_PERSISTENT_DATA.itemsByDisplayName;
    local nameSet = ITEMSEARCH_PERSISTENT_DATA.displayNameSet;

    self.searchChoices:setVisible(false);
    self.searchChoices:clear();

    local searchText = self.itemEntry:getInternalText();

    local matches = nil;

    matches = self:getExactMatches(searchText, itemsByDisplay, nameSet);

    if matches == nil then
        print("Did not find an exact match");
    else    
        print("Exact match from persistent data on display name, with " .. #matches .. " members");
        self:endMatch(matches, searchInventory, searchNearby, searchRoom, searchBuilding);
        return;
    end

    if matches == nil then
        matches = self:getPatternMatches(searchText, itemsByDisplay);
    end

    if matches == nil then
        print("No match found via pattern");
    else
        print("Pattern match from persistent data on display name, with " .. #matches .. " members");
        self:endMatch(matches, searchInventory, searchNearby, searchRoom, searchBuilding);
    end
end

function ItemSearchPanel:getPatternMatches(searchText, itemsByDisplay)
    local displayName = nil;

    local searchPattern = self:createSearchPattern(searchText);
    print("Generated search pattern is: " .. searchPattern);
    displayName = findBestMatch(string.len(searchText), searchPattern);

    if displayName ~= nil then
        return itemsByDisplay[displayName];
    else
        return nil;
    end
end

function ItemSearchPanel:pascalize(input)
    local results = {};
    local parts = splitString(input);

    for _, word in ipairs(parts) do
        table.insert(results, table.concat({ word:sub(1, 1):upper(), word:sub(2) }));
    end

    return table.concat(results, " ");
end

function ItemSearchPanel:pluralize(original)
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

function ItemSearchPanel:populateChoices(items)
    print("Got " .. #items .. " matches to pass to SearchChoiceTable");
    self.searchChoices:initList(items);
    self.searchChoices:setVisible(true);
end

function ItemSearchPanel:queueSearches()
    local searchInventory = self.searchInventoryTick.selected[1];
    local searchNearby = self.searchNearbyTick.selected[1];
    local searchRoom = self.searchRoomTick.selected[1];
    local searchBuilding = self.searchBuildingTick.selected[1];

    -- Gonna have displayName, name, and fullType, either the player entered an unambiguous name or we had them choose which they intend to get
    local searchTarget = ITEMSEARCH_PERSISTENT_DATA.searchTarget;
    -- function SearchInventoryAction:new(playerNum, character, inventory, searchTarget)
    if searchInventory then
        ISTimedActionQueue.add(SearchInventoryAction:new(self.playerNum, self.character, searchTarget, false));
    end

    if searchNearby then
        ISTimedActionQueue.add(SearchInventoryAction:new(self.playerNum, self.character, searchTarget, true));
    end
end

function ItemSearchPanel:render()
    -- Would not show up when put in createChildren. Perhaps overwritten/over-rendered by built-in ISCollapsableWindow functionality
    self:drawText("Search for what item?", 10, 40, 1, 1, 1, 1, UIFont.Small);

    local searchingFor = "Searching For: ";

    local searchTarget = ITEMSEARCH_PERSISTENT_DATA.searchTarget;

    if searchTarget ~= nil then
        local displayName = searchTarget.displayName;
        local name = searchTarget.name;

        searchingFor = searchingFor .. displayName .. " (Name: " .. name .. ")";
    else
        searchingFor = searchingFor .. " Search Item Not Set!";
    end

    local buttonHeight = self.startSearchButton.height;
    -- Height of the button below, a little padding, and enough height for the text
    local heightOffset = buttonHeight + SMALL_FONT + 12;
    self:drawText(searchingFor, 10, self.height - heightOffset, 1, 1, 1, 1, UIFont.Small)
end

function ItemSearchPanel:say(message)
    self.character:Say(message);
end

function ItemSearchPanel:sayResult(displayNameSearch, count, inventoryType)
    local message = self:formatMessage(count, displayNameSearch, inventoryType);

    self:say(message);
end

function ItemSearchPanel:searchInventory(displayName, name, fullType)
    self:say("Let me check my inventory...");
    -- TODO: Figure out some sort of shuffling through container animation, trigger it, and submit this as a short search action
    -- ISInventoryTransferAction:startActionAnim(), for source container character inventory, queues action anim "TransferItemOnSelf"
    local inventory = getPlayerInventory(self.playerNum);
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

    return false;
end

function ItemSearchPanel:searchNearby(displayName, name, fullType)    
    self:say("Hm, let's see what's around...");
    -- TODO: Get an ordered(?) list of searchable cells, then forward to a search action
    local loot = getPlayerLoot(self.playerNum);

    for i,v in ipairs(loot.inventoryPane.inventoryPage.backpacks) do
        local localInventory = v.inventory;
        local containerType = localInventory:getType();
        print("Searching loot container type: " .. containerType);

        local count = self:findItem(localInventory, displayName, name, fullType);

        if count ~= nil then
            self:sayResult(displayName, count, containerType);
            return true;
        end;
    end

    return false;
end

function ItemSearchPanel:searchRoom(displayName, name, fullType)
    -- TODO Attempt to find the item in other cells with containers (or even on the floor)
    local containerList = {};
        
    local room = self.player:getSquare():getRoom();
    local building = room:getBuilding();
    print("Inside building id: " .. building:getID());

    if room ~= nil then
        print("We're inside a room we can check for other containers");
        print("Looking at room, name: " .. room:getName());
        local roomContainers = {};
        local squares = room:getSquares();
        local squareCount = squares:size();
        print("Squares (arraylist) size: " .. squareCount);
        for i = 0, squareCount - 1 do
            local square = squares:get(i);
            local x = square:getX();
            local y = square:getY();
            -- *Should* be ignorable
            local z = square:getZ();
            print("Got square with x: " .. x .. ", y: " .. y .. ", z: " .. z);
            local objs = square:getObjects();

            for it = 0, objs:size() - 1 do
                local obj = objs:get(it);
                local objContainer = obj:getContainer();
                if objContainer ~= nil then
                    print("Found a container in the square, of type: " .. objContainer:getType());

                    local containerItems = objContainer:getItems();
                    local num = containerItems:size();
                    
                    for listIt = 0, num - 1 do
                        local containerItem = containerItems:get(listIt);
                        print("Found an item in the container, display name: " .. containerItem:getDisplayName() .. ", type: " .. containerItem:getType());
                    end
                end
            end
        end
    end
end

function ItemSearchPanel:setSearchTarget(item)    
    local displayName = item:getDisplayName();
    local name = item:getName();
    -- Don't get confused. If you have an *Item*, instead of an InventoryItem, you need to call getFullName() instead of getFullType()
    local fullType = item:getFullName();

    print("setSearchTarget called with displayName: " .. displayName .. " , name: " .. name .. ", full type: " .. fullType);
    ITEMSEARCH_PERSISTENT_DATA.searchTarget = { displayName = displayName, name = name, fullType = fullType };
    -- TODO: Clear any previous searching data we stored related to the room, etc.
    self.startSearchButton.enable = true;
end

function ItemSearchPanel:startSearch()
    print("Requested to start searching");
    local searchTarget = ITEMSEARCH_PERSISTENT_DATA.searchTarget;
    
    local displayName = searchTarget.displayName;
    local name = searchTarget.name;
    local fullType = searchTarget.fullType;

    local searchInventory = self.searchInventoryTick.selected[1];
    local searchNearby = self.searchNearbyTick.selected[1];
    local searchRoom = self.searchRoomTick.selected[1];
    local searchBuilding = self.searchBuildingTick.selected[1];
    print("searchInventory: " .. tostring(searchInventory) .. ", searchNearby: " .. tostring(searchNearby) .. ", searchRoom: " .. tostring(searchRoom) .. ", searchBuilding: " .. tostring(searchBuilding));
    local foundItem = false;
    
    -- Queue search actions!
    self:queueSearches();
    
    ui:setVisible(false);
    ui:removeFromUIManager();
    ui = null;
    uiOpen = false;
end

function ItemSearchPanel:update()
    ISCollapsableWindow.update(self);

    -- update size of entire window if internal element size updates
end

function cacheItems()
    print("Startup, getting cache of items available for searching");
    local allItems = getAllItems();

    ITEMSEARCH_PERSISTENT_DATA.itemCache = allItems;
    ITEMSEARCH_PERSISTENT_DATA.displayNameSet = {};
    ITEMSEARCH_PERSISTENT_DATA.itemsByDisplayName = {};

    local javaItemsSize = allItems:size();
    for x = 0, javaItemsSize -1 do
        local item = allItems:get(x);

        local module = item:getModuleName();
        local name = item:getName();
        local itemType = item:getType();
        local displayName = item:getDisplayName();

        if not setContains(ITEMSEARCH_PERSISTENT_DATA.displayNameSet, displayName) then
            addTo(ITEMSEARCH_PERSISTENT_DATA.displayNameSet, displayName);
            ITEMSEARCH_PERSISTENT_DATA.itemsByDisplayName[displayName] = { item };
        else
            local matches = ITEMSEARCH_PERSISTENT_DATA.itemsByDisplayName[displayName];
            table.insert(matches, item);
        end
    end
    print("Done with cacheItems startup function, should have cached item info for " .. javaItemsSize .. " items provided by getAllItems()");
end

function ItemSearchPanel:new(player)
    local o = {};
    local x = getMouseX() + 10;
    local y = getMouseY() + 10;
    local width = 830;
    local height = 450;

    o = ISCollapsableWindow:new(x, y, width, height);
    setmetatable(o, self);
    self.__index = self;

    o.player = player;
    o.playerNum = player:getPlayerNum();
    o.character = getSpecificPlayer(o.playerNum);
    o.inventory = o.character:getInventory();
    o.buttonBorderColor = { r = 0.7, g = 0.7, b = 0.7, a = 0.5 };
    o.variableColor = { r = 0.9, g = 0.55, b = 0.1, a = 1 };
    o.zOffsetSmallFont = 25;

    return o;
end

function onCustomUIKeyPressed(key)
    if key == 40 then
        if uiOpen then
            print("We closin' the UI my dude");
            ui:setVisible(false);
            ui:removeFromUIManager();
            ui = null;
            uiOpen = false;
        else
            print("We openin' the UI my dude");
            local uiInstance = ItemSearchPanel:new(getPlayer());
            uiInstance:initialise();
            uiInstance:addToUIManager();
            ui = uiInstance;
            uiOpen = true;
        end
    end
end

Events.OnGameBoot.Add(cacheItems);
Events.OnCustomUIKeyPressed.Add(onCustomUIKeyPressed);