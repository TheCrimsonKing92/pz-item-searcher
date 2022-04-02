require "TimedActions/ISBaseTimedAction"

local collectionUtil = require("PZISCollectionUtils");
local Set = collectionUtil.Set;
local stringUtil = require("PZISStringUtils");

SearchRoomAction = ISBaseTimedAction:derive("SearchRoomAction");

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

    local searchData = self.searchData;

    local containerCells = searchData.containerCells;
    local containerMap = searchData.containerMap;

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
    print("Number of container cells: " .. #containerCells);

    self:sortContainers();

    print("Now we should have the containers sorted closest-to-furthest with respect to the character");
    for i, v in ipairs(searchData.sortedContainers) do
        local parts = stringUtil:split(v, ':');
        local x = parts[1];
        local y = parts[2];
        local containersHere = containerMap[v];
        print("Found: " .. #containersHere .. " containers at cell x: " .. x .. ", y: " .. y);
        print("Container types: ");
        for _, container in ipairs(containersHere) do
            print(container:getType());
        end
    end
end

function SearchRoomAction:clearContainer()
    self.searchData.containerTarget = nil;
end

function SearchRoomAction:clearWalk()
    local searchData = self.searchData;

    searchData.walking = false;
    searchData.walkSucceeded = nil;
    searchData.walkTarget = nil;
end

function SearchRoomAction:forceStop()
    ISBaseTimedAction.perform(self);
end

function SearchRoomAction:getCharacterDistanceFrom(key)
    local parts = stringUtil:split(key, ':');
    local pointX = tonumber(parts[1]);
    local pointY = tonumber(parts[2]);

    local square = self.character:getSquare();
    local squareX = square:getX();
    local squareY = square:getY();

    return self:getDistanceBetween(squareX, squareY, pointX, pointY);
end

function SearchRoomAction:getDistanceBetween(x1, y1, x2, y2)
    local dx = x1 - x2;
    local dy = y1 - y2;

    return math.sqrt(math.pow(dx, 2) + math.pow(dy, 2));
end

function SearchRoomAction:hasRemainingTarget()
    local searchData = self.searchData;
    local consumedContainers = searchData.consumedContainers;
    local containerCells = searchData.containerCells;

    local consumed = consumedContainers:size();
    print("Number of consumed container cells: " .. consumed);
    local containers = containerCells:size();
    print("Number of container cells: " .. containers);

    return consumed < containers;
end

function SearchRoomAction:hasTarget()
    return self.searchData.containerTarget ~= nil;
end

function SearchRoomAction:isSearching()
    return self.searchData.isSearching;
end

function SearchRoomAction:isValid()
    return true;
end

function SearchRoomAction:isWalking()
    return self.searchData.walking;
end

function SearchRoomAction:perform()
    print("SearchRoomAction:perform");
end

function SearchRoomAction:say(message)
    self.character:Say(message);
end

function SearchRoomAction:setTarget()
    local searchData = self.searchData;
    local sortedContainers = searchData.sortedContainers;

    local next = table.remove(sortedContainers, 1);
    searchData.containerTarget = next;
end

function SearchRoomAction:simulateSearch()
    local searchData = self.searchData;
    local consumedContainers = searchData.consumedContainers;
    local containerTarget = searchData.containerTarget;
    local containerMap = searchData.containerMap;    
    
    -- displayName, name, fullType
    local searchTarget = self.searchTarget;
    local displayNameSearch = searchTarget.displayName;
    local nameSearch = searchTarget.name;
    local fullTypeSearch = searchTarget.fullType;

    print("Looking for search target with display name: " .. displayNameSearch .. ", name: " .. nameSearch .. ", and full type: " .. fullTypeSearch .. ", at target: " .. containerTarget);

    local containers = containerMap[containerTarget];

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

                if displayNameSearch == displayName and (nameSearch == name or fullTypeSearch == fullType) then
                    -- Ask the InventoryContainer for the count, not including items that can be drained, recursing through inventory container items
                    local count = container:getNumberOfItem(fullType, false, true);
                    self:say("I found it!");
                    consumedContainers:add(containerTarget)
                    return true;
                end
            end
        end
    end

    consumedContainers:add(containerTarget);
    return false;
end

function SearchRoomAction:sortContainers()
    local searchData = self.searchData;

    local newSortedContainers = {};

    local consumedContainers = searchData.consumedContainers;
    local containerMap = searchData.containerMap;
    local containerCells = searchData.containerCells;

    for key, _ in pairs(containerCells) do
        if not consumedContainers:contains(key) then
            local parts = stringUtil:split(key, ':');
            local x = parts[1];
            local y = parts[2];
    
            local containersHere = containerMap[key];
            print("Found: " .. #containersHere .. " containers at cell x: " .. x .. ", y: " .. y);
            print("Container types: ");
            for _, container in ipairs(containersHere) do
                print(container:getType());
            end
    
            table.insert(newSortedContainers, key);
        end
    end

    table.sort(newSortedContainers, function(a, b)
        return self:getCharacterDistanceFrom(a) < self:getCharacterDistanceFrom(b);
    end);

    self.searchData.sortedContainers = newSortedContainers;
end

function SearchRoomAction:start()
    self:say("Let me check the room...");
end

function SearchRoomAction:stopWalk(failed)
    print("Stopping walk");
    local searchData = self.searchData;

    searchData.walking = false;
    searchData.walkSucceeded = not failed;

    -- SuperSurvivor called self.player:StopAllActionQueue() but Iiiii'm not so sure about that
    self.character:StopAllActionQueue();
    self.character:getPathFindBehavior2():cancel();
    self.character:setPath2(nil);
end

function SearchRoomAction:update()    
    print("SearchRoomAction:update");

    if self.character:pressedMovement(false) or self.character:pressedCancelAction() then
        self:forceStop();
        return;
    end

    local walking = self:isWalking();

    if walking then
        print("We're walking");
        local walkResult = self.character:getPathFindBehavior2():update();

        if walkResult == BehaviorResult.Working then
            print("Walking appears to be working fine");
            return;
        end

        local failed = walkResult == BehaviorResult.Failed;
        self:stopWalk(failed);
        return;
    else
        print("We're not walking");
    end

    local hasTarget = self:hasTarget();
    local anyRemaining = self:hasRemainingTarget();

    if hasTarget then
        print("We have a target");
        if self:simulateSearch() then
            print("We found the item here, end the search");
            self:forceComplete();
            ISBaseTimedAction.perform(self);
            return;
        else
            print("We didn't find the item here, reset the target");
            self:clearContainer();
        end
    else
        print("We don't have a target");
        if anyRemaining then
            print("There are remaining targets, setting one");
            self:setTarget();
            if not self:walkToTarget() then
                print("We couldn't actually walk adjacent to the target");
                self:forceStop();
                ISBaseTimedAction.perform(self);
                return;
            else
                print("Appears we walked adjacent to the target");
                if self:simulateSearch() then
                    print("We found the item here, end the search");
                    self:forceComplete();
                    ISBaseTimedAction.perform(self);
                    return;
                end
            end
        else
            print("No remaining targets, force stop");
            self:forceStop();            
            -- Possibly redundant here
            ISBaseTimedAction.perform(self);
            return;
        end
    end  
end

function SearchRoomAction:walkToTarget()
    local searchData = self.searchData;
    print("Starting walk to container");
    self:clearWalk();
    print("Cleared old walk data");

    local target = searchData.containerTarget;
    local parts = stringUtil:split(target, ":");
    local targetX = tonumber(parts[1]);
    local targetY = tonumber(parts[2]);

    print("Got container square");

    local currentSquare = self.character:getCurrentSquare();
    local theZ = currentSquare:getZ();

    print("Trying to get actual square reference for target x: " .. targetX .. ", y: " .. targetY .. ", z: " .. theZ);
    local square = getSquare(targetX, targetY, theZ);
    print("Got the reference, calling lua walkAdj");

    local success = luautils.walkAdj(self.character, square, true);

    if success then
        self.character:faceLocation(targetX, targetY);
    end

    return success;
end

function SearchRoomAction:new(playerNum, character, searchTarget)
    local o = ISBaseTimedAction.new(self, character);
    
    o.character = character;
    o.forceProgressBar = false;
    o.playerNum = playerNum;
    o.room = character:getSquare():getRoom();
    local roomSquares = o.room:getSquares():size();
    print("Found " .. tostring(roomSquares) .. " room squares");
    o.maxTime = roomSquares * 8;
    o.searchTarget = searchTarget;
    o.stopOnWalk = true;
    o.stopOnRun = true;

    o.searchData = {};
    o.searchData.consumedContainers = Set:new();
    o.searchData.containerCells = Set:new();
    o.searchData.containerMap = {};
    o.searchData.containerTarget = nil;
    o.searchData.sortedContainers = {};
    o.searchData.searching = false;
    o.searchData.walking = false;
    o.searchData.walkSucceeded = nil;
    o.searchData.walkTarget = nil;

    o:cacheRoomContainers();
    return o;
end