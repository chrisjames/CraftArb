-- CraftArb.lua
-- Crafting arbitrage scanner for TurtleWoW (vanilla 1.12)

-- ---------------------------------------------------------------------------
-- Saved variables default structure
-- CraftArbDB = {
--   prices = {},          -- [itemId] = { min = N, timestamp = N }
--   minProfit = 1000,     -- minimum net profit to show (in copper)
-- }
-- ---------------------------------------------------------------------------

local ADDON_NAME = "CraftArb"
local VERSION    = "0.1"

-- ---------------------------------------------------------------------------
-- Initialisation
-- ---------------------------------------------------------------------------

function CraftArb_OnLoad(frame)
  -- Register for the events we care about at startup
  frame:RegisterEvent("ADDON_LOADED")
  frame:RegisterEvent("AUCTION_HOUSE_SHOW")
  frame:RegisterEvent("AUCTION_HOUSE_CLOSED")
end

function CraftArb_OnEvent(frame, event)
  if event == "ADDON_LOADED" then
    CraftArb_Init()
  elseif event == "AUCTION_HOUSE_SHOW" then
    CraftArb_OnAHShow()
  elseif event == "AUCTION_HOUSE_CLOSED" then
    CraftArb_OnAHClose()
  end
end

function CraftArb_Init()
  -- Initialise SavedVariables with defaults if this is the first load
  if not CraftArbDB then
    CraftArbDB = {}
  end
  if not CraftArbDB.prices then
    CraftArbDB.prices = {}
  end
  if not CraftArbDB.minProfit then
    CraftArbDB.minProfit = 1000  -- 10 silver default
  end

  -- Register slash commands
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
  elseif msg == "reset" then
    CraftArbDB.prices = {}
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00CraftArb:|r Price history cleared.")
  else
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00CraftArb commands:|r")
    DEFAULT_CHAT_FRAME:AddMessage("  /craftarb        — toggle panel")
    DEFAULT_CHAT_FRAME:AddMessage("  /craftarb reset  — clear saved prices")
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
  CraftArbStatusText:SetText("Auction House closed.")
end

-- ---------------------------------------------------------------------------
-- Stub: scan entry point (wired to the Scan button)
-- Will be fully implemented in the next stage.
-- ---------------------------------------------------------------------------

function CraftArb_StartScan()
  DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00CraftArb:|r Scan not yet implemented.")
  CraftArbStatusText:SetText("Scan not yet implemented.")
end

-- ---------------------------------------------------------------------------
-- Stub: show deals (wired to the Show Deals button)
-- Will be fully implemented after scanning is in place.
-- ---------------------------------------------------------------------------

function CraftArb_ShowDeals()
  DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00CraftArb:|r No scan data yet.")
  CraftArbStatusText:SetText("No scan data. Run a scan first.")
end
