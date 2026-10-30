local PlayerUtils = require("PZISPlayerUtils")
local globals = require("spec.support.pz_globals")

describe("PZISPlayerUtils", function()
    local previousGlobals

    before_each(function()
        previousGlobals = globals.install()
    end)

    after_each(function()
        globals.uninstall(previousGlobals)
    end)

    describe("getFailureBody", function()
        it("preserves the display name", function()
            assert.are.equal("Axe", PlayerUtils.getFailureBody("Axe"))
        end)

        it("preserves an empty display name", function()
            assert.are.equal("", PlayerUtils.getFailureBody(""))
        end)
    end)

    describe("getFailureMessage", function()
        it("combines a vowel name with a player-held inventory", function()
            assert.are.equal("I couldn't find an Axe in my backpack",
                PlayerUtils.getFailureMessage("backpack", "Axe"))
        end)

        it("combines a consonant name with a translated container title", function()
            globals.texts.IGUI_ContainerTitle_crate = "Wooden Crate"
            assert.are.equal("I couldn't find a Hammer in the wooden crate",
                PlayerUtils.getFailureMessage("crate", "Hammer"))
        end)
    end)

    describe("getFailurePrefix", function()
        it("uses an for a vowel name", function()
            assert.are.equal("I couldn't find an", PlayerUtils.getFailurePrefix("Axe"))
        end)

        it("uses a for a consonant name", function()
            assert.are.equal("I couldn't find a", PlayerUtils.getFailurePrefix("Hammer"))
        end)

        it("uses any for a name ending in s", function()
            assert.are.equal("I couldn't find any", PlayerUtils.getFailurePrefix("Nails"))
        end)
    end)

    describe("getFailureSuffix", function()
        it("identifies a player-held backpack", function()
            assert.are.equal("in my backpack", PlayerUtils.getFailureSuffix("backpack"))
        end)

        it("uses on for the floor", function()
            assert.are.equal("on the floor", PlayerUtils.getFailureSuffix("floor"))
        end)

        it("lower-cases a known container title", function()
            globals.texts.IGUI_ContainerTitle_crate = "Wooden Crate"
            assert.are.equal("in the wooden crate", PlayerUtils.getFailureSuffix("crate"))
        end)

        it("retains the trailing space for an unknown title", function()
            assert.are.equal("in the ", PlayerUtils.getFailureSuffix("shelf"))
        end)
    end)

    describe("getStartMessage", function()
        -- The current implementation passes the type string to table.concat.
        it("raises for a container type", function()
            assert.error_matches(function()
                PlayerUtils.getStartMessage("crate")
            end, "table expected")
        end)

        it("also raises for a player-held inventory type", function()
            assert.error_matches(function()
                PlayerUtils.getStartMessage("backpack")
            end, "table expected")
        end)
    end)

    describe("getStartPrefix", function()
        -- The current implementation has no return statement.
        it("returns nil without arguments", function()
            assert.is_nil(PlayerUtils.getStartPrefix())
        end)

        it("returns nil even when passed a container type", function()
            assert.is_nil(PlayerUtils.getStartPrefix("crate"))
        end)
    end)

    describe("getStartSuffix", function()
        it("identifies a player-held inventory when proximity is omitted", function()
            assert.are.equal("my backpack ...", PlayerUtils.getStartSuffix("backpack"))
        end)

        it("uses the raw container type when proximity is omitted", function()
            globals.texts.IGUI_ContainerTitle_crate = "Wooden Crate"
            assert.are.equal("this crate ...", PlayerUtils.getStartSuffix("crate"))
        end)

        it("identifies the container when explicitly not nearby", function()
            assert.are.equal("this crate ...", PlayerUtils.getStartSuffix("crate", false))
        end)

        it("says nearby without the container type when nearby", function()
            assert.are.equal("nearby", PlayerUtils.getStartSuffix("crate", true))
        end)
    end)

    describe("getSuccessBody", function()
        it("preserves a singular display name", function()
            assert.are.equal("Axe", PlayerUtils.getSuccessBody("Axe", 1))
        end)

        it("pluralizes a name for multiple results", function()
            assert.are.equal("Axes", PlayerUtils.getSuccessBody("Axe", 3))
        end)

        it("pluralizes a name ending in y", function()
            assert.are.equal("Batteries", PlayerUtils.getSuccessBody("Battery", 2))
        end)

        it("preserves the singular name for a zero count", function()
            assert.are.equal("Axe", PlayerUtils.getSuccessBody("Axe", 0))
        end)
    end)

    describe("getSuccessMessage", function()
        it("combines one vowel-named result with a player-held inventory", function()
            assert.are.equal("Aha, I found it! I have an Axe in my backpack",
                PlayerUtils.getSuccessMessage("backpack", "Axe", 1))
        end)

        it("combines multiple results with a translated container title", function()
            globals.texts.IGUI_ContainerTitle_crate = "Wooden Crate"
            assert.are.equal("Aha, I found some! There are 3 Hammers in the wooden crate",
                PlayerUtils.getSuccessMessage("crate", "Hammer", 3))
        end)
    end)

    describe("getSuccessPrefix", function()
        it("uses I have an for one vowel-named player-held result", function()
            assert.are.equal("Aha, I found it! I have an",
                PlayerUtils.getSuccessPrefix("backpack", "Axe", 1))
        end)

        it("uses There is a for one consonant-named container result", function()
            assert.are.equal("Aha, I found it! There is a",
                PlayerUtils.getSuccessPrefix("crate", "Hammer", 1))
        end)

        it("includes the count for multiple container results", function()
            assert.are.equal("Aha, I found some! There are 3",
                PlayerUtils.getSuccessPrefix("crate", "Hammer", 3))
        end)

        it("includes the count for multiple player-held results", function()
            assert.are.equal("Aha, I found some! I have 2",
                PlayerUtils.getSuccessPrefix("inventory", "Axe", 2))
        end)
    end)

    describe("getSuccessSuffix", function()
        it("identifies the player's inventory", function()
            assert.are.equal("in my inventory", PlayerUtils.getSuccessSuffix("inventory"))
        end)

        it("uses on for the floor", function()
            assert.are.equal("on the floor", PlayerUtils.getSuccessSuffix("floor"))
        end)

        it("lower-cases a known container title", function()
            globals.texts.IGUI_ContainerTitle_crate = "Wooden Crate"
            assert.are.equal("in the wooden crate", PlayerUtils.getSuccessSuffix("crate"))
        end)

        it("retains the trailing space for an unknown title", function()
            assert.are.equal("in the ", PlayerUtils.getSuccessSuffix("shelf"))
        end)
    end)

    describe("isPlayerHeld", function()
        it("recognizes a backpack", function()
            assert.is_true(PlayerUtils.isPlayerHeld("backpack"))
        end)

        it("recognizes inventory", function()
            assert.is_true(PlayerUtils.isPlayerHeld("inventory"))
        end)

        it("excludes the floor", function()
            assert.is_false(PlayerUtils.isPlayerHeld("floor"))
        end)

        it("excludes a world container", function()
            assert.is_false(PlayerUtils.isPlayerHeld("crate"))
        end)

        it("excludes nil", function()
            assert.is_false(PlayerUtils.isPlayerHeld(nil))
        end)
    end)

    describe("say", function()
        it("passes the message to Say exactly once", function()
            local character = globals.newRecordingCharacter()
            PlayerUtils.say(character, "hello")
            assert.are.equal(1, character.sayCount)
            assert.are.same({ "hello" }, character.said)
        end)

        it("still calls Say once for an empty message", function()
            local character = globals.newRecordingCharacter()
            PlayerUtils.say(character, "")
            assert.are.equal(1, character.sayCount)
            assert.are.same({ "" }, character.said)
        end)

        it("still calls Say once for a nil message", function()
            local character = globals.newRecordingCharacter()
            PlayerUtils.say(character, nil)
            assert.are.equal(1, character.sayCount)
            assert.is_nil(character.said[1])
        end)
    end)

    describe("sayResult", function()
        it("says the singular player-held success message once", function()
            local character = globals.newRecordingCharacter()
            PlayerUtils.sayResult(character, "backpack", "Axe", 1)
            assert.are.equal(1, character.sayCount)
            assert.are.same({ "Aha, I found it! I have an Axe in my backpack" }, character.said)
        end)

        it("says the plural container success message once", function()
            globals.texts.IGUI_ContainerTitle_crate = "Wooden Crate"
            local character = globals.newRecordingCharacter()
            PlayerUtils.sayResult(character, "crate", "Hammer", 3)
            assert.are.equal(1, character.sayCount)
            assert.are.same({ "Aha, I found some! There are 3 Hammers in the wooden crate" }, character.said)
        end)

        it("says a failure message once for zero results", function()
            local character = globals.newRecordingCharacter()
            PlayerUtils.sayResult(character, "floor", "Axe", 0)
            assert.are.equal(1, character.sayCount)
            assert.are.same({ "I couldn't find an Axe on the floor" }, character.said)
        end)

        it("says a failure message once for a nil count", function()
            local character = globals.newRecordingCharacter()
            PlayerUtils.sayResult(character, "backpack", "Nails", nil)
            assert.are.equal(1, character.sayCount)
            assert.are.same({ "I couldn't find any Nails in my backpack" }, character.said)
        end)

        it("preserves spaces for an empty name and unknown container with zero results", function()
            local character = globals.newRecordingCharacter()
            PlayerUtils.sayResult(character, "shelf", "", 0)
            assert.are.equal(1, character.sayCount)
            assert.are.same({ "I couldn't find a  in the " }, character.said)
        end)

        it("still says success once for an empty name with a positive count", function()
            local character = globals.newRecordingCharacter()
            PlayerUtils.sayResult(character, "inventory", "", 1)
            assert.are.equal(1, character.sayCount)
            assert.are.same({ "Aha, I found it! I have a  in my inventory" }, character.said)
        end)
    end)

    describe("sayStart", function()
        it("says the populated-container message once using the translated title", function()
            globals.texts.IGUI_ContainerTitle_crate = "Wooden Crate"
            local character = globals.newRecordingCharacter()
            PlayerUtils.sayStart(character, "crate", 5)
            assert.are.equal(1, character.sayCount)
            assert.are.same({ "Hm, let's see what's in this wooden crate" }, character.said)
        end)

        it("says the empty-container message once for a zero count", function()
            globals.texts.IGUI_ContainerTitle_crate = "Wooden Crate"
            local character = globals.newRecordingCharacter()
            PlayerUtils.sayStart(character, "crate", 0)
            assert.are.equal(1, character.sayCount)
            assert.are.same({ "I don't think there's anything in this wooden crate" }, character.said)
        end)

        it("retains the trailing space for an unknown title", function()
            local character = globals.newRecordingCharacter()
            PlayerUtils.sayStart(character, "shelf", 2)
            assert.are.equal(1, character.sayCount)
            assert.are.same({ "Hm, let's see what's in this " }, character.said)
        end)

        it("still says the empty-container message for an empty type", function()
            local character = globals.newRecordingCharacter()
            PlayerUtils.sayStart(character, "", 0)
            assert.are.equal(1, character.sayCount)
            assert.are.same({ "I don't think there's anything in this " }, character.said)
        end)

        it("raises before saying anything for a nil count", function()
            local character = globals.newRecordingCharacter()
            assert.error_matches(function()
                PlayerUtils.sayStart(character, "crate", nil)
            end, "attempt to compare")
            assert.are.equal(0, character.sayCount)
            assert.are.same({}, character.said)
        end)
    end)
end)
