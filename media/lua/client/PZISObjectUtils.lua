local PZISObjectUtils = {};

function PZISObjectUtils:generateTransferAction(character, item, srcInventory, destInventory)
    local transferItemAction = ISInventoryTransferAction:new(character, item, srcInventory, destInventory);
    transferItemAction.hasDoneActionAnim = false;
    local oldDoActionAnim = transferItemAction.doActionAnim;
    transferItemAction.doActionAnim = function(self, cont)
        if not self.hasDoneActionAnim then
            oldDoActionAnim(self, cont);
            self.hasDoneActionAnim = true;
        else
            print("[ItemSearcher (PZISObjectUtils)]: This transfer action from ItemSearcher has had doActionAnim already called previously: avoiding invoking it again (item transactions will become inconsistent on the server)");
        end
    end

    return transferItemAction;
end

function PZISObjectUtils:getContainerName(container)
    return self:getContainerNameByType(container:getType());
end

function PZISObjectUtils:getContainerNameByType(containerType)
    return string.lower(getTextOrNull("IGUI_ContainerTitle_" .. containerType) or "");
end

return PZISObjectUtils;