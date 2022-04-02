require "TimedActions/ISBaseTimedAction"

local collectionUtil = require("PZISCollectionUtils");
local Set = collectionUtil.Set;
local stringUtil = require("PZISStringUtils");

SearchRoomContainerAction = ISBaseTimedAction:derive("SearchRoomContainerAction");

-- The PutItemInBag FMOD event duration is 10 seconds long, which stops it playing too frequently.
SearchRoomContainerAction.searchSoundDelay = 9.5;
SearchRoomContainerAction.searchSoundTime = 0;

local print = function(...)
    print("[ItemSearcher (SearchRoomContainerAction)] - ", ...);
end

SearchRoomContainerAction.getDistanceBetween = function(x1, y1, x2, y2)
    local dx = x1 - x2;
    local dy = y1 - y2;

    return math.sqrt(math.pow(dx, 2) + math.pow(dy, 2));
end

SearchRoomContainerAction.getDistanceFromCharacterPoint = function(key, playerX, playerY)
    local parts = stringUtil:split(key, ':');
    local pointX = tonumber(parts[1]);
    local pointY = tonumber(parts[2]);

    return SearchRoomContainerAction.getDistanceBetween(playerX, playerY, pointX, pointY);
end

SearchRoomContainerAction.findRoomContainers = function(room, playerX, playerY)
    print("Scanning room def and caching container info");
    local squares = room:getSquares();
    local roomDef = room:getRoomDef();

    local squareCount = squares:size();

    local consumedCells = Set:new();
    local containerCells = Set:new();
    local containerMap = {};

    local containerCount = 0;

    for i = 0, squareCount - 1 do
        local square = squares:get(i);
        local x = square:getX();
        local y = square:getY();
        local key = x .. ':' .. y;

        local objects = square:getObjects();
        local containersHere = {};

        for objInd = 0, objects:size() - 1 do
            local object = objects:get(objInd);
            local objectContainer = object:getContainer();

            if objectContainer ~= nil then
                table.insert(containersHere, objectContainer);
            end            
        end

        if #containersHere > 0 then
            containerCount = containerCount + #containersHere;
            containerMap[key] = containersHere;
            containerCells:add(key);
        end
    end

    print("Found: " .. containerCount .. " containers in the room");
    print("Number of container cells: " .. containerCells:size());

    local sortedContainers = SearchRoomContainerAction.sortContainersFromCharacterPoint(containerCells, consumedCells, playerX, playerY);

    return consumedCells, containerCells, containerMap, sortedContainers;
end

SearchRoomContainerAction.sortContainersFromCharacterPoint = function(containerCells, consumedCells, playerX, playerY)
    print("Sorting containers from character point");
    local sortedContainers = {};

    for key, _ in pairs(containerCells) do
        if not consumedCells:contains(key) then
            table.insert(sortedContainers, key);
        end
    end

    table.sort(sortedContainers, function(a, b)
        local aDist = SearchRoomContainerAction.getDistanceFromCharacterPoint(a, playerX, playerY);
        local bDist = SearchRoomContainerAction.getDistanceFromCharacterPoint(b, playerX, playerY);
        return aDist < bDist;
    end);

    return sortedContainers;
end

function SearchRoomContainerAction:getCharacterDistanceFrom(key)
    local parts = stringUtil:split(key, ':');
    local pointX = tonumber(parts[1]);
    local pointY = tonumber(parts[2]);

    local square = self.character:getSquare();
    local squareX = square:getX();
    local squareY = square:getY();

    return self:getDistanceBetween(squareX, squareY, pointX, pointY);
end

function SearchRoomContainerAction:isValid()
    return true;
end

function SearchRoomContainerAction:perform()
    -- displayName, name, fullType
    local searchTarget = self.searchTarget;
    local displayNameSearch = searchTarget.displayName;
    local nameSearch = searchTarget.name;
    local fullTypeSearch = searchTarget.fullType;

    local consumedCells = self.consumedCells;
    local containerCell = self.containerCell;
    local containerCells = self.containerCells;
    local containerMap = self.containerMap;

    print("Looking for search target with display name: " .. displayNameSearch .. ", name: " .. nameSearch .. ", and full type: " .. fullTypeSearch .. ", at target: " .. containerCell);

    local containers = containerMap[containerCell];

    local itemsSearched = 0;
    for _, container in ipairs(containers) do
        self:say("Please be patient, searching in container type: " .. container:getType());

        local items = container:getItems();
        local itemsCount = items:size();

        if itemsCount > 0 then
            for x = 0, itemsCount - 1 do
                local item = items:get(x);

                local displayName = item:getDisplayName();
                local name = item:getName();
                local fullType = item:getFullType();

                itemsSearched = itemsSearched + 1;

                if self.maxTime > 3 then
                    self:setCurrentTime(itemsSearched);
                else
                    -- TODO track job delta for edge cases of item count
                end
                

                if displayNameSearch == displayName and (nameSearch == name or fullTypeSearch == fullType) then
                    -- Ask the InventoryContainer for the count, not including items that can be drained, recursing through inventory container items
                    local count = container:getNumberOfItem(fullType, false, true);
                    self:say("I found it!");
                    consumedCells:add(containerCell)
                    self:forceComplete();
                    ISBaseTimedAction.perform(self);
                    return;
                end
            end
        else
            self:say("There's nothing in this " .. container:getType());
        end
    end

    consumedCells:add(containerCell);

    if consumedCells:size() < containerCells:size() then
        self:queueNext();
        print("Queued next room container search");
    else
        print("No more cells with containers to search");
        self:forceStop();
    end
    
    ISBaseTimedAction.perform(self);
end

function SearchRoomContainerAction:queueNext()
    local sorted = self:sortContainers();

    if #sorted == 0 then
        return false;
    end

    local next = table.remove(sorted, 1);

    local parts = stringUtil:split(next, ":");
    local targetX = tonumber(parts[1]);
    local targetY = tonumber(parts[2]);

    local theZ = self.character:getCurrentSquare():getZ();
    local target = getSquare(targetX, targetY, theZ);

    -- Queues the walk to the adjacent square, allow it to clear other actions
    luautils.walkAdj(self.character, target);
    -- Queues the search
    ISTimedActionQueue.add(SearchRoomContainerAction:new(self.character, self.searchTarget, next, self.containerCells, self.containerMap, self.consumedCells));
end

function SearchRoomContainerAction:say(message)
    self.character:Say(message);
end

function SearchRoomContainerAction:sortContainers()
    local square = self.character:getSquare();
    local playerX = square:getX();
    local playerY = square:getY();

    return SearchRoomContainerAction.sortContainersFromCharacterPoint(self.containerCells, self.consumedCells, playerX, playerY);
end

function SearchRoomContainerAction:start()
    if not SearchRoomContainerAction.searchSound or not self.character:getEmitter():isPlaying(SearchRoomContainerAction.searchSound) then
        if SearchRoomContainerAction.searchSoundTime + SearchRoomContainerAction.searchSoundDelay < getTimestamp() then
            SearchRoomContainerAction.searchSoundTime = getTimestamp();
            SearchRoomContainerAction.searchSound = self.character:getEmitter():playSound("PutItemInBag");
        end
    end

    self:setActionAnim("TransferItemOnSelf");
end

function SearchRoomContainerAction:update()
    print("SearchRoomContainerAction:update");

    if self.character:pressedMovement(false) or self.character:pressedCancelAction() then
        self:forceStop();
        return;
    end
end

function SearchRoomContainerAction:waitToStart()
    print("Wait to start, face x: " .. self.containerX .. ", y: " .. self.containerY);
    self.character:faceLocation(self.containerX, self.containerY);
    return self.character:shouldBeTurning();
end

function SearchRoomContainerAction:new(character, searchTarget, containerCell, containerCells, containerMap, consumedCells)
    local o = ISBaseTimedAction.new(self, character);

    o.character = character;
    local currentSquare = o.character:getCurrentSquare();
    -- set of used x:y keys
    o.consumedCells = consumedCells;
    -- x:y key
    o.containerCell = containerCell;
    local parts = stringUtil:split(o.containerCell, ':');
    o.containerX = tonumber(parts[1]);
    o.containerY = tonumber(parts[2]);
    o.containerZ = currentSquare:getZ();
    print("Getting actual square reference for container target");
    o.containerSquare = getSquare(o.containerX, o.containerY, o.containerZ);
    -- set of x:y keys
    o.containerCells = containerCells;
    -- map of x:y key to table of containers
    o.containerMap = containerMap;
    o.forceProgressBar = true;
    -- displayName, name, fullName
    o.searchTarget = searchTarget;

    local itemCount = 0;

    local containersToSearch = containerMap[containerCell];

    for i, container in ipairs(containersToSearch) do
        local containerItems = container:getItems();
        local itemsCount = containerItems:size();

        if itemsCount > 0 then
            itemCount = itemCount + itemsCount;
        end
    end

    if itemCount == 0 then
        print("No items found, setting a minimum value for max time");
        o.maxTime = 3;
    elseif itemCount > 0 then
        o.maxTime = itemCount * 4 + 3;
        print("Max time set to " .. o.maxTime .. " based on item count");
    elseif o.character:isTimedActionInstant() then
        print("Character has instant timed actions, maxTime == 1");
        o.maxTime = 1;
    end

    return o;
end