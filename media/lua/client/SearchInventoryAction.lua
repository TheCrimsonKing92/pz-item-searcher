require "TimedActions/ISBaseTimedAction"

SearchInventoryAction = ISBaseTimedAction:derive("ItemSearchAction");

function SearchInventoryAction:new(playerNum)
    local character = getSpecificPlayer(playerNum);
    local o = ISBaseTimedAction.new(self, character);
    o.search = search;
    o.stopOnWalk = true;
    o.stopOnRun = true;
end