local addonName, RT = ...

-- Допоміжна функція для ключів БД
local function GetReagentKey(entry)
    if type(entry) == "table" then return table.concat(entry, "_") end
    return tostring(entry)
end

-- Отримання іконки якості
local function GetQualityIcon(quality)
    if not quality or quality < 1 or quality > 3 then return "" end
    local atlas = ({"Professions-Icon-Quality-Tier1", "Professions-Icon-Quality-Tier2", "Professions-Icon-Quality-Tier3"})[quality]
    return CreateAtlasMarkup(atlas, 18, 18)
end

-- Отримання кольору імені персонажа
local function GetClassColorName(fullName)
    if not fullName then return "|cffccccccUnknown|r" end
    local shortName = string.split("-", fullName)
    local data = RT.db and RT.db.charData and RT.db.charData[fullName]
    local classFile = data and data.class
    
    if not classFile and fullName == (UnitName("player") .. "-" .. GetRealmName()) then
        _, classFile = UnitClass("player")
    end

    if not classFile then return "|cffcccccc" .. shortName .. "|r" end
    local color = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[classFile]
    return string.format("|c%s%s|r", color.colorStr, shortName)
end

-- =====================
-- ДЕТАЛІЗАЦІЯ (MENU)
-- =====================
local detailFrame = CreateFrame("Frame", "RT_DetailMenu", UIParent, "BackdropTemplate")
detailFrame:SetClampedToScreen(true)
detailFrame:SetFrameStrata("TOOLTIP")
detailFrame:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
})
detailFrame:SetBackdropColor(0, 0, 0, 0.9)
detailFrame:Hide()

local close = CreateFrame("Button", nil, detailFrame, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", 2, 2); close:SetScale(0.8)
close:SetScript("OnClick", function() detailFrame:Hide() end)

detailFrame.rows = {}

-- Функція для оновлення параметрів тултіпу
function RT:UpdateDetailFrameSettings()
    if not detailFrame then return end

    -- Перевірка значення detailScale
    local scale = self.db.detailScale or 1
    if scale < 0.5 then scale = 0.5 end
    if scale > 1.5 then scale = 1.5 end
    self.db.detailScale = scale

    -- Застосовуємо масштабування
    detailFrame:SetScale(scale)

    local fSize = self.db.detailFontSize or 12
    local fPath = "Fonts\\FRIZQT__.TTF"

    if detailFrame.title then
        detailFrame.title:SetFont(fPath, fSize + 2, "OUTLINE")
    end

    for _, row in ipairs(detailFrame.rows) do
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

local function ShowDetailMenu(anchor, entry, title)
    if not RT.db then return end
    
    -- Перевірка: якщо це не таблиця (одиничний предмет), меню не показуємо
    if type(entry) ~= "table" then return end

    -- Оновлюємо масштабування перед показом
    RT:UpdateDetailFrameSettings()

    local fSize = RT.db.detailFontSize or 12
    local fPath = "Fonts\\FRIZQT__.TTF"

    detailFrame:ClearAllPoints()
    local x, y = anchor:GetCenter()
    if x > (GetScreenWidth() / 2) then
        detailFrame:SetPoint("TOPRIGHT", anchor, "TOPLEFT", -15, 0)
    else
        detailFrame:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 15, 0)
    end
    
    detailFrame:Show()
    
    for _, row in ipairs(detailFrame.rows) do 
        row:Hide() 
        if row.subRows then for _, sr in ipairs(row.subRows) do sr:Hide() end end
    end

    if not detailFrame.title then
        detailFrame.title = detailFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    end
    detailFrame.title:SetFont(fPath, fSize + 2, "OUTLINE")
    detailFrame.title:SetPoint("TOPLEFT", 12, -12)
    detailFrame.title:SetText("|cffffd100" .. title .. "|r")

    local yOffset, rowIndex = -38, 1
    local ICON_SIZE, ROW_HEIGHT_ITEM, ROW_HEIGHT_SUB, MENU_WIDTH = 22, 26, 16, 280
    local itemIDs = entry

    for _, id in ipairs(itemIDs) do
        local currentName = UnitName("player") .. "-" .. GetRealmName()
        local bags = C_Item.GetItemCount(id, false, false, false, false) or 0
        local bank = (C_Item.GetItemCount(id, true, false, false, false) or 0) - bags
        local warband = (C_Item.GetItemCount(id, true, false, true, true) or 0) - (bags + bank)

        local locations = {}
        local itemTotal = warband + bags + bank

        if RT.db.charData then
            for charKey, data in pairs(RT.db.charData) do
                if charKey ~= currentName then
                    local countInBags = data.items and data.items[id] or 0
                    local countInBank = data.bankItems and data.bankItems[id] or 0
                    if (countInBags + countInBank) > 0 then
                        table.insert(locations, { name = GetClassColorName(charKey), bags = countInBags, bank = countInBank })
                        itemTotal = itemTotal + countInBags + countInBank
                    end
                end
            end
        end

        if itemTotal > 0 then
            if not detailFrame.rows[rowIndex] then
                local r = CreateFrame("Frame", nil, detailFrame)
                r:SetSize(MENU_WIDTH - 20, ROW_HEIGHT_ITEM)
                r:EnableMouse(true)
                r.icon = r:CreateTexture(nil, "ARTWORK"); r.icon:SetSize(ICON_SIZE, ICON_SIZE); r.icon:SetPoint("LEFT", 5, 0)
                r.name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); r.name:SetPoint("LEFT", r.icon, "RIGHT", 5, 0)
                r.total = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); r.total:SetPoint("RIGHT", -5, 0)
                
                -- ПРИВ'ЯЗКА ТУЛТІПА ДО МЕНЮ
                r:SetScript("OnEnter", function(self)
                    GameTooltip:SetOwner(detailFrame, "ANCHOR_NONE") -- Важливо: ANCHOR_NONE для ручного позиціонування
                    GameTooltip:SetPoint("TOPLEFT", detailFrame, "TOPRIGHT", 5, 0)
                    GameTooltip:SetItemByID(self.itemID)
                    GameTooltip:Show()
                end)
                r:SetScript("OnLeave", function() GameTooltip:Hide() end)
                
                r.subRows = {}
                detailFrame.rows[rowIndex] = r
            end
            
            local r = detailFrame.rows[rowIndex]
            r.itemID = id
            r.name:SetFont(fPath, fSize, "")
            r.total:SetFont(fPath, fSize, "OUTLINE")
            r.icon:SetTexture(C_Item.GetItemIconByID(id))
            local q = C_TradeSkillUI.GetItemReagentQualityByItemInfo(id)
            r.name:SetText((C_Item.GetItemNameByID(id) or "Loading...") .. " " .. GetQualityIcon(q))
            r.total:SetText("|cffffffff" .. itemTotal .. "|r")
            r:SetPoint("TOPLEFT", 10, yOffset); r:Show()
            
            yOffset = yOffset - ROW_HEIGHT_ITEM

            local tempLocs = {}
            if bags > 0 or bank > 0 then table.insert(tempLocs, {name = GetClassColorName(currentName), bags = bags, bank = bank}) end
            for _, loc in ipairs(locations) do table.insert(tempLocs, loc) end
            if warband > 0 then table.insert(tempLocs, {name = "|cffeda55fWarband|r", total = warband}) end

            for i, loc in ipairs(tempLocs) do
                if not r.subRows[i] then
                    local sr = CreateFrame("Frame", nil, detailFrame)
                    sr:SetSize(MENU_WIDTH - 30, ROW_HEIGHT_SUB)
                    sr.char = sr:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); sr.char:SetPoint("LEFT", 35, 0)
                    sr.details = sr:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); sr.details:SetPoint("RIGHT", -5, 0)
                    r.subRows[i] = sr
                end
                local sr = r.subRows[i]
                sr.char:SetFont(fPath, fSize - 2, "")
                sr.details:SetFont(fPath, fSize - 2, "")
                sr.char:SetText(loc.name)
                if loc.total then sr.details:SetText(loc.total)
                else
                    local p = {}
                    if loc.bags and loc.bags > 0 then table.insert(p, "Bags: " .. loc.bags) end
                    if loc.bank and loc.bank > 0 then table.insert(p, "Bank: " .. loc.bank) end
                    sr.details:SetText(table.concat(p, ", "))
                end
                sr:SetPoint("TOPLEFT", 0, yOffset); sr:Show()
                yOffset = yOffset - ROW_HEIGHT_SUB
            end
            yOffset = yOffset - 5
            rowIndex = rowIndex + 1
        end
    end
    detailFrame:SetSize(MENU_WIDTH, math.abs(yOffset) + 15)
end

-- =====================
-- ТРЕКЕР ТА ОНОВЛЕННЯ
-- =====================
function RT:GetAccountWideCount(entry)
    if not self.db or not self.db.charData then return 0 end
    local itemIDs = (type(entry) == "table") and entry or {entry}
    local total = 0
    local currentKey = UnitName("player") .. "-" .. GetRealmName()
    for _, id in ipairs(itemIDs) do
        total = total + (C_Item.GetItemCount(id, true, false, true, true) or 0)
        for charKey, data in pairs(self.db.charData) do
            if charKey ~= currentKey then
                total = total + (data.items and data.items[id] or 0)
                total = total + (data.bankItems and data.bankItems[id] or 0)
            end
        end
    end
    return total
end

function RT:UpdateTracker()

    if not self.frame or not self.db or not self.charDb then return end
    
    if self.charDb.visible == false then
        self.frame:Hide()
        return
    else
        self.frame:Show()
    end

    self.db.goals = self.db.goals or {}
    self.db.enabled = self.db.enabled or {}
    self.db.showExpansion = self.db.showExpansion or {}
    
    for _, f in ipairs(self.icons or {}) do f:Hide() end
    self.icons = self.icons or {}
    wipe(self.icons)

    self:UpdateDetailFrameSettings() -- Додаємо цей виклик

    local activeElements = {}
    local function Collect(data, exp)
        if exp and self.db.showExpansion[exp] == false then return end
        if type(data) == "table" and data[1] then
            for _, e in ipairs(data) do if self.db.enabled[GetReagentKey(e)] then table.insert(activeElements, e) end end
        else
            for _, sub in pairs(data) do if type(sub) == "table" then Collect(sub, exp) end end
        end
    end
    if RT_REAGENTS then for k, v in pairs(RT_REAGENTS) do Collect(v, k) end end

    local offsetX, offsetY, totalW, totalH = 0, 0, 0, 0
    local pos = self.db.textPosition or "Right"

    for _, entry in ipairs(activeElements) do
        local key = GetReagentKey(entry)
        local displayID = type(entry) == "table" and (type(entry[1]) == "table" and entry[1][1] or entry[1]) or entry
        local count = self:GetAccountWideCount(entry)
        local goal = self.db.goals[key]

        local row = CreateFrame("Frame", nil, self.frame)
        row:SetSize(self.db.iconSize, self.db.iconSize); row:EnableMouse(true); row:RegisterForDrag("LeftButton")

        local tex = row:CreateTexture(nil, "ARTWORK"); tex:SetAllPoints(row); tex:SetTexture(C_Item.GetItemIconByID(displayID))
        local txt = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        txt:SetFont(txt:GetFont(), self.db.nameFontSize)

        -- ======
        -- name formatting in tracker window
        -- ======
        local nameStr = C_Item.GetItemNameByID(displayID) or "Loading..."
        
        local countText = (goal and goal > 0) and string.format("%d/%d", count, goal) or tostring(count)
        local displayText = ""
        
        if self.db.showNames then
            if self.db.showCountInName then
                displayText = nameStr .. ": " .. countText
            else
                displayText = nameStr
            end
        elseif self.db.showCountInName then
            displayText = countText
        end
        
        txt:SetText(displayText)
        
        txt:ClearAllPoints()
        if pos == "Right" then txt:SetPoint("LEFT", row, "RIGHT", 8, 0)
        elseif pos == "Left" then txt:SetPoint("RIGHT", row, "LEFT", -8, 0)
        elseif pos == "Top" then txt:SetPoint("BOTTOM", row, "TOP", 0, 4)
        elseif pos == "Bottom" then txt:SetPoint("TOP", row, "BOTTOM", 0, -4) end
        
        txt:SetShown(self.db.showNames or self.db.showCountInName)

        -- ======
        -- /name formatting in tracker window end/
        -- ======

        if goal and count >= goal then txt:SetTextColor(0, 1, 0) else txt:SetTextColor(1, 0.82, 0) end

        local fsIcon = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fsIcon:SetPoint("BOTTOMRIGHT", row, -1, 1)
        fsIcon:SetFont(fsIcon:GetFont(), self.db.counterFontSize, "OUTLINE")
        
        if goal and goal > 0 then
            fsIcon:SetText(string.format("%d/%d", count, goal))
            -- Додаємо колір: якщо мета досягнута - зелений, якщо ні - білий/жовтий
            if count >= goal then
                fsIcon:SetTextColor(0, 1, 0) -- Зелений
            else
                fsIcon:SetTextColor(1, 1, 1) -- Білий (або 1, 0.82, 0 для золотого)
            end
        else
            fsIcon:SetText(count)
            fsIcon:SetTextColor(1, 1, 1)
        end
        
        fsIcon:SetShown(self.db.showCountOnIcon)

      row:SetScript("OnEnter", function(s)
            -- Визначаємо сторону для тултіпа
            if detailFrame:IsShown() then
                local x, _ = s:GetCenter()
                if x > (GetScreenWidth() / 2) then
                    GameTooltip:SetOwner(s, "ANCHOR_LEFT")
                else
                    GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
                end
            else
                GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
            end

            if type(entry) == "table" then
                GameTooltip:AddLine(nameStr, 1, 0.82, 0)
                
                -- Використовуємо ту саму логіку підрахунку, що і в детальному меню
                for _, id in ipairs(entry) do
                    -- Викликаємо нашу функцію для повного підрахунку по аккаунту для конкретного ID
                    local totalForID = self:GetAccountWideCount(id)
                    
                    if totalForID > 0 then
                        local q = C_TradeSkillUI.GetItemReagentQualityByItemInfo(id)
                        local qualityMarkup = GetQualityIcon(q)
                        local itemName = C_Item.GetItemNameByID(id) or "Loading..."
                        
                        -- Виводимо рядок: Іконка Якості + Назва | Загальна кількість
                        GameTooltip:AddDoubleLine(qualityMarkup .. " " .. itemName, "|cffffffff" .. totalForID .. "|r", 1, 1, 1, 1, 1, 1)
                    end
                end
                GameTooltip:AddLine("\n|cff00ff00<Left-Click to Pin Details>|r")
            else 
                GameTooltip:SetItemByID(displayID) 
            end
            
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)

        row:SetScript("OnMouseDown", function(_, btn)
            if btn == "LeftButton" then ShowDetailMenu(row, entry, nameStr)
            elseif btn == "RightButton" then 
                local popup = StaticPopup_Show("RT_SET_GOAL")
                if popup then popup.data = { key = key } end
            end
        end)

        row:SetScript("OnDragStart", function() if not self.db.locked then self.frame:StartMoving() end end)
        row:SetScript("OnDragStop", function() 
            self.frame:StopMovingOrSizing() 
            local p, _, rp, x, y = self.frame:GetPoint()
            self.db.position = { point = p, relativePoint = rp, x = x, y = y }
        end)

        local step = self.db.iconSize + self.db.spacing
        if self.db.orientation == "Horizontal" then
            row:SetPoint("LEFT", self.frame, offsetX, 0)
            offsetX = offsetX + step + (self.db.showNames and (pos == "Right" or pos == "Left") and (txt:GetStringWidth() + 8) or 0)
            totalW, totalH = offsetX, step
        else
            row:SetPoint("TOP", self.frame, 0, offsetY)
            offsetY = offsetY - step
            totalW, totalH = math.max(totalW, (self.db.showNames and (pos == "Right" or pos == "Left") and (step + txt:GetStringWidth() + 8) or step)), math.abs(offsetY)
        end
        table.insert(self.icons, row)
    end
    self.frame:SetSize(totalW > 0 and totalW or 32, totalH > 0 and totalH or 32)
end

function RT:CreateTracker()
    if self.frame then return end
    self.frame = CreateFrame("Frame", "RT_MainFrame", UIParent)
    local p = self.db and self.db.position or {point="CENTER", relativePoint="CENTER", x=0, y=0}
    self.frame:SetPoint(p.point, UIParent, p.relativePoint, p.x, p.y)
    self.frame:SetMovable(true); self.frame:SetClampedToScreen(true); self.frame:EnableMouse(true)
    self.icons = {}
end