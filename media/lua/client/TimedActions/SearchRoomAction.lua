require "TimedActions/ISBaseTimedAction"

SearchRoomAction = ISBaseTimedAction:derive("SearchRoomAction");

SEARCH_ROOM_ACTION_PERSISTENT_DATA = {
    containers = nil,
    squares = nil
};

local print = function(...)
    print("[ItemSearcher (SearchRoomAction)] - ", ...);
end

function SearchRoomAction:cacheRoomContainers()
    print("Caching room containers prior to search");
    local squares = self.room:getSquares();

    local squareCount = squares:size();

    local containerList = {};

    for i = 0, squareCount - 1 do
        local square = squares:get(i);

        local x = square:getX();
        local y = square:getY();

        local objects = square:getObjects();

        for objInd = 0, objects:size() - 1 do
            local object = objects:get(objInd);
            local objectContainer = object:getContainer();

            if objectContainer ~= nil then
                table.insert(containerList, objectContainer);
            end            
        end
    end

    print("Found : " .. #containerList .. " containers in the room");
    for i, v in ipairs(containerList) do
        local container = v;
        local parent = container:getParent();
        local parentSquare = parent:getSquare();

        local type = container:getType();
        print("Found container of type " .. tostring(type) .. " at square, x: " .. parentSquare:getX() .. ", y: " .. parentSquare:getY());
    end
end

function SearchRoomAction:isValid()
    return true;
end

function SearchRoomAction:perform()
    ISBaseTimedAction.perform(self);
end

function SearchRoomAction:say(message)
    self.character:Say(message);
end

function SearchRoomAction:start()
    self:say("Let me check the room...");
end

function SearchRoomAction:new(playerNum, character, searchTarget)
    local o = ISBaseTimedAction.new(self, character);
    
    o.character = character;
    o.forceProgressBar = true;
    o.playerNum = playerNum;
    o.room = character:getSquare():getRoom();
    local roomSquares = o.room:getSquares():size();
    print("Found " .. tostring(roomSquares) .. " room squares");
    o.maxTime = roomSquares * 8;
    o.searchTarget = searchTarget;
    o.stopOnWalk = true;
    o.stopOnRun = true;

    o:cacheRoomContainers();
    return o;
end