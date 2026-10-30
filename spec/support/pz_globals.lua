local M = {}

function M.install()
    local previous = {
        getTextOrNull = { value = rawget(_G, "getTextOrNull") },
        ISInventoryTransferAction = { value = rawget(_G, "ISInventoryTransferAction") },
    }

    M.texts = {}
    M.actions = {}

    _G.getTextOrNull = function(key)
        return M.texts[key]
    end

    _G.ISInventoryTransferAction = {
        new = function(self, character, item, srcInventory, destInventory)
            local action = {
                character = character,
                item = item,
                srcInventory = srcInventory,
                destInventory = destInventory,
                originalDoActionAnimCalls = 0,
                doActionAnim = function(self, container)
                    self.originalDoActionAnimCalls = self.originalDoActionAnimCalls + 1
                    self.lastAnimationContainer = container
                end,
            }
            table.insert(M.actions, action)
            return action
        end,
    }

    return previous
end

function M.uninstall(previous)
    _G.getTextOrNull = previous.getTextOrNull.value
    _G.ISInventoryTransferAction = previous.ISInventoryTransferAction.value
end

return M
