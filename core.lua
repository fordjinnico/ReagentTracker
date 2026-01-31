local addonName, ns = ...
RT = ns
ReagentTracker = RT

local defaults = {
    enabled = {},
    showExpansion = {},
    goals = {},
    charData = {}, 
    iconSize = 32,
    counterFontSize = 12,
    nameFontSize = 14,
    detailScale = 1,          -- Скейлінг вікна деталей
    detailFontSize = 12,       -- Шрифт у вікні деталей
    showNames = true,
    showCountOnIcon = true,
    showCountInName = true,
    orientation = "Vertical",
    textPosition = "Right",
    scale = 1,
    locked = false,
    spacing = 6,
    position = { point = "CENTER", relativePoint = "CENTER", x = 0, y = 0 },
}

local function CopyDefaults(src, dst)
    if type(dst) ~= "table" then dst = {} end
    for k, v in pairs(src) do
        if type(v) == "table" then dst[k] = CopyDefaults(v, dst[k])
        elseif dst[k] == nil then dst[k] = v end
    end
    return dst
end

local function SyncCharacterItems()
    if not RT.db or not RT.db.charData or not RT_REAGENTS then return end
    
    local name = UnitName("player")
    local server = GetRealmName()
    if not name or not server then return end 
    
    local charKey = name .. "-" .. server
    -- Створюємо структуру, якщо її немає
    RT.db.charData[charKey] = RT.db.charData[charKey] or {}
    RT.db.charData[charKey].items = RT.db.charData[charKey].items or {}
    RT.db.charData[charKey].bankItems = RT.db.charData[charKey].bankItems or {}
    
    -- Зберігаємо клас для гарного відображення в деталях
    local _, classFile = UnitClass("player")
    RT.db.charData[charKey].class = classFile

    -- Допоміжна функція для обробки одного ID
    local function UpdateItem(id)
        if not id then return end
        -- bCount: тільки сумки чара
        -- tCount: сумки + звичайний банк + варбенд банк
        local bCount = C_Item.GetItemCount(id, false, false, false, false) or 0
        local tCount = C_Item.GetItemCount(id, true, false, true, false) or 0
        local bankAndWarband = tCount - bCount

        -- Оновлюємо значення (якщо 0 - краще видалити ключ, щоб не роздувати файл)
        RT.db.charData[charKey].items[id] = (bCount > 0) and bCount or nil
        RT.db.charData[charKey].bankItems[id] = (bankAndWarband > 0) and bankAndWarband or nil
    end

    -- Рекурсивний обхід всієї твоєї data.lua
    local function DeepScan(tab)
        for _, entry in pairs(tab) do
            if type(entry) == "table" then
                -- Перевіряємо, чи це список ID (як для TWW якості) чи вкладена категорія
                if type(entry[1]) == "number" then
                    for _, id in ipairs(entry) do UpdateItem(id) end
                else
                    DeepScan(entry) -- йдемо глибше (напр. Classic -> Mining)
                end
            elseif type(entry) == "number" then
                UpdateItem(entry)
            end
        end
    end

    DeepScan(RT_REAGENTS)
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("BAG_UPDATE_DELAYED")
f:RegisterEvent("BANKFRAME_OPENED")
f:RegisterEvent("BANKFRAME_CLOSED")

local isThrottled = false

f:SetScript("OnEvent", function(_, event, addon)
    if event == "ADDON_LOADED" and addon == addonName then

      ReagentTrackerDB = CopyDefaults(defaults, ReagentTrackerDB or {})
      RT.db = ReagentTrackerDB
    
      RT.db.charSettings = RT.db.charSettings or {}
      local charKey = UnitName("player") .. "-" .. GetRealmName()
      
      if not RT.db.charSettings[charKey] then
          RT.db.charSettings[charKey] = { visible = true }
      end
      
      RT.charDb = RT.db.charSettings[charKey]
    end

    if event == "PLAYER_LOGIN" then
        if not RT.db then ReagentTrackerDB = CopyDefaults(defaults, ReagentTrackerDB or {}); RT.db = ReagentTrackerDB end
        
        if RT.CreateTracker then
            RT:CreateTracker()
            SyncCharacterItems()
            C_Timer.After(2, function() 
                if RT.UpdateTracker then RT:UpdateTracker() end 
            end)
        end
    end

    if event == "BAG_UPDATE_DELAYED" then
        if not isThrottled and RT.db then
            isThrottled = true
            C_Timer.After(1, function()
                SyncCharacterItems()
                if RT.UpdateTracker then RT:UpdateTracker() end
                isThrottled = false
            end)
        end
    end
end)


StaticPopupDialogs["RT_SET_GOAL"] = {
    text = "Enter farm goal for reagent(0 for reset):",
    button1 = "Save",
    button2 = "Cancel",
    hasEditBox = true,
    maxLetters = 10,
    OnAccept = function(self)
        local data = self.data 
        local editBox = self.EditBox or _G[self:GetName().."EditBox"]
        if editBox and data and data.key then
            local text = editBox:GetText()
            local goal = tonumber(text)
            if goal then
                RT.db.goals = RT.db.goals or {}
                if goal <= 0 then
                    RT.db.goals[data.key] = nil
                else
                    RT.db.goals[data.key] = goal
                end
                RT:UpdateTracker()
            end
        end
    end,
    EditBoxOnEnterPressed = function(self)
        local parent = self:GetParent()
        StaticPopupDialogs["RT_SET_GOAL"].OnAccept(parent)
        parent:Hide()
    end,
    OnShow = function(self)
        local data = self.data
        local editBox = self.EditBox or _G[self:GetName().."EditBox"]
        if editBox and data and data.key then
            RT.db.goals = RT.db.goals or {}
            local currentGoal = RT.db.goals[data.key] or ""
            editBox:SetText(currentGoal)
            editBox:SetFocus()
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}