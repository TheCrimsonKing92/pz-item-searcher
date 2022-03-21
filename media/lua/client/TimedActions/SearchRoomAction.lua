require "TimedActions/ISBaseTimedAction"

SearchRoomAction = ISBaseTimedAction:derive("SearchRoomAction");

SEARCH_ROOM_ACTION_PERSISTENT_DATA = {};
SEARCH_ROOM_ACTION_PERSISTENT_DATA.containers = nil;

local print = function(...)
    print("[ItemSearcher (SearchRoomAction)] - ", ...);
end

function SearchRoomAction:cacheRoomContainers()
    print("Caching room containers prior to search");
    local squares = self.room:getSquares();
    local roomDef = self.room:getRoomDef();

    print("Room definition: ");
    local defX = roomDef:getX();
    local defY = roomDef:getY();
    local defX2 = roomDef:getX2();
    local defY2 = roomDef:getY2();
    local defH = roomDef:getH();
    local defW = roomDef:getW();
    print("X: " .. defX .. ", X2: " .. defX2 .. ", Y: " .. defY .. ", Y2: " .. defY2 .. ", H: " .. defH .. ", W: " .. defW);

    local squareCount = squares:size();

    local containerCount = 0;
    local containerCountByX = {};
    local containersByX = {};

    for i = 0, squareCount - 1 do
        local containerList = {};
        local square = squares:get(i);

        local x = square:getX();

        if containersByX[x] == nil then
            containersByX[x] = {};
            containerCountByX[x] = {};
        end

        local y = square:getY();

        if containerCountByX[x][y] == nil then
            containerCountByX[x][y] = 0;
        end

        local thisSquareCount = containerCountByX[x][y];

        local objects = square:getObjects();

        for objInd = 0, objects:size() - 1 do
            local object = objects:get(objInd);
            local objectContainer = object:getContainer();

            if objectContainer ~= nil then
                containerCount = containerCount + 1;
                thisSquareCount = thisSquareCount + 1;
                table.insert(containerList, objectContainer);
            end            
        end

        containersByX[x][y] = containerList;
        containerCountByX[x][y] = thisSquareCount;
    end

    SEARCH_ROOM_ACTION_PERSISTENT_DATA.containers = containersByX;

    print("Found : " .. containerCount .. " containers in the room");

    for x, cells in pairs(containersByX) do
        for y, containers in pairs(cells) do
            if #containers > 0 then
                print("At x: " .. x .. ", y: " .. y .. ", we found " .. #containers .. " containers");
                print("Container types: ");
                for _, container in ipairs(containers) do
                    print(container:getType());
                end
            end
        end
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