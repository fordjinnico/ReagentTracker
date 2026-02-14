local addonName, RT = ...
RT.IconFrames = RT.IconFrames or {}

local function GetQualityIcon(quality)
    if not quality or quality < 1 or quality > 3 then return "" end
    local atlas = ({"Professions-Icon-Quality-Tier1", "Professions-Icon-Quality-Tier2", "Professions-Icon-Quality-Tier3"})[quality]
    return CreateAtlasMarkup(atlas, 18, 18)
end

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

function RT:GetAccountWideCount(entry)
    if not self.db then return 0 end
    local itemIDs = (type(entry) == "table") and entry or {entry}
    local total = 0
    for _, id in ipairs(itemIDs) do
        total = total + (self.db.warbandItems and self.db.warbandItems[id] or 0)
        if self.db.charData then
            for _, data in pairs(self.db.charData) do
                total = total + (data.items and data.items[id] or 0) + (data.bankItems and data.bankItems[id] or 0)
            end
        end
    end
    return total
end

function RT:CalculatePotentialForData(targetID, itemsTable, bankTable)
    if not RT_PIGMENTREAGENTS then return 0 end
    local potential = 0
    for sourceID, data in pairs(RT_PIGMENTREAGENTS) do
        if data.output and data.output[targetID] then
            local count = (itemsTable and itemsTable[sourceID] or 0) + (bankTable and bankTable[sourceID] or 0)
            if count >= data.input then
                potential = potential + (math.floor(count / data.input) * data.output[targetID])
            end
        end
    end
    return math.floor(potential)
end

local function GetGlobalPotential(self, targetID)
    if not RT_PIGMENTREAGENTS then return 0 end
    local totalPot = 0
    for sourceID, data in pairs(RT_PIGMENTREAGENTS) do
        if data.output[targetID] then
            local c = self:GetAccountWideCount(sourceID)
            totalPot = totalPot + (math.floor(c / data.input) * data.output[targetID])
        end
    end
    return totalPot
end

local detailFrame, sourceFrame

local function CloseAllMenus()
    if detailFrame then detailFrame:Hide() end
    if sourceFrame then sourceFrame:Hide() end
    if GameTooltip:GetOwner() == detailFrame or GameTooltip:GetOwner() == sourceFrame then
        GameTooltip:Hide()
    end
end

detailFrame = CreateFrame("Frame", "RT_DetailMenu", UIParent, "BackdropTemplate")
detailFrame:SetClampedToScreen(true); detailFrame:SetFrameStrata("TOOLTIP")
detailFrame:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 }
})
detailFrame:SetBackdropColor(0, 0, 0, 0.9); detailFrame:Hide()
detailFrame:SetScript("OnHide", function() if sourceFrame then sourceFrame:Hide() end end)

sourceFrame = CreateFrame("Frame", "RT_SourceMenu", UIParent, "BackdropTemplate")
sourceFrame:SetClampedToScreen(true); sourceFrame:SetFrameStrata("TOOLTIP")
sourceFrame:SetBackdrop(detailFrame:GetBackdrop()); sourceFrame:SetBackdropColor(0, 0, 0, 0.9); sourceFrame:Hide()

local clickWatcher = CreateFrame("Frame")
clickWatcher:RegisterEvent("GLOBAL_MOUSE_DOWN")
clickWatcher:SetScript("OnEvent", function()
    if detailFrame:IsShown() then
        if not detailFrame:IsMouseOver() and not sourceFrame:IsMouseOver() then
            CloseAllMenus()
        end
    end
end)

local close = CreateFrame("Button", nil, detailFrame, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", 2, 2); close:SetScale(0.8); close:SetScript("OnClick", CloseAllMenus)

detailFrame.rows = {}; sourceFrame.rows = {}

local function CreateLocationRows(parentRow, locations, startY, fPath, fSize)
    local yLocal = startY
    for i, loc in ipairs(locations) do
        if not parentRow.subRows[i] then
            local sr = CreateFrame("Frame", nil, parentRow:GetParent())
            sr:SetSize(parentRow:GetWidth() - 10, 16)
            sr.left = sr:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); sr.left:SetPoint("LEFT", 35, 0)
            sr.right = sr:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); sr.right:SetPoint("RIGHT", -5, 0)
            parentRow.subRows[i] = sr
        end
        local sr = parentRow.subRows[i]
        sr.left:SetFont(fPath, fSize - 2, ""); sr.right:SetFont(fPath, fSize - 2, "")
        sr.left:SetText(loc.name)
        local countStr = loc.isWarband and ("Warband: " .. (loc.total or 0)) or (string.format("Bags: %d, Bank: %d", loc.bags or 0, loc.bank or 0))
        if loc.pot and loc.pot > 0 then countStr = countStr .. " |cff00ff00(+" .. loc.pot .. ")|r" end
        sr.right:SetText(countStr); sr:SetPoint("TOPLEFT", parentRow, "TOPLEFT", 0, yLocal); sr:Show()
        yLocal = yLocal - 16
    end
    return math.abs(yLocal)
end

local function SetSmartTooltipAnchor(ownerFrame)
    GameTooltip:SetOwner(ownerFrame, "ANCHOR_NONE")
    local x, _ = ownerFrame:GetCenter()
    if x > (GetScreenWidth() / 2) then
        local target = sourceFrame:IsShown() and sourceFrame or detailFrame
        GameTooltip:SetPoint("TOPRIGHT", target, "TOPLEFT", -5, 0)
    else
        local target = sourceFrame:IsShown() and sourceFrame or detailFrame
        GameTooltip:SetPoint("TOPLEFT", target, "TOPRIGHT", 5, 0)
    end
end

local function ShowSourceMenu(anchor, targetID)
    if not RT_PIGMENTREAGENTS then return end
    sourceFrame:ClearAllPoints()
    local x, _ = anchor:GetCenter()
    if x > (GetScreenWidth() / 2) then
        sourceFrame:SetPoint("TOPRIGHT", anchor, "TOPLEFT", -10, 0)
    else
        sourceFrame:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 10, 0)
    end
    sourceFrame:Show()
    
    for _, r in ipairs(sourceFrame.rows) do r:Hide(); if r.subRows then for _, sr in ipairs(r.subRows) do sr:Hide() end end end

    local yOffset, rowIndex, fPath, fSize, MENU_WIDTH = -15, 1, "Fonts\\FRIZQT__.TTF", RT.db.detailFontSize or 12, 340
    for herbID, data in pairs(RT_PIGMENTREAGENTS) do
        if data.output[targetID] then
            local count = RT:GetAccountWideCount(herbID)
            if not sourceFrame.rows[rowIndex] then
                local r = CreateFrame("Frame", nil, sourceFrame)
                r:SetSize(MENU_WIDTH - 20, 26); r:EnableMouse(true)
                r.icon = r:CreateTexture(nil, "ARTWORK"); r.icon:SetSize(22, 22); r.icon:SetPoint("LEFT", 5, 0)
                r.name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); r.name:SetPoint("LEFT", r.icon, "RIGHT", 5, 0)
                r.total = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); r.total:SetPoint("RIGHT", -5, 0)
                r.subRows = {}
                r:SetScript("OnEnter", function(s) 
                    SetSmartTooltipAnchor(sourceFrame)
                    GameTooltip:SetItemByID(s.itemID); GameTooltip:Show() 
                end)
                r:SetScript("OnLeave", function() GameTooltip:Hide() end)
                sourceFrame.rows[rowIndex] = r
            end
            local r = sourceFrame.rows[rowIndex]
            r.itemID = herbID; r.name:SetFont(fPath, fSize, ""); r.total:SetFont(fPath, fSize, "OUTLINE")
            r.icon:SetTexture(C_Item.GetItemIconByID(herbID))
            local hName = C_Item.GetItemNameByID(herbID) or "Loading..."
            if count == 0 then
                r.name:SetText("|cff888888" .. hName .. "|r"); r.total:SetText("|cff8888880|r"); r.icon:SetDesaturated(true)
            else
                local potential = math.floor((count / data.input) * data.output[targetID])
                r.name:SetText(hName); r.total:SetText(string.format("%d |cff00ff00(+%d)|r", count, potential)); r.icon:SetDesaturated(false)
            end
            local locs = {}
            if count > 0 then
                local currentName = UnitName("player") .. "-" .. GetRealmName()
                local b = C_Item.GetItemCount(herbID, false, false, false, false) or 0
                local bk = (C_Item.GetItemCount(herbID, true, false, false, false) or 0) - b
                if b > 0 or bk > 0 then table.insert(locs, {name = GetClassColorName(currentName), bags = b, bank = bk}) end
                if RT.db.charData then
                    for k, v in pairs(RT.db.charData) do
                        if k ~= currentName then
                            local cB, cBk = v.items and v.items[herbID] or 0, v.bankItems and v.bankItems[herbID] or 0
                            if (cB + cBk) > 0 then table.insert(locs, {name = GetClassColorName(k), bags = cB, bank = cBk}) end
                        end
                    end
                end
                local wb = RT.db.warbandItems and RT.db.warbandItems[herbID] or 0
                if wb > 0 then table.insert(locs, {name = "|cffeda55fWarband|r", total = wb, isWarband = true}) end
            end
            r:SetPoint("TOPLEFT", 10, yOffset); r:Show()
            local hRow = (count > 0 and #locs > 0) and CreateLocationRows(r, locs, -26, fPath, fSize) or 26
            yOffset = yOffset - hRow - 8; rowIndex = rowIndex + 1
        end
    end
    if rowIndex == 1 then sourceFrame:Hide() else sourceFrame:SetSize(MENU_WIDTH, math.abs(yOffset) + 10) end
end

local function ShowDetailMenu(anchor, entry, title)
    if not RT.db then return end
    detailFrame:SetScale(RT.db.detailScale or 1); sourceFrame:SetScale(RT.db.detailScale or 1)
    local fSize, fPath, MENU_WIDTH = RT.db.detailFontSize or 12, "Fonts\\FRIZQT__.TTF", 340
    detailFrame:ClearAllPoints(); local x, _ = anchor:GetCenter()
    if x > (GetScreenWidth() / 2) then detailFrame:SetPoint("TOPRIGHT", anchor, "TOPLEFT", -15, 0)
    else detailFrame:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 15, 0) end
    detailFrame:Show()
    
    for _, row in ipairs(detailFrame.rows) do row:Hide(); if row.subRows then for _, sr in ipairs(row.subRows) do sr:Hide() end end end
    if not detailFrame.title then detailFrame.title = detailFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal") end
    detailFrame.title:SetFont(fPath, fSize + 2, "OUTLINE"); detailFrame.title:SetPoint("TOPLEFT", 12, -12); detailFrame.title:SetText("|cffffd100" .. title .. "|r")

    local yOffset, rowIndex = -38, 1
    local ids = (type(entry) == "table") and entry or {entry}
    for _, id in ipairs(ids) do
        local locs, currentName = {}, UnitName("player") .. "-" .. GetRealmName()
        local b = C_Item.GetItemCount(id, false, false, false, false) or 0
        local bk = (C_Item.GetItemCount(id, true, false, false, false) or 0) - b
        local pPot = RT:CalculatePotentialForData(id, RT.db.charData[currentName] and RT.db.charData[currentName].items, RT.db.charData[currentName] and RT.db.charData[currentName].bankItems)
        if b > 0 or bk > 0 or pPot > 0 then table.insert(locs, {name = GetClassColorName(currentName), bags = b, bank = bk, pot = pPot}) end
        if RT.db.charData then
            for k, v in pairs(RT.db.charData) do
                if k ~= currentName then
                    local cB, cBk = v.items and v.items[id] or 0, v.bankItems and v.bankItems[id] or 0
                    local cPot = RT:CalculatePotentialForData(id, v.items, v.bankItems)
                    if (cB + cBk) > 0 or cPot > 0 then table.insert(locs, { name = GetClassColorName(k), bags = cB, bank = cBk, pot = cPot }) end
                end
            end
        end
        local wb = RT.db.warbandItems and RT.db.warbandItems[id] or 0
        local wbPot = RT:CalculatePotentialForData(id, RT.db.warbandItems, nil)
        if wb > 0 or wbPot > 0 then table.insert(locs, {name = "|cffeda55fWarband|r", total = wb, isWarband = true, pot = wbPot}) end

        if not detailFrame.rows[rowIndex] then
            local r = CreateFrame("Frame", nil, detailFrame)
            r:SetSize(MENU_WIDTH - 20, 26); r:EnableMouse(true)
            r.icon = r:CreateTexture(nil, "ARTWORK"); r.icon:SetSize(22, 22); r.icon:SetPoint("LEFT", 5, 0)
            r.name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); r.name:SetPoint("LEFT", r.icon, "RIGHT", 5, 0)
            r.total = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); r.total:SetPoint("RIGHT", -5, 0)
            r.subRows = {}
            r:SetScript("OnEnter", function(s) 
                SetSmartTooltipAnchor(detailFrame)
                GameTooltip:SetItemByID(s.itemID); GameTooltip:Show() 
            end)
            r:SetScript("OnLeave", function() GameTooltip:Hide() end)
            r:SetScript("OnMouseDown", function(s, btn) if btn == "LeftButton" then ShowSourceMenu(detailFrame, s.itemID) end end)
            detailFrame.rows[rowIndex] = r
        end
        local r = detailFrame.rows[rowIndex]; r.itemID = id
        r.name:SetFont(fPath, fSize, ""); r.total:SetFont(fPath, fSize, "OUTLINE"); r.icon:SetTexture(C_Item.GetItemIconByID(id))
        r.name:SetText((C_Item.GetItemNameByID(id) or "Loading...") .. " " .. GetQualityIcon(C_TradeSkillUI.GetItemReagentQualityByItemInfo(id)))
        r.total:SetText(RT:GetAccountWideCount(id) .. (GetGlobalPotential(RT, id) > 0 and (" |cff00ff00(+" .. GetGlobalPotential(RT, id) .. ")|r") or ""))
        r:SetPoint("TOPLEFT", 10, yOffset); r:Show()
        yOffset = yOffset - CreateLocationRows(r, locs, -26, fPath, fSize) - 8; rowIndex = rowIndex + 1
    end
    detailFrame:SetSize(MENU_WIDTH, math.abs(yOffset) + 15)
end

function RT:UpdateTracker()
    if not self.frame or not self.db or not self.charDb then return end
    if self.charDb.visible == false then self.frame:Hide(); return else self.frame:Show() end

    for _, f in ipairs(RT.IconFrames) do f:Hide() end
    local activeElements = {}
    local function Collect(data, exp)
        if exp and self.db.showExpansion[exp] == false then return end
        if type(data) == "table" and data[1] then
            for _, e in ipairs(data) do 
                local key = type(e) == "table" and table.concat(e, "_") or tostring(e)
                if self.db.enabled[key] then table.insert(activeElements, e) end 
            end
        else
            for _, sub in pairs(data) do if type(sub) == "table" then Collect(sub, exp) end end
        end
    end
    if RT_REAGENTS then for k, v in pairs(RT_REAGENTS) do Collect(v, k) end end

    local offsetX, offsetY, maxRowW, maxRowH = 0, 0, 0, 0
    local pos, isH = self.db.textPosition or "Right", (self.db.orientation == "Horizontal")
    local mainAnchor = (pos == "Left" and not isH) and "TOPRIGHT" or (pos == "Bottom" and "TOP" or (pos == "Top" and "BOTTOM" or "TOPLEFT"))

    for i, entry in ipairs(activeElements) do
        local key = type(entry) == "table" and table.concat(entry, "_") or tostring(entry)
        local displayID = type(entry) == "table" and (type(entry[1]) == "table" and entry[1][1] or entry[1]) or entry
        local count = self:GetAccountWideCount(entry)
        local potential = (type(entry) == "table") and (function() local p=0; for _, id in ipairs(entry) do p=p+GetGlobalPotential(self, id) end; return p end)() or GetGlobalPotential(self, entry)

        local row = RT.IconFrames[i] or CreateFrame("Frame", nil, self.frame)
        if not RT.IconFrames[i] then
            row:EnableMouse(true); row:RegisterForDrag("LeftButton")
            row.tex = row:CreateTexture(nil, "ARTWORK"); row.tex:SetAllPoints(row)
            row.txt = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            row.fsIcon = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            RT.IconFrames[i] = row
        end
        row:Show(); row:SetSize(self.db.iconSize, self.db.iconSize); row.tex:SetTexture(C_Item.GetItemIconByID(displayID))
        
        local goal, countLabel = self.db.goals[key], tostring(count)
        if goal and goal > 0 then countLabel = count .. "/" .. goal end
        if potential > 0 then countLabel = countLabel .. " |cff00ff00(+" .. potential .. ")|r" end

        row.txt:SetFont(row.txt:GetFont(), self.db.nameFontSize)
        local nameStr = C_Item.GetItemNameByID(displayID) or "Loading..."
        row.txt:SetText((self.db.showNames and self.db.showCountInName) and (nameStr .. ": " .. countLabel) or (self.db.showNames and nameStr or (self.db.showCountInName and countLabel or "")))
        
        local txtAnchor = {Right={"LEFT",row,"RIGHT",8,0}, Left={"RIGHT",row,"LEFT",-8,0}, Top={"BOTTOM",row,"TOP",0,4}, Bottom={"TOP",row,"BOTTOM",0,-4}}
        row.txt:ClearAllPoints(); row.txt:SetPoint(unpack(txtAnchor[pos])); row.txt:SetShown(self.db.showNames or self.db.showCountInName)
        row.txt:SetTextColor(goal and count >= goal and 0 or 1, goal and count >= goal and 1 or 0.82, 0)

        row.fsIcon:ClearAllPoints(); row.fsIcon:SetPoint("BOTTOMRIGHT", row, -1, 1); row.fsIcon:SetFont(row.fsIcon:GetFont(), self.db.counterFontSize, "OUTLINE")
        row.fsIcon:SetText(countLabel); row.fsIcon:SetShown(self.db.showCountOnIcon)

        row:SetScript("OnEnter", function(s)
            if IsMouseButtonDown("LeftButton") then return end
            GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
            if type(entry) == "table" then
                GameTooltip:AddLine(nameStr, 1, 0.82, 0)
                for _, id in ipairs(entry) do
                    local tID = self:GetAccountWideCount(id); local q = C_TradeSkillUI.GetItemReagentQualityByItemInfo(id)
                    GameTooltip:AddDoubleLine(GetQualityIcon(q) .. " " .. (C_Item.GetItemNameByID(id) or "Loading..."), (tID > 0 and "|cffffffff" or "|cff888888") .. tID .. "|r")
                end
            else 
                GameTooltip:SetItemByID(displayID) 
            end
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)

        row:SetScript("OnMouseDown", function(_, btn)
            if btn == "LeftButton" then
                if IsShiftKeyDown() then 
                    self.db.enabled[key] = false; self:UpdateTracker()
                else 
                    ShowDetailMenu(row, entry, nameStr)
                    local isPigment = false
                    if RT_PIGMENTREAGENTS then
                        for _, data in pairs(RT_PIGMENTREAGENTS) do
                            if data.output[displayID] then isPigment = true; break end
                        end
                    end
                    if potential > 0 or isPigment then 
                        ShowSourceMenu(detailFrame, displayID) 
                    end
                end
            elseif btn == "RightButton" then
                if IsShiftKeyDown() then self.db.goals[key] = nil; self:UpdateTracker()
                else local p = StaticPopup_Show("RT_SET_GOAL"); if p then p.data = {key=key} end end
            end
        end)
        row:SetScript("OnDragStart", function() if not self.db.locked then CloseAllMenus(); self.frame:StartMoving() end end)
        row:SetScript("OnDragStop", function() self.frame:StopMovingOrSizing(); local p, _, rp, x, y = self.frame:GetPoint(); self.db.position = {point=p, relativePoint=rp, x=x, y=y} end)

        row:ClearAllPoints(); local spc, sz = self.db.spacing or 5, self.db.iconSize
        if isH then
            row:SetPoint("LEFT", self.frame, "LEFT", offsetX, 0)
            offsetX = offsetX + sz + (row.txt:IsShown() and (row.txt:GetStringWidth() + 12) or 0) + spc
            maxRowH = math.max(maxRowH, sz); maxRowW = offsetX
        else
            row:SetPoint(mainAnchor, self.frame, mainAnchor, 0, offsetY)
            offsetY = offsetY - (sz + (row.txt:IsShown() and (pos == "Top" or pos == "Bottom") and (row.txt:GetStringHeight() + 8) or 0)) - spc
            maxRowW = math.max(maxRowW, sz + (row.txt:IsShown() and (pos == "Left" or pos == "Right") and (row.txt:GetStringWidth() + 12) or 0))
            maxRowH = math.abs(offsetY)
        end
    end
    self.frame:SetSize(maxRowW > 0 and maxRowW or 32, maxRowH > 0 and maxRowH or 32)
end

function RT:CreateTracker()
    if self.frame then return end
    self.frame = CreateFrame("Frame", "RT_MainFrame", UIParent)
    local p = self.db and self.db.position or {point="CENTER", relativePoint="CENTER", x=0, y=0}
    self.frame:SetPoint(p.point, UIParent, p.relativePoint, p.x, p.y)
    self.frame:SetMovable(true); self.frame:SetClampedToScreen(true); self.frame:EnableMouse(true)
end