ReagentTracker = {}
RT = ReagentTracker

local defaults = {
  enabled = {},
  iconSize = 32,
  fontSize = 12,
  showNames = true,
  layout = "vertical",
  scale = 1,
  locked = false,

  position = {
    point = "CENTER",
    relativePoint = "CENTER",
    x = 0,
    y = 0,
  },
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

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("BAG_UPDATE_DELAYED")

f:SetScript("OnEvent", function(_, event, addon)
  if event == "ADDON_LOADED" and addon == "ReagentTracker" then
    ReagentTrackerDB = CopyDefaults(defaults, ReagentTrackerDB or {})
    RT.db = ReagentTrackerDB
  end

  if event == "PLAYER_LOGIN" then
    RT:CreateTracker()
    RT:UpdateTracker()
  end

  if event == "BAG_UPDATE_DELAYED" then
    RT:UpdateTracker()
  end
end)
