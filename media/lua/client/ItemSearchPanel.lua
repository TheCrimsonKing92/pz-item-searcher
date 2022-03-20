require "ISUI/ISCollapsableWindow"
require "ISUI/ISPanel"

local collectionUtil = require("PZISCollectionUtils");
local setUtil = collectionUtil.set;
local stringUtil = require("PZISStringUtils");

local textManager = getTextManager();
local SMALL_FONT = textManager:getFontHeight(UIFont.Small)
local buttonHeight = SMALL_FONT + 2 * 4;

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

function ItemSearchPanel:close()
    self:resetMatch();
    self:setVisible(false);
    self:removeFromUIManager();
    ui = null;
    uiOpen = false;
end

function ItemSearchPanel:createChildren()
    ISCollapsableWindow.createChildren(self);
    self:setTitle("Item Searcher");
    local buttonWidth = 75;
    local padBottom = 10;

    local textSize = textManager:MeasureStringX(UIFont.Small, "Search for what item?");

    local id = "Input";
    local inputY = 40;
    local inputWidth = 150;
    -- 10 is our left-margin, 8 to separate the box from the label, the rest from the text itself
    -- title, x, y, width, height
    self.itemEntry = ISTextEntryBox:new("", 18 + textSize, inputY, inputWidth, buttonHeight);
    self.itemEntry.id = id;
    self.itemEntry:initialise();
    self.itemEntry:instantiate();
    self.itemEntry.onCommandEntered = function () self:getMatch() end;
    self:addChild(self.itemEntry);

    -- x, y, width, height, name, changeOptionTarget, changeOptionMethod, changeOptionArg1, changeOptionArg2
    self.searchInventoryTick = ISTickBox:new(textSize + inputWidth + 25, inputY, 10, 10, "", nil, nil);
    self.searchInventoryTick:initialise();
    self.searchInventoryTick:instantiate();
    self.searchInventoryTick.selected[1] = true;
    self.searchInventoryTick:addOption("Search Inventory");
    self:addChild(self.searchInventoryTick);

    local searchInventoryWidth = textManager:MeasureStringX(UIFont.Small, "Search Inventory");

    -- 10 is our leftPad, searchInventoryWidth is the text length of the leftward tick, 10 is the size of the leftward tick itself, then we need some additional padding
    -- local secondTickX = 10 + searchInventoryWidth + 10 + 13;
    local searchNearbyX = textSize + inputWidth + 25 + 25 + searchInventoryWidth;
    self.searchNearbyTick = ISTickBox:new(searchNearbyX, inputY, 10, 10, "", nil, nil);
    self.searchNearbyTick:initialise();
    self.searchNearbyTick:instantiate();
    self.searchNearbyTick.selected[1] = true;
    self.searchNearbyTick:addOption("Search Nearby");
    self:addChild(self.searchNearbyTick);

    local searchNearbyTextWidth = textManager:MeasureStringX(UIFont.Small, "Search Nearby");
    local searchRoomX = searchNearbyX + 25 + searchNearbyTextWidth;

    self.searchRoomTick = ISTickBox:new(searchRoomX, inputY, 10, 10, "", nil, nil);
    self.searchRoomTick:initialise();
    self.searchRoomTick:instantiate();
    self.searchRoomTick.selected[1] = true;
    self.searchRoomTick:addOption("Search Room");
    self:addChild(self.searchRoomTick);

    --[[
    local searchRoomTextWidth = textManager:MeasureStringX(UIFont.Small, "Search Room");
    local searchBuildingX = searchRoomX + 25 + searchRoomTextWidth;

    self.searchBuildingTick = ISTickBox:new(searchBuildingX, inputY, 10, 10, "", nil, nil);
    self.searchBuildingTick:initialise();
    self.searchBuildingTick:instantiate();
    self.searchBuildingTick.selected[1] = true;
    self.searchBuildingTick:addOption("Search Building");
    self:addChild(self.searchBuildingTick);
    ]]--

    self:createStartSearch();
end

function ItemSearchPanel:createSearchPattern(input)
    local patternTable = {};
    local contains = setUtil.contains;

    local function isAlpha(char)
        return contains(ALPHA_SET, char);
    end

    local function isMagic(char)
        return contains(MAGIC_SET, char);
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

function ItemSearchPanel:createStartSearch()
    if self.startSearchButton ~= nil then
        return;
    end
    

    local buttonCallback = function()
        self:startSearch();
    end

    local buttonY = 108;

    if self.searchChoices ~= nil then
        buttonY = buttonY + 202;
    end

    -- x, y, width, height, text, click target, click function
    self.startSearchButton = ISButton:new(10, buttonY, 70, buttonHeight, "Start Searching", self, buttonCallback);
    self.startSearchButton.enable = false;
    self.startSearchButton:initialise();
    self.startSearchButton:instantiate();
    self:addChild(self.startSearchButton);
end

function ItemSearchPanel:createTable()
    local tableCallback = function(item)
        self:setSearchTarget(item);
    end
    
    -- x, y, width, height, callback
    self.searchChoices = SearchChoiceTable:new(10, 105, 800, 170, tableCallback);
    self.searchChoices:initialise();
    self.searchChoices:setVisible(false);
    self:addChild(self.searchChoices);
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
    local contains = setUtil.contains;
    local searchText = stringUtil:pascalize(searchText);

    if contains(nameSet, searchText) then
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

    self:resetMatch();

    local searchText = self.itemEntry:getInternalText();

    local matches = nil;

    matches = self:getExactMatches(searchText, itemsByDisplay, nameSet);

    if matches ~= nil then
        self:endMatch(matches);
        return;
    end

    matches = self:getPatternMatches(searchText, itemsByDisplay);

    if matches ~= nil then
        self:endMatch(matches);
    else
        print("No match found");
    end
end

function ItemSearchPanel:getPatternMatches(searchText, itemsByDisplay)
    local displayName = nil;

    local searchPattern = self:createSearchPattern(searchText);
    displayName = findBestMatch(string.len(searchText), searchPattern);

    if displayName ~= nil then
        return itemsByDisplay[displayName];
    else
        return nil;
    end
end

function ItemSearchPanel:pluralize(original)
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

function ItemSearchPanel:populateChoices(items)
    if self.searchChoices == nil then
        self:setHeight(self:getHeight() + 200);
        self:createTable();
        self:recreateStartSearch();
    end

    self.searchChoices:initList(items);
    self.searchChoices:setVisible(true);
end

function ItemSearchPanel:queueSearches()
    local searchInventory = self.searchInventoryTick.selected[1];
    local searchNearby = self.searchNearbyTick.selected[1];
    local searchRoom = self.searchRoomTick.selected[1];
    -- local searchBuilding = self.searchBuildingTick.selected[1];

    -- Gonna have displayName, name, and fullType, either the player entered an unambiguous name or we had them choose which they intend to get
    local searchTarget = ITEMSEARCH_PERSISTENT_DATA.searchTarget;
    -- function SearchInventoryAction:new(playerNum, character, inventory, searchTarget)
    if searchInventory then
        ISTimedActionQueue.add(SearchInventoryAction:new(self.playerNum, self.character, searchTarget, false));
    end

    if searchNearby then
        ISTimedActionQueue.add(SearchInventoryAction:new(self.playerNum, self.character, searchTarget, true));
    end

    if searchRoom then
        ISTimedActionQueue.add(SearchRoomAction:new(self.playerNum, self.character, searchTarget));
    end;
end

function ItemSearchPanel:recreateStartSearch()
    self:removeStartSearch();
    self:createStartSearch();
end

function ItemSearchPanel:render()
    -- Would not show up when put in createChildren. Perhaps overwritten/over-rendered by built-in ISCollapsableWindow functionality
    self:drawText("Search for what item?", 10, 42, 1, 1, 1, 1, UIFont.Small);

    local searchingFor = "Searching For: ";

    local searchTarget = ITEMSEARCH_PERSISTENT_DATA.searchTarget;

    if searchTarget ~= nil then
        local displayName = searchTarget.displayName;
        local name = searchTarget.name;

        searchingFor = searchingFor .. displayName .. " (Name: " .. name .. ")";
    else
        searchingFor = searchingFor .. " Search item not set! Enter an unambiguous display name, or double-click a table result.";
    end

    -- Height of the button below, a little padding, and enough height for the text
    local heightOffset = buttonHeight + SMALL_FONT + 12;
    self:drawText(searchingFor, 10, 80, 1, 1, 1, 1, UIFont.Small)
end

function ItemSearchPanel:removeStartSearch()
    self:removeChild(self.startSearchButton);
    self.startSearchButton = nil;
end

function ItemSearchPanel:resetChoices()
    if self.searchChoices == nil then
        return;
    end
    
    self.searchChoices:setVisible(false);
    self.searchChoices:clear();
    self:removeChild(self.searchChoices);
    self.searchChoices = nil;
    self:setHeight(self:getHeight() - 200);
    self:recreateStartSearch();
end

function ItemSearchPanel:resetMatch()
    self:resetChoices();
    ITEMSEARCH_PERSISTENT_DATA.searchTarget = nil;
    self.startSearchButton.enable = false;
end

function ItemSearchPanel:say(message)
    self.character:Say(message);
end

function ItemSearchPanel:sayResult(displayNameSearch, count, inventoryType)
    local message = self:formatMessage(count, displayNameSearch, inventoryType);

    self:say(message);
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

    ITEMSEARCH_PERSISTENT_DATA.searchTarget = { displayName = displayName, name = name, fullType = fullType };
    -- TODO: Clear any previous searching data we stored related to the room, etc.
    self.startSearchButton.enable = true;
end

function ItemSearchPanel:startSearch()
    self:queueSearches();
    self:close();
end

function ItemSearchPanel:update()
    ISCollapsableWindow.update(self);
end

function cacheItems()
    print("Startup, getting cache of items available for searching");
    local add = setUtil.add;
    local contains = setUtil.contains;
    local allItems = getAllItems();

    ITEMSEARCH_PERSISTENT_DATA.itemCache = allItems;
    ITEMSEARCH_PERSISTENT_DATA.displayNameSet = {};
    ITEMSEARCH_PERSISTENT_DATA.itemsByDisplayName = {};

    local javaItemsSize = allItems:size();
    for x = 0, javaItemsSize -1 do
        local item = allItems:get(x);
        local displayName = item:getDisplayName();

        if not contains(ITEMSEARCH_PERSISTENT_DATA.displayNameSet, displayName) then
            add(ITEMSEARCH_PERSISTENT_DATA.displayNameSet, displayName);
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
    -- Initial height doesn't contain space for the SearchChoiceTable
    local height = 150;

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
            ui:setVisible(false);
            ui:removeFromUIManager();
            ui = null;
            uiOpen = false;
        else
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