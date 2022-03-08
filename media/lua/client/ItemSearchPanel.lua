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
                potentialMatchEnd = thisLength;
            end;
        end
    end
end

local print = function(...)
    print("[ItemSearcher] - ", ...);
end

local function setContains(set, key)
    return set[key] ~= nil;
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
end

function ItemSearchPanel:update()
    ISCollapsableWindow.update(self);

    -- update size of entire window if internal element size updates
end

function ItemSearchPanel:render()    
    -- Entry label
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

function ItemSearchPanel:new()
    local o = {};
    local x = getMouseX() + 10;
    local y = getMouseY() + 10;

    o = ISCollapsableWindow:new(x, y, 300, 100);
    setmetatable(o, self);
    self.__index = self;

    o.buttonBorderColor = { r = 0.7, g = 0.7, b = 0.7, a = 0.5 };
    o.variableColor = { r = 0.9, g = 0.55, b = 0.1, a = 1 };
    o.zOffsetSmallFont = 25;

    return o;
end

function ItemSearchPanel:search()
    local ipairs = ipairs;
    local pairs = pairs;

    local nameSet = ITEMSEARCH_PERSISTENT_DATA.displayNameSet;

    local searchText = self.itemEntry:getInternalText();
    print("Entered search value is: " .. searchText);
    
    local exactMatch = setContains(nameSet, searchText);
    local displayName = nil;

    if exactMatch then
        local matches = ITEMSEARCH_PERSISTENT_DATA.itemsByDisplayName[searchText];
        print("Exact match from persistent data on display name: ", ITEMSEARCH_PERSISTENT_DATA.itemsByDisplayName[searchText]);
        for i, match in ipairs(matches) do
            print(match:getDisplayName() .. ": " .. tostring(match:getType()) .. " - " .. match:getModuleName() .. "." .. match:getName());
            -- TODO: If we truly have multiple items, this will always take the last match found, making this non-deterministic
            displayName = match:getDisplayName();
        end
    end

    if displayName == nil then
        local searchPattern = self:createSearchPattern(searchText);
        print("Generated search pattern is: " .. searchPattern);
        displayName = findBestMatch(string.len(searchText), searchPattern);

        if displayName ~= nil then
            print("Best match found via pattern was: " .. displayName);
        else
            print("No match found via pattern");
        end
    end

    if displayName == nil then
        print("No match found, out of options :(");
        return;
    else
        print("The match we found was: " .. displayName);
    end

    local player = getPlayer();
    local playerNum = player:getPlayerNum();
    local foundItem = false;
    local inventory = getPlayerInventory(playerNum);

    local containerList = {};

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
        local messageParts = {};
        local suffixParts = {" in "};

        if inventoryType == "inventory" then
            table.insert(messageParts, "I have ");
            table.insert(suffixParts, "my inventory");
        else
            if count == 1 then
                table.insert(messageParts, "There is ");
            else
                table.insert(messageParts, "There are ");
            end
            table.insert(suffixParts, "the ");
            table.insert(suffixParts, inventoryType);
        end

        if count == 1 then
            table.insert(messageParts, "a");
        else
            table.insert(messageParts, count);
        end
        
        table.insert(messageParts, " ");
        table.insert(messageParts, displayName);

        if count > 1 and not endsWith(displayName, "s") then
            table.insert(messageParts, "s");
        end

        table.insert(messageParts, table.concat(suffixParts, ""));

        return table.concat(messageParts, "");
    end

    local sayResult = function(playerNum, displayNameSearch, count, inventoryType)
        local message = formatMessage(count, displayNameSearch, inventoryType);

        getSpecificPlayer(playerNum):Say(message);
    end

    for i,v in ipairs(inventory.inventoryPane.inventoryPage.backpacks) do
        local localInventory = v.inventory;
        local containerType = localInventory:getType();
        if containerType == "none" then
            containerType = "inventory"
        end

        local count = findItem(localInventory, displayName);

        if count ~= nil then
            foundItem = true;
            sayResult(playerNum, displayName, count, containerType);
            break;
        end

        -- TODO only conditionally do this
        print("inserting container from player backpack, container type: " .. containerType);
        table.insert(containerList, localInventory);
    end

    if foundItem then
        return;
    end

    local loot = getPlayerLoot(playerNum);

    for i,v in ipairs(loot.inventoryPane.inventoryPage.backpacks) do
        local localInventory = v.inventory;
        local containerType = localInventory:getType();
        print("Searching loot container type: " .. containerType);

        local count = findItem(localInventory, displayName);

        if count ~= nil then
            foundItem = true;
            sayResult(playerNum, displayName, count, containerType);
            table.insert(containerList, localInventory);
        end;
    end

    -- TODO Attempt to find the item in other cells with containers (or even on the floor)
    local room = player:getSquare():getRoom();

    if room ~= nil then
        print("We're inside a room we can check for other containers");
        local tileList = room:getTileList();
        --print("Stuff available on vector: ");
        --for key,value in pairs(tileList) do
        --    print("Found member " .. key);
        --end
        -- print("Tile list (vector) size: " .. tileList:size());
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
                if (objContainer ~= nil) then
                    print("Found a container in the square, of type: " .. objContainer:getType());

                    local containerItems = objContainer:getItems();
                    local num = containerItems:size();
                    
                    for listIt = 0, containerItems:size() - 1 do
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

        local type = item:getType();

        local displayName = item:getDisplayName();

        if string.find(name, "PanFriedVegetables") ~= nil then
            print("PANFRIEDVEGETABLES DISPLAY NAME: " .. displayName .. ", Module: " .. module .. ", type: " .. tostring(type) .. ", name: " .. name);
        end;

        if not setContains(ITEMSEARCH_PERSISTENT_DATA.displayNameSet) then
            addTo(ITEMSEARCH_PERSISTENT_DATA.displayNameSet, displayName);
            ITEMSEARCH_PERSISTENT_DATA.itemsByDisplayName[displayName] = { item };
        else
            table.insert(ITEMSEARCH_PERSISTENT_DATA.itemsByDisplayName[displayName], item);
            print("We now have more than one item by the display name of " .. displayName);
            for i, v in ipairs(ITEMSEARCH_PERSISTENT_DATA.itemsByDisplayName[displayName]) do
                print(displayName .. "[" .. i .. "]" .. " Module: " .. v:getModuleName());
            end
        end
    end
    print("Done with cacheItems startup function, should have cached display item info for " .. javaItemsSize .. " items provided by getAllItems()");
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
            local uiInstance = ItemSearchPanel:new();
            uiInstance:initialise();
            uiInstance:addToUIManager();
            ui = uiInstance;
            uiOpen = true;
        end
    end
end

Events.OnGameBoot.Add(cacheItems);
Events.OnCustomUIKeyPressed.Add(onCustomUIKeyPressed);