# CraftArb — WoW Addon Project

## Project Overview
CraftArb is a World of Warcraft addon for the TurtleWoW private server (Ambershire realm).
It scans the Auction House and surfaces profitable crafting arbitrage opportunities —
specifically comparing the AH price of raw materials vs. the AH price of processed/crafted outputs.

## Target Professions
- Mining (ore → smelted bars)
- Fishing (raw fish)
- Cooking (raw fish → cooked food/oils)

## Design Goals
- Semi-automatic: scan AH data, surface deals, player confirms each action
- Persist price history across sessions via SavedVariables
- Custom UI panel (dedicated window, not chat output)
- Show mat cost, sell value, and net profit (after 5% AH cut) per recipe

## Technical Environment
- **Server:** TurtleWoW private server, Ambershire realm
- **WoW version:** Vanilla 1.12 (patch 11200)
- **Language:** Lua, using the vanilla WoW 1.12 addon API
- **No external libraries** — use only the WoW built-in API and UI XML system

## WoW Vanilla API Constraints
- UI defined in XML (.xml) + logic in Lua (.lua), declared in a .toc manifest
- AH queries use `QueryAuctionItems()` — must throttle requests (~1.5s apart) to avoid server rejection
- `AUCTION_ITEM_LIST_UPDATE` event fires when AH results are ready
- `GetAuctionItemInfo("list", index)` reads individual auction rows
- `GetAuctionItemLink("list", index)` retrieves item links for parsing item IDs
- SavedVariables declared in .toc and available as globals on load
- No `coroutines` for async — use `OnUpdate` frame timers for sequencing
- Interface version: 11200

## Item ID Notes
- Item IDs should be verified in-game with: /script print(GetItemInfo(itemId))
- TurtleWoW may have custom items not present in standard vanilla databases
- Standard vanilla IDs are a safe starting point for common ores, bars, and fish

## Slash Commands
- /craftarb or /carb — toggle the main panel
- Additional subcommands TBD during development

## Out of Scope (for now)
- Auto-buying or auto-posting auctions
- Professions other than Mining, Fishing, Cooking
- Crafting queue or materials shopping list (potential future feature)