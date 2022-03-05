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

local print = function(...)
    print("[ItemSearcher] - ", ...);
end

local function setContains(set, key)
    return set[key] ~= nil;
end

function ItemSearchPanel:close()
    print("UI be closin' (via the built-in close button)");
    ui = null;
    uiOpen = false;
    self:removeFromUIManager();
end

function ItemSearchPanel:createChildren()
    ISCollapsableWindow.createChildren(self);
    self:setTitle("Item Searcher");
    -- Add entry box for item input
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

--[[
function ItemSearchPanel:create()

    id = "Close";
    self.close = ISButton:new(self:getWidth() - buttonWidth - 10, self:getHeight() - padBottom - buttonHeight, buttonWidth, buttonHeight, id, self, ItemSearchPanel.onOptionMouseDown);
    self.close.id = id;
    self.close.borderColor = self.buttonBorderColor;
    self.close:initialise();
    self.close:instantiate();
    self:addChild(self.close);

    id = "Search";
    self.search = ISButton:new(10, self:getHeight() - padBottom - buttonHeight, buttonWidth, buttonHeight, id, self, ItemSearchPanel.onOptionMouseDown);
    self.search.id = id;
    self.search.borderColor = self.buttonBorderColor;
    self.search:initialise();
    self.search:instantiate();
    self:addChild(self.search);
end
--]]

function ItemSearchPanel:createSearchPattern(input)
    local patternTable = {};

    local function isMagic(char)
        return setContains(MAGIC_SET, char);
    end

    local function whitelisted(char)
        return setContains(ALPHA_SET, char);
    end

    for i = 1, #input do
        local char = input:sub(i, i);

        if whitelisted(char) then
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

    -- ISCollapsableWindow has some defaults, so we don't necessarily have to set these
    -- o.backgroundColor = { r = 0, g = 0, b = 0, a = 1 };
    -- o.borderColor = { r = 0.4, g = 0.4, b = 0.4, a = 1 };
    o.buttonBorderColor = { r = 0.7, g = 0.7, b = 0.7, a = 0.5 };
    o.variableColor = { r = 0.9, g = 0.55, b = 0.1, a = 1 };
    o.zOffsetSmallFont = 25;

    return o;
end

function ItemSearchPanel:search()
    local ipairs = ipairs;
    local pairs = pairs;

    local function endsWith(str, ending)
        return ending == "" or str:sub(-#ending) == ending;
    end

    local nameSet = ITEMSEARCH_PERSISTENT_DATA.displayNameSet;

    local function findBestMatch(searchPattern)
        local result = nil;

        local potentialMatchBegin = nil;
        local potentialMatchEnd = nil;
        local thisBegin = nil;
        local thisEnd = nil;

        for k, _ in pairs(nameSet) do
            thisBegin, thisEnd = string.find(k, searchPattern);

            if thisBegin ~= nil then
                print("Search pattern: " .. searchPattern .. ", current item: " .. k .. ", begin index: " .. thisBegin .. ", end index: " .. thisEnd);
                if thisBegin == 1 then
                    return k;
                end
    
                if result == nil or ((thisBegin < potentialMatchBegin) or (thisBegin == potentialMatchBegin and thisEnd < potentialMatchEnd)) then
                    result = k;
                    potentialMatchBegin = thisBegin;
                    potentialMatchEnd = thisEnd;
                end;
            end
        end
    end

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
        displayName = findBestMatch(searchPattern);

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
    print("Got player", player);
    local playerNum = player:getPlayerNum();
    local inventory = getPlayerInventory(playerNum);
    local loot = getPlayerLoot(playerNum);

    local containerList = {};
    local foundItem = false;
    for i,v in ipairs(inventory.inventoryPane.inventoryPage.backpacks) do
        if foundItem then
            break;
        end

        print("inserting container from player inventory: ", v.inventory);
        local localInventory = v.inventory;
        -- this is a Java list, you can't use Lua's ipairs or other methods to manipulate it
        local it = localInventory:getItems();
        for x = 0, it:size()-1 do
            local item = it:get(x);
            local currentDisplayName = item:getDisplayName();
            print("Found thing in inventory container: " .. currentDisplayName);

            if displayName == currentDisplayName then
                foundItem = true;
                local char = getSpecificPlayer(playerNum);
                local fullType = item:getFullType();
                -- Ask the InventoryContainer for the count, not including items that can be drained, recursing through inventory container items
                local count = localInventory:getNumberOfItem(fullType, false, true);
                print("Count of item from getNumberOfItems(fullType: " .. fullType .. ", false, true): " .. count);
                local message = "";

                if count == 1 then
                    message = "I have a " .. displayName .. " in my inventory";
                else
                    -- TODO refactor to pluralize function
                    if endsWith(displayName, "s") then
                        message = "I have " .. count .. " " .. displayName .. " in my inventory";
                    else
                        message = "I have " .. count .. " " .. displayName .. "s in my inventory";
                    end
                end
                char:Say(message);
                break;
            end
        end
        table.insert(containerList, localInventory);
    end

    for i,v in ipairs(loot.inventoryPane.inventoryPage.backpacks) do
        print("inserting container from loot: ", v.inventory)
        local it = v.inventory:getItems();
        for x = 0, it:size()-1 do
            local item = it:get(x);
            print("Found thing in loot container: ", item);
        end
        table.insert(containerList, v.inventory);
    end
    print(containerList);
    -- Queue search actions!
end

function cacheItems()
    print("Startup, getting cache of items available for searching");
    local allItems = getAllItems();

    local function addTo(set, key)
        set[key] = true;
    end

    local function setContains(set, key)
        return set[key] ~= nil;
    end

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

        if not setContains(ITEMSEARCH_PERSISTENT_DATA.displayNameSet) then
            addTo(ITEMSEARCH_PERSISTENT_DATA.displayNameSet, displayName);
            ITEMSEARCH_PERSISTENT_DATA.itemsByDisplayName[displayName] = { item };
        else
            table.insert(ITEMSEARCH_PERSISTENT_DATA.itemsByDisplayName[displayName], item)
            print("We now have more than one item by the display name of " .. displayName);
            for i, v in ipairs(ITEMSEARCH_PERSISTENT_DATA.itemsByDisplayName[displayName]) do
                print(displayName .. "[" .. i .. "]" .. " Module: " .. v:getModuleName());
            end
        end
    end
    print("Done starting up, should have cached display item info for " .. javaItemsSize .. " items provided by getAllItems()");
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