require "ISUI/ISPanel"
local SMALL_FONT = getTextManager():getFontHeight(UIFont.Small)

ITEMSEARCH_PERSISTENT_DATA = {};

local ui = null;
local uiOpen = false;

ItemSearchPanel = ISPanel:derive("ItemSearchPanel");

function ItemSearchPanel:initialise()
    ISPanel.initialise(self);
    self:create();
end

function ItemSearchPanel:prerender()
    ISPanel.prerender(self);
    -- Draw basic text, etc.
    -- text, x, y, r, g, b, a, font size
    self:drawText("Item Searcher", 90, 10, 1, 1, 1, 1, UIFont.Medium);
    self:drawText("Search for what item?", 10, 40, 1, 1, 1, 1, UIFont.Small);
end

function ItemSearchPanel:render()    
end

function ItemSearchPanel:create()
    -- Add entry box for item input
    local buttonHeight = SMALL_FONT + 2 * 4;
    local buttonWidth = 75;
    local padBottom = 10;

    local textSize = getTextManager():MeasureStringX(UIFont.Small, "Search for what item?");

    local id = "Input";    
    -- 10 is our left-margin, 5 to separate the box from the label, the rest from the text itself
    self.itemEntry = ISTextEntryBox:new("", 15 + textSize, 40, 150, buttonHeight);
    self.itemEntry.id = id;
    self.itemEntry:initialise();
    self.itemEntry:instantiate();
    self:addChild(self.itemEntry);

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

function ItemSearchPanel:new()
    local o = {};
    local x = getMouseX() + 10;
    local y = getMouseY() + 10;

    o = ISPanel:new(x, y, 300, 200);
    setmetatable(o, self);
    self.__index = self;

    o.backgroundColor = { r = 0, g = 0, b = 0, a = 1 };
    o.borderColor = { r = 0.4, g = 0.4, b = 0.4, a = 1 };
    o.buttonBorderColor = { r = 0.7, g = 0.7, b = 0.7, a = 0.5 };
    o.variableColor = { r = 0.9, g = 0.55, b = 0.1, a = 1 };
    o.zOffsetSmallFont = 25;
    o.moveWithMouse = false;

    return o;
end

function ItemSearchPanel:onOptionMouseDown(button, x, y)
    local function setContains(set, key)
        return set[key] ~= nil;
    end

    if button.id == "Close" then
        print("Need to close (due to mouse)");
        self:setVisible(false);
        self:removeFromUIManager();
        ui = null;
        uiOpen = false;
    end

    if button.id == "Search" then
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
    print("We executin' key handling yo");
    if key == 40 then
        print("It's the custom key dawg");
        if uiOpen then
            print("We closin' the UI my dude");
            ui:setVisible(false);
            ui:removeFromUIManager();
            ui = null;
            uiOpen = false;
        else
            print("We openin' the UI my dude");
            local panel = ItemSearchPanel:new();
            panel:initialise();
            panel:addToUIManager();
            ui = panel;
            uiOpen = true;
        end
    else
        print("We don't handle that key dawg");
    end
end

Events.OnGameBoot.Add(cacheItems);
Events.OnCustomUIKeyPressed.Add(onCustomUIKeyPressed);