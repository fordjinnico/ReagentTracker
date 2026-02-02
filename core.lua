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
    detailScale = 1,
    detailFontSize = 12,
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

local function UpdateItemData(charKey, id)
    if not id then return end
    local bCount = C_Item.GetItemCount(id, false, false, false, false) or 0
    local tCount = C_Item.GetItemCount(id, true, false, true, false) or 0
    local bankAndWarband = tCount - bCount

    RT.db.charData[charKey].items[id] = (bCount > 0) and bCount or nil
    RT.db.charData[charKey].bankItems[id] = (bankAndWarband > 0) and bankAndWarband or nil
end

-- FULL SCAN FOR LOGIN/BANK SCREEN LOADED/LOGOUT
local function SyncAllItems()
    if not RT.db or not RT.db.charData or not RT_REAGENTS then return end
    
    local charKey = UnitName("player") .. "-" .. GetRealmName()
    RT.db.charData[charKey] = RT.db.charData[charKey] or { items = {}, bankItems = {} }
    
    local _, classFile = UnitClass("player")
    RT.db.charData[charKey].class = classFile

    local function DeepScan(tab)
        for _, entry in pairs(tab) do
            if type(entry) == "table" then
                if type(entry[1]) == "number" then
                    for _, id in ipairs(entry) do UpdateItemData(charKey, id) end
                else
                    DeepScan(entry)
                end
            elseif type(entry) == "number" then
                UpdateItemData(charKey, entry)
            end
        end
    end
    DeepScan(RT_REAGENTS)
end

-- FAST SCAN FOR LOOT UPDATE (Optimized for performance)
local function SyncActiveOnly()
    local charKey = UnitName("player") .. "-" .. GetRealmName()
    if not RT.db.enabled then return end
    
    for key, isEnabled in pairs(RT.db.enabled) do
        if isEnabled then
            if type(key) == "number" then
                UpdateItemData(charKey, key)
            elseif type(key) == "string" then
                for idStr in string.gmatch(key, "(%d+)") do
                    UpdateItemData(charKey, tonumber(idStr))
                end
            end
        end
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("BAG_UPDATE_DELAYED")
f:RegisterEvent("BANKFRAME_CLOSED")
f:RegisterEvent("PLAYER_LOGOUT")

local isThrottled = false

f:SetScript("OnEvent", function(_, event, addon)
    if event == "ADDON_LOADED" and addon == addonName then
        ReagentTrackerDB = CopyDefaults(defaults, ReagentTrackerDB or {})
        RT.db = ReagentTrackerDB
        
        local charKey = UnitName("player") .. "-" .. GetRealmName()
        RT.db.charSettings = RT.db.charSettings or {}
        RT.db.charSettings[charKey] = RT.db.charSettings[charKey] or { visible = true }
        RT.charDb = RT.db.charSettings[charKey]
    end

    if event == "PLAYER_LOGIN" then
        if not RT.db then
            ReagentTrackerDB = CopyDefaults(defaults, ReagentTrackerDB or {})
            RT.db = ReagentTrackerDB 
        end

        if RT.CreateTracker then
            RT:CreateTracker()
            SyncAllItems() 
            C_Timer.After(2, function() if RT.UpdateTracker then RT:UpdateTracker() end end)
        end
    end

    if event == "BANKFRAME_CLOSED" then
        SyncAllItems() 
        RT:UpdateTracker()
    end

    if event == "PLAYER_LOGOUT" then
        SyncAllItems() 
    end

    if event == "BAG_UPDATE_DELAYED" then
        if not isThrottled and RT.db then
            isThrottled = true
            C_Timer.After(0.3, function()
                SyncActiveOnly() 
                if RT.UpdateTracker then RT:UpdateTracker() end
                isThrottled = false
            end)
        end
    end
end)

StaticPopupDialogs["RT_SET_GOAL"] = {
    text = "Enter farm goal for reagent (0 for reset):",
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