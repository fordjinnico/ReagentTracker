local panel = CreateFrame("Frame")
panel.name = "Reagent Tracker"

local function GetReagentKey(entry)
  if type(entry) == "table" then
    return table.concat(entry, "_")
  end
  return tostring(entry)
end

local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("Reagent Tracker")

local ICON_SIZE = 32
local ICONS_PER_ROW = 8
local START_X = 20
local START_Y = -60
local BORDER = 2
local ROW_SPACING = 10

local function CreateIcon(parent, entry, x, y)
  local key = GetReagentKey(entry)
  local displayID = type(entry) == "table" and entry[1] or entry

  local btn = CreateFrame("Button", nil, parent)
  btn:SetSize(ICON_SIZE, ICON_SIZE)
  btn:SetPoint("TOPLEFT", x, y)

  local icon = btn:CreateTexture(nil, "ARTWORK")
  icon:SetAllPoints()
  icon:SetTexture(C_Item.GetItemIconByID(displayID))

  local border = {}
  local function edge()
    local t = btn:CreateTexture(nil, "OVERLAY")
    t:SetColorTexture(0, 1, 0, 1)
    return t
  end

  border.top = edge()
  border.top:SetPoint("TOPLEFT", -BORDER, BORDER)
  border.top:SetPoint("TOPRIGHT", BORDER, BORDER)
  border.top:SetHeight(BORDER)

  border.bottom = edge()
  border.bottom:SetPoint("BOTTOMLEFT", -BORDER, -BORDER)
  border.bottom:SetPoint("BOTTOMRIGHT", BORDER, -BORDER)
  border.bottom:SetHeight(BORDER)

  border.left = edge()
  border.left:SetPoint("TOPLEFT", -BORDER, BORDER)
  border.left:SetPoint("BOTTOMLEFT", -BORDER, -BORDER)
  border.left:SetWidth(BORDER)

  border.right = edge()
  border.right:SetPoint("TOPRIGHT", BORDER, BORDER)
  border.right:SetPoint("BOTTOMRIGHT", BORDER, -BORDER)
  border.right:SetWidth(BORDER)

  local function SetBorder(v)
    for _, t in pairs(border) do
      t:SetShown(v)
    end
  end

  SetBorder(RT.db.enabled[key])

  btn:SetScript("OnClick", function()
    RT.db.enabled[key] = not RT.db.enabled[key]
    SetBorder(RT.db.enabled[key])
    RT:UpdateTracker()
  end)

  btn:SetScript("OnEnter", function()
    GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
    GameTooltip:SetItemByID(displayID)
    GameTooltip:Show()
  end)

  btn:SetScript("OnLeave", GameTooltip_Hide)
end

local function CreateOptions()
  local y = START_Y

  for expansion, items in pairs(RT_REAGENTS) do
    local header = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    header:SetPoint("TOPLEFT", 16, y)
    header:SetText(expansion)
    y = y - 32

    local col, row = 0, 0

    for _, entry in ipairs(items) do
      local x = START_X + col * (ICON_SIZE + 8)
      local iconY = y - row * (ICON_SIZE + ROW_SPACING)

      CreateIcon(panel, entry, x, iconY)

      col = col + 1
      if col >= ICONS_PER_ROW then
        col = 0
        row = row + 1
      end
    end

    y = y - (row + 1) * (ICON_SIZE + ROW_SPACING) - 20
  end
end

panel:SetScript("OnShow", function(self)
  if self.initialized then return end
  self.initialized = true
  CreateOptions()
end)

local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
Settings.RegisterAddOnCategory(category)
