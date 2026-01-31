local addonName, RT = ...

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
    Midnight     = "Midnight"
}

local TAB_ORDER = { "General", "Lumber", "Classic", "Outland", "Wotlk", "Cataclysm", "Pandaria", "Draenor", "Legion", "Bfa", "Shadowlands", "DragonIsles", "TheWarWithin", "Midnight" }

panel.Tabs = {} 
local ICON_SIZE = 32
local ICONS_PER_ROW = 8
local ROW_SPACING = 68

local calcFS = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
calcFS:Hide()

local function UpdateTabStyle(tab, isActive)
    if isActive then tab:LockHighlight(); tab.Text:SetTextColor(1, 0.82, 0)
    else tab:UnlockHighlight(); tab.Text:SetTextColor(1, 1, 1) end
end

local function CreateCustomTab(name, index)
    local tab = CreateFrame("Button", "RT_CustomTab"..index, panel, "UIPanelButtonTemplate")
    tab.Text = tab:GetFontString(); tab.Text:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE") 
    tab:SetText(name)
    calcFS:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE"); calcFS:SetText(name)
    tab:SetSize(calcFS:GetStringWidth() + 24, 26) 
    tab:SetScript("OnClick", function()
        panel.selectedTab = index
        for i, t in ipairs(panel.Tabs) do
            UpdateTabStyle(t, i == index)
            if t.contentFrame then t.contentFrame:SetShown(i == index) end
        end
        PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
    end)
    panel.Tabs[index] = tab
    return tab
end

local function LayoutTabs()
    local MAX_WIDTH = 610
    local startX, startY, currentX, currentY = 15, -15, 15, -15
    for i, tab in ipairs(panel.Tabs) do
        if currentX + tab:GetWidth() > MAX_WIDTH and i > 1 then
            currentX = 15; currentY = currentY - 32
        end
        tab:SetPoint("TOPLEFT", panel, "TOPLEFT", currentX, currentY)
        currentX = currentX + tab:GetWidth() + 5
    end
    return math.abs(currentY) + 32
end

local function CreateScrollableContent(parent)
    local scrollFrame = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 5, -5); scrollFrame:SetPoint("BOTTOMRIGHT", -25, 5)
    local content = CreateFrame("Frame", nil, scrollFrame); content:SetSize(580, 100); scrollFrame:SetScrollChild(content)
    return content
end

-- Заміни функцію CreateGeneralOptions у своєму options.lua на цю:

local function CreateGeneralOptions(parent)
    -- Перевірка, чи завантажена БД. Якщо ні - створюємо заглушку або чекаємо
    if not RT.db then 
        local errorMsg = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        errorMsg:SetPoint("CENTER")
        errorMsg:SetText("Database not loaded yet. Please reopen settings.")
        return 
    end

    local title = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 20, -10); title:SetText("General Settings")

    -- 1. Основний перемикач видимості
    local showTracker = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    showTracker:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
    showTracker.Text:SetText("Show Tracker Window")
    -- Перевіряємо RT.charDb (персональна база)
    showTracker:SetChecked(RT.charDb and RT.charDb.visible)
    showTracker:SetScript("OnClick", function(self)
        if RT.charDb then
            RT.charDb.visible = self:GetChecked()
            RT:UpdateTracker()
        end
    end)

    -- 2. Замок позиції
    local lock = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    lock:SetPoint("TOPLEFT", showTracker, "BOTTOMLEFT", 0, -5)
    lock.Text:SetText("Lock Tracker Position")
    lock:SetChecked(RT.db.locked)
    lock:SetScript("OnClick", function(self) RT.db.locked = self:GetChecked() end)

    -- 3. Орієнтація
    local orientBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    orientBtn:SetPoint("TOPLEFT", lock, "BOTTOMLEFT", 4, -10)
    orientBtn:SetSize(180, 26)
    orientBtn:SetText("Orientation: " .. (RT.db.orientation or "Vertical"))
    orientBtn:SetScript("OnClick", function(self)
        RT.db.orientation = (RT.db.orientation == "Vertical") and "Horizontal" or "Vertical"
        self:SetText("Orientation: " .. RT.db.orientation)
        RT:UpdateTracker()
    end)

    -- 4. Назви та Позиція тексту
    local names = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    names:SetPoint("TOPLEFT", orientBtn, "BOTTOMLEFT", -4, -10)
    names.Text:SetText("Show Reagent Names")
    names:SetChecked(RT.db.showNames)
    names:SetScript("OnClick", function(self) RT.db.showNames = self:GetChecked(); RT:UpdateTracker() end)

    local labelPos = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    labelPos:SetPoint("TOPLEFT", names, "BOTTOMLEFT", 8, -12)
    labelPos:SetText("Text Position:")

    local dropdown = CreateFrame("Frame", "RT_TextPosDropdown", parent, "UIDropDownMenuTemplate")
    dropdown:SetPoint("LEFT", labelPos, "RIGHT", -15, -2)
    UIDropDownMenu_SetWidth(dropdown, 90)
    UIDropDownMenu_SetText(dropdown, RT.db.textPosition or "Right")
    UIDropDownMenu_Initialize(dropdown, function()
        for _, side in ipairs({"Left", "Right", "Top", "Bottom"}) do
            local info = UIDropDownMenu_CreateInfo()
            info.text, info.func = side, function() 
                RT.db.textPosition = side
                UIDropDownMenu_SetText(dropdown, side)
                RT:UpdateTracker() 
            end
            UIDropDownMenu_AddButton(info)
        end
    end)

    -- 5. Чекбокси підрахунку
    local cIcon = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    cIcon:SetPoint("TOPLEFT", labelPos, "BOTTOMLEFT", -8, -10)
    cIcon.Text:SetText("Count on Icon")
    cIcon:SetChecked(RT.db.showCountOnIcon)
    cIcon:SetScript("OnClick", function(self) RT.db.showCountOnIcon = self:GetChecked(); RT:UpdateTracker() end)

    local cName = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    cName:SetPoint("TOPLEFT", cIcon, "BOTTOMLEFT", 0, -5)
    cName.Text:SetText("Count in Name")
    cName:SetChecked(RT.db.showCountInName)
    cName:SetScript("OnClick", function(self) RT.db.showCountInName = self:GetChecked(); RT:UpdateTracker() end)

    -- Функція слайдерів з перевіркою
    local function CreateSlider(label, min, max, dbKey, yOff, step)
        local s = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
        s:SetPoint("TOPLEFT", 20, yOff) 
        s:SetMinMaxValues(min, max)
        s:SetValueStep(step or 1)
        s:SetWidth(200)
        local currentVal = RT.db[dbKey] or min
        s.Text:SetText(label .. ": " .. currentVal)
        s:SetValue(currentVal)
        s:SetScript("OnValueChanged", function(self, v)
            if step and step < 1 then v = math.floor(v * 100) / 100 else v = math.floor(v) end
            RT.db[dbKey] = v
            self.Text:SetText(label .. ": " .. v)
            RT:UpdateTracker()
        end)
        return s
    end

    CreateSlider("Icon Size", 16, 64, "iconSize", -300)
    CreateSlider("Counter Font", 8, 30, "counterFontSize", -340)
    CreateSlider("Name Font", 8, 24, "nameFontSize", -380)
    CreateSlider("Spacing", 0, 50, "spacing", -420)
    
    CreateSlider("Menu Scale", 0.5, 1.5, "detailScale", -540, 0.05):SetScript("OnValueChanged", function(self, v)
        -- Округлюємо значення до найближчого кроку 0.05
        v = math.floor(v * 20 + 0.5) / 20
        RT.db.detailScale = v
        self.Text:SetText("Menu Scale: " .. string.format("%.2f", v))
        RT:UpdateTracker()
        RT:UpdateDetailFrameSettings()
    end)

    CreateSlider("Menu Font Size", 8, 24, "detailFontSize", -580):SetScript("OnValueChanged", function(self, v)
        if step and step < 1 then v = math.floor(v * 100) / 100 else v = math.floor(v) end
        RT.db.detailFontSize = v
        self.Text:SetText("Menu Font Size: " .. v)
        RT:UpdateTracker()
        RT:UpdateDetailFrameSettings() -- Додаємо цей виклик
    end)
    
    local reset = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    reset:SetPoint("TOPLEFT", 20, -460); reset:SetSize(140, 26); reset:SetText("Reset Position")
    reset:SetScript("OnClick", function()
        RT.db.position = { point = "CENTER", relativePoint = "CENTER", x = 0, y = 0 }
        if RT.frame then
            RT.frame:ClearAllPoints()
            RT.frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        end
    end)

    local dTitle = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    dTitle:SetPoint("TOPLEFT", 20, -500); dTitle:SetText("Detail Menu Settings:")
    
    -- Експаншени (права колонка)
    local expTitle = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    expTitle:SetPoint("TOPLEFT", parent, "TOP", 60, -10); expTitle:SetText("Show Expansions:")
    local lastExp = expTitle
    
    -- Перевірка наявності таблиці showExpansion
    RT.db.showExpansion = RT.db.showExpansion or {}
    
    for _, key in ipairs(TAB_ORDER) do
        if key ~= "General" then
            local cb = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
            cb:SetPoint("TOPLEFT", lastExp, "BOTTOMLEFT", 0, -2)
            cb.Text:SetText(EXPANSION_NAMES[key] or key)
            cb:SetChecked(RT.db.showExpansion[key] ~= false)
            cb:SetScript("OnClick", function(self) 
                RT.db.showExpansion[key] = self:GetChecked()
                RT:UpdateTracker() 
            end)
            lastExp = cb
        end
    end
    parent:SetHeight(800) 
end

local function PopulateExpansionTab(frame, key)
    local data = RT_REAGENTS[key]
    if not data then return end
    
    local y = -15
    local loopData = (data[1] ~= nil) and { [EXPANSION_NAMES[key] or key] = data } or data
    
    local sortedCategories = {}
    for catName in pairs(loopData) do table.insert(sortedCategories, catName) end
    
    local categoryOrder = { ["Mining"] = 1, ["Herbalism"] = 2, ["Leather"] = 3, ["Cloth"] = 4, ["Fishing"] = 6 }
    table.sort(sortedCategories, function(a, b)
        return (categoryOrder[a] or 100) < (categoryOrder[b] or 100)
    end)
    
    for _, catName in ipairs(sortedCategories) do
        local reagents = loopData[catName]
        local h = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        h:SetPoint("TOPLEFT", 20, y); h:SetText(catName); h:SetTextColor(1, 0.82, 0)
        
        y = y - 25 
        local col, row = 0, 0

        for _, entry in ipairs(reagents) do
            local itemKey = (type(entry) == "table") and table.concat(entry, "_") or tostring(entry)
            local displayID = type(entry) == "table" and (type(entry[1]) == "table" and entry[1][1] or entry[1]) or entry
            
            local btn = CreateFrame("Button", nil, frame)
            btn:SetSize(ICON_SIZE, ICON_SIZE + 28)
            btn:SetPoint("TOPLEFT", 20 + col * (ICON_SIZE + 40), y - row * ROW_SPACING)
            
            local icon = btn:CreateTexture(nil, "ARTWORK")
            icon:SetSize(ICON_SIZE, ICON_SIZE); icon:SetPoint("TOP")
            icon:SetTexture(C_Item.GetItemIconByID(displayID))
            
            local nameText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            nameText:SetPoint("TOP", icon, "BOTTOM", 0, -4); nameText:SetWidth(ICON_SIZE + 35); nameText:SetJustifyH("CENTER"); nameText:SetWordWrap(true)
            
            local currentName = C_Item.GetItemNameByID(displayID)