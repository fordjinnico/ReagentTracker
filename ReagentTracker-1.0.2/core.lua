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
    -- ЗАХИСТ: якщо база ще не готова або немає списку реагентів
    if not RT.db or not RT.db.charData or not RT_REAGENTS then return end
    
    local name = UnitName("player")
    local _, classFile = UnitClass("player")
    local server = GetRealmName()
    if not name or not server then return end -- Захист від раннього завантаження
    
    local charKey = name .. "-" .. server
    RT.db.charData[charKey] = RT.db.charData[charKey] or {}
    RT.db.charData[charKey].class = classFile
    RT.db.charData[charKey].items = RT.db.charData[charKey].items or {}
    
    wipe(RT.db.charData[charKey].items)
    
    local function Scan(tab)
        for _, entry in pairs(tab) do
            if type(entry) == "table" then
                if type(entry[1]) == "number" then
                    for _, id in ipairs(entry) do
                        local count = C_Item.GetItemCount(id, true, false, false, false)
                        if count and count > 0 then RT.db.charData[charKey].items[id] = count end
                    end
                else
                    Scan(entry)
                end
            elseif type(entry) == "number" then
                local count = C_Item.GetItemCount(entry, true, false, false, false)
                if count and count > 0 then RT.db.charData[charKey].items[entry] = count end
            end
        end
    end
    Scan(RT_REAGENTS)
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("BAG_UPDATE_DELAYED")

local isThrottled = false

f:SetScript("OnEvent", function(_, event, addon)
    if event == "ADDON_LOADED" and addon == addonName then
        ReagentTrackerDB = CopyDefaults(defaults, ReagentTrackerDB or {})
        RT.db = ReagentTrackerDB
    end

    if event == "PLAYER_LOGIN" then
        -- Подвійна перевірка готовності бази
        if not RT.db then ReagentTrackerDB = CopyDefaults(defaults, ReagentTrackerDB or {}); RT.db = ReagentTrackerDB end
        
        if RT.CreateTracker then
            RT:CreateTracker()
            SyncCharacterItems()
            -- Даємо грі 2 секунди "прокашлятися" перед першим рендером трекера
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