require "ISUI/ISCollapsableWindow"
require "ISUI/ISPanel"

local collectionUtil = require("PZISCollectionUtils");
local Set = collectionUtil.Set;
local playerUtil = require("PZISPlayerUtils");
local stringUtil = require("PZISStringUtils");

local textManager = getTextManager();
local SMALL_FONT = textManager:getFontHeight(UIFont.Small);
local buttonHeight = SMALL_FONT + 2 * 4;
local buttonWidth = 70;

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

local SEARCH_MODE = {
    RESTRICTED = 1,
    HYBRID = 2,
    UNRESTRICTED = 3
};

local SEARCH_MODE_COLORS = { { r = 1, g = 0, b = 0, a = 1 }, { r = 1, g = 1, b = 0, a = 1 }, { r = 0, g = 1, b = 0, a = 1 } };
local SEARCH_MODE_NAMES = {"Restricted", "Hybrid", "Unrestricted"};

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
    -- Default value, x, y, width, height
    self.itemEntry = ISTextEntryBox:new("", uiLeftPadding + textSize + 8, searchInputYOffset - (buttonHeight / 6), inputWidth, buttonHeight);
    self.itemEntry.id = "Input";
    self.itemEntry:initialise();
    self.itemEntry:instantiate();
    self.itemEntry.onCommandEntered = function () self:getMatch() end;
    self.itemEntry.tooltip = "Press Enter / Return to identify your item"
    self:addChild(self.itemEntry);

    local currentSearchMode = self:getCurrentSandboxSearchMode();
    local r, g, b, a = self:getSearchModeColors(currentSearchMode);
    local searchModeName = SEARCH_MODE_NAMES[currentSearchMode];
    local searchModeLabel = ISLabel:new(uiLeftPadding + textSize + 8 + inputWidth + 8, searchInputYOffset, SMALL_FONT, searchModeName .. " Search Mode", r, g, b, a, UIFont.Small, true);
    searchModeLabel.tooltip = self:getSearchModeLabelTooltip(searchModeName);
    searchModeLabel:initialise();
    searchModeLabel:instantiate();
    self.searchModeLabel = searchModeLabel;
    self:addChild(searchModeLabel);

    self.searchLocations = ISTickBox:new(uiLeftPadding, searchInputYOffset + 25, 10, 10, "Search Where?", nil, nil);
    self.searchLocations:initialise();
    self.searchLocations:instantiate();
    self.searchLocations:addOption("Search Inventory");
    self.searchLocations.selected[1] = true;
    self.searchLocations:addOption("Search Nearby");
    self.searchLocations.selected[2] = true;
    self.searchLocations:addOption("Search Room");

    if self:shouldRoomSearchBeRestricted() then
        self.searchLocations:disableOption("Search Room", true);
    else
        self.searchLocations.selected[3] = true;
    end

    local oldOnMouseMove = self.searchLocations.onMouseMove;
    self.searchLocations.onMouseMove = function(dx, dy) oldOnMouseMove(dx, dy) if self.mouseOverOption ~= 0 then self:updateSearchLocationsTooltipText() end end;
    self:addChild(self.searchLocations);

    local takeItemXOffset = textManager:MeasureStringX(UIFont.Small, "Search Inventory") + 20 + 30;
    self.searchOptions = ISTickBox:new(uiLeftPadding + takeItemXOffset, searchInputYOffset + 25, 10, 10, "Take Item", nil, nil);
    self.searchOptions:initialise();
    self.searchOptions:instantiate();
    self.searchOptions:addOption("Silent Search");
    self.searchOptions.selected[1] = false;
    self.searchOptions:addOption("Take Item");
    self.searchOptions.selected[2] = true;

    local oldOnMouseMoveOptions = self.searchOptions.onMouseMove;
    self.searchOptions.onMouseMove = function(dx, dy) oldOnMouseMoveOptions(dx, dy) if self.mouseOverOption ~= 0 then self:updateSearchOptionsTooltipText() end end;

    self:addChild(self.searchOptions);

    local yOffset = searchingForTextYOffset;

    if self.searchChoices ~= nil then
        yOffset = yOffset + tableHeight + tableVerticalPadding + 5;
    end

    local searchingForLabel = ISLabel:new(uiLeftPadding, yOffset, SMALL_FONT, self:getSearchingForText(), 1, 1, 1, 1, UIFont.Small, true);
    searchingForLabel:initialise();
    searchingForLabel:instantiate();
    self.searchingForLabel = searchingForLabel;
    self:addChild(self.searchingForLabel);

    self:createStartSearch();
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

function ItemSearchPanel:getCurrentSandboxSearchMode()
    return SandboxVars.ItemSearcher.SearchMode or SEARCH_MODE.RESTRICTED;
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

    local searchPattern = stringUtil:createSearchPattern(searchText);
    displayName = findBestMatch(string.len(searchText), searchPattern);

    if displayName ~= nil then
        return itemsByDisplay[displayName];
    else
        return nil;
    end
end

function ItemSearchPanel:getPlayerSafehouse()
    return SafeHouse.hasSafehouse(self.player);
end

function ItemSearchPanel:getSearchingForText()
    local searchingFor = "Searching For: "

    if ITEMSEARCH_PERSISTENT_DATA.searchTarget == nil then
        return searchingFor  .. " Search item not set! Enter an unambiguous display name, or double-click a table result.";
    end

    local searchTarget = ITEMSEARCH_PERSISTENT_DATA.searchTarget;

    local displayName = searchTarget.displayName;
    local name = searchTarget.name;

    return searchingFor .. displayName .. " (Name: " .. name .. ")";
end

function ItemSearchPanel:getSearchModeColors(mode)
    local searchMode = mode or self:getCurrentSandboxSearchMode();
    local colors = SEARCH_MODE_COLORS[searchMode];

    return colors.r, colors.g, colors.b, colors.a;
end

function ItemSearchPanel:getSearchModeLabelTooltip(searchModeName)
    if "Restricted" == searchModeName then
        return "Room search is only usable in your safehouse";
    elseif "Hybrid" == searchModeName then
        return  "Search anywhere but someone else's safehouse";
    else
        return "Search where you please!";
    end
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
    elseif xDiff == 0 and (yDiff == -1 or yDiff == 1) then
        return true;
    else
        return false;
    end
end

function ItemSearchPanel:isHybridMode()
    return SEARCH_MODE.HYBRID == self:getCurrentSandboxSearchMode();
end

function ItemSearchPanel:isPlayerInOtherSafehouse()
    if not isClient() then
        return false;
    end

    local square = self.character:getSquare();
    local safeHouse = SafeHouse.getSafeHouse(square);

    if safeHouse == nil then
        return false;
    end

    local username = self.character:getUsername();
    -- This bypasses the special privileges that admins have
    local playerAllowed = safeHouse:playerAllowed(username);

    return not playerAllowed;
end

function ItemSearchPanel:isPlayerInRoom()
    return self.character:getSquare():getRoom() ~= nil
end

function ItemSearchPanel:isPlayerInTheirSafehouse()
    local square = self.character:getSquare();
    local safehouse = self:getPlayerSafehouse();

    -- Player doesn't have a safehouse
    if safehouse == nil then
        return false;
    end
    
    local squareX = square:getX();
    local squareY = square:getY();

    return squareX >= safehouse:getX() and
           squareX < safehouse:getX2() and
           squareY >= safehouse:getY() and
           squareY < safehouse:getY2();
end

function ItemSearchPanel:isRestrictedMode()
    return SEARCH_MODE.RESTRICTED == self:getCurrentSandboxSearchMode();
end

function ItemSearchPanel:isUnrestrictedMode()
    return SEARCH_MODE.UNRESTRICTED == self:getCurrentSandboxSearchMode();
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
    local searchInventory = self.searchLocations.selected[1];
    local searchNearby = self.searchLocations.selected[2];
    local searchRoom = self.searchLocations.selected[3];
    -- local searchBuilding = self.searchLocations.selected[4];

    local silentSearch = self.searchOptions.selected[1];
    local takeItem = self.searchOptions.selected[2];

    if not searchInventory and not searchNearby and not searchRoom then
        print("No search method selected");
        return;
    end

    -- Gonna have displayName, name, and fullType, either the player entered an unambiguous name or we had them choose which they intend to get
    local searchTarget = ITEMSEARCH_PERSISTENT_DATA.searchTarget;
    -- function SearchInventoryAction:new(playerNum, character, inventory, searchTarget)
    if searchInventory then
        ISTimedActionQueue.add(SearchInventoryAction:new(self.playerNum, self.character, searchTarget, false, silentSearch, takeItem));
    end

    if searchNearby then
        ISTimedActionQueue.add(SearchInventoryAction:new(self.playerNum, self.character, searchTarget, true, silentSearch, takeItem));
    end

    if searchRoom then
        local square = self.character:getSquare();
        local playerX = square:getX();
        local playerY = square:getY();
        local theZ = square:getZ();

        local room = square:getRoom();

        if room == nil and not silentSearch then
            self.character:Say("I'm not in a room to search!");
            return;
        end
        
        local consumedCells, containerCells, containerMap, sortedContainers = SearchRoomContainerAction.findRoomContainers(room, playerX, playerY);

        if containerCells:size() == 0 and not silentSearch then
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
        local containerDetails = { containerCell = first, containerCells = containerCells, containerMap = containerMap, consumedCells = consumedCells };
        ISTimedActionQueue.add(SearchRoomContainerAction:new(self.character, searchTarget, silentSearch, takeItem, containerDetails));
    end
end

function ItemSearchPanel:recreateStartSearch()
    self:removeStartSearch();
    self:createStartSearch();
end

function ItemSearchPanel:render()
    ISCollapsableWindow.render(self);
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
    self.searchingForLabel:setName(self:getSearchingForText());
    self.startSearchButton.enable = false;
end

function ItemSearchPanel:setSearchTarget(item)    
    local displayName = item:getDisplayName();
    local name = item:getName();
    -- Don't get confused. If you have an *Item*, instead of an InventoryItem, you need to call getFullName() instead of getFullType()
    local fullType = item:getFullName();

    ITEMSEARCH_PERSISTENT_DATA.searchTarget = { displayName = displayName, name = name, fullType = fullType };
    -- TODO: Clear any previous searching data we stored related to the room, etc.
    self.searchingForLabel:setName(self:getSearchingForText());
    self.startSearchButton.enable = true;
end

function ItemSearchPanel:shouldRoomSearchBeRestricted()
    if self:isRestrictedMode() then
        return not self:isPlayerInTheirSafehouse();
    elseif self:isHybridMode() then
        return self:isPlayerInOtherSafehouse();
    else
        return not self:isPlayerInRoom();
    end
end

function ItemSearchPanel:startSearch()
    self:queueSearches();
    self:close();
end

function ItemSearchPanel:update()
    ISCollapsableWindow.update(self);
end

function ItemSearchPanel:updateSearchLocationsTooltipText()
    local mousedOption = self.searchLocations.mouseOverOption;
    if mousedOption == 1 then
        self.searchLocations.tooltip = "Search your personal inventory";
    elseif mousedOption == 2 then
        self.searchLocations.tooltip = "Search nearby inventories";
    elseif mousedOption == 3 then
        if self:isRestrictedMode() and not self:isPlayerInTheirSafehouse() then
            self.searchLocations.tooltip = "Searching is only allowed in your safehouse";
        elseif self:isHybridMode() and self:isPlayerInOtherSafehouse() then
            self.searchLocations.tooltip = "Searching is not allowed in other safehouses";
        elseif not self:isPlayerInRoom() then
            self.searchLocations.tooltip = "Room search unavailable outside";
        else
            self.searchLocations.tooltip = "Search all room containers";
        end
    else
        self.searchLocations.tooltip = nil;
    end
end

function ItemSearchPanel:updateSearchOptionsTooltipText()
    local mousedOption = self.searchOptions.mouseOverOption;
    if mousedOption == 1 then
        self.searchOptions.tooltip = "Search without saying anything";
    elseif mousedOption == 2 then
        self.searchOptions.tooltip = "Queue an inventory transfer action if the item is found";
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