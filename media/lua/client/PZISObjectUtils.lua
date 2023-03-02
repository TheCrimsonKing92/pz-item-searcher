local PZISObjectUtils = {};

function PZISObjectUtils:getContainerName(container)
    return self:getContainerNameByType(container:getType());
end

function PZISObjectUtils:getContainerNameByType(containerType)
    return string.lower(getTextOrNull("IGUI_ContainerTitle_" .. containerType) or "");
end

return PZISObjectUtils;