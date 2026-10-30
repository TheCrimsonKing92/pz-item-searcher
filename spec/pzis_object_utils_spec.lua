local ObjectUtils = require("PZISObjectUtils")
local globals = require("spec.support.pz_globals")

describe("PZISObjectUtils", function()
    local previousGlobals

    before_each(function()
        previousGlobals = globals.install()
    end)

    after_each(function()
        globals.uninstall(previousGlobals)
    end)

    describe("getContainerNameByType", function()
        it("lower-cases a known translated title", function()
            globals.texts.IGUI_ContainerTitle_crate = "Wooden Crate"
            assert.are.equal("wooden crate", ObjectUtils:getContainerNameByType("crate"))
        end)

        it("returns an empty string for an unknown type", function()
            assert.are.equal("", ObjectUtils:getContainerNameByType("unknown"))
        end)
    end)

    describe("generateTransferAction", function()
        it("forwards construction arguments and runs the original animation only once", function()
            local character, item, source, destination = {}, {}, {}, {}
            local action = ObjectUtils:generateTransferAction(character, item, source, destination)
            assert.are.equal(character, action.character)
            assert.are.equal(item, action.item)
            assert.are.equal(source, action.srcInventory)
            assert.are.equal(destination, action.destInventory)
            assert.are.equal(action, globals.actions[1])
            assert.are.equal(0, action.originalDoActionAnimCalls)
            assert.is_false(action.hasDoneActionAnim)

            action:doActionAnim(source)
            assert.are.equal(1, action.originalDoActionAnimCalls)
            assert.are.equal(source, action.lastAnimationContainer)
            assert.is_true(action.hasDoneActionAnim)

            action:doActionAnim(destination)
            assert.are.equal(1, action.originalDoActionAnimCalls)
            assert.are.equal(source, action.lastAnimationContainer)
            assert.is_true(action.hasDoneActionAnim)
        end)

        it("keeps animation state separate for each generated action", function()
            local first = ObjectUtils:generateTransferAction({}, {}, {}, {})
            local second = ObjectUtils:generateTransferAction({}, {}, {}, {})
            assert.are_not.equal(first, second)
            first:doActionAnim({})
            assert.are.equal(1, first.originalDoActionAnimCalls)
            assert.are.equal(0, second.originalDoActionAnimCalls)
            assert.is_false(second.hasDoneActionAnim)
            second:doActionAnim({})
            assert.are.equal(1, first.originalDoActionAnimCalls)
            assert.are.equal(1, second.originalDoActionAnimCalls)
            assert.is_true(second.hasDoneActionAnim)
        end)
    end)
end)
