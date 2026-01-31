local function GetReagentKey(entry)
  if type(entry) == "table" then
    return table.concat(entry, "_")
  end
  return tostring(entry)
end

function RT:CreateTracker()
  if self.frame then return end

  local f = CreateFrame("Frame", "RT_MainFrame", UIParent)
  f:SetClampedToScreen(true)

  local pos = self.db.position
  f:SetPoint(pos.point, UIParent, pos.relativePoint, pos.x, pos.y)
  f:SetScale(self.db.scale)

  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)

  f:SetScript("OnDragStop", function(frame)
    frame:StopMovingOrSizing()
    local point, _, relativePoint, x, y = frame:GetPoint()
    self.db.position.point = point
    self.db.position.relativePoint = relativePoint
    self.db.position.x = x
    self.db.position.y = y
  end)

  self.frame = f
  self.icons = {}
end

function RT:GetGroupedItemCount(entry)
  if type(entry) == "table" then
    local total = 0
    for _, id in ipairs(entry) do
      total = total + C_Item.GetItemCount(id, true, false)
    end
    return total
  end
  return C_Item.GetItemCount(entry, true, false)
end

function RT:GetReagentDisplayInfo(entry)
  local id = type(entry) == "table" and entry[1] or entry
  return C_Item.GetItemIconByID(id), C_Item.GetItemNameByID(id)
end

function RT:UpdateTracker()
  if not self.frame then return end

  for _, icon in ipairs(self.icons) do
    icon:Hide()
  end
  wipe(self.icons)

  local x, y = 0, 0
  local spacing = 6
  local rowHeight = self.db.iconSize + spacing
  local maxWidth = 0

  for _, items in pairs(RT_REAGENTS) do
    for _, entry in ipairs(items) do
      local key = GetReagentKey(entry)

      if self.db.enabled[key] then
        local icon, name = self:GetReagentDisplayInfo(entry)
        local count = self:GetGroupedItemCount(entry)

        local row = CreateFrame("Frame", nil, self.frame)
        row:SetSize(self.db.iconSize, self.db.iconSize)
        row:SetPoint("TOPLEFT", x, -y)

        local tex = row:CreateTexture(nil, "ARTWORK")
        tex:SetAllPoints()
        tex:SetTexture(icon)

        local countText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        countText:SetPoint("BOTTOMRIGHT", -2, 2)
        countText:SetFont(countText:GetFont(), self.db.fontSize)
        countText:SetText(count)

        local width = self.db.iconSize

        if self.db.showNames then
          local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
          nameText:SetPoint("LEFT", row, "RIGHT", 6, 0)
          nameText:SetText(name or "")
          width = width + 110
        end

        table.insert(self.icons, row)

        if self.db.layout == "vertical" then
          y = y + rowHeight
          maxWidth = max(maxWidth, width)
        else
          x = x + width + spacing
        end
      end
    end
  end

  self.frame:SetSize(
    max(maxWidth, x, 1),
    max(y, self.db.iconSize, 1)
  )
end
