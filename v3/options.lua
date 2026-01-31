local panel = CreateFrame("Frame")
panel.name = "Reagent Tracker"

local function GetReagentKey(entry)
  if type(entry) == "table" then
    return table.concat(entry, "_")
  end
  return entry
end

local function Num(v, d)
  if type(v) == "number" then return v end
  return d
end

local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("Reagent Tracker")

-- =====================
-- TOP OPTIONS
-- =====================

local scaleSlider = CreateFrame("Slider", nil, panel, "OptionsSliderTemplate")
scaleSlider:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -20)
scaleSlider:SetMinMaxValues(0.5, 2)
scaleSlider:SetValueStep(0.05)
scaleSlider:SetObeyStepOnDrag(true)
scaleSlider:SetWidth(200)
scaleSlider.Text:SetText("Scale")

local spacingSlider = CreateFrame("Slider", nil, panel, "OptionsSliderTemplate")
spacingSlider:SetPoint("TOPLEFT", scaleSlider, "BOTTOMLEFT", 0, -30)
spacingSlider:SetMinMaxValues(0, 20)
spacingSlider:SetValueStep(1)
spacingSlider:SetWidth(200)
spacingSlider.Text:SetText("Icon spacing")

local showNames = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
showNames:SetPoint("TOPLEFT", spacingSlider, "BOTTOMLEFT", 0, -20)
showNames.text:SetText("Show reagent names (tracker)")

local lockCheck = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
lockCheck:SetPoint("TOPLEFT", showNames, "BOTTOMLEFT", 0, -6)
lockCheck.text:SetText("Lock tracker")

local resetBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
resetBtn:SetSize(120, 22)
resetBtn:SetPoint("TOPLEFT", lockCheck, "BOTTOMLEFT", 0, -10)
resetBtn:SetText("Reset position")

-- =====================
-- NAME POSITION DROPDOWN
-- =====================

local namePosDrop = CreateFrame("Frame", "RT_NamePosDrop", panel, "UIDropDownMenuTemplate")
local optionsBottomY = -20

namePosDrop:SetPoint("TOPLEFT", resetBtn, "BOTTOMLEFT", -14, optionsBottomY)

-- резервуємо місце під dropdown
optionsBottomY = optionsBottomY - 60

UIDropDownMenu_SetWidth(namePosDrop, 120)
UIDropDownMenu_SetText(namePosDrop, "Name position")

local NAME_POS = {
  { key = "BOTTOM", text = "Bottom" },
  { key = "TOP", text = "Top" },
  { key = "LEFT", text = "Left" },
  { key = "RIGHT", text = "Right" },
}

UIDropDownMenu_Initialize(namePosDrop, function()
  for _, opt in ipairs(NAME_POS) do
    local info = UIDropDownMenu_CreateInfo()
    info.text = opt.text
    info.func = function()
      RT.db.namePos = opt.key
      UIDropDownMenu_SetText(namePosDrop, opt.text)
      RT:UpdateTracker()
    end
    UIDropDownMenu_AddButton(info)
  end
end)

-- =====================
-- REAGENT GRID
-- =====================

local ICON_SIZE = 32
local ICONS_PER_ROW = 8
local START_X = 20
local START_Y = optionsBottomY - 230
local BORDER = 2
local ROW_SPACING = 64

local function CreateIcon(parent, entry, x, y)
  local key = GetReagentKey(entry)
  local displayID = type(entry) == "table" and entry[1] or entry

  local btn = CreateFrame("Button", nil, parent)
  btn:SetPoint("TOPLEFT", x, y)
  btn:SetSize(ICON_SIZE, ICON_SIZE + 24)

  local icon = btn:CreateTexture(nil, "ARTWORK")
  icon:SetSize(ICON_SIZE, ICON_SIZE)
  icon:SetPoint("TOP")
  icon:SetTexture(C_Item.GetItemIconByID(displayID))

  local nameText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  nameText:SetPoint("TOP", icon, "BOTTOM", 0, -2)
  nameText:SetWidth(ICON_SIZE + 14)
  nameText:SetJustifyH("CENTER")
  nameText:SetText(C_Item.GetItemNameByID(displayID) or "?")

  -- BORDER (ICON ONLY)
  local border = {}
  local function edge()
    local t = btn:CreateTexture(nil, "OVERLAY")
    t:SetColorTexture(0, 1, 0, 1)
    return t
  end

  border.top = edge()
  border.top:SetPoint("TOPLEFT", icon, -BORDER, BORDER)
  border.top:SetPoint("TOPRIGHT", icon, BORDER, BORDER)
  border.top:SetHeight(BORDER)

  border.bottom = edge()
  border.bottom:SetPoint("BOTTOMLEFT", icon, -BORDER, -BORDER)
  border.bottom:SetPoint("BOTTOMRIGHT", icon, BORDER, -BORDER)
  border.bottom:SetHeight(BORDER)

  border.left = edge()
  border.left:SetPoint("TOPLEFT", icon, -BORDER, BORDER)
  border.left:SetPoint("BOTTOMLEFT", icon, -BORDER, -BORDER)
  border.left:SetWidth(BORDER)

  border.right = edge()
  border.right:SetPoint("TOPRIGHT", icon, BORDER, BORDER)
  border.right:SetPoint("BOTTOMRIGHT", icon, BORDER, -BORDER)
  border.right:SetWidth(BORDER)

  local function SetBorder(v)
    for _, t in pairs(border) do
      t:SetShown(v)
    end
  end

  btn:SetScript("OnClick", function()
    RT.db.enabled[key] = not RT.db.enabled[key]
    SetBorder(RT.db.enabled[key])
    RT:UpdateTracker()
  end)

  btn._refresh = function()
    SetBorder(RT.db.enabled[key])
  end

  btn._refresh()
  return btn
end

local function CreateOptions()
  local y = START_Y

  for expansion, items in pairs(RT_REAGENTS) do
    local header = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    header:SetPoint("TOPLEFT", 16, y)
    header:SetText(expansion)
    y = y - 26

    local col, row = 0, 0
    for _, entry in ipairs(items) do
      local x = START_X + col * (ICON_SIZE + 20)
      local iy = y - row * ROW_SPACING

      CreateIcon(panel, entry, x, iy)

      col = col + 1
      if col >= ICONS_PER_ROW then
        col = 0
        row = row + 1
      end
    end

    y = y - (row + 1) * ROW_SPACING
  end
end

panel:SetScript("OnShow", function(self)
  if self.initialized then return end
  self.initialized = true

  -- SAFE DEFAULTS
  RT.db.scale   = Num(RT.db.scale, 1)
  RT.db.spacing = Num(RT.db.spacing, 6)
  RT.db.namePos = RT.db.namePos or "BOTTOM"

  scaleSlider:SetValue(RT.db.scale)
  spacingSlider:SetValue(RT.db.spacing)
  showNames:SetChecked(RT.db.showNames)
  lockCheck:SetChecked(RT.db.locked)

  UIDropDownMenu_SetText(namePosDrop, RT.db.namePos)

  scaleSlider:SetScript("OnValueChanged", function(_, v)
    RT.db.scale = v
    RT.frame:SetScale(v)
  end)

  spacingSlider:SetScript("OnValueChanged", function(_, v)
    RT.db.spacing = v
    RT:UpdateTracker()
  end)

  showNames:SetScript("OnClick", function(self)
    RT.db.showNames = self:GetChecked()
    RT:UpdateTracker()
  end)

  lockCheck:SetScript("OnClick", function(self)
    RT.db.locked = self:GetChecked()
  end)

  resetBtn:SetScript("OnClick", function()
    RT.db.position.point = "CENTER"
    RT.db.position.relativePoint = "CENTER"
    RT.db.position.x = 0
    RT.db.position.y = 0
    RT.frame:ClearAllPoints()
    RT.frame:SetPoint("CENTER")
  end)

  CreateOptions()
end)

local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
Settings.RegisterAddOnCategory(category)
