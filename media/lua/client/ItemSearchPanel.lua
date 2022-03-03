require "ISUI/ISCollapsableWindow"
require "ISUI/ISPanel"
local SMALL_FONT = getTextManager():getFontHeight(UIFont.Small)

ITEMSEARCH_PERSISTENT_DATA = {};

local ui = null;
local uiOpen = false;

ItemSearchPanel = ISCollapsableWindow:derive("ItemSearchPanel");

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
    local function setContains(set, key)
        return set[key] ~= nil;
    end

    local searchText = self.itemEntry:getInternalText();
    print("Internal search value is: " .. searchText);
    if setContains(ITEMSEARCH_PERSISTENT_DATA.displayNameSet, searchText) then
        local matches = ITEMSEARCH_PERSISTENT_DATA.itemsByDisplayName[searchText];
        print("Exact match from persistent data on display name: ", ITEMSEARCH_PERSISTENT_DATA.itemsByDisplayName[searchText]);
        for i, match in ipairs(matches) do
            print(match:getDisplayName() .. ": " .. tostring(match:getType()) .. " - " .. match:getModuleName() .. "." .. match:getName());
        end
    else
        print("No exact match found :( try a fuzzy match/contains shenanigans");
    end

    local player = getPlayer();
    print("Got player", player);
    local playerNum = player:getPlayerNum();
    local inventory = getPlayerInventory(playerNum);
    local loot = getPlayerLoot(playerNum);

    local containerList = {};
    for i,v in ipairs(inventory.inventoryPane.inventoryPage.backpacks) do
        print("inserting container from player inventory: ", v.inventory);
        -- this is a Java list, you can't use Lua's ipairs or other methods to manipulate it
        local it = v.inventory:getItems();
        for x = 0, it:size()-1 do
            local item = it:get(x);
            local displayName = item:getDisplayName();
            print("Found thing in inventory container: ", item:getDisplayName());

            if searchText == displayName then
                print("FOUND IT BY DISPLAY NAME!");
                local char = getSpecificPlayer(playerNum);
                local message = "I have a " .. displayName .. " in my inventory";
                char:Say(message);
            end

            local cat = item:getCategory();
            local type = tostring(item:getType());
            print("item category: " .. cat .. ", item type: " .. type);
        end
        table.insert(containerList, v.inventory);
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

    for x = 0, allItems:size() -1 do
        print("Found item in allItems arraylist");
        local item = allItems:get(x);

        local module = item:getModuleName();

        local name = item:getName();

        local type = item:getType();

        local displayName = item:getDisplayName();

        print("Display name: " .. item:getDisplayName());
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
    print("Should have cached display item info for " .. allItems:size() .. " items provided by getAllItems()");
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