require "ISUI/ISPanel"

SearchChoiceTable = ISPanel:derive("SearchChoiceTable");

local textManager = getTextManager();

local SMALL_FONT = textManager:getFontHeight(UIFont.Small);
local MEDIUM_FONT = textManager:getFontHeight(UIFont.Medium);
local LARGE_FONT = textManager:getFontHeight(UIFont.Large);

local HEADER_HEIGHT = MEDIUM_FONT + 2 * 2;

function SearchChoiceTable:chooseItem(item)
    -- Pass back/confirm to parent
    print("Chose item : " .. tostring(item));
end

function SearchChoiceTable:chooseSelected(button, x, y)
    -- Grab the one selected in itemChoices and pass back
    local selectedIndex = button.parent.itemChoices.selected;
    print("Selected index: " .. selectedIndex);
end

function SearchChoiceTable:createChildren()
    ISPanel.createChildren(self);

    -- Stuff derived from ISItemListTable tbh
    local buttonHeight = math.max(25, SMALL_FONT + 3 * 2);
    local entryHeight = MEDIUM_FONT + 2 * 2;
    local bottomHeight = 5 + SMALL_FONT * 2 + 5 + buttonHeight + 20 + LARGE_FONT + HEADER_HEIGHT + entryHeight;

    self.itemChoices = ISScrollingListBox:new(0, HEADER_HEIGHT, self.width, self.height - bottomHeight - HEADER_HEIGHT);
    self.itemChoices:initialise();
    self.itemChoices:instantiate();
    self.itemChoices.itemheight = SMALL_FONT + 4 * 2;
    self.itemChoices.selected = 0;
    self.itemChoices.joypadParent = self;
    self.itemChoices.font = UIFont.NewSmall;
    -- self.itemChoices.doDrawItem = self.drawItemChoice;
    self.itemChoices.drawBorder = true;
    self.itemChoices:addColumn("Type", 0);
    self.itemChoices:addColumn("Name", 200);
    self.itemChoices:addColumn("Category", 450);
    self.itemChoices:addColumn("DisplayCategory", 650);
    self.itemChoices:setOnMouseDoubleClick(self, SearchChoiceTable.chooseItem);
    self:addChild(self.itemChoices);

    self.chooseItem = ISButton:new(0, self.itemChoices.y + self.itemChoices.height + 5 + SMALL_FONT * 2 + 5, 100, buttonHeight, "Choose", self, SearchChoiceTable.chooseSelected);
end

function SearchChoiceTable:initList(items)
    print("Got " .. #items .. " items for the list");
    self.itemChoices:clear();
    print("Clear existing list content");
end

function SearchChoiceTable:render()
    ISPanel.render(self);


end

function SearchChoiceTable:new(x, y, width, height, playerNum)
    local o = ISPanel:new(x, y, width, height);
    setmetatable(o, self);
    self.__index = self;
    o.listHeaderColor = {r=0.4, g=0.4, b=0.4, a=0.3};
    o.borderColor = {r=0.4, g=0.4, b=0.4, a=0};
    o.backgroundColor = {r=0, g=0, b=0, a=1};
    o.buttonBorderColor = {r=0.7, g=0.7, b=0.7, a=0.5};

    return o;
end