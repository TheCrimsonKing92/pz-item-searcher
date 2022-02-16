require "ISUI/ISPanel"
local SMALL_FONT = getTextManager():getFontHeight(UIFont.Small)

ITEMSEARCH_PERSISTENT_DATA = {};

ItemSearchPanel = ISPanel:derive("ItemSearchPanel");

function ItemSearchPanel:initialise()
    ISPanel.initialise(self);
    self:create();
end

function ItemSearchPanel:prerender()
    ISPanel.prerender(self);
    -- Draw basic text, etc.
end

function ItemSearchPanel:render()    
end

function ItemSearchPanel:create()
    local function makeButton(x, y, width, height, title)
        local id = string.upper(title);
        local button = ISButton:new(x, y, width, height, title, self, ItemSearchPanel.onOptionMouseDown);

        button.id = id;
        button.initialise();
        button.instantiate();
        button.borderColor = self.buttonBorderColor;

        self.addChild(button);

        return button;
    end
    -- Add entry box for item input
    local buttonHeight = SMALL_FONT + 2 * 4;
    local buttonWidth = 75;
    local padBottom = 10;

    local itemEntry = ISTextEntryBox:new("Search for what item?", 25, 40, 150, buttonHeight);
    itemEntry:initialise();
    itemEntry:instantiate();
    self.addChild(self.itemEntry);

    self.close = makeButton(self:getWidth() - buttonWidth - 5, self:getHeight() - padBottom - buttonHeight, buttonWidth, buttonHeight, "Close");
    self.search = makeButton(5, self:getHeight() - padBottom - buttonHeight, buttonWidth, buttonHeight, "Search");
end

function ItemSearchPanel:new()
    local o = {};
    local x = getMouseX() + 10;
    local y = getMouseY() + 10;

    o = ISPanel:new(x, y, 100, 200);
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
    if button.id == "CLOSE" then
        self:setVisible(false);
        self.removeFromUIManager();
    end

    if button.id == "SEARCH" then
        -- Queue search actions!
    end
end

function onCustomUIKeyPressed(key)
    if key == 0 then
        local panel = ItemSearchPanel:new();
        panel.initialize();
        panel.addToUIManager();
    end
end

Events.OnCustomUIKeyPressed.Add(onCustomUIKeyPressed);