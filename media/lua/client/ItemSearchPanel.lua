require "ISUI/ISCollapsableWindow"
require "ISUI/ISPanel"
local SMALL_FONT = getTextManager():getFontHeight(UIFont.Small)

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
        print("isBetterMatch called with newBegin: " .. newBegin .. ", newEnd: " .. newEnd .. ", newLength: " .. newLength);
        print("potentialMatchBegin: " .. tostring(potentialMatchBegin) .. ", potentialMatchEnd: " .. tostring(potentialMatchEnd) .. ", potentialMatchLength: " .. tostring(potentialMatchLength));
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
    print("[ItemSearcher] - ", ...);
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

    local textSize = getTextManager():MeasureStringX(UIFont.Small, "Search for what item?");

    local id = "Input";    
    -- 10 is our left-margin, 8 to separate the box from the label, the rest from the text itself
    self.itemEntry = ISTextEntryBox:new("", 18 + textSize, 40, 150, buttonHeight);
    self.itemEntry.id = id;
    self.itemEntry:initialise();
    self.itemEntry:instantiate();
    self.itemEntry.onCommandEntered = function () self:search() end;
    self:addChild(self.itemEntry);

    -- x, y, width, height, name, changeOptionTarget, changeOptionMethod, changeOptionArg1, changeOptionArg2
    self.searchInventoryTick = ISTickBox:new(10, 60, 10, 10, "", nil, nil);
    self.searchInventoryTick:initialise();
    self.searchInventoryTick:instantiate();
    self.searchInventoryTick.selected[1] = true;
    self.searchInventoryTick:addOption("Search Inventory");
    self:addChild(self.searchInventoryTick);

    self.searchRoomTick = ISTickBox:new(10, 85, 10, 10, "", nil, nil);
    self.searchRoomTick:initialise();
    self.searchRoomTick:instantiate();
    self.searchRoomTick.selected[1] = true;
    self.searchRoomTick:addOption("Search Room");
    self:addChild(self.searchRoomTick);

    self.searchBuildingTick = ISTickBox:new(10, 110, 10, 10, "", nil, nil);
    self.searchBuildingTick:initialise();
    self.searchBuildingTick:instantiate();
    self.searchBuildingTick.selected[1] = true;
    self.searchBuildingTick:addOption("Search Building");
    self:addChild(self.searchBuildingTick);

    -- x, y, width, height, inventory, zoom
    self.searchChoices = SearchChoiceTable:new(10, 140, 800, 120, self.playerNum);
    self.searchChoices:initialise();
    self:addChild(self.searchChoices);
end

function ItemSearchPanel:update()
    ISCollapsableWindow.update(self);

    -- update size of entire window if internal element size updates
end

function ItemSearchPanel:render()
    -- Would not show up when put in createChildren. Perhaps overwritten/over-rendered by built-in ISCollapsableWindow functionality
    self:drawText("Search for what item?", 10, 40, 1, 1, 1, 1, UIFont.Small);
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

function ItemSearchPanel:populateChoices(items)
    print("Got " .. #items .. " matches to pass to SearchChoiceTable");
    self.searchChoices:initList(items);
end

function ItemSearchPanel:search()
    local ipairs = ipairs;
    local pairs = pairs;

    local itemsByDisplay = ITEMSEARCH_PERSISTENT_DATA.itemsByDisplayName;
    local nameSet = ITEMSEARCH_PERSISTENT_DATA.displayNameSet;

    local findItem = function(container, displayNameSearch)
        local containerType = container:getType();
        print("Searching locally in " .. containerType .. " container");
        local items = container:getItems();

        for i = 0, items:size() - 1 do
            local item = items:get(i);

            local displayName = item:getDisplayName();

            if displayNameSearch == displayName then
                local fullType = item:getFullType();
                -- Ask the InventoryContainer for the count, not including items that can be drained, recursing through inventory container items
                local count = container:getNumberOfItem(fullType, false, true);
                return count;
            end
        end

        return nil;
    end

    local formatMessage = function(count, displayName, inventoryType)
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
                return pluralize(displayName);
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

    local getExactMatch = function(searchText, itemsByDisplay)
        local pascalize = function(input)
            local results = {};
            local parts = splitString(input);

            for _, word in ipairs(parts) do
                table.insert(results, table.concat({ word:sub(1, 1):upper(), word:sub(2) }));
            end

            return table.concat(results, " ");
        end
        local displayName = nil;

        local searchText = pascalize(searchText);

        if setContains(nameSet, searchText) then
            local matches = itemsByDisplay[searchText];
            print("Exact match from persistent data on display name, with " .. #matches .. " members");
            -- All of these should have the same display name, so take the first
            displayName = matches[1]:getDisplayName();
            -- TODO: Present a selection of choices to allow the player specific searching
            self:populateChoices(matches);
        end

        return displayName;
    end

    local getPatternMatch = function(searchText)
        local displayName = nil;

        local searchPattern = self:createSearchPattern(searchText);
        print("Generated search pattern is: " .. searchPattern);
        displayName = findBestMatch(string.len(searchText), searchPattern);

        if displayName ~= nil then
            print("Best match found via pattern was: " .. displayName);
        else
            print("No match found via pattern");
        end

        return displayName;
    end

    local pluralize = function(original)
        if endsWith(original, "y") then
            local parts = {};
            table.insert(parts, original:sub(1, #original - 1));
            table.insert(parts, "ies");

            return table.concat(parts);
        end

        if not endsWith(original, "s") then
            local parts = {};
            table.insert(original);
            table.insert("s");

            return table.concat(parts);
        else
            return original;
        end
    end

    local say = function(message)
        self.character:Say(message);
    end

    local sayResult = function(displayNameSearch, count, inventoryType)
        local message = formatMessage(count, displayNameSearch, inventoryType);

        say(message);
    end

    local searchText = self.itemEntry:getInternalText();
    print("Entered search value is: " .. searchText);

    local searchInventory = self.searchInventoryTick.selected[1];
    local searchRoom = self.searchRoomTick.selected[1];
    local searchBuilding = self.searchBuildingTick.selected[1];

    -- Performance optimization:
    -- Attempt to Pascal-case words to more often get an exact match, which is much faster than searching patterns
    local displayName = getExactMatch(searchText, itemsByDisplay);

    if displayName == nil then
        displayName = getPatternMatch(searchText);
    end

    local playerNum = self.playerNum;
    local foundItem = false;

    local containerList = {};

    if searchInventory then
        say("Let me check my inventory...");
        -- TODO: Figure out some sort of shuffling through container animation, trigger it, and submit this as a short search action
        -- ISInventoryTransferAction:startActionAnim(), for source container character inventory, queues action anim "TransferItemOnSelf"
        local inventory = getPlayerInventory(playerNum);
        for i,v in ipairs(inventory.inventoryPane.inventoryPage.backpacks) do
            local localInventory = v.inventory;
            local containerType = localInventory:getType();

            if containerType == "none" then
                containerType = "inventory";
            elseif startsWith(containerType, "Bag") then
                containerType = "backpack";
            end
    
            local count = findItem(localInventory, displayName);
    
            if count ~= nil then
                foundItem = true;
                sayResult(displayName, count, containerType);
                break;
            end
    
            -- TODO only conditionally do this
            print("inserting container from player backpack, container type: " .. containerType);
            table.insert(containerList, localInventory);
        end
    
        if foundItem then
            return;
        end
    end

    if searchRoom then
        say("Hm, let's see what's around...");
        -- TODO: Get an ordered list of searchable cells, then forward to a search action
        local loot = getPlayerLoot(playerNum);
    
        for i,v in ipairs(loot.inventoryPane.inventoryPage.backpacks) do
            local localInventory = v.inventory;
            local containerType = localInventory:getType();
            print("Searching loot container type: " .. containerType);
    
            local count = findItem(localInventory, displayName);
    
            if count ~= nil then
                foundItem = true;
                sayResult(displayName, count, containerType);
                table.insert(containerList, localInventory);
                break;
            end;
        end

        if foundItem then
            return;
        end
    end

    if searchBuilding then

    end

    -- TODO Attempt to find the item in other cells with containers (or even on the floor)
    local room = player:getSquare():getRoom();
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

    print(containerList);
    -- Queue search actions!
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

        -- if string.find(name, "PanFriedVegetables") ~= nil then
        --     print("PANFRIEDVEGETABLES DISPLAY NAME: " .. displayName .. ", Module: " .. module .. ", type: " .. tostring(itemType) .. ", name: " .. name);
        -- end;

        print("Display name: " .. displayName .. ", Module: " .. module .. ", Type: " .. tostring(itemType) .. ", Name: " .. name);

        if not setContains(ITEMSEARCH_PERSISTENT_DATA.displayNameSet, displayName) then
            addTo(ITEMSEARCH_PERSISTENT_DATA.displayNameSet, displayName);
            ITEMSEARCH_PERSISTENT_DATA.itemsByDisplayName[displayName] = { item };
        else
            local matches = ITEMSEARCH_PERSISTENT_DATA.itemsByDisplayName[displayName];
            table.insert(matches, item);

            print("We have more than one item by the display name of " .. displayName);
            local last = #matches - 1;
            local lastMatch = matches[last];
            local lastMatchModule = lastMatch:getModuleName();
            local lastMatchType = tostring(lastMatch:getType());
            local lastMatchName = lastMatch:getName();
            print("Previous: " .. displayName .. "[" .. last .. "]" .. " Module: " .. lastMatchModule .. ", Type: " .. lastMatchType .. ", Name: " .. lastMatchName);
            print("Current: " .. displayName .. "[" .. tostring(#matches) .. "]" .. " Module: " .. item:getModuleName() .. ", Type: " .. tostring(item:getType()) .. ", Name: " .. item:getName());
        end
    end
    print("Done with cacheItems startup function, should have cached display item info for " .. javaItemsSize .. " items provided by getAllItems()");
end

function ItemSearchPanel:new(player)
    local o = {};
    local x = getMouseX() + 10;
    local y = getMouseY() + 10;
    local width = 830;
    local height = 500;

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