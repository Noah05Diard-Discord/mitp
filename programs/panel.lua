-- panel_gui.lua
-- Click-only GUI panel for router (fully mouse-driven)
local modem = peripheral.find("modem") or error("No modem found!")
local panelPort = 2
modem.open(panelPort)

-- UI helpers
local function send(msg) modem.transmit(panelPort, panelPort, msg) end

local function receive(timeout)
    local timer = os.startTimer(timeout or 3)
    while true do
        local e = {os.pullEvent()}
        if e[1] == "modem_message" and e[3] == panelPort then return e[5] end
        if e[1] == "timer" and e[2] == timer then return nil end
    end
end

local function clear()
    term.setBackgroundColor(colors.black)
    term.clear()
    term.setCursorPos(1,1)
    term.setTextColor(colors.white)
end

local function center(y, text, color)
    local w, _ = term.getSize()
    local x = math.max(1, math.floor((w - #text) / 2) + 1)
    if color then term.setTextColor(color) end
    term.setCursorPos(x, y)
    term.write(text)
    term.setTextColor(colors.white)
end

local function drawRect(x, y, w, h, bg, fg)
    term.setBackgroundColor(bg or colors.gray)
    term.setTextColor(fg or colors.white)
    for j = 0, h-1 do
        term.setCursorPos(x, y + j)
        term.write((" "):rep(w))
    end
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
end

-- simple button draw; returns button table
local function drawButton(x, y, w, label)
    drawRect(x, y, w, 1, colors.gray, colors.white)
    local tx = x + math.floor((w - #label) / 2)
    term.setCursorPos(tx, y)
    term.write(label)
    return {x=x, y=y, w=w, id=label}
end

local function waitClick(buttons)
    while true do
        local ev, side, cx, cy = os.pullEvent("mouse_click")
        for _, b in ipairs(buttons) do
            if cy == b.y and cx >= b.x and cx <= b.x + b.w - 1 then
                return b.id
            end
        end
    end
end

-- numeric keypad modal (mouse-only)
-- returns string (digits) or nil if cancelled
local function numericKeypad(prompt, maxLen)
    maxLen = maxLen or 6
    local input = ""
    while true do
        clear()
        center(2, prompt, colors.cyan)
        center(4, "[" .. (input == "" and " " or input) .. "]", colors.yellow)

        -- draw keypad
        local startX, startY = 10, 7
        local keys = {
            {"1","2","3"},
            {"4","5","6"},
            {"7","8","9"},
            {"<","0","OK"},
            {"CANCEL"}
        }
        local buttons = {}
        for r = 1, #keys do
            local row = keys[r]
            local cols = #row
            for c = 1, cols do
                local label = row[c]
                local bx = startX + (c-1)*6
                local by = startY + (r-1)*2
                drawButton(bx, by, 5, label)
                table.insert(buttons, {x=bx, y=by, w=5, id=label})
            end
        end

        local id = waitClick(buttons)
        if id == "OK" then
            if input ~= "" then return input end
        elseif id == "<" then
            input = input:sub(1, -2)
        elseif id == "CANCEL" then
            return nil
        else
            if #input < maxLen then
                input = input .. id
            end
        end
    end
end

-- password keypad modal (masked input)
local function passwordKeypad(prompt, maxLen)
    maxLen = maxLen or 12
    local real = ""
    while true do
        clear()
        center(2, prompt, colors.cyan)
        local masked = string.rep("*", #real)
        center(4, "[" .. (masked == "" and " " or masked) .. "]", colors.yellow)

        -- keypad same as numeric but includes letters? We'll keep numeric keypad for simplicity.
        local res = numericKeypad("Enter password (OK to confirm)", maxLen)
        if not res then return nil end
        return res
    end
end

-- confirmation dialog
local function confirmDialog(text)
    clear()
    center(4, text, colors.yellow)
    local b1 = drawButton(10, 8, 12, "YES")
    local b2 = drawButton(26, 8, 12, "NO")
    local pick = waitClick({b1, b2})
    return pick == "YES"
end

-- masked center hint
local function infoScreen(title, lines)
    clear()
    center(2, title, colors.cyan)
    for i = 1, #lines do
        local y = 4 + i - 1
        term.setCursorPos(4, y)
        term.write(lines[i])
    end
    center(20, "Click anywhere to continue", colors.gray)
    os.pullEvent("mouse_click")
end

-- login screen (mouse keypad for password)
local function loginScreen()
    while true do
        local pwd = passwordKeypad("Router Panel - Enter Password")
        if not pwd then return nil end
        send({ "login", pwd })
        local r = receive()
        if r and r[1] == "login_ok" then
            return pwd
        else
            infoScreen("Login failed", {"Wrong password. Try again."})
        end
    end
end

-- render main dashboard buttons, return id of clicked
local function dashboardMenu()
    clear()
    center(2, "Router Control Panel", colors.cyan)
    local buttons = {}
    table.insert(buttons, drawButton(10,5,20,"View Status"))
    table.insert(buttons, drawButton(10,7,20,"List Ports"))
    table.insert(buttons, drawButton(10,9,20,"Add Port"))
    table.insert(buttons, drawButton(10,11,20,"Remove Port"))
    table.insert(buttons, drawButton(10,13,20,"Change Password"))
    table.insert(buttons, drawButton(10,15,20,"Data Limiter"))
    table.insert(buttons, drawButton(10,17,20,"Reset Counters"))
    table.insert(buttons, drawButton(10,19,20,"Logout"))
    return waitClick(buttons)
end

-- show status
local function showStatus()
    send({"main"})
    local r = receive()
    if r and r[1] == "status" then
        infoScreen("Router Status", {
            "Download (external->internal): " .. tostring(r[2]),
            "Upload (internal->external): " .. tostring(r[3]),
            "Total: " .. tostring(r[4])
        })
    else
        infoScreen("Router Status", {"No response from router."})
    end
end

-- list ports (clickable; returns selected port or nil)
local function listPortsScreen()
    send({"list"})
    local r = receive()
    if not (r and r[1] == "list") then
        infoScreen("Ports", {"No response or empty list."})
        return nil
    end
    local ports = r[2] or {}
    while true do
        clear()
        center(2, "Open Ports (click a port to copy/act)", colors.cyan)
        local buttons = {}
        local y = 4
        for i, p in ipairs(ports) do
            local txt = tostring(p)
            term.setCursorPos(6, y)
            term.write("- " .. txt)
            drawRect(26, y, 8, 1, colors.gray, colors.white)
            term.setCursorPos(27, y)
            term.write("SELECT")
            table.insert(buttons, {x=26, y=y, w=6, id=txt})
            y = y + 1
            if y >= 18 then break end
        end
        center(20, "Click SELECT to choose a port, or anywhere else to return", colors.gray)
        local ev, side, cx, cy = os.pullEvent("mouse_click")
        local chosen = nil
        for _, b in ipairs(buttons) do
            if cy == b.y and cx >= b.x and cx <= b.x + b.w - 1 then
                chosen = tonumber(b.id)
                break
            end
        end
        if not chosen then return nil end
        -- chosen port: show actions for that port
        local ok = confirmDialog("Remove port " .. tostring(chosen) .. " ?")
        if ok then
            return chosen
        end
    end
end

-- Add port flow (keypad)
local function addPortFlow(pwd)
    local pstr = numericKeypad("Enter port to ADD (OK to confirm)", 5)
    if not pstr then return end
    local port = tonumber(pstr)
    if not port then infoScreen("Add Port", {"Invalid port number."}); return end
    send({"edit", pwd, "add", port})
    local r = receive()
    if r then infoScreen("Add Port", {r[2] or "Response received"}) else infoScreen("Add Port", {"No response"}) end
end

-- Remove port flow (list -> confirm)
local function removePortFlow(pwd)
    local chosen = listPortsScreen()
    if not chosen then return end
    -- confirm removal
    if confirmDialog("Confirm remove port " .. tostring(chosen) .. " ?") then
        send({"edit", pwd, "remove", chosen})
        local r = receive()
        if r then infoScreen("Remove Port", {r[2] or "Response received"}) else infoScreen("Remove Port", {"No response"}) end
    end
end

-- change password flow (masked keypad)
local function changePasswordFlow(pwd)
    local newp = passwordKeypad("Enter NEW password (OK to confirm)")
    if not newp then return end
    -- confirm twice
    local confirm = passwordKeypad("Confirm NEW password")
    if not confirm then return end
    if confirm ~= newp then infoScreen("Change Password", {"Passwords do not match."}); return end
    send({"edit", pwd, "passwd", newp})
    local r = receive()
    if r and r[1] == "edit_ok" then
        infoScreen("Password", {"Password changed."})
        -- return new password to use for further actions
        return newp
    else
        infoScreen("Password", {r and r[2] or "No response"})
        return nil
    end
end

-- Data limiter UI (fully clickable)
local function dataLimiterFlow(pwd)
    -- fetch current limiter info
    send({"getlimit"})
    local r = receive()
    if not (r and r[1] == "limitinfo") then infoScreen("Data Limiter", {"No response from router."}); return end
    local lim = r[2] or {}
    local cnt = r[3] or {dc=0, uc=0}
    lim.enabled = lim.enabled == true
    lim.upLimit = tonumber(lim.upLimit) or 0
    lim.downLimit = tonumber(lim.downLimit) or 0

    while true do
        clear()
        center(2, "Data Limiter", colors.cyan)
        term.setCursorPos(4,4)
        term.write("Enabled: " .. tostring(lim.enabled))
        term.setCursorPos(4,5)
        term.write("Upload limit (internal->external): " .. tostring(lim.upLimit) .. "   Used: " .. tostring(cnt.uc))
        term.setCursorPos(4,6)
        term.write("Download limit (external->internal): " .. tostring(lim.downLimit) .. "   Used: " .. tostring(cnt.dc))

        local buttons = {}
        table.insert(buttons, drawButton(4, 9, 18, lim.enabled and "Disable" or "Enable"))
        table.insert(buttons, drawButton(24,9,18, "Set Upload"))
        table.insert(buttons, drawButton(4,11,18, "Set Download"))
        table.insert(buttons, drawButton(24,11,18, "Reset Counters"))
        table.insert(buttons, drawButton(14,13,18, "Back"))
        local choice = waitClick(buttons)
        if choice == (lim.enabled and "Disable" or "Enable") then
            lim.enabled = not lim.enabled
            send({"edit", pwd, "limit", {enabled=lim.enabled, up=lim.upLimit, down=lim.downLimit}})
            local resp = receive()
            infoScreen("Limiter", {resp and resp[2] or "No response"})
        elseif choice == "Set Upload" then
            local v = numericKeypad("Set upload limit (packets)", 7)
            if v then
                lim.upLimit = tonumber(v) or lim.upLimit
                send({"edit", pwd, "limit", {enabled=lim.enabled, up=lim.upLimit, down=lim.downLimit}})
                local resp = receive()
                infoScreen("Limiter", {resp and resp[2] or "No response"})
            end
        elseif choice == "Set Download" then
            local v = numericKeypad("Set download limit (packets)", 7)
            if v then
                lim.downLimit = tonumber(v) or lim.downLimit
                send({"edit", pwd, "limit", {enabled=lim.enabled, up=lim.upLimit, down=lim.downLimit}})
                local resp = receive()
                infoScreen("Limiter", {resp and resp[2] or "No response"})
            end
        elseif choice == "Reset Counters" then
            if confirmDialog("Reset traffic counters?") then
                send({"edit", pwd, "resetcounters"})
                local resp = receive()
                infoScreen("Limiter", {resp and resp[2] or "No response"})
            end
        elseif choice == "Back" then
            return
        end
        -- refresh limiter data
        send({"getlimit"})
        r = receive()
        if r and r[1] == "limitinfo" then
            lim = r[2] or lim
            cnt = r[3] or cnt
            lim.enabled = lim.enabled == true
            lim.upLimit = tonumber(lim.upLimit) or lim.upLimit
            lim.downLimit = tonumber(lim.downLimit) or lim.downLimit
        end
    end
end

-- Reset counters flow (quick)
local function resetCountersFlow(pwd)
    if confirmDialog("Reset router counters (dc/uc/total)?") then
        send({"edit", pwd, "resetcounters"})
        local r = receive()
        if r then infoScreen("Reset Counters", {r[2] or "Response"}) else infoScreen("Reset Counters", {"No response"}) end
    end
end

-- main loop
while true do
    clear()
    local pwd = loginScreen()
    if not pwd then break end

    while true do
        local choice = dashboardMenu()
        if choice == "View Status" then
            showStatus()
        elseif choice == "List Ports" then
            -- just show ports, allow removal by selecting "SELECT" next to a port
            local removedPort = listPortsScreen()
            if removedPort then
                if confirmDialog("Remove port " .. tostring(removedPort) .. " ?") then
                    send({"edit", pwd, "remove", removedPort})
                    local r = receive()
                    infoScreen("Remove Port", {r and r[2] or "No response"})
                end
            end
        elseif choice == "Add Port" then
            addPortFlow(pwd)
        elseif choice == "Remove Port" then
            removePortFlow(pwd)
        elseif choice == "Change Password" then
            local newp = changePasswordFlow(pwd)
            if newp then pwd = newp end
        elseif choice == "Data Limiter" then
            dataLimiterFlow(pwd)
        elseif choice == "Reset Counters" then
            resetCountersFlow(pwd)
        elseif choice == "Logout" then
            break
        end
    end
end
