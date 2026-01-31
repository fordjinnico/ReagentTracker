local panel = CreateFrame("Frame")
panel.name = "Reagent Tracker"

-- Словник для гарних назв табів
local EXPANSION_NAMES = {
    General      = "General",
    Lumber       = "Lumber",
    Classic      = "Classic",
    Outland      = "Outland",
    Wotlk        = "WoTLK",
    Cataclysm    = "Cataclysm",
    Pandaria     = "Pandaria",
    Draenor      = "Draenor",
    Legion       = "Legion",
    Bfa          = "BfA",
    Shadowlands  = "Shadowlands",
    DragonIsles  = "Dragon Isles",
    TheWarWithin = "The War Within",
}

local TAB_ORDER = { "General", "Lumber", "Classic", "Outland", "Wotlk", "Cataclysm", "Pandaria", "Draenor", "Legion", "Bfa", "Shadowlands", "DragonIsles", "TheWarWithin" }

local tabs = {}
local ICON_SIZE = 32
local ICONS_PER_ROW = 8
local ROW_SPACING = 68 -- Трохи збільшив, щоб назви не наповзали

-- =====================
-- ДОПОМІЖНІ ФУНКЦІЇ
-- =====================

local function GetReagentKey(entry)
    if type(entry) == "table" then return table.concat(entry, "_") end
    return tostring(entry)
end

local function ShowTab(index)
    PanelTemplates_SetTab(panel, index)
    for i, tab in ipairs(tabs) do
        if tab.content then tab.content:SetShown(i == index) end
    end
end

local tabX, tabY = 20, -40
local function CreateTab(name, index)
    local tab = CreateFrame("Button", "RT_Tab"..index, panel, "PanelTabButtonTemplate")
    tab:SetID(index)
    tab:SetText(name)
    PanelTemplates_TabResize(tab, 0)
    local width = tab:GetTextWidth() + 25
    if tabX + width > 610 then
        tabX = 20
        tabY = tabY - 30
    end
    tab:SetPoint("TOPLEFT", panel, "TOPLEFT", tabX, tabY)
    tabX = tabX + width + 5
    tab:SetScript("OnClick", function() ShowTab(index) end)
    tabs[index] = tab
    return tab
end

-- =====================
-- СТВОРЕННЯ ІКОНОК (З НАЗВАМИ)
-- =====================

local function CreateIcon(parent, entry, x, y)
    local key = GetReagentKey(entry)
    local displayID = type(entry) == "table" and entry[1] or entry

    local btn = CreateFrame("Button", nil, parent)
    btn:SetPoint("TOPLEFT", x, y)
    btn:SetSize(ICON_SIZE, ICON_SIZE + 28)

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetSize(ICON_SIZE, ICON_SIZE)
    icon:SetPoint("TOP")
    icon:SetTexture(C_Item.GetItemIconByID(displayID))

    -- ПОВЕРНУЛИ НАЗВУ В МЕНЮ
    local nameText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameText:SetPoint("TOP", icon, "BOTTOM", 0, -4)
    nameText:SetWidth(ICON_SIZE + 30)
    nameText:SetJustifyH("CENTER")
    nameText:SetWordWrap(true)
    nameText:SetText(C_Item.GetItemNameByID(displayID) or "...")

    local border = {}
    for _, side in ipairs({ "top", "bottom", "left", "right" }) do
        local t = btn:CreateTexture(nil, "OVERLAY")
        t:SetColorTexture(0, 1, 0, 1)
        border[side] = t
    end
    border.top:SetPoint("TOPLEFT", icon, -2, 2); border.top:SetPoint("TOPRIGHT", icon, 2, 2); border.top:SetHeight(2)
    border.bottom:SetPoint("BOTTOMLEFT", icon, -2, -2); border.bottom:SetPoint("BOTTOMRIGHT", icon, 2, -2); border.bottom:SetHeight(2)
    border.left:SetPoint("TOPLEFT", icon, -2, 2); border.left:SetPoint("BOTTOMLEFT", icon, -2, -2); border.left:SetWidth(2)
    border.right:SetPoint("TOPRIGHT", icon, 2, 2); border.right:SetPoint("BOTTOMRIGHT", icon, 2, -2); border.right:SetWidth(2)

    local function UpdateVisuals()
        local active = RT.db.enabled[key]
        for _, t in pairs(border) do t:SetShown(active) end
        icon:SetAlpha(active and 1 or 0.5)
        if active then
            nameText:SetTextColor(1, 1, 1)
        else
            nameText:SetTextColor(0.5, 0.5, 0.5)
        end
    end

    btn:SetScript("OnClick", function()
        RT.db.enabled[key] = not RT.db.enabled[key]
        UpdateVisuals()
        RT:UpdateTracker()
    end)
    UpdateVisuals()
end

-- =====================
-- ТАБ GENERAL (БЕЗ ЗМІН)
-- =====================

local function CreateGeneralOptions(parent)
    local title = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 20, -10)
    title:SetText("General Settings")

    local lock = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    lock:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -15)
    lock.text:SetText("Lock Tracker Position")
    lock:SetChecked(RT.db.locked)
    lock:SetScript("OnClick", function(self) RT.db.locked = self:GetChecked() end)

    local names = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    names:SetPoint("TOPLEFT", lock, "BOTTOMLEFT", 0, -5)
    names.text:SetText("Show Reagent Names in Tracker")
    names:SetChecked(RT.db.showNames)
    names:SetScript("OnClick", function(self) RT.db.showNames = self:GetChecked(); RT:UpdateTracker() end)

    local size = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    size:SetPoint("TOPLEFT", names, "BOTTOMLEFT", 10, -30)
    size:SetMinMaxValues(16, 64); size:SetValueStep(1); size:SetWidth(180)
    size.Text:SetText("Icon Size: " .. (RT.db.iconSize or 32))
    size:SetValue(RT.db.iconSize or 32)
    size:SetScript("OnValueChanged", function(self, v) 
        v = math.floor(v); RT.db.iconSize = v; self.Text:SetText("Icon Size: "..v); RT:UpdateTracker() 
    end)

    local cFont = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    cFont:SetPoint("TOPLEFT", size, "BOTTOMLEFT", 0, -40)
    cFont:SetMinMaxValues(8, 30); cFont:SetValueStep(1); cFont:SetWidth(180)
    cFont.Text:SetText("Counter Font Size: " .. (RT.db.counterFontSize or 14))
    cFont:SetValue(RT.db.counterFontSize or 14)
    cFont:SetScript("OnValueChanged", function(self, v) 
        v = math.floor(v); RT.db.counterFontSize = v; self.Text:SetText("Counter Font Size: "..v); RT:UpdateTracker() 
    end)

    local nFont = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    nFont:SetPoint("TOPLEFT", cFont, "BOTTOMLEFT", 0, -40)
    nFont:SetMinMaxValues(8, 24); nFont:SetValueStep(1); nFont:SetWidth(180)
    nFont.Text:SetText("Name Font Size: " .. (RT.db.nameFontSize or 12))
    nFont:SetValue(RT.db.nameFontSize or 12)
    nFont:SetScript("OnValueChanged", function(self, v) 
        v = math.floor(v); RT.db.nameFontSize = v; self.Text:SetText("Name Font Size: "..v); RT:UpdateTracker() 
    end)

    local reset = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    reset:SetPoint("TOPLEFT", nFont, "BOTTOMLEFT", -10, -30)
    reset:SetSize(130, 25); reset:SetText("Reset Position")
    reset:SetScript("OnClick", function()
        RT.db.position = { point = "CENTER", relativePoint = "CENTER", x = 0, y = 0 }
        RT.frame:ClearAllPoints()
        RT.frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end)
end

-- =====================
-- ТАБИ ЕКСПАНШЕНІВ
-- =====================

local function PopulateExpansionTab(frame, key)
    local data = RT_REAGENTS[key]
    if not data then return end
    local y = -15
    local isFlat = data[1] ~= nil
    local loopData = isFlat and { [EXPANSION_NAMES[key] or key] = data } or data

    for catName, reagents in pairs(loopData) do
        local h = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        h:SetPoint("TOPLEFT", 20, y)
        h:SetText(catName)
        h:SetTextColor(1, 0.82, 0)
        y = y - 25
        local col, row = 0, 0
        for _, entry in ipairs(reagents) do
            CreateIcon(frame, entry, 20 + col * (ICON_SIZE + 35), y - row * ROW_SPACING)
            col = col + 1
            if col >= ICONS_PER_ROW then col = 0; row = row + 1 end
        end
        y = y - (row + 1) * ROW_SPACING - 15
    end
end

panel:SetScript("OnShow", function(self)
    if self.initialized then return end
    for i, key in ipairs(TAB_ORDER) do
        local tab = CreateTab(EXPANSION_NAMES[key] or key, i)
        local content = CreateFrame("Frame", nil, panel)
        content:SetPoint("TOPLEFT", 0, -100); content:SetPoint("BOTTOMRIGHT")
        content:Hide(); tab.content = content
        if key == "General" then CreateGeneralOptions(content) else PopulateExpansionTab(content, key) end
    end
    panel.numTabs = #tabs
    panel.Tabs = tabs
    ShowTab(1)
    self.initialized = true
end)

local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
Settings.RegisterAddOnCategory(category)