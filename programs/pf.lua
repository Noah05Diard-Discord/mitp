-- router.lua
-- Router with persistent Data Limiter and panel control
local CONFIG_FILE = "config.cfg"
local PASSWORD_FILE = "password.cfg"
local LIMIT_FILE = "limit.cfg"

-- Basic helpers
local function loadTable(path, default)
    if fs.exists(path) then
        local f = fs.open(path, "r")
        local data = textutils.unserialize(f.readAll())
        f.close()
        return data or default
    end
    return default
end

local function saveTable(path, tbl)
    local f = fs.open(path, "w")
    f.write(textutils.serialize(tbl))
    f.close()
end

-- Load or default config
local ports = loadTable(CONFIG_FILE, {80, 443})
local password = loadTable(PASSWORD_FILE, {pwd = "admin"})
local limitCfg = loadTable(LIMIT_FILE, {
    enabled = false,
    upLimit = 1000,    -- internal -> external cap (packets/messages)
    downLimit = 1000,  -- external -> internal cap
})

-- runtime counters (not persisted)
local dc, uc, tc = 0, 0, 0

-- modem / peripheral names (adjust these if your sides differ)
local panelPort = 2
local outputSide = "back"   -- network facing outside
local inputSide = "bottom"  -- network facing inside

local oP = peripheral.wrap(outputSide)
local iP = peripheral.wrap(inputSide)
if not oP or not iP then error("Couldn't wrap modem sides. Check peripheral names.") end

-- close all ports and open allowed ones
print("Initializing router ports...")
for i = 0, 65535 do
    pcall(function() oP.close(i) end)
    pcall(function() iP.close(i) end)
end
for _, p in ipairs(ports) do
    pcall(function() oP.open(p) end)
    pcall(function() iP.open(p) end)
end
oP.open(panelPort)
print("Router ready. Panel port:", panelPort)

-- helper to determine whether traffic should pass
local function limiterAllows()
    if not limitCfg.enabled then return true end
    -- block both directions if either limit has been reached
    if uc >= (limitCfg.upLimit or math.huge) then return false end
    if dc >= (limitCfg.downLimit or math.huge) then return false end
    return true
end

-- send response helper to panel
local function replyToPanel(msg)
    -- reply on panel port from router -> router
    oP.transmit(panelPort, panelPort, msg)
end

-- main loop
while true do
    local ev = {os.pullEvent("modem_message")}
    -- ev format: { "modem_message", side, channel, replyChannel, message, ... }
    local side = ev[2]
    local channel = ev[3]
    local replyChannel = ev[4]
    local msg = ev[5]

    -- messages from panel must be on panelPort
    if channel == panelPort then
        if type(msg) == "table" then
            local cmd = msg[1]
            if cmd == "main" then
                replyToPanel({ "status", dc, uc, tc })
            elseif cmd == "list" then
                replyToPanel({ "list", ports })
            elseif cmd == "login" then
                if msg[2] == password.pwd then
                    replyToPanel({ "login_ok" })
                else
                    replyToPanel({ "login_fail" })
                end
            elseif cmd == "getlimit" then
                replyToPanel({ "limitinfo", limitCfg, { dc = dc, uc = uc } })
            elseif cmd == "edit" then
                -- msg: {"edit", pwd, action, value}
                local pwd = msg[2]
                local action = msg[3]
                local value = msg[4]
                if pwd ~= password.pwd then
                    replyToPanel({ "edit_fail", "Bad password" })
                else
                    if action == "add" then
                        if type(value) ~= "number" then
                            replyToPanel({ "edit_fail", "Port must be a number" })
                        else
                            -- avoid duplicates
                            local found = false
                            for _, p in ipairs(ports) do if p == value then found = true break end end
                            if not found then
                                table.insert(ports, value)
                                pcall(function() oP.open(value) end)
                                pcall(function() iP.open(value) end)
                                saveTable(CONFIG_FILE, ports)
                                replyToPanel({ "edit_ok", "Added port " .. tostring(value) })
                            else
                                replyToPanel({ "edit_fail", "Port already exists" })
                            end
                        end
                    elseif action == "remove" then
                        if type(value) ~= "number" then
                            replyToPanel({ "edit_fail", "Port must be a number" })
                        else
                            local removed = false
                            for i = #ports, 1, -1 do
                                if ports[i] == value then
                                    table.remove(ports, i)
                                    pcall(function() oP.close(value) end)
                                    pcall(function() iP.close(value) end)
                                    removed = true
                                end
                            end
                            if removed then
                                saveTable(CONFIG_FILE, ports)
                                replyToPanel({ "edit_ok", "Removed port " .. tostring(value) })
                            else
                                replyToPanel({ "edit_fail", "Port not found" })
                            end
                        end
                    elseif action == "passwd" then
                        if type(value) ~= "string" then
                            replyToPanel({ "edit_fail", "Password must be a string" })
                        else
                            password.pwd = value
                            saveTable(PASSWORD_FILE, password)
                            replyToPanel({ "edit_ok", "Password changed" })
                        end
                    elseif action == "limit" then
                        -- value expected: { enabled = bool, up = num, down = num }
                        value = value or {}
                        limitCfg.enabled = (value.enabled == true)
                        limitCfg.upLimit = tonumber(value.up) or limitCfg.upLimit
                        limitCfg.downLimit = tonumber(value.down) or limitCfg.downLimit
                        saveTable(LIMIT_FILE, limitCfg)
                        replyToPanel({ "edit_ok", "Limiter updated" })
                    elseif action == "resetcounters" then
                        dc, uc, tc = 0, 0, 0
                        replyToPanel({ "edit_ok", "Counters reset" })
                    else
                        replyToPanel({ "edit_fail", "Unknown edit action" })
                    end
                end
            else
                replyToPanel({ "edit_fail", "Unknown command" })
            end
        end
    else
        -- normal traffic from network sides
        -- identify whether packet is from inside or outside by side value
        -- we'll treat messages arriving on inputSide as from INSIDE,
        -- and messages arriving on outputSide as from OUTSIDE.
        -- If other sides appear, we forward them as a passthrough.
        local isFromInside = (side == inputSide)
        local isFromOutside = (side == outputSide)

        -- if limiter is enabled and limit reached, block both directions
        if limitCfg.enabled then
            if not limiterAllows() then
                -- limiter blocks everything (both directions)
                -- we simply drop/ignore the packet
                -- no response to sender
            else
                -- allow and count
                if isFromInside then
                    -- internal -> external (upload)
                    pcall(function() oP.transmit(channel, replyChannel, msg) end)
                    uc = uc + 1
                    tc = tc + 1
                elseif isFromOutside then
                    -- external -> internal (download)
                    pcall(function() iP.transmit(channel, replyChannel, msg) end)
                    dc = dc + 1
                    tc = tc + 1
                else
                    -- unknown side, passthrough both ways
                    -- try both directions safe
                    pcall(function() oP.transmit(channel, replyChannel, msg) end)
                    pcall(function() iP.transmit(channel, replyChannel, msg) end)
                    tc = tc + 1
                end
            end
        else
            -- limiter not enabled: always forward & count appropriately
            if isFromInside then
                pcall(function() oP.transmit(channel, replyChannel, msg) end)
                uc = uc + 1
                tc = tc + 1
            elseif isFromOutside then
                pcall(function() iP.transmit(channel, replyChannel, msg) end)
                dc = dc + 1
                tc = tc + 1
            else
                pcall(function() oP.transmit(channel, replyChannel, msg) end)
                pcall(function() iP.transmit(channel, replyChannel, msg) end)
                tc = tc + 1
            end
        end
    end
end
