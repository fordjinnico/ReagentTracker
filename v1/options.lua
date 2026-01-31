local panel = CreateFrame("Frame")
panel.name = "Reagent Tracker"

local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("Reagent Tracker")

local ICON_SIZE = 32
local ICONS_PER_ROW = 8
local START_X = 20
local START_Y = -50
local BORDER_THICKNESS = 2

local function CreateIcon(parent, itemID, x, y)
  local btn = CreateFrame("Button", nil, parent)
  btn:SetSize(ICON_SIZE, ICON_SIZE)
  btn:SetPoint("TOPLEFT", x, y)

  local icon = btn:CreateTexture(nil, "ARTWORK")
  icon:SetAllPoints()
  icon:SetTexture(C_Item.GetItemIconByID(itemID))

  -- === BORDER ===
  local border = {}

  local function CreateBorder()
    -- TOP
    border.top = btn:CreateTexture(nil, "OVERLAY")
    border.top:SetColorTexture(0, 1, 0, 1)
    border.top:SetPoint("TOPLEFT", btn, "TOPLEFT", -BORDER_THICKNESS, BORDER_THICKNESS)
    border.top:SetPoint("TOPRIGHT", btn, "TOPRIGHT", BORDER_THICKNESS, BORDER_THICKNESS)
    border.top:SetHeight(BORDER_THICKNESS)

    -- BOTTOM
    border.bottom = btn:CreateTexture(nil, "OVERLAY")
    border.bottom:SetColorTexture(0, 1, 0, 1)
    border.bottom:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", -BORDER_THICKNESS, -BORDER_THICKNESS)
    border.bottom:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", BORDER_THICKNESS, -BORDER_THICKNESS)
    border.bottom:SetHeight(BORDER_THICKNESS)

    -- LEFT
    border.left = btn:CreateTexture(nil, "OVERLAY")
    border.left:SetColorTexture(0, 1, 0, 1)
    border.left:SetPoint("TOPLEFT", btn, "TOPLEFT", -BORDER_THICKNESS, BORDER_THICKNESS)
    border.left:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", -BORDER_THICKNESS, -BORDER_THICKNESS)
    border.left:SetWidth(BORDER_THICKNESS)

    -- RIGHT
    border.right = btn:CreateTexture(nil, "OVERLAY")
    border.right:SetColorTexture(0, 1, 0, 1)
    border.right:SetPoint("TOPRIGHT", btn, "TOPRIGHT", BORDER_THICKNESS, BORDER_THICKNESS)
    border.right:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", BORDER_THICKNESS, -BORDER_THICKNESS)
    border.right:SetWidth(BORDER_THICKNESS)
  end

  CreateBorder()

  local function SetBorderVisible(visible)
    for _, t in pairs(border) do
      t:SetShown(visible)
    end
  end

  SetBorderVisible(RT.db.enabled[itemID])

  btn:SetScript("OnClick", function()
    RT.db.enabled[itemID] = not RT.db.enabled[itemID]
    SetBorderVisible(RT.db.enabled[itemID])
    RT:UpdateTracker()
  end)

  btn:SetScript("OnEnter", function()
    GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
    GameTooltip:SetItemByID(itemID)
    GameTooltip:Show()
  end)

  btn:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)
end

local function CreateOptions()
  local y = START_Y

  for expansion, items in pairs(RT_REAGENTS) do
    local header = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    header:SetPoint("TOPLEFT", 16, y)
    header:SetText(expansion)
    y = y - 28

    local col, row = 0, 0

    for _, itemID in ipairs(items) do
      local x = START_X + col * (ICON_SIZE + 6)
      local iconY = y - row * (ICON_SIZE + 6)

      CreateIcon(panel, itemID, x, iconY)

      col = col + 1
      if col >= ICONS_PER_ROW then
        col = 0
        row = row + 1
      end
    end

    y = y - (row + 1) * (ICON_SIZE + 6) - 14
  end
end

panel:SetScript("OnShow", function(self)
  if self.initialized then return end
  self.initialized = true
  CreateOptions()
end)

local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
Settings.RegisterAddOnCategory(category)
