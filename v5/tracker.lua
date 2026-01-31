local function GetReagentKey(entry)
    if type(entry) == "table" then
        return table.concat(entry, "_")
    end
    return tostring(entry)
end

function RT:CreateTracker()
    if self.frame then return end

    local f = CreateFrame("Frame", "RT_MainFrame", UIParent)
    local pos = self.db.position
    f:SetPoint(pos.point, UIParent, pos.relativePoint, pos.x, pos.y)
    f:SetScale(self.db.scale or 1)
    f:SetSize(1, 1)

    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")

    f:SetScript("OnDragStart", function(frame)
        if not RT.db.locked then
            frame:StartMoving()
        end
    end)

    f:SetScript("OnDragStop", function(frame)
        frame:StopMovingOrSizing()
        local point, _, relativePoint, x, y = frame:GetPoint()
        RT.db.position.point = point
        RT.db.position.relativePoint = relativePoint
        RT.db.position.x = x
        RT.db.position.y = y
    end)

    self.frame = f
    self.icons = {}
end

function RT:GetGroupedItemCount(entry)
    local function count(id)
        return C_Item.GetItemCount(id, true, false, true, true)
    end

    if type(entry) == "table" then
        local total = 0
        for _, id in ipairs(entry) do
            total = total + count(id)
        end
        return total
    end

    return count(entry)
end

function RT:GetDisplayInfo(entry)
    local id = type(entry) == "table" and entry[1] or entry
    return C_Item.GetItemIconByID(id), C_Item.GetItemNameByID(id)
end

-- =====================
-- TRACKER UPDATE (FIXED LOGIC)
-- =====================

function RT:UpdateTracker()
    if not self.frame then return end

    local iconSize = self.db.iconSize or 32
    local spacing = self.db.spacing or 6
    local counterFS = self.db.counterFontSize or 14
    local nameFS = self.db.nameFontSize or 12

    for _, f in ipairs(self.icons) do f:Hide() end
    wipe(self.icons)

    local y = 0
    local maxWidth = 0

    -- Функція для глибокого пошуку іконок у базі даних
    local function ProcessReagents(data)
        if not data then return end
        
        -- Якщо це список ID (Lumber або категорія професії)
        if type(data) == "table" and data[1] then
            for _, entry in ipairs(data) do
                local key = GetReagentKey(entry)
                if self.db.enabled[key] then
                    local icon, name = self:GetDisplayInfo(entry)
                    local count = self:GetGroupedItemCount(entry)

                    local row = CreateFrame("Frame", nil, self.frame)
                    row:SetPoint("TOPLEFT", 0, y)

                    local tex = row:CreateTexture(nil, "ARTWORK")
                    tex:SetSize(iconSize, iconSize)
                    tex:SetTexture(icon)
                    tex:SetPoint("LEFT")

                    local countText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                    countText:SetPoint("BOTTOMRIGHT", tex, "BOTTOMRIGHT", -2, 2)
                    countText:SetFont(countText:GetFont(), counterFS, "OUTLINE")
                    countText:SetText(count)

                    local width = iconSize
                    if self.db.showNames then
                        local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                        nameText:SetFont(nameText:GetFont(), nameFS)
                        nameText:SetText(name or "")
                        nameText:SetPoint("LEFT", tex, "RIGHT", 6, 0)
                        width = width + nameText:GetStringWidth() + 10
                    end

                    row:SetSize(width, iconSize)
                    maxWidth = math.max(maxWidth, width)
                    table.insert(self.icons, row)
                    y = y - (iconSize + spacing)
                end
            end
        else
            -- Якщо це вкладена таблиця (наприклад, Classic -> Mining)
            for _, subData in pairs(data) do
                if type(subData) == "table" then
                    ProcessReagents(subData)
                end
            end
        end
    end

    -- Запуск обробки всієї бази
    ProcessReagents(RT_REAGENTS)

    self.frame:SetSize(maxWidth > 0 and maxWidth or 100, math.abs(y) > 0 and math.abs(y) or 20)
    self.frame:SetShown(#self.icons > 0)
end