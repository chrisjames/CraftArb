-- CraftArb.lua
-- Crafting arbitrage scanner for TurtleWoW (vanilla 1.12)

-- CraftArbDB = {
--   prices = {},          -- [itemId] = { min = N, timestamp = N }
--   minProfit = 1000,     -- minimum net profit to show (in copper)
-- }

local VERSION = "0.1"

-- ---------------------------------------------------------------------------
-- Recipe data
--
-- All item IDs are standard vanilla 1.12 values and should be verified
-- in-game with: /script print(GetItemInfo(itemId))
--
-- Structure:
--   name    = display name
--   output  = { id = itemId, qty = N }   (qty = how many the craft produces)
--   mats    = { { id = itemId, qty = N }, ... }
-- ---------------------------------------------------------------------------

CraftArb_Recipes = {

  -- Mining: ore -> bars
  {
    name   = "Copper Bar",
    output = { id = 2840, qty = 1 },
    mats   = { { id = 2770, qty = 2 } },   -- 2x Copper Ore
  },
  {
    name   = "Tin Bar",
    output = { id = 3576, qty = 1 },
    mats   = { { id = 2771, qty = 2 } },   -- 2x Tin Ore
  },
  {
    name   = "Bronze Bar",
    output = { id = 2841, qty = 2 },       -- smelting makes 2 bars
    mats   = { { id = 2770, qty = 1 },     -- 1x Copper Ore
               { id = 2771, qty = 1 } },   -- 1x Tin Ore
  },
  {
    name   = "Iron Bar",
    output = { id = 3575, qty = 1 },
    mats   = { { id = 2772, qty = 2 } },   -- 2x Iron Ore
  },
  {
    name   = "Gold Bar",
    output = { id = 3577, qty = 1 },
    mats   = { { id = 2776, qty = 2 } },   -- 2x Gold Ore
  },
  {
    name   = "Mithril Bar",
    output = { id = 3860, qty = 1 },
    mats   = { { id = 3858, qty = 2 } },   -- 2x Mithril Ore
  },
  {
    name   = "Truesilver Bar",
    output = { id = 6037, qty = 1 },
    mats   = { { id = 7911, qty = 2 } },   -- 2x Truesilver Ore
  },
  {
    name   = "Thorium Bar",
    output = { id = 12359, qty = 1 },
    mats   = { { id = 10620, qty = 2 } },  -- 2x Thorium Ore
  },

  -- Cooking: raw fish -> processed outputs
  {
    name   = "Blackmouth Oil",
    output = { id = 6370, qty = 1 },
    mats   = { { id = 6303, qty = 1 } },   -- 1x Raw Oily Blackmouth
  },
  {
    name   = "Stonescale Oil",
    output = { id = 13423, qty = 1 },
    mats   = { { id = 13422, qty = 1 } },  -- 1x Stonescale Eel
  },
  {
    name   = "Nightfin Soup",
    output = { id = 13931, qty = 1 },
    mats   = { { id = 13439, qty = 1 } },  -- 1x Raw Nightfin Snapper
  },
  {
    name   = "Sagefish Delight",
    output = { id = 21217, qty = 1 },
    mats   = { { id = 21153, qty = 2 } },  -- 2x Raw Sagefish
  },
}

-- Build a deduplicated list of every item ID we need to scan
-- (called once at init, stored in CraftArb_ScanItems)
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
-- Initialisation
-- ---------------------------------------------------------------------------

function CraftArb_OnLoad(frame)
  -- ADDON_LOADED does not exist in vanilla 1.12; use VARIABLES_LOADED instead,
  -- which fires after SavedVariables are available.
  frame:RegisterEvent("VARIABLES_LOADED")
  frame:RegisterEvent("AUCTION_HOUSE_SHOW")
  frame:RegisterEvent("AUCTION_HOUSE_CLOSED")
end

function CraftArb_OnEvent(frame, event)
  if event == "VARIABLES_LOADED" then
    CraftArb_Init()
  elseif event == "AUCTION_HOUSE_SHOW" then
    CraftArb_OnAHShow()
  elseif event == "AUCTION_HOUSE_CLOSED" then
    CraftArb_OnAHClose()
  end
end

function CraftArb_Init()
  if not CraftArbDB then
    CraftArbDB = {}
  end
  if not CraftArbDB.prices then
    CraftArbDB.prices = {}
  end
  if not CraftArbDB.minProfit then
    CraftArbDB.minProfit = 1000  -- 10 silver default
  end

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
  elseif msg == "reset" then
    CraftArbDB.prices = {}
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00CraftArb:|r Price history cleared.")
  else
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00CraftArb commands:|r")
    DEFAULT_CHAT_FRAME:AddMessage("  /craftarb          -- toggle panel")
    DEFAULT_CHAT_FRAME:AddMessage("  /craftarb recipes  -- list all tracked recipes")
    DEFAULT_CHAT_FRAME:AddMessage("  /craftarb reset    -- clear saved prices")
  end
end

-- Print all recipes to chat for verification
function CraftArb_PrintRecipes()
  DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00CraftArb recipes (" .. table.getn(CraftArb_Recipes) .. "):|r")
  for _, r in ipairs(CraftArb_Recipes) do
    local matStr = ""
    for i, mat in ipairs(r.mats) do
      matStr = matStr .. mat.qty .. "x[" .. mat.id .. "]"
      if i < table.getn(r.mats) then matStr = matStr .. " + " end
    end
    DEFAULT_CHAT_FRAME:AddMessage(
      "  " .. r.name ..
      " -- " .. matStr ..
      " -> " .. r.output.qty .. "x[" .. r.output.id .. "]"
    )
  end
  DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00" .. table.getn(CraftArb_ScanItems) .. " unique items to scan.|r")
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
  CraftArbStatusText:SetText("Auction House closed.")
end

-- ---------------------------------------------------------------------------
-- Stub: scan entry point (wired to the Scan button)
-- ---------------------------------------------------------------------------

function CraftArb_StartScan()
  DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00CraftArb:|r Scan not yet implemented.")
  CraftArbStatusText:SetText("Scan not yet implemented.")
end

-- ---------------------------------------------------------------------------
-- Stub: show deals (wired to the Show Deals button)
-- ---------------------------------------------------------------------------

function CraftArb_ShowDeals()
  DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00CraftArb:|r No scan data yet.")
  CraftArbStatusText:SetText("No scan data. Run a scan first.")
end
