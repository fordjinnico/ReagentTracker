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

local function CreateGeneralOptions(parent)
    if not RT.db then
        local errorMsg = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        errorMsg:SetPoint("CENTER")
        errorMsg:SetText("|cffff0000Error: Database not loaded. Please reload the UI.|r")
        return
    end

    local title = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 20, -10); title:SetText("General Settings")

    local lock = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    lock:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10); lock.text:SetText("Lock Tracker Position")
    lock:SetChecked(RT.db.locked); lock:SetScript("OnClick", function(self) RT.db.locked = self:GetChecked() end)

    local orientBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    orientBtn:SetPoint("TOPLEFT", lock, "BOTTOMLEFT", 0, -10); orientBtn:SetSize(180, 26)
    orientBtn:SetText("Orientation: " .. (RT.db.orientation or "Vertical"))
    orientBtn:SetScript("OnClick", function(self)
        RT.db.orientation = (RT.db.orientation == "Vertical") and "Horizontal" or "Vertical"
        self:SetText("Orientation: " .. RT.db.orientation); RT:UpdateTracker()
    end)

    local names = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    names:SetPoint("TOPLEFT", orientBtn, "BOTTOMLEFT", 0, -10); names.text:SetText("Show Reagent Names")
    names:SetChecked(RT.db.showNames); names:SetScript("OnClick", function(self) RT.db.showNames = self:GetChecked(); RT:UpdateTracker() end)

    local labelPos = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    labelPos:SetPoint("TOPLEFT", names, "BOTTOMLEFT", 25, -5); labelPos:SetText("Text Position:")

    local dropdown = CreateFrame("Frame", "RT_TextPosDropdown", parent, "UIDropDownMenuTemplate")
    dropdown:SetPoint("LEFT", labelPos, "RIGHT", -15, -2); UIDropDownMenu_SetWidth(dropdown, 90)
    UIDropDownMenu_SetText(dropdown, RT.db.textPosition or "Right")
    UIDropDownMenu_Initialize(dropdown, function()
        for _, side in ipairs({"Left", "Right", "Top", "Bottom"}) do
            local info = UIDropDownMenu_CreateInfo()
            info.text, info.func = side, function() RT.db.textPosition = side; UIDropDownMenu_SetText(dropdown, side); RT:UpdateTracker() end
            UIDropDownMenu_AddButton(info)
        end
    end)

    local cIcon = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cIcon:SetPoint("TOPLEFT", labelPos, "BOTTOMLEFT", -5, -10); cIcon.text:SetText("Count on Icon")
    cIcon:SetChecked(RT.db.showCountOnIcon); cIcon:SetScript("OnClick", function(self) RT.db.showCountOnIcon = self:GetChecked(); RT:UpdateTracker() end)

    local cName = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cName:SetPoint("TOPLEFT", cIcon, "BOTTOMLEFT", 0, -5); cName.text:SetText("Count in Name")
    cName:SetChecked(RT.db.showCountInName); cName:SetScript("OnClick", function(self) RT.db.showCountInName = self:GetChecked(); RT:UpdateTracker() end)

    local function CreateSlider(label, min, max, dbKey, rel, yOff, step)
        local s = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
        s:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, yOff) 
        s:SetMinMaxValues(min, max); s:SetValueStep(step or 1); s:SetWidth(200)
        s.Text:SetText(label .. ": " .. (RT.db[dbKey] or min))
        s:SetValue(RT.db[dbKey] or min)
        s:SetScript("OnValueChanged", function(self, v)
            if step and step < 1 then v = math.floor(v * 100) / 100 else v = math.floor(v) end
            RT.db[dbKey] = v; self.Text:SetText(label .. ": " .. v); RT:UpdateTracker()
            if RT_DetailMenu and RT_DetailMenu:IsShown() then 
                RT_DetailMenu:SetScale(RT.db.detailScale or 1)
                local fPath, fSize = "Fonts\\FRIZQT__.TTF", RT.db.detailFontSize or 12
                if RT_DetailMenu.title then RT_DetailMenu.title:SetFont(fPath, fSize + 2, "OUTLINE") end
                for _, row in ipairs(RT_DetailMenu.rows) do
                    if row.name then row.name:SetFont(fPath, fSize, "") end
                    if row.total then row.total:SetFont(fPath, fSize, "OUTLINE") end
                    if row.subRows then
                        for _, sr in ipairs(row.subRows) do
                            if sr.char then sr.char:SetFont(fPath, fSize - 2, "") end
                            if sr.details then sr.details:SetFont(fPath, fSize - 2, "") end
                        end
                    end
                end
            end
        end)
        return s
    end

    local s1 = CreateSlider("Icon Size", 16, 64, "iconSize", nil, -260)
    local s2 = CreateSlider("Counter Font", 8, 30, "counterFontSize", nil, -300)
    local s3 = CreateSlider("Name Font", 8, 24, "nameFontSize", nil, -340)
    local s4 = CreateSlider("Spacing", 0, 50, "spacing", nil, -380)
    
    local reset = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    reset:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, -420); reset:SetSize(140, 26); reset:SetText("Reset Position")
    reset:SetScript("OnClick", function()
        RT.db.position = { point = "CENTER", relativePoint = "CENTER", x = 0, y = 0 }
        RT.frame:ClearAllPoints(); RT.frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end)

    local dTitle = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    dTitle:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, -470); dTitle:SetText("Detail Menu (Tooltip) Settings:")
    
    local ds1 = CreateSlider("Menu Scale", 0.5, 2, "detailScale", nil, -510, 0.05)
    local ds2 = CreateSlider("Menu Font Size", 8, 24, "detailFontSize", nil, -550)

    -- Експаншени (права колонка)
    local expTitle = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    expTitle:SetPoint("TOPLEFT", parent, "TOP", 60, -10); expTitle:SetText("Show Expansions:")
    local lastExp = expTitle
    for _, key in ipairs(TAB_ORDER) do
        if key ~= "General" then
            local cb = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
            cb:SetPoint("TOPLEFT", lastExp, "BOTTOMLEFT", 0, -2); cb.Text:SetText(EXPANSION_NAMES[key] or key)
            cb:SetChecked(RT.db.showExpansion[key] ~= false)
            cb:SetScript("OnClick", function(self) RT.db.showExpansion[key] = self:GetChecked(); RT:UpdateTracker() end)
            lastExp = cb
        end
    end
    parent:SetHeight(780) 
end

local function PopulateExpansionTab(frame, key)
    local data = RT_REAGENTS[key]
    if not data then return end
    
    local y = -15
    local loopData = (data[1] ~= nil) and { [EXPANSION_NAMES[key] or key] = data } or data
    
    local sortedCategories = {}
    for catName in pairs(loopData) do
        table.insert(sortedCategories, catName)
    end
    
    -- =====================
    -- Inner categories order for menu
    -- =====================
    local categoryOrder = {
        ["Mining"] = 1, ["Herbalism"] = 2, 
        ["Leather"] = 3, ["Cloth"] = 4, ["Essences"] = 5, ["Motes"] = 5, ["Fishing"] = 6, ["Food"] = 7
    }
    
    table.sort(sortedCategories, function(a, b)
        local orderA = categoryOrder[a] or 100
        local orderB = categoryOrder[b] or 100
        return orderA < orderB
    end)
    
    for _, catName in ipairs(sortedCategories) do
        local reagents = loopData[catName]
        
        local h = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        h:SetPoint("TOPLEFT", 20, y)
        h:SetText(catName)
        h:SetTextColor(1, 0.82, 0)
        
        y = y - 25 
        
        local col, row = 0, 0
        local itemsInThisCat = 0

        for _, entry in ipairs(reagents) do
            local itemKey = (type(entry) == "table") and table.concat(entry, "_") or tostring(entry)
            local displayID = type(entry) == "table" and (type(entry[1]) == "table" and entry[1][1] or entry[1]) or entry
            
            local btn = CreateFrame("Button", nil, frame)
            btn:SetSize(ICON_SIZE, ICON_SIZE + 28)
            btn:SetPoint("TOPLEFT", 20 + col * (ICON_SIZE + 40), y - row * ROW_SPACING)
            
            local icon = btn:CreateTexture(nil, "ARTWORK")
            icon:SetSize(ICON_SIZE, ICON_SIZE)
            icon:SetPoint("TOP")
            icon:SetTexture(C_Item.GetItemIconByID(displayID))
            
            local nameText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            nameText:SetPoint("TOP", icon, "BOTTOM", 0, -4)
            nameText:SetWidth(ICON_SIZE + 35)
            nameText:SetJustifyH("CENTER")
            nameText:SetWordWrap(true)
            
            local currentName = C_Item.GetItemNameByID(displayID)
            if currentName and currentName ~= "" then
                nameText:SetText(currentName)
            else
                nameText:SetText("...")
                ItemEventListener:AddCallback(displayID, function()
                    local loadedName = C_Item.GetItemNameByID(displayID)
                    if loadedName then nameText:SetText(loadedName) end
                end)
            end
            
            local function UpdateVisuals()
                local active = RT.db.enabled[itemKey]
                icon:SetAlpha(active and 1 or 0.3)
                nameText:SetTextColor(active and 1 or 0.5, active and 1 or 0.5, active and 1 or 0.5)
            end
            
            btn:SetScript("OnClick", function() 
                RT.db.enabled[itemKey] = not RT.db.enabled[itemKey]
                UpdateVisuals()
                RT:UpdateTracker() 
            end)
            
            UpdateVisuals()
            itemsInThisCat = itemsInThisCat + 1
            col = col + 1
            if col >= ICONS_PER_ROW then col = 0; row = row + 1 end
        end

        local finalRows = (col > 0) and (row + 1) or row
        y = y - (finalRows * ROW_SPACING) - 10
    end
    
    frame:SetHeight(math.abs(y) + 20)
end

panel:SetScript("OnShow", function(self)
    if not RT.db then
        print("|cffff0000Error: Database not loaded. Please reload the UI.|r")
        return
    end

    if self.initialized then return end
    for i, key in ipairs(TAB_ORDER) do
        local tab = CreateCustomTab(EXPANSION_NAMES[key] or key, i)
        local wrapper = CreateFrame("Frame", nil, panel)
        tab.contentFrame = wrapper
        local scrollChild = CreateScrollableContent(wrapper)
        if key == "General" then CreateGeneralOptions(scrollChild) else PopulateExpansionTab(scrollChild, key) end
    end
    local h = LayoutTabs()
    for _, t in ipairs(panel.Tabs) do
        t.contentFrame:SetPoint("TOPLEFT", 10, -h - 20); t.contentFrame:SetPoint("BOTTOMRIGHT", -10, 10); t.contentFrame:Hide()
    end
    local line = panel:CreateTexture(nil, "ARTWORK"); line:SetTexture("Interface\\Common\\UI-TooltipDivider-Transparent")
    line:SetHeight(2); line:SetPoint("TOPLEFT", 15, -h - 15); line:SetPoint("TOPRIGHT", -15, -h - 15)
    panel.Tabs[1]:Click(); self.initialized = true
end)

local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
Settings.RegisterAddOnCategory(category)

local function SlashHandler(msg)
    msg = msg:lower():trim()
    
    if msg == "show" then
        if RT.charDb then
            RT.charDb.visible = true
            RT:UpdateTracker()
            print("|cff00ff00Reagent Tracker: Show for " .. UnitName("player") .. " |r")
        end
    elseif msg == "hide" then
        if RT.charDb then
            RT.charDb.visible = false
            RT:UpdateTracker()
            print("|cffff0000Reagent Tracker: Hide for " .. UnitName("player") .. " |r")
        end
    else
        Settings.OpenToCategory(category:GetID())
    end
end

SlashCmdList["REAGENTTRACKER"] = SlashHandler
SLASH_REAGENTTRACKER1, SLASH_REAGENTTRACKER2, SLASH_REAGENTTRACKER3 = "/reagents", "/rtr", "/reagenttracker"