-- AutoClip: asks OBS (on the Linux PC) to save the last 2 minutes when something worth keeping happens.
-- An addon can't reach OBS, so it takes two screenshots 1.5 s apart. The watcher on the PC
-- (wow-autoclip.path -> obs-record auto) treats a pair like that as the signal: moves both out of
-- Screenshots and saves the clip. Your own single screenshots are left alone.
-- Blocked in this client (Nov 12 popups): changing the screenshotFormat cvar, muting ActionStatus.
-- Setup: see the README.

local DEFAULTS = { pvp = true, level = true, boss = true, death = false }
local LABELS = { pvp = "PvP killing blow (you or your pet)", level = "level up", boss = "boss kill", death = "your death" }
local ORDER = { "pvp", "level", "boss", "death" }
local AFTER = 8 -- seconds to wait after the moment, so the clip shows what came right after

local pending = false
local f = CreateFrame("Frame")

local function say(msg) print("|cffbd93f9AutoClip|r " .. msg) end

local function shoot()
    Screenshot()
    C_Timer.After(1.5, function()
        Screenshot()
        pending = false
    end)
end

local function want(kind)
    if not AutoClipDB[kind] or pending then return end
    pending = true
    C_Timer.After(AFTER, shoot)
end

f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PARTY_KILL") -- not COMBAT_LOG_EVENT_UNFILTERED: restricted in this client, the load popup (Nov 12)
f:RegisterEvent("PLAYER_LEVEL_UP")
f:RegisterEvent("ENCOUNTER_END")
f:RegisterEvent("PLAYER_DEAD")
f:RegisterEvent("ADDON_ACTION_FORBIDDEN")
f:RegisterEvent("ADDON_ACTION_BLOCKED")

f:SetScript("OnEvent", function(_, event, ...)
    if event == "PARTY_KILL" then
        local src, dest = ...
        -- The GUIDs can come as secret values where unit identity is restricted; then skip it quietly.
        local ok, mine = pcall(function()
            return (src == UnitGUID("player") or src == UnitGUID("pet")) and dest:sub(1, 7) == "Player-"
        end)
        if ok and mine then want("pvp") end
    elseif event == "PLAYER_LEVEL_UP" then
        want("level")
    elseif event == "ENCOUNTER_END" then
        if select(5, ...) == 1 then want("boss") end
    elseif event == "PLAYER_DEAD" then
        want("death")
    elseif event == "ADDON_ACTION_FORBIDDEN" or event == "ADDON_ACTION_BLOCKED" then
        local who, what = ...
        if who == "AutoClip" then
            say("|cffff5555blocked:|r " .. tostring(what) .. " (" .. event .. ")")
            AutoClipDB.blocked = date("%H:%M:%S") .. " " .. event .. " " .. tostring(what)
        end
    elseif event == "ADDON_LOADED" and ... == "AutoClip" then
        AutoClipDB = AutoClipDB or {}
        for k, v in pairs(DEFAULTS) do
            if AutoClipDB[k] == nil then AutoClipDB[k] = v end
        end
    end
end)

SLASH_AUTOCLIP1 = "/autoclip"
SlashCmdList.AUTOCLIP = function(msg)
    local kind = (msg or ""):lower():match("%a+")
    if kind == "test" then
        if pending then return end
        say("test clip in " .. AFTER .. " s")
        pending = true
        C_Timer.After(AFTER, shoot)
        return
    end
    if kind and DEFAULTS[kind] ~= nil then
        AutoClipDB[kind] = not AutoClipDB[kind]
    end
    say("clips the last 2 min on (/autoclip <word> turns one on or off, /autoclip test makes one now):")
    for _, k in ipairs(ORDER) do
        say(("  %s: %s  (%s)"):format(k, AutoClipDB[k] and "|cff50fa7bon|r" or "|cffff5555off|r", LABELS[k]))
    end
end
