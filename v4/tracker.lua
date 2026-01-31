local function GetReagentKey(entry)
  if type(entry) == "table" then
    return table.concat(entry, "_")
  end
  return entry
end

function RT:CreateTracker()
  if self.frame then return end

  local f = CreateFrame("Frame", "RT_MainFrame", UIParent)

  local pos = self.db.position
  f:SetPoint(pos.point, UIParent, pos.relativePoint, pos.x, pos.y)
  f:SetScale(self.db.scale)
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

-- bags + bank + reagent bank + warband
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
  return
    C_Item.GetItemIconByID(id),
    C_Item.GetItemNameByID(id)
end

function RT:UpdateTracker()
  local iconSize = self.db.iconSize or 32
  if not self.frame then return end

  for _, f in ipairs(self.icons) do
    f:Hide()
  end
  wipe(self.icons)

  local y = 0
  local spacing = self.db.spacing or 6
  local maxWidth = 0

  for _, items in pairs(RT_REAGENTS) do
    for _, entry in ipairs(items) do
      local key = GetReagentKey(entry)

      if self.db.enabled[key] then
        local icon, name = self:GetDisplayInfo(entry)
        local count = self:GetGroupedItemCount(entry)

        local row = CreateFrame("Frame", nil, self.frame)
        row:SetPoint("TOPLEFT", 0, y)

        local tex = row:CreateTexture(nil, "ARTWORK")
        tex:SetSize(iconSize, iconSize)
        tex:SetTexture(icon)

        local countText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        countText:SetPoint("BOTTOMRIGHT", tex, "BOTTOMRIGHT", -2, 2)
        countText:SetFont(countText:GetFont(), self.db.fontSize)
        countText:SetText(count)

        local width = iconSize
        local height = iconSize

        tex:SetPoint("LEFT")

        if self.db.showNames then
          local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
          nameText:SetText(name or "")
          
          if self.db.namePos == "BOTTOM" then
            nameText:SetPoint("TOP", tex, "BOTTOM", 0, -2)
            height = height + nameText:GetStringHeight() + 4

          elseif self.db.namePos == "TOP" then
            nameText:SetPoint("BOTTOM", tex, "TOP", 0, 2)
            height = height + nameText:GetStringHeight() + 4

          elseif self.db.namePos == "RIGHT" then
            nameText:SetPoint("LEFT", tex, "RIGHT", 6, 0)
            width = width + nameText:GetStringWidth() + 6

          elseif self.db.namePos == "LEFT" then
            nameText:SetPoint("RIGHT", tex, "LEFT", -6, 0)
            width = width + nameText:GetStringWidth() + 6
          end
        end

        row:SetSize(width, height)
        maxWidth = max(maxWidth, width)

        table.insert(self.icons, row)
        y = y - (height + spacing)
      end
    end
  end

  self.frame:SetWidth(maxWidth)
  self.frame:SetHeight(-y)
end
