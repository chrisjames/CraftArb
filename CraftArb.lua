-- CraftArb.lua
-- Crafting arbitrage scanner for TurtleWoW (vanilla 1.12)

-- CraftArbDB = {
--   prices = {},          -- [itemId] = { min = N, timestamp = N }
--   minProfit = 1000,     -- minimum net profit to show (in copper)
-- }

local VERSION = "0.1"

-- ---------------------------------------------------------------------------
-- Item name lookup
-- Hardcoded so we don't depend on GetItemInfo cache being warm.
-- Verify IDs in-game: /script print(GetItemInfo(itemId))
-- ---------------------------------------------------------------------------

CraftArb_ItemNames = {
  -- Ores
  [2770]  = "Copper Ore",
  [2771]  = "Tin Ore",
  [2772]  = "Iron Ore",
  [2776]  = "Gold Ore",
  [3858]  = "Mithril Ore",
  [7911]  = "Truesilver Ore",
  [10620] = "Thorium Ore",
  -- Bars
  [2840]  = "Copper Bar",
  [3576]  = "Tin Bar",
  [2841]  = "Bronze Bar",
  [3575]  = "Iron Bar",
  [3577]  = "Gold Bar",
  [3860]  = "Mithril Bar",
  [6037]  = "Truesilver Bar",
  [12359] = "Thorium Bar",
  -- Fish
  [6303]  = "Raw Oily Blackmouth",
  [13422] = "Stonescale Eel",
  [13439] = "Raw Nightfin Snapper",
  [21153] = "Raw Sagefish",
  -- Cooked outputs
  [6370]  = "Blackmouth Oil",
  [13423] = "Stonescale Oil",
  [13931] = "Nightfin Soup",
  [21217] = "Sagefish Delight",
}

-- ---------------------------------------------------------------------------
-- Recipe data
-- ---------------------------------------------------------------------------

CraftArb_Recipes = {
  -- Mining: ore -> bars
  { name = "Copper Bar",     output = { id = 2840,  qty = 1 }, mats = { { id = 2770,  qty = 2 } } },
  { name = "Tin Bar",        output = { id = 3576,  qty = 1 }, mats = { { id = 2771,  qty = 2 } } },
  { name = "Bronze Bar",     output = { id = 2841,  qty = 2 }, mats = { { id = 2770,  qty = 1 }, { id = 2771, qty = 1 } } },
  { name = "Iron Bar",       output = { id = 3575,  qty = 1 }, mats = { { id = 2772,  qty = 2 } } },
  { name = "Gold Bar",       output = { id = 3577,  qty = 1 }, mats = { { id = 2776,  qty = 2 } } },
  { name = "Mithril Bar",    output = { id = 3860,  qty = 1 }, mats = { { id = 3858,  qty = 2 } } },
  { name = "Truesilver Bar", output = { id = 6037,  qty = 1 }, mats = { { id = 7911,  qty = 2 } } },
  { name = "Thorium Bar",    output = { id = 12359, qty = 1 }, mats = { { id = 10620, qty = 2 } } },
  -- Cooking: raw fish -> processed outputs
  { name = "Blackmouth Oil",    output = { id = 6370,  qty = 1 }, mats = { { id = 6303,  qty = 1 } } },
  { name = "Stonescale Oil",    output = { id = 13423, qty = 1 }, mats = { { id = 13422, qty = 1 } } },
  { name = "Nightfin Soup",     output = { id = 13931, qty = 1 }, mats = { { id = 13439, qty = 1 } } },
  { name = "Sagefish Delight",  output = { id = 21217, qty = 1 }, mats = { { id = 21153, qty = 2 } } },
}

-- Build deduplicated scan list from all recipe item IDs
function CraftArb_BuildScanList()
  local seen = {}
  CraftArb_ScanItems = {}
  for _, recipe in ipairs(CraftArb_Recipes) do
    if not seen[recipe.output.id] then
      seen[recipe.output.id] = true
      table.insert(CraftArb_ScanItems, recipe.output.id)
    end
    for _, mat in ipairs(recipe.mats) do
      if not seen[mat.id] then
        seen[mat.id] = true
        table.insert(CraftArb_ScanItems, mat.id)
      end
    end
  end
end

-- ---------------------------------------------------------------------------
-- Scan state machine (not persisted)
-- ---------------------------------------------------------------------------

CraftArb_Scan = {
  active   = false,
  queue    = {},   -- item IDs left to query
  total    = 0,    -- total items at scan start (for progress display)
  current  = nil,  -- item ID currently being queried
  timer    = 0,    -- seconds until next query fires
  waiting  = false, -- true while waiting for AUCTION_ITEM_LIST_UPDATE
}

function CraftArb_StartScan()
  if not AuctionFrame or not AuctionFrame:IsShown() then
    DEFAULT_CHAT_FRAME:AddMessage("|cffff4444CraftArb:|r Open the Auction House first.")
    CraftArbStatusText:SetText("Open the Auction House first.")
    return
  end

  CraftArb_Scan.queue   = {}
  for _, id in ipairs(CraftArb_ScanItems) do
    table.insert(CraftArb_Scan.queue, id)
  end
  CraftArb_Scan.total   = table.getn(CraftArb_Scan.queue)
  CraftArb_Scan.active  = true
  CraftArb_Scan.timer   = 0    -- fire first query immediately
  CraftArb_Scan.waiting = false
  CraftArb_Scan.current = nil

  CraftArbStatusText:SetText("Starting scan...")
  DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00CraftArb:|r Scanning " .. CraftArb_Scan.total .. " items...")
end

-- Called every frame by CraftArbEventFrame OnUpdate
function CraftArb_OnUpdate(elapsed)
  if not CraftArb_Scan.active or CraftArb_Scan.waiting then return end

  CraftArb_Scan.timer = CraftArb_Scan.timer - elapsed
  if CraftArb_Scan.timer > 0 then return end

  -- All items done?
  if table.getn(CraftArb_Scan.queue) == 0 then
    CraftArb_ScanComplete()
    return
  end

  -- Pop next item and query AH
  CraftArb_Scan.current = table.remove(CraftArb_Scan.queue, 1)
  local name = CraftArb_ItemNames[CraftArb_Scan.current]
  if not name then
    -- Unknown item - skip without delay
    return
  end

  local done = CraftArb_Scan.total - table.getn(CraftArb_Scan.queue)
  CraftArbStatusText:SetText("Scanning " .. done .. "/" .. CraftArb_Scan.total .. ": " .. name)
  QueryAuctionItems(name, nil, nil, nil, nil, nil, 0, nil, nil)
  CraftArb_Scan.waiting = true
end

-- Called when AH returns results for the current query
function CraftArb_OnAuctionListUpdate()
  if not CraftArb_Scan.active or not CraftArb_Scan.current then return end

  local itemId = CraftArb_Scan.current
  local count  = GetNumAuctionItems("list")
  local minPerUnit = nil

  for i = 1, count do
    local _, _, stackSize, _, _, _, _, _, buyout = GetAuctionItemInfo("list", i)
    local link = GetAuctionItemLink("list", i)
    if link and buyout and buyout > 0 and stackSize and stackSize > 0 then
      -- Parse item ID from link format: |Hitem:ITEMID:...|h
      local _, _, linkId = string.find(link, "|Hitem:(%d+):")
      if tonumber(linkId) == itemId then
        local perUnit = buyout / stackSize
        if not minPerUnit or perUnit < minPerUnit then
          minPerUnit = perUnit
        end
      end
    end
  end

  if minPerUnit then
    CraftArbDB.prices[itemId] = { min = minPerUnit, timestamp = time() }
  end

  -- Wait 1.5s before next query
  CraftArb_Scan.waiting = false
  CraftArb_Scan.timer   = 1.5
end

function CraftArb_ScanComplete()
  CraftArb_Scan.active  = false
  CraftArb_Scan.current = nil
  CraftArbStatusText:SetText("Scan complete! Click Show Deals.")
  DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00CraftArb:|r Scan complete.")
end

-- ---------------------------------------------------------------------------
-- Initialisation
-- ---------------------------------------------------------------------------

function CraftArb_OnLoad(frame)
  frame:RegisterEvent("VARIABLES_LOADED")
  frame:RegisterEvent("AUCTION_HOUSE_SHOW")
  frame:RegisterEvent("AUCTION_HOUSE_CLOSED")
  frame:RegisterEvent("AUCTION_ITEM_LIST_UPDATE")
end

function CraftArb_OnEvent(frame, event)
  if event == "VARIABLES_LOADED" then
    CraftArb_Init()
  elseif event == "AUCTION_HOUSE_SHOW" then
    CraftArb_OnAHShow()
  elseif event == "AUCTION_HOUSE_CLOSED" then
    CraftArb_OnAHClose()
  elseif event == "AUCTION_ITEM_LIST_UPDATE" then
    CraftArb_OnAuctionListUpdate()
  end
end

function CraftArb_Init()
  if not CraftArbDB then CraftArbDB = {} end
  if not CraftArbDB.prices then CraftArbDB.prices = {} end
  if not CraftArbDB.minProfit then CraftArbDB.minProfit = 1000 end

  CraftArb_BuildScanList()

  SLASH_CRAFTARB1 = "/craftarb"
  SLASH_CRAFTARB2 = "/carb"
  SlashCmdList["CRAFTARB"] = CraftArb_SlashCmd

  DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00CraftArb v" .. VERSION .. " loaded.|r  Type /craftarb to open.")
end

-- ---------------------------------------------------------------------------
-- Slash command handler
-- ---------------------------------------------------------------------------

function CraftArb_SlashCmd(msg)
  msg = string.lower(msg or "")
  if msg == "" or msg == "show" then
    CraftArb_TogglePanel()
  elseif msg == "recipes" then
    CraftArb_PrintRecipes()
  elseif msg == "prices" then
    CraftArb_PrintPrices()
  elseif msg == "reset" then
    CraftArbDB.prices = {}
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00CraftArb:|r Price history cleared.")
  else
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00CraftArb commands:|r")
    DEFAULT_CHAT_FRAME:AddMessage("  /craftarb          -- toggle panel")
    DEFAULT_CHAT_FRAME:AddMessage("  /craftarb recipes  -- list tracked recipes")
    DEFAULT_CHAT_FRAME:AddMessage("  /craftarb prices   -- dump saved prices")
    DEFAULT_CHAT_FRAME:AddMessage("  /craftarb reset    -- clear saved prices")
  end
end

-- ---------------------------------------------------------------------------
-- Debug helpers
-- ---------------------------------------------------------------------------

function CraftArb_PrintRecipes()
  DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00CraftArb recipes (" .. table.getn(CraftArb_Recipes) .. "):|r")
  for _, r in ipairs(CraftArb_Recipes) do
    local matStr = ""
    for i, mat in ipairs(r.mats) do
      matStr = matStr .. mat.qty .. "x[" .. mat.id .. "]"
      if i < table.getn(r.mats) then matStr = matStr .. " + " end
    end
    DEFAULT_CHAT_FRAME:AddMessage("  " .. r.name .. " -- " .. matStr .. " -> " .. r.output.qty .. "x[" .. r.output.id .. "]")
  end
  DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00" .. table.getn(CraftArb_ScanItems) .. " unique items to scan.|r")
end

-- Print all saved prices to chat for debugging
function CraftArb_PrintPrices()
  local count = 0
  for id, data in pairs(CraftArbDB.prices) do
    local name = CraftArb_ItemNames[id] or ("Item " .. id)
    local gold   = math.floor(data.min / 10000)
    local silver = math.floor(math.mod(data.min, 10000) / 100)
    local copper = math.floor(math.mod(data.min, 100))
    DEFAULT_CHAT_FRAME:AddMessage(
      string.format("  %s: %dg %ds %dc", name, gold, silver, copper)
    )
    count = count + 1
  end
  if count == 0 then
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00CraftArb:|r No prices saved yet. Run a scan first.")
  else
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00CraftArb:|r " .. count .. " prices saved.")
  end
end

-- ---------------------------------------------------------------------------
-- Panel show/hide
-- ---------------------------------------------------------------------------

function CraftArb_TogglePanel()
  if CraftArbFrame:IsShown() then
    CraftArbFrame:Hide()
  else
    CraftArbFrame:Show()
  end
end

-- ---------------------------------------------------------------------------
-- Auction House events
-- ---------------------------------------------------------------------------

function CraftArb_OnAHShow()
  CraftArbStatusText:SetText("Auction House open. Click Scan to begin.")
end

function CraftArb_OnAHClose()
  if CraftArb_Scan.active then
    CraftArb_Scan.active  = false
    CraftArb_Scan.waiting = false
    CraftArbStatusText:SetText("Scan cancelled - AH closed.")
    DEFAULT_CHAT_FRAME:AddMessage("|cffff4444CraftArb:|r Scan cancelled - AH closed.")
  else
    CraftArbStatusText:SetText("Auction House closed.")
  end
end

-- ---------------------------------------------------------------------------
-- Show Deals (stub - profit calc comes in next stage)
-- ---------------------------------------------------------------------------

function CraftArb_ShowDeals()
  local count = 0
  for _ in pairs(CraftArbDB.prices) do count = count + 1 end
  if count == 0 then
    CraftArbStatusText:SetText("No scan data. Run a scan first.")
  else
    CraftArbStatusText:SetText("Deals coming soon! (" .. count .. " prices stored)")
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00CraftArb:|r " .. count .. " prices stored. Use /craftarb prices to inspect.")
  end
end
