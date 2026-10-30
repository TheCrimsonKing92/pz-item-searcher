local StringUtils = require("PZISStringUtils")

describe("PZISStringUtils", function()
    describe("createSearchPattern", function()
        it("matches either case of each letter", function()
            assert.are.equal("[aA][xX][eE]", StringUtils:createSearchPattern("Axe"))
        end)

        it("escapes hyphens", function()
            assert.are.equal("[cC][aA][nN]%-[oO][pP][eE][nN][eE][rR]",
                StringUtils:createSearchPattern("can-opener"))
        end)

        it("returns an empty pattern for empty input", function()
            assert.are.equal("", StringUtils:createSearchPattern(""))
        end)

        it("leaves dots unescaped", function()
            assert.are.equal("[aA].[bB]", StringUtils:createSearchPattern("a.b"))
        end)
    end)

    describe("endsWith", function()
        it("recognizes a matching suffix", function()
            assert.is_true(StringUtils:endsWith("Crowbar", "bar"))
        end)

        it("compares suffixes case-sensitively", function()
            assert.is_false(StringUtils:endsWith("Crowbar", "Bar"))
        end)

        it("accepts an empty suffix", function()
            assert.is_true(StringUtils:endsWith("Crowbar", ""))
        end)
    end)

    describe("pascalize", function()
        it("capitalizes words and collapses whitespace", function()
            assert.are.equal("Baseball Bat", StringUtils:pascalize("  baseball   bat "))
        end)

        it("preserves the remaining letter case", function()
            assert.are.equal("HELLO", StringUtils:pascalize("hELLO"))
        end)

        it("returns an empty string for empty input", function()
            assert.are.equal("", StringUtils:pascalize(""))
        end)
    end)

    describe("pluralize", function()
        it("appends s to a singular word", function()
            assert.are.equal("axes", StringUtils:pluralize("axe"))
        end)

        it("replaces a trailing y with ies", function()
            assert.are.equal("batteries", StringUtils:pluralize("battery"))
        end)

        it("leaves an already plural word ending in s unchanged", function()
            assert.are.equal("nails", StringUtils:pluralize("nails"))
        end)

        it("replaces y even when preceded by a vowel", function()
            assert.are.equal("keies", StringUtils:pluralize("key"))
        end)

        it("appends s to an empty string", function()
            assert.are.equal("s", StringUtils:pluralize(""))
        end)
    end)

    describe("split", function()
        it("splits on whitespace by default", function()
            assert.are.same({ "a", "b", "c" }, StringUtils:split("a b\tc"))
        end)

        it("splits on the supplied separator and drops empty fields", function()
            assert.are.same({ "a", "b" }, StringUtils:split("a,,b", ","))
        end)

        it("keeps input with no separator as one part", function()
            assert.are.same({ "abc" }, StringUtils:split("abc", ","))
        end)

        it("returns no parts for empty input", function()
            assert.are.same({}, StringUtils:split(""))
        end)
    end)

    describe("startsWith", function()
        it("recognizes a matching prefix", function()
            assert.is_true(StringUtils:startsWith("Crowbar", "Crow"))
        end)

        it("compares prefixes case-sensitively", function()
            assert.is_false(StringUtils:startsWith("Crowbar", "crow"))
        end)

        it("accepts an empty prefix", function()
            assert.is_true(StringUtils:startsWith("Crowbar", ""))
        end)
    end)

    describe("startsWithVowel", function()
        it("recognizes both lower-case and upper-case vowels", function()
            assert.is_true(StringUtils:startsWithVowel("apple"))
            assert.is_true(StringUtils:startsWithVowel("Egg"))
        end)

        it("rejects a consonant", function()
            assert.is_false(StringUtils:startsWithVowel("banana"))
        end)

        it("returns false for empty input", function()
            assert.is_false(StringUtils:startsWithVowel(""))
        end)
    end)
end)
