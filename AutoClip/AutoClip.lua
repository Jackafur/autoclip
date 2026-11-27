-- AutoClip: asks OBS (on the Linux PC) to save the last 2 minutes when something worth keeping happens.
-- An addon can't reach OBS, so it takes two screenshots 1.5 s apart. The watcher on the PC
-- (wow-autoclip.path -> obs-record auto) treats a pair like that as the signal: moves both out of
-- Screenshots and saves the clip. Your own single screenshots are left alone.
-- Blocked in this client (Nov 12 popups): changing the screenshotFormat cvar, muting ActionStatus.
-- Setup: see the README.

local DEFAULTS = { pvp = true, level = true, boss = true, death = false }
local LABELS = { pvp = "PvP kill (an honorable kill, or your killing blow on a player)", level = "level up", boss = "boss kill", death = "your death" }
local ORDER = { "pvp", "level", "boss", "death" }
-- Seconds to wait after the moment, so the clip shows what came right after. 12 since Nov 26 (was 8): the PC cuts the
-- last 3.5 s off each automatic clip, where WoW's "Screen Captured" text sits. /autoclip wait 8 = the old wait.
-- Not under 8: the PC is busy for up to 8 s cutting a clip, and screenshots that land meanwhile are not seen.
local AFTER_DEFAULT, AFTER_MIN, AFTER_MAX = 12, 8, 30
-- A clip ends about half a second before its first screenshot. A moment in the last LATE seconds before that, or
-- during the two screenshots, would be cut off or missing, so it gets a clip of its own once this one is done.
local LATE = 4
local function after()
    local n = AutoClipDB and tonumber(AutoClipDB.after)
    if n and n >= AFTER_MIN and n <= AFTER_MAX then return n end
    return AFTER_DEFAULT
end

local pending = false
local lateAt, again, byKey = 0, false, false -- from lateAt on, a moment no longer fits the clip on its way
local f = CreateFrame("Frame")

local function say(msg) print("|cffbd93f9AutoClip|r " .. msg) end

local GAP, GAP_KEY = 1.5, 2.6 -- seconds between the two shots: an event, or your key (the PC keeps those in Clips, whole)
local shoot
local function wait()
    pending = true
    byKey = false
    lateAt = GetTime() + after() - LATE
    C_Timer.After(after(), function() shoot() end)
end
shoot = function(gap)
    Screenshot()
    C_Timer.After(gap or GAP, function()
        Screenshot()
        pending = false
        if again then
            again = false
            wait()
        end
    end)
end

-- Your own key (Esc, Options, Keybindings, AddOns, AutoClip): saves the last 5 min now, no wait, into ~/Videos/OBS/Clips.
BINDING_HEADER_AUTOCLIP = "AutoClip"
BINDING_NAME_AUTOCLIP_SAVE = "AutoClip - Save a clip (the last 5 minutes)"
function AutoClip_Save()
    if pending then
        if not byKey and GetTime() >= lateAt then again = true end -- a second press of the key asks for nothing more
        say("a clip is already on its way")
        return
    end
    pending = true
    byKey = true
    lateAt = GetTime()
    say("saving the last 5 min")
    shoot(GAP_KEY)
end

local function want(kind)
    if not AutoClipDB[kind] then return end
    if pending then
        if GetTime() >= lateAt then again = true end
        return
    end
    wait()
end

f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PARTY_KILL") -- not COMBAT_LOG_EVENT_UNFILTERED: restricted in this client, the load popup (Nov 12)
-- PARTY_KILL's GUIDs are secret when unit identity is restricted (the API docs), which is just when the victim is an enemy
-- player, so it missed his PvP kills (Nov 13). The honorable kill count is not secret: a change of the player's = a PvP kill
-- he had a hand in (a kill worth honor; a grey-level player gives none).
f:RegisterEvent("PLAYER_PVP_KILLS_CHANGED")
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
    elseif event == "PLAYER_PVP_KILLS_CHANGED" then
        local unit = ...
        local ok, me = pcall(function() return unit == "player" end)
        if ok and me then want("pvp") end
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
        say("test clip in " .. after() .. " s")
        wait()
        return
    end
    if kind == "wait" then
        local n = tonumber((msg or ""):match("%d+"))
        if n and n >= AFTER_MIN and n <= AFTER_MAX then
            AutoClipDB.after = n
        elseif n then
            say(("wait: %d to %d seconds"):format(AFTER_MIN, AFTER_MAX))
        end
        say(("waits %d s after the moment (/autoclip wait <seconds>, %d to %d; %d is the usual)"):format(after(), AFTER_MIN, AFTER_MAX, AFTER_DEFAULT))
        return
    end
    if kind and DEFAULTS[kind] ~= nil then
        AutoClipDB[kind] = not AutoClipDB[kind]
    end
    say("clips the last 2 min on (/autoclip <word> turns one on or off, /autoclip test makes one now; your own key: Keybindings, AddOns, AutoClip):")
    for _, k in ipairs(ORDER) do
        say(("  %s: %s  (%s)"):format(k, AutoClipDB[k] and "|cff50fa7bon|r" or "|cffff5555off|r", LABELS[k]))
    end
    say(("  waits %d s after the moment (/autoclip wait <seconds>)"):format(after()))
end
