local panel = CreateFrame("Frame")
panel.name = "Reagent Tracker"

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
    Bfa          = "Battle for Azeroth",
    Shadowlands  = "Shadowlands",
    DragonIsles  = "Dragon Isles",
    TheWarWithin = "The War Within",
}

local TAB_ORDER = { "General", "Lumber", "Classic", "Outland", "Wotlk", "Cataclysm", "Pandaria", "Draenor", "Legion", "Bfa", "Shadowlands", "DragonIsles", "TheWarWithin" }

panel.Tabs = {} 
local ICON_SIZE = 32
local ICONS_PER_ROW = 8
local ROW_SPACING = 68

local calcFS = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
calcFS:Hide()

-- =====================
-- СТИЛІЗАЦІЯ ПІД ДИЗАЙН WOW
-- =====================

local function UpdateTabStyle(tab, isActive)
    if isActive then
        -- Ефект натиснутої золотої кнопки
        tab:LockHighlight()
        tab.Text:SetTextColor(1, 0.82, 0) -- Класичний золотий текст WoW
    else
        tab:UnlockHighlight()
        tab.Text:SetTextColor(1, 1, 1) -- Білий текст для неактивних
    end
end

local function CreateCustomTab(name, index)
    -- Використовуємо UIPanelButtonTemplate для "рідного" вигляду
    local tab = CreateFrame("Button", "RT_CustomTab"..index, panel, "UIPanelButtonTemplate")
    
    -- ТЕКСТ (12 розмір, як ти просив)
    tab.Text = tab:GetFontString()
    tab.Text:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE") 
    tab:SetText(name)

    -- РОЗРАХУНОК (Текст + 24 пікселі відступу для солідності)
    calcFS:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    calcFS:SetText(name)
    local textWidth = calcFS:GetStringWidth()
    
    tab:SetSize(textWidth + 24, 26) 

    tab:SetScript("OnClick", function()
        panel.selectedTab = index
        for i, t in ipairs(panel.Tabs) do
            UpdateTabStyle(t, i == index)
            if t.contentFrame then t.contentFrame:SetShown(i == index) end
        end
        PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB) -- Звук кліку як у грі
    end)

    panel.Tabs[index] = tab
    UpdateTabStyle(tab, false)
    return tab
end

local function LayoutTabs()
    local MAX_WIDTH = 610
    local startX, startY = 15, -15
    local currentX, currentY = startX, startY
    local rowHeight = 32 
    local horizontalGap = 5

    for i, tab in ipairs(panel.Tabs) do
        local w = tab:GetWidth()
        if currentX + w > MAX_WIDTH and i > 1 then
            currentX = startX
            currentY = currentY - rowHeight
        end
        tab:SetPoint("TOPLEFT", panel, "TOPLEFT", currentX, currentY)
        currentX = currentX + w + horizontalGap
    end
    return math.abs(currentY) + rowHeight
end

-- =====================
-- КОНТЕНТ
-- =====================

local function CreateScrollableContent(parent)
    local scrollFrame = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 5, -5)
    scrollFrame:SetPoint("BOTTOMRIGHT", -25, 5)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(580, 100)
    scrollFrame:SetScrollChild(content)
    
    return content, scrollFrame
end

local function CreateGeneralOptions(parent)
    local title = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 20, -10); title:SetText("General Settings")

    local lock = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    lock:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
    lock.text:SetText("Lock Tracker Position")
    lock:SetChecked(RT.db.locked)
    lock:SetScript("OnClick", function(self) RT.db.locked = self:GetChecked() end)

    local orientBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    orientBtn:SetPoint("TOPLEFT", lock, "BOTTOMLEFT", 0, -10)
    orientBtn:SetSize(180, 26)
    orientBtn:SetText("Orientation: " .. (RT.db.orientation or "Vertical"))
    orientBtn:SetScript("OnClick", function(self)
        RT.db.orientation = (RT.db.orientation == "Vertical") and "Horizontal" or "Vertical"
        self:SetText("Orientation: " .. RT.db.orientation); RT:UpdateTracker()
    end)

    local names = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    names:SetPoint("TOPLEFT", orientBtn, "BOTTOMLEFT", 0, -10)
    names.text:SetText("Show Reagent Names")
    names:SetChecked(RT.db.showNames)
    names:SetScript("OnClick", function(self) RT.db.showNames = self:GetChecked(); RT:UpdateTracker() end)

    local labelPos = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    labelPos:SetPoint("TOPLEFT", names, "BOTTOMLEFT", 25, -5); labelPos:SetText("Text Position:")

    local dropdown = CreateFrame("Frame", "RT_TextPosDropdown", parent, "UIDropDownMenuTemplate")
    dropdown:SetPoint("LEFT", labelPos, "RIGHT", -15, -2); UIDropDownMenu_SetWidth(dropdown, 90)
    UIDropDownMenu_SetText(dropdown, RT.db.textPosition or "Right")
    UIDropDownMenu_Initialize(dropdown, function()
        for _, side in ipairs({"Left", "Right", "Top", "Bottom"}) do
            local info = UIDropDownMenu_CreateInfo()
            info.text, info.func = side, function()
                RT.db.textPosition = side; UIDropDownMenu_SetText(dropdown, side); RT:UpdateTracker()
            end
            UIDropDownMenu_AddButton(info)
        end
    end)

    local cIcon = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cIcon:SetPoint("TOPLEFT", labelPos, "BOTTOMLEFT", -5, -10)
    cIcon.text:SetText("Count on Icon")
    cIcon:SetChecked(RT.db.showCountOnIcon)
    cIcon:SetScript("OnClick", function(self) RT.db.showCountOnIcon = self:GetChecked(); RT:UpdateTracker() end)

    local cName = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cName:SetPoint("TOPLEFT", cIcon, "BOTTOMLEFT", 0, -5)
    cName.text:SetText("Count in Name")
    cName:SetChecked(RT.db.showCountInName)
    cName:SetScript("OnClick", function(self) RT.db.showCountInName = self:GetChecked(); RT:UpdateTracker() end)

    local expTitle = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    expTitle:SetPoint("TOPLEFT", parent, "TOP", 60, -10); expTitle:SetText("Show Expansions:")

    local lastExp = expTitle
    for _, key in ipairs(TAB_ORDER) do
        if key ~= "General" then
            local cb = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
            cb:SetPoint("TOPLEFT", lastExp, "BOTTOMLEFT", 0, -2)
            cb.Text:SetText(EXPANSION_NAMES[key] or key)
            cb:SetChecked(RT.db.showExpansion[key] ~= false)
            cb:SetScript("OnClick", function(self) RT.db.showExpansion[key] = self:GetChecked(); RT:UpdateTracker() end)
            lastExp = cb
        end
    end

    local function CreateSlider(label, min, max, dbKey, yOff)
        local s = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
        s:SetPoint("TOPLEFT", cName, "BOTTOMLEFT", -10, yOff)
        s:SetMinMaxValues(min, max); s:SetValueStep(1); s:SetWidth(200)
        s.Text:SetText(label .. ": " .. (RT.db[dbKey] or min))
        s:SetValue(RT.db[dbKey] or min)
        s:SetScript("OnValueChanged", function(self, v)
            v = math.floor(v); RT.db[dbKey] = v; self.Text:SetText(label .. ": " .. v); RT:UpdateTracker()
        end)
        return s
    end

    CreateSlider("Icon Size", 16, 64, "iconSize", -45)
    CreateSlider("Counter Font", 8, 30, "counterFontSize", -85)
    CreateSlider("Name Font", 8, 24, "nameFontSize", -125)
    CreateSlider("Spacing", 0, 50, "spacing", -165)
    
    local reset = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    reset:SetPoint("TOPLEFT", cName, "BOTTOMLEFT", 0, -220) 
    reset:SetSize(140, 26); reset:SetText("Reset Position")
    reset:SetScript("OnClick", function()
        RT.db.position = { point = "CENTER", relativePoint = "CENTER", x = 0, y = 0 }
        RT.frame:ClearAllPoints(); RT.frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end)
    
    parent:SetHeight(560) 
end

local function PopulateExpansionTab(frame, key)
    local data = RT_REAGENTS[key]
    if not data then return end
    local y, loopData = -15, (data[1] ~= nil) and { [EXPANSION_NAMES[key] or key] = data } or data

    for catName, reagents in pairs(loopData) do
        local h = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        h:SetPoint("TOPLEFT", 20, y); h:SetText(catName); h:SetTextColor(1, 0.82, 0)
        y = y - 25
        local col, row = 0, 0
        for _, entry in ipairs(reagents) do
            local itemKey = (type(entry) == "table") and table.concat(entry, "_") or tostring(entry)
            local displayID = type(entry) == "table" and entry[1] or entry
            local btn = CreateFrame("Button", nil, frame)
            btn:SetPoint("TOPLEFT", 20 + col * (ICON_SIZE + 40), y - row * ROW_SPACING)
            btn:SetSize(ICON_SIZE, ICON_SIZE + 28)

            local icon = btn:CreateTexture(nil, "ARTWORK")
            icon:SetSize(ICON_SIZE, ICON_SIZE); icon:SetPoint("TOP")
            icon:SetTexture(C_Item.GetItemIconByID(displayID))

            local nameText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            nameText:SetPoint("TOP", icon, "BOTTOM", 0, -4); nameText:SetWidth(ICON_SIZE + 35)
            nameText:SetJustifyH("CENTER"); nameText:SetWordWrap(true)
            nameText:SetText(C_Item.GetItemNameByID(displayID) or "...")

            local function UpdateVisuals()
                local active = RT.db.enabled[itemKey]
                icon:SetAlpha(active and 1 or 0.3)
                nameText:SetTextColor(active and 1 or 0.5, active and 1 or 0.5, active and 1 or 0.5)
            end
            btn:SetScript("OnClick", function() RT.db.enabled[itemKey] = not RT.db.enabled[itemKey]; UpdateVisuals(); RT:UpdateTracker() end)
            UpdateVisuals()

            col = col + 1
            if col >= ICONS_PER_ROW then col = 0; row = row + 1 end
        end
        y = y - (row + 1) * ROW_SPACING - 15
    end
    frame:SetHeight(math.abs(y) + 20)
end

-- =====================
-- ІНІЦІАЛІЗАЦІЯ
-- =====================

panel:SetScript("OnShow", function(self)
    if self.initialized then return end
    
    for i, key in ipairs(TAB_ORDER) do
        local tab = CreateCustomTab(EXPANSION_NAMES[key] or key, i)
        local wrapper = CreateFrame("Frame", nil, panel)
        tab.contentFrame = wrapper
        
        local scrollChild, _ = CreateScrollableContent(wrapper)
        if key == "General" then CreateGeneralOptions(scrollChild) else PopulateExpansionTab(scrollChild, key) end
    end

    local h = LayoutTabs()

    for _, t in ipairs(panel.Tabs) do
        t.contentFrame:SetPoint("TOPLEFT", 10, -h - 20)
        t.contentFrame:SetPoint("BOTTOMRIGHT", -10, 10)
        t.contentFrame:Hide()
    end

    local line = panel:CreateTexture(nil, "ARTWORK")
    line:SetTexture("Interface\\Common\\UI-TooltipDivider-Transparent")
    line:SetHeight(2); line:SetPoint("TOPLEFT", 15, -h - 15); line:SetPoint("TOPRIGHT", -15, -h - 15)

    panel.Tabs[1]:Click()
    self.initialized = true
end)

local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
Settings.RegisterAddOnCategory(category)

SlashCmdList["REAGENTTRACKER"] = function() Settings.OpenToCategory(category:GetID()) end
SLASH_REAGENTTRACKER1, SLASH_REAGENTTRACKER2 = "/reagents", "/rtr"