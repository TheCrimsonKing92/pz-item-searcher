require "ISUI/AdminPanel/ISItemsListTable"

SearchChoiceTable = ISItemsListTable:derive("SearchChoiceTable");

function SearchChoiceTable:clearList()
    self.datas:removeChildren();
end

function SearchChoiceTable:new(x, y, width, height, playerNum)
    local viewerFacsimile = {};
    viewerFacsimile.playerSelect.selected = playerNum + 1;

    local o = ISItemsListTable:new(x, y, width, height, viewerFacsimile);
    setmetatable(o, self);
end