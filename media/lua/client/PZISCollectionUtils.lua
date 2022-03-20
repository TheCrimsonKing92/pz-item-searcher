local collectionUtils = {};

collectionUtils.set = {};

collectionUtils.set.add = function(set, key)
    set[key] = true;
end

collectionUtils.set.contains = function(set, key)
    return set[key] ~= nil;
end

return collectionUtils;

