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
        if type(v) == "table" then
            dst[k] = CopyDefaults(v, dst[k])
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
    return dst
end

RT.ItemMap = {} 

local function BuildItemMap(tab)
    for _, entry in pairs(tab) do
        if type(entry) == "table" then
            if type(entry[1]) == "number" then

                for _, id in ipairs(entry) do RT.ItemMap[id] = true end
            else
                BuildItemMap(entry)
            end
        elseif type(entry) == "number" then
            RT.ItemMap[entry] = true
        end
    end
end

local function UpdateItemData(charKey, id)
    if not id then return end
    
    local bags = C_Item.GetItemCount(id, false, false, false, false) or 0
    local totalWithBank = C_Item.GetItemCount(id, true, false, false, false) or 0
    local personalBank = totalWithBank - bags

    RT.db.charData[charKey].items[id] = (bags > 0) and bags or nil
    RT.db.charData[charKey].bankItems[id] = (personalBank > 0) and personalBank or nil
    
    RT.db.warbandItems = RT.db.warbandItems or {}
    local totalWithWarband = C_Item.GetItemCount(id, true, false, true, true) or 0
    local warbandOnly = totalWithWarband - totalWithBank
    RT.db.warbandItems[id] = (warbandOnly > 0) and warbandOnly or nil
end

local function SyncAllItems()
    if not RT.db or not RT.db.charData or not RT_REAGENTS then return end
    
    local charKey = UnitName("player") .. "-" .. GetRealmName()
    RT.db.charData[charKey] = RT.db.charData[charKey] or { items = {}, bankItems = {} }
    
    local idsToUpdate = {}
    for id in pairs(RT.ItemMap) do
        table.insert(idsToUpdate, id)
    end

    local index = 1
    local function BatchUpdate()
        local count = 0
        while index <= #idsToUpdate and count < 20 do
            UpdateItemData(charKey, idsToUpdate[index])
            index = index + 1
            count = count + 1
        end

        if index <= #idsToUpdate then
            C_Timer.After(0.1, BatchUpdate)
        else
            if RT.UpdateTracker then RT:UpdateTracker() end
        end
    end
    
    BatchUpdate()
end

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
f:RegisterEvent("GET_ITEM_INFO_RECEIVED")
f:RegisterEvent("AUCTION_HOUSE_CLOSED")
f:RegisterEvent("AUCTION_HOUSE_SHOW")
f:RegisterEvent("MAIL_CLOSED")

local isThrottled = false

    f:SetScript("OnEvent", function(_, event, addon)
    if event == "ADDON_LOADED" and addon == addonName then
        ReagentTrackerDB = CopyDefaults(defaults, ReagentTrackerDB or {})
        RT.db = ReagentTrackerDB
        
        local charKey = UnitName("player") .. "-" .. GetRealmName()
        RT.db.charSettings = RT.db.charSettings or {}
        RT.db.charSettings[charKey] = RT.db.charSettings[charKey] or { visible = true }
        RT.charDb = RT.db.charSettings[charKey]

        local function BuildItemMap(tab)
            for _, entry in pairs(tab) do
                if type(entry) == "table" then
                    if type(entry[1]) == "number" then
                        for _, id in ipairs(entry) do RT.ItemMap[id] = true end
                    else
                        BuildItemMap(entry)
                    end
                elseif type(entry) == "number" then
                    RT.ItemMap[entry] = true
                end
            end
        end

        if RT_REAGENTS then
            BuildItemMap(RT_REAGENTS)
        end
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
            C_Timer.After(0.5, function()
                local charKey = UnitName("player") .. "-" .. GetRealmName()
                for id in pairs(RT.ItemMap) do
                    UpdateItemData(charKey, id)
                end
                
                if RT.UpdateTracker then RT:UpdateTracker() end
                isThrottled = false
            end)
        end
    end

    if event == "AUCTION_HOUSE_CLOSED" or event == "MAIL_CLOSED" then
        SyncAllItems() 
    end
    
    if event == "GET_ITEM_INFO_RECEIVED" then
    if RT.UpdateTracker then
        RT:UpdateTracker()
    end
end
end)

StaticPopupDialogs["RT_SET_GOAL"] = {
    text = "Enter farm goal (e.g. 100, +50 or -20):",
    button1 = "Save",
    button2 = "Cancel",
    hasEditBox = true,
    maxLetters = 15,
    OnAccept = function(self)
        local data = self.data 
        local editBox = self.EditBox or _G[self:GetName().."EditBox"]
        if editBox and data and data.key then
            local text = editBox:GetText()
            
            RT.db.goals = RT.db.goals or {}
            local currentGoal = RT.db.goals[data.key] or 0
            

            local firstChar = text:sub(1, 1)
            local modifier = tonumber(text:match("^[%+%-]%d+")) 
            local absoluteValue = tonumber(text) 
            
            local newGoal = 0
            
            if modifier then
                newGoal = currentGoal + modifier
            elseif absoluteValue then
                newGoal = absoluteValue
            else
                return 
            end

            if newGoal <= 0 then
                RT.db.goals[data.key] = nil
            else
                RT.db.goals[data.key] = newGoal
            end
            
            RT:UpdateTracker()
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
            editBox:HighlightText()
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}