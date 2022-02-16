--***********************************************************
--**                    TheCrimsonKing92                   **
--***********************************************************

require "TimedActions/ISBaseTimedAction"

ItemSearchAction = ISBaseTimedAction:derive("ItemSearchAction");

function ItemSearchAction:isValid()
end

function ItemSearchAction:perform()
    -- find the item indicated by search among the various nearby containers/floor
end

function ItemSearchAction:new(player, search)
    local character = getSpecificPlayer(player);
    local o = ISBaseTimedAction.new(self, character);
    o.search = search;
    o.stopOnWalk = true;
    o.stopOnRun = true;
    return o;
end