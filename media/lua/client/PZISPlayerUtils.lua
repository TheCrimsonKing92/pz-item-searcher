local PZISPlayerUtils = {};

PZISPlayerUtils.walkToContainer = function(container, playerNum)
    if container:getType() == "floor" then
        return true
    end

    local playerObj = getSpecificPlayer(playerNum);

    if container:getParent() and container:getParent():getSquare():DistToProper(playerObj:getCurrentSquare()) < 2 then
        return true;
    end

    if container:isInCharacterInventory(playerObj) then
        return true
    end
    
    local isoObject = container:getParent();

    if not isoObject or not isoObject:getSquare() then
        return true
    end

    if instanceof(isoObject, "BaseVehicle") then
        if playerObj:getVehicle() == isoObject then
            return true
        end

        if playerObj:getVehicle() then
            error "luautils.walkToContainer()"
        end

        local part = container:getVehiclePart();

        if part and part:getArea() then
            if part:getVehicle():canAccessContainer(part:getIndex(), playerObj) then
                return true;
            end

            if part:getDoor() and part:getInventoryItem() then
                -- TODO: open the door if needed
            end

            ISTimedActionQueue.add(ISPathFindAction:pathToVehicleArea(playerObj, part:getVehicle(), part:getArea()))
            return true
        end

        error "luautils.walkToContainer()";
    end

    if instanceof(isoObject, "IsoDeadBody") then
        return true
    end

    local adjacent = AdjacentFreeTileFinder.Find(isoObject:getSquare(), playerObj);

    if not adjacent then
        return false;
    end

    if adjacent == playerObj:getCurrentSquare() then
        return true;
    end

    ISTimedActionQueue.add(ISWalkToTimedAction:new(playerObj, adjacent));
    return true;
end