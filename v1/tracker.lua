function RT:CreateTracker()
  if self.frame then return end

  local f = CreateFrame("Frame", "RT_MainFrame", UIParent)
  f:SetPoint("CENTER")
  f:SetSize(200, 50)
  f:SetScale(self.db.scale)

  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)

  self.frame = f
  self.icons = {}
end

function RT:GetItemCountCombined(itemID)
  -- API 12.0-safe
  return C_Item.GetItemCount(itemID, true, false)
end

function RT:UpdateTracker()
  if not self.frame then return end

  for _, icon in ipairs(self.icons) do
    icon:Hide()
  end
  wipe(self.icons)

  local x = 0

  for _, items in pairs(RT_REAGENTS) do
    for _, itemID in ipairs(items) do
      if self.db.enabled[itemID] then
        local btn = CreateFrame("Frame", nil, self.frame)
        btn:SetSize(self.db.iconSize, self.db.iconSize)
        btn:SetPoint("LEFT", self.frame, "LEFT", x, 0)

        local tex = btn:CreateTexture(nil, "ARTWORK")
        tex:SetAllPoints()
        tex:SetTexture(C_Item.GetItemIconByID(itemID))

          local count = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            if self.db.showNames then
              local name = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
              name:SetPoint("TOP", btn, "BOTTOM", 0, -2)
              name:SetText(C_Item.GetItemNameByID(itemID) or "")
            end
        count:SetPoint("BOTTOMRIGHT", -2, 2)
        count:SetFont(count:GetFont(), self.db.fontSize)
        count:SetText(self:GetItemCountCombined(itemID))

        table.insert(self.icons, btn)
        x = x + self.db.iconSize + 6
      end
    end
  end

  self.frame:SetWidth(max(x, 1))
end

