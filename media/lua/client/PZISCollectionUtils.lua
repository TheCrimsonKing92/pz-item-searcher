local collectionUtils = {};

local Set = {};

function Set:add(key)
    self[key] = true;
end

function Set:contains(key)
    return self[key] ~= nil;
end

function Set:merge(otherSet)
    for k, _ in pairs(otherSet) do
        self:add(k);
    end
end

function Set:new(list)
    list = list or {};
    
    local set = {};
    setmetatable(set, self);
    self.__index = self;

    for _, v in ipairs(list) do
        set[v] = true;
    end

    return set;
end

collectionUtils.Set = Set;

return collectionUtils;

