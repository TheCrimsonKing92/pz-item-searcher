require "ISUI/ISCollapsableWindow"
require "ISUI/ISPanel"

local collectionUtil = require("PZISCollectionUtils");
local Set = collectionUtil.Set;
local playerUtil = require("PZISPlayerUtils");
local stringUtil = require("PZISStringUtils");

local textManager = getTextManager();
local SMALL_FONT = textManager:getFontHeight(UIFont.Small)
local buttonHeight = SMALL_FONT + 2 * 4;
local buttonWidth = 70;

local alphas = {"a", "A", "b", "B", "c", "C", "d", "D", "e", "E", "f", "F", "g", "G", "h", "H", "i", "I", "j", "J", "k", "K", "l", 'L', 'm', 'M', 'n', 'N', 'o', 'O', 'p', 'P', 'q', 'Q', 'r', 'R', 's', 'S', 't', 'T', 'u', 'U', 'v', 'V', 'w', 'W', 'x', 'X', 'y', 'Y', 'z', 'Z'};
local patternMagics = {"-"};
local ALPHA_SET = Set:new(alphas);
local MAGIC_SET = Set:new(patternMagics);

ITEMSEARCH_PERSISTENT_DATA = {};
ITEMSEARCH_PERSISTENT_DATA.displayNameSet = Set:new();
ITEMSEARCH_PERSISTENT_DATA.itemsByDisplayName = {};
ITEMSEARCH_PERSISTENT_DATA.searchTarget = nil;

local ui = null;
local uiOpen = false;

local uiLeftPadding = 10;

local searchInputYOffset = 40;

local tableHeight = 170;
local tableVerticalPadding = 30;
local tableWidth = 800;
local tableWidthAdjustment = 425;
local tableYOffset = 130;

local searchingForTextYOffset = 130;

local startSearchYOffset = 155;

ItemSearchPanel = ISCollapsableWindow:derive("ItemSearchPanel");

local function findBestMatch(originalLength, searchPattern)
    local pairs = pairs;
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

    local inputLabel = ISLabel:new(uiLeftPadding, searchInputYOffset, SMALL_FONT, "Search for what item?", 1, 1, 1, 1, UIFont.Small, true);
    self:addChild(inputLabel);
    local textSize = textManager:MeasureStringX(UIFont.Small, "Search for what item?");

    local inputWidth = 150;
    -- 10 is our left-margin, 8 to separate the box from the label, the rest from the text itself
    -- title, x, y, width, height
    self.itemEntry = ISTextEntryBox:new("", uiLeftPadding + textSize + 8, searchInputYOffset - (buttonHeight / 6), inputWidth, buttonHeight);
    self.itemEntry.id = "Input";
    self.itemEntry:initialise();
    self.itemEntry:instantiate();
    self.itemEntry.onCommandEntered = function () self:getMatch() end;
    self.itemEntry.tooltip = "Press Enter / Return to identify your item"
    self:addChild(self.itemEntry);

    self.searchOptions = ISTickBox:new(uiLeftPadding, searchInputYOffset + 25, 10, 10, "Search Where?", nil, nil);
    self.searchOptions:initialise();
    self.searchOptions:instantiate();

    self.searchOptions:addOption("Search Inventory");
    self.searchOptions.selected[1] = true;
    self.searchOptions:addOption("Search Nearby");
    self.searchOptions.selected[2] = true;
    self.searchOptions:addOption("Search Room");

    if not self:isPlayerInRoom() then
        self.searchOptions:disableOption("Search Room", true);
        self.searchOptions.tooltip = "Room search unavailable outside";
    else
        self.searchOptions.selected[3] = true;
    end

    local oldOnMouseMove = self.searchOptions.onMouseMove;
    self.searchOptions.onMouseMove = function(dx, dy) oldOnMouseMove(dx, dy) if self.mouseOverOption ~= 0 then self:updateSearchOptionsTooltipText() end end;

    self:addChild(self.searchOptions);

    local takeItemXOffset = textManager:MeasureStringX(UIFont.Small, "Search Inventory") + 20 + 30;
    self.takeItemOption = ISTickBox:new(uiLeftPadding + takeItemXOffset, searchInputYOffset + 25, 10, 10, "Take Item", nil, nil);
    self.takeItemOption:initialise();
    self.takeItemOption:instantiate();
    self.takeItemOption:addOption("Take Item");
    self.takeItemOption.selected[1] = false;
    self.takeItemOption.tooltip = "Queue an inventory transfer action if the item is found";
    self:addChild(self.takeItemOption);

    self:createStartSearch();
end

function ItemSearchPanel:createSearchPattern(input)
    local patternTable = {};

    for i = 1, #input do
        local char = input:sub(i, i);

        if ALPHA_SET:contains(char) then
            local charPattern = {"[", char:lower(), char:upper(), "]"};
            patternTable[#patternTable + 1] = table.concat(charPattern, "")
        elseif MAGIC_SET:contains(char) then
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

    local yOffset = startSearchYOffset;

    if self.searchChoices ~= nil then
        yOffset = yOffset + tableHeight + tableVerticalPadding + 5;
    end

    -- x, y, width, height, text, click target, click function
    self.startSearchButton = ISButton:new(uiLeftPadding, yOffset, buttonWidth, buttonHeight, "Start Searching", self, buttonCallback);
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
    self.searchChoices = SearchChoiceTable:new(uiLeftPadding, tableYOffset, tableWidth, tableHeight, tableCallback);
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

function ItemSearchPanel:getExactMatches(searchText, itemsByDisplay, nameSet)
    local searchText = stringUtil:pascalize(searchText);

    if nameSet:contains(searchText) then
        return itemsByDisplay[searchText];
    else
        return nil;
    end
end

function ItemSearchPanel:getMatch()
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

function ItemSearchPanel:getSearchingForText()
    local searchingFor = "Searching For: ";

    local searchTarget = ITEMSEARCH_PERSISTENT_DATA.searchTarget;

    if searchTarget ~= nil then
        local displayName = searchTarget.displayName;
        local name = searchTarget.name;

        searchingFor = searchingFor .. displayName .. " (Name: " .. name .. ")";
    else
        searchingFor = searchingFor .. " Search item not set! Enter an unambiguous display name, or double-click a table result.";
    end

    return searchingFor;
end

function ItemSearchPanel:isAdjacent(square)
    local current = self.character:getCurrentSquare();
    local playerX = current:getX();
    local playerY = current:getY();

    local squareX = square:getX();
    local squareY = square:getY();

    local xDiff = playerX - squareX;
    local yDiff = playerY - squareY;

    if xDiff <= -2 or xDiff >= 2 or yDiff <= -2 or yDiff >= 2 then
        return false;
    end

    if yDiff == 0 and (xDiff == -1 or xDiff == 1) then
        return true;
    elseif xDiff == 00 and (yDiff == -1 or yDiff == 1) then
        return true;
    else
        return false;
    end
end

function ItemSearchPanel:isPlayerInRoom()
    return self.character:getSquare():getRoom() ~= nil
end

function ItemSearchPanel:populateChoices(items)
    if self.searchChoices == nil then
        self:setHeight(self:getHeight() + tableHeight + tableVerticalPadding);
        self:setWidth(self:getHeight() + tableWidthAdjustment);
        self:createTable();
        self:recreateStartSearch();
    end

    self.searchChoices:initList(items);
    self.searchChoices:setVisible(true);
end

function ItemSearchPanel:queueSearches()
    local searchInventory = self.searchOptions.selected[1];
    local searchNearby = self.searchOptions.selected[2];
    local searchRoom = self.searchOptions.selected[3];
    -- local searchBuilding = self.searchOptions.selected[4];

    local takeItem = self.takeItemOption.selected[1];

    if not searchInventory and not searchNearby and not searchRoom then
        print("No search method selected");
        return;
    end

    -- Gonna have displayName, name, and fullType, either the player entered an unambiguous name or we had them choose which they intend to get
    local searchTarget = ITEMSEARCH_PERSISTENT_DATA.searchTarget;
    -- function SearchInventoryAction:new(playerNum, character, inventory, searchTarget)
    if searchInventory then
        ISTimedActionQueue.add(SearchInventoryAction:new(self.playerNum, self.character, searchTarget, false, takeItem));
    end

    if searchNearby then
        ISTimedActionQueue.add(SearchInventoryAction:new(self.playerNum, self.character, searchTarget, true, takeItem));
    end

    if searchRoom then
        local square = self.character:getSquare();
        local playerX = square:getX();
        local playerY = square:getY();
        local theZ = square:getZ();

        local room = square:getRoom();

        if room == nil then
            self.character:Say("I'm not in a room to search!");
            return;
        end
        
        local consumedCells, containerCells, containerMap, sortedContainers = SearchRoomContainerAction.findRoomContainers(room, playerX, playerY);

        if containerCells:size() == 0 then
            self.character:Say("There's nothing to search in here.");
            return;
        end

        local first = table.remove(sortedContainers, 1);

        local parts = stringUtil:split(first, ":");
        local targetX = tonumber(parts[1]);
        local targetY = tonumber(parts[2]);

        local targetSquare = getSquare(targetX, targetY, theZ);
        -- Grab a representative container from the square
        local squareContainers = containerMap[first];
        local representative = squareContainers[1];
        -- Queues the walk to the container square
        playerUtil.walkToContainer(self.character, representative);
        -- Queues the search
        ISTimedActionQueue.add(SearchRoomContainerAction:new(self.character, searchTarget, first, containerCells, containerMap, consumedCells));
    end
end

function ItemSearchPanel:recreateStartSearch()
    self:removeStartSearch();
    self:createStartSearch();
end

function ItemSearchPanel:render()
    local yOffset = searchingForTextYOffset;

    if self.searchChoices ~= nil then
        yOffset = yOffset + tableHeight + tableVerticalPadding + 5;
    end

    self:drawText(self:getSearchingForText(), uiLeftPadding, yOffset, 1, 1, 1, 1, UIFont.Small)
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
    self:setHeight(self:getHeight() - (tableHeight + tableVerticalPadding));
    self:setWidth(self:getWidth() - tableWidthAdjustment);
    self:recreateStartSearch();
end

function ItemSearchPanel:resetMatch()
    self:resetChoices();
    ITEMSEARCH_PERSISTENT_DATA.searchTarget = nil;
    self.startSearchButton.enable = false;
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

function ItemSearchPanel:updateSearchOptionsTooltipText()
    local mousedOption = self.searchOptions.mouseOverOption;
    if mousedOption == 1 then
        self.searchOptions.tooltip = "Search your personal inventory";
    elseif mousedOption == 2 then
        self.searchOptions.tooltip = "Search nearby inventories";
    elseif mousedOption == 3 and not self:isPlayerInRoom() then
        self.searchOptions.tooltip = "Room search unavailable outside";
    elseif mousedOption == 3 then
        self.searchOptions.tooltip = "Search all room containers";
    else
        self.searchOptions.tooltip = nil;
    end
end

function cacheItems()
    print("Startup, getting cache of items available for searching");
    local displayNameSet = ITEMSEARCH_PERSISTENT_DATA.displayNameSet;
    local allItems = getAllItems();

    ITEMSEARCH_PERSISTENT_DATA.itemCache = allItems;

    local javaItemsSize = allItems:size();
    for x = 0, javaItemsSize -1 do
        local item = allItems:get(x);
        local displayName = item:getDisplayName();

        if not displayNameSet:contains(displayName) then
            displayNameSet:add(displayName);
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
    local width = 580;
    -- Initial height doesn't contain space for the SearchChoiceTable
    local height = 200;

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