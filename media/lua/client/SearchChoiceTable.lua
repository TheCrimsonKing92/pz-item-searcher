require "ISUI/ISPanel"

SearchChoiceTable = ISPanel:derive("SearchChoiceTable");

local textManager = getTextManager();

local SMALL_FONT = textManager:getFontHeight(UIFont.Small);
local MEDIUM_FONT = textManager:getFontHeight(UIFont.Medium);
local LARGE_FONT = textManager:getFontHeight(UIFont.Large);

local HEADER_HEIGHT = MEDIUM_FONT + 2 * 2;

local defaultSort = function(a, b)
    return not string.sort(a.item:getDisplayName(), b.item:getDisplayName());
end

local print = function(...)
    print("[ItemSearcher (SearchChoiceTable)] - ", ...);
end

function SearchChoiceTable:chooseItem(item)
    self.itemChosenCallback(item);
end

function SearchChoiceTable:chooseSelected(button, x, y)
    local selectedIndex = button.parent.itemChoices.selected;
    local item = button.parent.itemChoices.items[selected].item;
    self.itemChosenCallback(item);
end

function SearchChoiceTable:clear()
    self.itemChoices:clear();
end

function SearchChoiceTable:createChildren()
    ISPanel.createChildren(self);

    -- Stuff derived from ISItemListTable tbh
    local buttonHeight = math.max(25, SMALL_FONT + 3 * 2);
    local entryHeight = MEDIUM_FONT + 2 * 2;
    local bottomHeight = 5 + SMALL_FONT * 2 + 5 + buttonHeight + 20 + LARGE_FONT + HEADER_HEIGHT + entryHeight;

    self.itemChoices = ISScrollingListBox:new(0, HEADER_HEIGHT, self.width, self.height);
    self.itemChoices:initialise();
    self.itemChoices:instantiate();
    self.itemChoices.itemheight = SMALL_FONT + 4 * 2;
    self.itemChoices.selected = 1;
    self.itemChoices.joypadParent = self;
    self.itemChoices.font = UIFont.NewSmall;
    self.itemChoices.doDrawItem = self.drawItemChoice;
    self.itemChoices.drawBorder = true;
    self.itemChoices:addColumn("Type", 0);
    self.itemChoices:addColumn("Name", 200);
    self.itemChoices:addColumn("Category", 450);
    self.itemChoices:addColumn("DisplayCategory", 650);
    self.itemChoices:setOnMouseDoubleClick(self, SearchChoiceTable.chooseItem);
    self:addChild(self.itemChoices);

    self.chooseItem = ISButton:new(0, self.itemChoices.y + self.itemChoices.height + 5 + SMALL_FONT * 2 + 5, 100, buttonHeight, "Choose", self, SearchChoiceTable.chooseSelected);
end

function SearchChoiceTable:drawItemChoice(y, item, alt)
    local yScroll = self:getYScroll();
    local yTotal = y + yScroll;

    local itemheight = self.itemheight;

    if yTotal + itemheight < 0 or yTotal >= self.height then
        return y + itemheight;
    end

    local a = 0.9;

    local width = self:getWidth();

    if self.selected == item.index then
        self:drawRect(0, y, width, itemheight, 0.3, 0.7, 0.35, 0.15);
    end

    if alt then
        self:drawRect(0, y, width, itemheight, 0.3, 0.6, 0.5, 0.5);
    end

    self:drawRectBorder(0, y, width, itemheight, a, self.borderColor.r, self.borderColor.g, self.borderColor.b);

    local iconX = 4;
    local iconSize = SMALL_FONT;
    local xOffset = 10;

    local clipX = self.columns[1].size;
    local clipX2 = self.columns[2].size;
    local clipY = math.max(0, yTotal);
    local clipY2 = math.min(self.height, yTotal + itemheight);

    self:setStencilRect(clipX, clipY, clipX2 - clipX, clipY2 - clipY);
    self:drawText(item.item:getName(), xOffset, y + 4, 1, 1, 1, a, self.font);
    self:clearStencilRect();

    clipX = self.columns[2].size
    clipX2 = self.columns[3].size
    self:setStencilRect(clipX, clipY, clipX2 - clipX, clipY2 - clipY)
    self:drawText(item.item:getDisplayName(), self.columns[2].size + iconX + iconSize + 4, y + 4, 1, 1, 1, a, self.font);
    self:clearStencilRect()

    clipX = self.columns[3].size
    clipX2 = self.columns[4].size
    self:setStencilRect(clipX, clipY, clipX2 - clipX, clipY2 - clipY)
    self:drawText(item.item:getTypeString(), self.columns[3].size + xOffset, y + 4, 1, 1, 1, a, self.font);
    self:clearStencilRect();

    local displayCategory = item.item:getDisplayCategory();

    if displayCategory ~= nil then
        local text = getText("IGUI_ItemCat_" .. displayCategory);
        self:drawText(text, self.columns[4].size + xOffset, y + 4, 1, 1, 1, a, self.font);
    else
        self:drawText("Error: No category set", self.columns[4].size + xOffset, y + 4, 1, 1, 1, a, self.font);
    end


    self:repaintStencilRect(0, clipY, self.width, clipY2 - clipY)

    local icon = item.item:getIcon()
    if item.item:getIconsForTexture() and not item.item:getIconsForTexture():isEmpty() then
        icon = item.item:getIconsForTexture():get(0)
    end
    if icon then
        local texture = getTexture("Item_" .. icon)
        if texture then
            self:drawTextureScaledAspect2(texture, self.columns[2].size + iconX, y + (itemheight - iconSize) / 2, iconSize, iconSize,  1, 1, 1, 1);
        end
    end
    
    return y + self.itemheight;
end

function SearchChoiceTable:initList(items)
    self.itemChoices:clear();

    for x, v in ipairs(items) do
        -- There's a lot we could add here to mimic ISItemsListTable if we want to add categorization, filtering, etc.
        self.itemChoices:addItem(v:getDisplayName(), v);
    end

    table.sort(self.itemChoices.items, defaultSort);
end

function SearchChoiceTable:render()
    ISPanel.render(self);
end

function SearchChoiceTable:new(x, y, width, height, itemChosenCallback)
    local o = ISPanel:new(x, y, width, height);
    setmetatable(o, self);
    self.__index = self;
    o.listHeaderColor = {r=0.4, g=0.4, b=0.4, a=0.3};
    o.borderColor = {r=0.4, g=0.4, b=0.4, a=0};
    o.backgroundColor = {r=0, g=0, b=0, a=1};
    o.buttonBorderColor = {r=0.7, g=0.7, b=0.7, a=0.5};
    o.itemChosenCallback = itemChosenCallback;
    return o;
end