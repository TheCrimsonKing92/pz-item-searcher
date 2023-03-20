# Item Searcher

## Description

Adds a convenient method to make characters search for specific items in nearby containers

## Compatibility

This mod should be compatible with any build 41 code (developed and tested with 41.65-41.68), but has not been specifically tested for Build 40.

## Client Usage

### Start a Search
The main Item Searcher UI is bound to the single/double quote key (usually next to Enter on QWERTY keyboards). Press the key to open the UI, type the item you're searching for, and press Enter to find the item. If you enter a term which is ambiguous, double-click an entry in the item list to select it for searching, or provide another search term. Click "Start Searching" and your character is off to the races!


## Server Usage

### Configuring Search Mode
ItemSearcher begins life with a default SearchMode value of 3, meaning searching is unrestricted. While this is desirable for singleplayer, it is likely that a server setup should have restrictions on where room searching is allowed.

* Find your sandbox variables file (for example, servertest's file lives at *\Zomboid\Server\servertest_SandboxVars.lua)
* Find the ItemSearcher block
* Find the SearchMode entry
* Tweak the value to your liking: 1 - Restricted Mode; searching is only allowed in your safehouse, 2 - Hybrid Mode; searching is allowed outside of others' safehouses, 3 - Unrestricted Mode; searching is allowed anywhere.
