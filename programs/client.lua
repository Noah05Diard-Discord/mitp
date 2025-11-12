-- MITP Website Client (CPID-aware) with Scrolling - FIXED
local MODEM = peripheral.find("modem") or error("No modem found!")
MODEM.open(312)

local DNS_CHANNEL = 312
local TOKEN_COUNTER = 0
local colors_table = {
    black=colors.black, white=colors.white, red=colors.red,
    green=colors.green, blue=colors.blue, yellow=colors.yellow,
    cyan=colors.cyan, magenta=colors.magenta, gray=colors.gray,
    lightGray=colors.lightGray, orange=colors.orange
}

-- Scrolling variables
local scrollY = 0
local maxScrollY = 0
local contentHeight = 0

local function getToken()
    TOKEN_COUNTER = TOKEN_COUNTER + 1
    return math.random(1000,9999) + TOKEN_COUNTER
end

-- DNS resolution: returns server PCID
local function getPCID(domain)
    local token = getToken()
    MODEM.transmit(DNS_CHANNEL, DNS_CHANNEL, {
        ACTION="GET_ADDR",
        ADDR=domain,
        TOKEN=token,
        DEST="DNS"
    })
    local timer = os.startTimer(5)
    while true do
        local e = {os.pullEvent()}
        if e[1]=="modem_message" and type(e[5])=="table" and e[5].TOKEN==token and e[5].DEST=="CLIENT" then
            return e[5].ADDR, e[5].SUCCESS
        elseif e[1]=="timer" and e[2]==timer then
            return nil,false
        end
    end
end

-- Get page from server
local function getPage(serverPCID, page)
    local token = getToken()
    MODEM.transmit(DNS_CHANNEL, 312, {
        ACTION="GET_WEB",
        ADDR=serverPCID,       -- target server PCID from DNS
        PAGE=page,
        DEST="SERVER",
        TOKEN=token,
        CPID=os.getComputerID()  -- send client CPID for authorization
    })
    local timer = os.startTimer(5)
    while true do
        local e = {os.pullEvent()}
        if e[1]=="modem_message" and type(e[5])=="table" and e[5].TOKEN==token and e[5].DEST=="CLIENT" then
            return e[5].PAGE
        elseif e[1]=="timer" and e[2]==timer then
            return nil
        end
    end
end

-- Parse MCML into ordered table of elements
local function parseMCML(content)
    local elements = {}
    local styles = {}

    -- Parse head styles
    local head = content:match("<head>(.-)</head>") or ""
    for forid, defs in head:gmatch('<style%s+for="(.-)">(.-)</style>') do
        local styleTable = {}
        for k,v in defs:gmatch("(%w+)%s*:%s*(%w+)") do
            styleTable[k] = v
        end
        styles[forid] = styleTable
    end

    -- Parse body
    local bodyID, bodyContent = content:match('<body%s+id="(.-)">(.-)</body>')
    if not bodyID then
        bodyContent = content:match('<body.->(.-)</body>') or ""
        bodyID = "body"
    end
    local bodyStyle = styles[bodyID] or {}

    -- Split by <newLine> and append it to process last line
    bodyContent = bodyContent .. "<newLine>"
    
    for line in bodyContent:gmatch("(.-)<newLine>") do
        local pos = 1
        while pos <= #line do
            -- Find next tag
            local s,e,tag = line:find("<(%w+)", pos)
            if s then
                -- capture text before tag as plain text
                if s > pos then
                    local plain = line:sub(pos, s-1)
                    if #plain>0 then
                        table.insert(elements,{type="text", text=plain, style=bodyStyle})
                    end
                end

                if tag=="text" then
                    -- extract id, x, y and text content
                    local full = line:sub(s)
                    local id = full:match('<text%s+id="(.-)"') or ""
                    local x = tonumber(full:match('<text.-x="(.-)"'))
                    local y = tonumber(full:match('<text.-y="(.-)"'))
                    local text = full:match('<text.->(.-)</text>') or ""
                    local style = (id~="" and styles[id]) or bodyStyle
                    table.insert(elements,{type="text", text=text, style=style, x=x, y=y})
                    local endPos = line:find("</text>", s)
                    pos = endPos and (endPos + 7) or (e + 1)
                    
                elseif tag=="button" then
                    local full = line:sub(s)
                    local web = full:match('web="(.-)"') or ""
                    local page = full:match('page="(.-)"') or ""
                    local id = full:match('id="(.-)"') or ""
                    local x = tonumber(full:match('<button.-x="(.-)"'))
                    local y = tonumber(full:match('<button.-y="(.-)"'))
                    local label = full:match('<button.->(.-)</button>') or ""
                    local style = (id~="" and styles[id]) or bodyStyle
                    -- Set default button colors
                    style = {
                        textColor = style.textColor or "white",
                        bgColor = style.bgColor or "blue"
                    }
                    table.insert(elements,{type="button", text=label, web=web, page=page, style=style, x=x, y=y})
                    local endPos = line:find("</button>", s)
                    pos = endPos and (endPos + 9) or (e + 1)
                    
                elseif tag=="rect" then
                    local full = line:sub(s)
                    local id = full:match('<rect%s+id="(.-)"') or ""
                    local x = tonumber(full:match('<rect.-x="(.-)"'))
                    local y = tonumber(full:match('<rect.-y="(.-)"'))
                    local width = tonumber(full:match('<rect.-width="(.-)"')) or 1
                    local height = tonumber(full:match('<rect.-height="(.-)"')) or 1
                    local style = (id~="" and styles[id]) or bodyStyle
                    table.insert(elements,{type="rect", width=width, height=height, style=style, x=x, y=y})
                    local endPos = line:find("/>", s) or line:find("</rect>", s)
                    pos = endPos and (endPos + 2) or (e + 1)
                    
                elseif tag=="textbox" then
                    local full = line:sub(s)
                    local id = full:match('<textbox%s+id="(.-)"') or ""
                    local x = tonumber(full:match('<textbox.-x="(.-)"'))
                    local y = tonumber(full:match('<textbox.-y="(.-)"'))
                    local width = tonumber(full:match('<textbox.-width="(.-)"')) or 10
                    local height = tonumber(full:match('<textbox.-height="(.-)"')) or 1  -- Force height to 1
                    local web = full:match('web="(.-)"') or ""
                    local page = full:match('page="(.-)"') or ""
                    local style = (id~="" and styles[id]) or bodyStyle
                    table.insert(elements,{type="textbox", id=id, width=width, height=1, web=web, page=page, style=style, x=x, y=y, content=""})
                    local endPos = line:find("/>", s) or line:find("</textbox>", s)
                    pos = endPos and (endPos + 2) or (e + 1)
                else
                    pos = e+1
                end
            else
                -- no more tags, remaining text
                local remaining = line:sub(pos)
                if #remaining>0 then
                    table.insert(elements,{type="text", text=remaining, style=bodyStyle})
                end
                break
            end
        end
        -- newline at end of line
        table.insert(elements,{type="newline"})
    end

    return elements, styles, bodyID, bodyStyle
end

-- Calculate content height for scrolling - FIXED
local function calculateContentHeight(elements)
    local maxY = 2  -- Start from line 2
    
    for _, el in ipairs(elements) do
        local elementBottom = 2
        
        if el.type == "newline" then
            -- For newlines, we need to track the current Y position
            -- This is handled in the main rendering loop
        elseif el.type == "text" then
            if el.y then
                elementBottom = el.y
            else
                -- If no Y specified, use current position
                elementBottom = maxY
            end
        elseif el.type == "button" then
            if el.y then
                elementBottom = el.y
            else
                elementBottom = maxY
            end
        elseif el.type == "rect" then
            if el.y then
                elementBottom = el.y + (el.height or 1) - 1
            else
                elementBottom = maxY + (el.height or 1) - 1
            end
        elseif el.type == "textbox" then
            if el.y then
                elementBottom = el.y + 2  -- Textbox has 3 lines (border)
            else
                elementBottom = maxY + 2
            end
        end
        
        -- Update maxY if this element extends further down
        if elementBottom > maxY then
            maxY = elementBottom
        end
    end
    
    -- Also count newlines to get proper height
    local currentY = 2
    for _, el in ipairs(elements) do
        if el.type == "newline" then
            currentY = currentY + 1
            if currentY > maxY then
                maxY = currentY
            end
        elseif el.type == "text" then
            if el.y and el.y > currentY then
                currentY = el.y
            end
        elseif el.type == "button" then
            if el.y and el.y > currentY then
                currentY = el.y
            end
        elseif el.type == "rect" then
            if el.y and el.y > currentY then
                currentY = el.y
            end
            currentY = currentY + (el.height or 1)
        elseif el.type == "textbox" then
            if el.y and el.y > currentY then
                currentY = el.y
            end
            currentY = currentY + 3  -- Textbox height with border
        end
        
        if currentY > maxY then
            maxY = currentY
        end
    end
    
    return maxY
end

-- Render the MCML table with scrolling - FIXED
local function renderMCML(elements, bodyStyle)
    local bg = colors_table[bodyStyle.bgColor] or colors.black
    local fg = colors_table[bodyStyle.textColor] or colors.white
    term.setBackgroundColor(bg)
    term.setTextColor(fg)
    
    -- Clear from line 2 downward
    local screenWidth, screenHeight = term.getSize()
    for i=2,screenHeight do
        term.setCursorPos(1,i)
        term.clearLine()
    end

    local x,y = 1,2  -- Start at line 2
    local buttons = {}
    local textboxes = {}

    -- First pass: render all elements with scroll offset
    for _, el in ipairs(elements) do
        if el.type=="newline" then
            y=y+1
            x=1
        elseif el.type=="text" then
            -- Set position if specified
            if el.x and el.y then
                x, y = el.x, el.y
            end
            
            -- Apply scrolling offset
            local renderY = y - scrollY
            if renderY >= 2 and renderY <= screenHeight then
                local fg = colors_table[el.style.textColor] or colors_table[bodyStyle.textColor] or colors.white
                local bg = colors_table[el.style.bgColor] or colors_table[bodyStyle.bgColor] or colors.black
                term.setTextColor(fg)
                term.setBackgroundColor(bg)
                term.setCursorPos(x,renderY)
                term.write(el.text)
            end
            x=x+#el.text
            
        elseif el.type=="button" then
            -- Set position if specified
            if el.x and el.y then
                x, y = el.x, el.y
            end
            
            -- Apply scrolling offset
            local renderY = y - scrollY
            if renderY >= 2 and renderY <= screenHeight then
                local fg = colors_table[el.style.textColor] or colors.white
                local bg = colors_table[el.style.bgColor] or colors.blue
                term.setTextColor(fg)
                term.setBackgroundColor(bg)
                term.setCursorPos(x,renderY)
                term.write(" "..el.text.." ")
                table.insert(buttons,{x=x,y=renderY,w=#el.text+2,web=el.web,page=el.page,originalY=y})
            end
            x=x+#el.text+2
            
        elseif el.type=="rect" then
            -- Set position if specified
            if el.x and el.y then
                x, y = el.x, el.y
            end
            
            local bg = colors_table[el.style.bgColor] or colors_table[bodyStyle.bgColor] or colors.black
            term.setBackgroundColor(bg)
            
            -- Draw rectangle with scrolling
            for row = 0, (el.height or 1)-1 do
                local renderY = y + row - scrollY
                if renderY >= 2 and renderY <= screenHeight then
                    term.setCursorPos(x, renderY)
                    term.write(string.rep(" ", el.width or 1))
                end
            end
            
            x = x + (el.width or 1)
            
        elseif el.type=="textbox" then
            -- Set position if specified
            if el.x and el.y then
                x, y = el.x, el.y
            end
            
            local fg = colors_table[el.style.textColor] or colors_table[bodyStyle.textColor] or colors.white
            local bg = colors_table[el.style.bgColor] or colors_table[bodyStyle.bgColor] or colors.black
            local borderColor = colors_table[el.style.borderColor] or colors.white
            
            -- Draw textbox border and content with scrolling
            for row = 0, 2 do
                local renderY = y + row - scrollY
                if renderY >= 2 and renderY <= screenHeight then
                    term.setBackgroundColor(borderColor)
                    term.setTextColor(borderColor)
                    term.setCursorPos(x, renderY)
                    
                    if row == 0 then
                        term.write("+" .. string.rep("-", el.width) .. "+")
                    elseif row == 1 then
                        term.write("|")
                        term.setBackgroundColor(bg)
                        term.setTextColor(fg)
                        term.write(string.rep(" ", el.width))
                        term.setBackgroundColor(borderColor)
                        term.setTextColor(borderColor)
                        term.write("|")
                    elseif row == 2 then
                        term.write("+" .. string.rep("-", el.width) .. "+")
                    end
                end
            end
            
            -- Write the content with scrolling
            local contentY = y + 1 - scrollY
            if contentY >= 2 and contentY <= screenHeight then
                if el.content and #el.content > 0 then
                    term.setBackgroundColor(bg)
                    term.setTextColor(fg)
                    term.setCursorPos(x+1, contentY)
                    if #el.content > el.width then
                        term.write(el.content:sub(1, el.width))
                    else
                        term.write(el.content)
                    end
                end
            end
            
            -- Store textbox info for interaction
            table.insert(textboxes, {
                x=x+1, y=y+1, width=el.width, height=1,
                id=el.id, web=el.web, page=el.page,
                content=el.content or "",
                bg=bg, fg=fg, borderColor=borderColor,
                originalY=y+1  -- Store original position for click detection
            })
            
            x = x + el.width + 2
        end
    end

    -- Draw scrollbar if needed - FIXED
    if maxScrollY > 0 then
        local scrollbarX = screenWidth
        local availableHeight = screenHeight - 2  -- Minus URL bar
        local scrollbarHeight = math.max(1, math.floor(availableHeight * (availableHeight / contentHeight)))
        local scrollbarPos = 2 + math.floor((scrollY / maxScrollY) * (availableHeight - scrollbarHeight))
        
        -- Debug info
        term.setCursorPos(1, screenHeight)
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.gray)
        term.write("H:" .. contentHeight .. " S:" .. scrollY .. "/" .. maxScrollY)
        
        for yPos = 2, screenHeight do
            term.setBackgroundColor(colors.black)
            term.setTextColor(colors.gray)
            term.setCursorPos(scrollbarX, yPos)
            if yPos >= scrollbarPos and yPos < scrollbarPos + scrollbarHeight then
                term.write("#")
            else
                term.write("|")
            end
        end
    end

    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    return buttons, textboxes
end

-- Handle textbox input
local function handleTextboxInput(textbox)
    local content = textbox.content
    local cursorPos = #content + 1
    
    -- Calculate screen position considering scroll
    local screenY = textbox.originalY - scrollY
    if screenY < 2 or screenY > term.getSize() then
        return content, false  -- Textbox not visible
    end
    
    term.setBackgroundColor(textbox.bg)
    term.setTextColor(textbox.fg)
    term.setCursorPos(textbox.x, screenY)
    term.write(string.rep(" ", textbox.width))
    term.setCursorPos(textbox.x, screenY)
    term.write(content)
    term.setCursorPos(textbox.x + cursorPos - 1, screenY)
    
    while true do
        local event = {os.pullEvent()}
        if event[1] == "char" then
            -- Add character
            if #content < textbox.width then
                content = content:sub(1, cursorPos - 1) .. event[2] .. content:sub(cursorPos)
                cursorPos = cursorPos + 1
                term.write(event[2])
            end
        elseif event[1] == "key" then
            local key = event[2]
            if key == keys.enter then
                -- Validate and navigate if web and page are specified
                if textbox.web and textbox.web ~= "" and textbox.page and textbox.page ~= "" then
                    return content, true  -- Return content and navigation flag
                else
                    return content, false  -- Return content only, no navigation
                end
            elseif key == keys.backspace then
                -- Backspace handling
                if cursorPos > 1 then
                    content = content:sub(1, cursorPos - 2) .. content:sub(cursorPos)
                    cursorPos = cursorPos - 1
                    term.setCursorPos(textbox.x, screenY)
                    term.write(content .. " ")
                    term.setCursorPos(textbox.x + cursorPos - 1, screenY)
                end
            elseif key == keys.left then
                -- Move cursor left
                if cursorPos > 1 then
                    cursorPos = cursorPos - 1
                    term.setCursorPos(textbox.x + cursorPos - 1, screenY)
                end
            elseif key == keys.right then
                -- Move cursor right
                if cursorPos <= #content then
                    cursorPos = cursorPos + 1
                    term.setCursorPos(textbox.x + cursorPos - 1, screenY)
                end
            end
        elseif event[1] == "mouse_click" then
            -- Set cursor position based on click
            local clickX, clickY = event[3], event[4]
            if clickY == screenY and clickX >= textbox.x and clickX <= textbox.x + textbox.width - 1 then
                cursorPos = math.min(clickX - textbox.x + 1, #content + 1)
                term.setCursorPos(textbox.x + cursorPos - 1, screenY)
            else
                -- Click outside textbox - treat as done editing but don't navigate
                return content, false
            end
        end
    end
end

-- Draw URL bar with refresh button and scroll info
local function drawURLBar(domain,page)
    term.setBackgroundColor(colors.gray)
    term.setTextColor(colors.black)
    term.setCursorPos(1,1)
    term.clearLine()
    local urlText = "Domain: "..domain.." | Page: "..page
    if maxScrollY > 0 then
        urlText = urlText .. " | Scroll: " .. scrollY .. "/" .. maxScrollY
    end
    term.write(urlText)
    
    -- Draw refresh button
    local w,h = term.getSize()
    term.setCursorPos(w-9,1)
    term.setBackgroundColor(colors.green)
    term.write(" Refresh ")
    
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
end

-- Handle scrolling
local function handleScrolling(direction)
    local newScrollY = scrollY + direction
    if newScrollY >= 0 and newScrollY <= maxScrollY then
        scrollY = newScrollY
        return true
    end
    return false
end

-- Main UI loop
local function openPage(domain,page)
    -- Reset scroll when loading new page
    scrollY = 0
    maxScrollY = 0
    
    drawURLBar(domain,page)
    local pcid, ok = getPCID(domain)
    if not ok or not pcid then
        term.setCursorPos(1,3)
        print("Domain not found!")
        os.pullEvent("key")
        return
    end

    local content = getPage(pcid,page)
    if not content then
        term.setCursorPos(1,3)
        print("Failed to fetch page!")
        os.pullEvent("key")
        return
    end

    local elements, styles, bodyID, bodyStyle = parseMCML(content)
    
    -- Calculate content height and max scroll - FIXED
    contentHeight = calculateContentHeight(elements)
    local _, screenHeight = term.getSize()
    maxScrollY = math.max(0, contentHeight - screenHeight + 1)
    
    -- Debug output
    print("Content height: " .. contentHeight)
    print("Screen height: " .. screenHeight)
    print("Max scroll: " .. maxScrollY)
    
    local buttons, textboxes = renderMCML(elements, bodyStyle)

    while true do
        local e = {os.pullEvent()}
        if e[1]=="mouse_click" then
            local cx, cy = e[3], e[4]
            
            -- Check if refresh button clicked
            local w,h = term.getSize()
            if cy==1 and cx>=w-9 and cx<=w then
                openPage(domain,page)
                return
            end
            
            -- Check page buttons (adjust for scroll)
            for _,btn in ipairs(buttons) do
                if cy==btn.y and cx>=btn.x and cx<=btn.x+btn.w-1 then
                    openPage(btn.web,btn.page)
                    return
                end
            end
            
            -- Check textboxes for input (adjust for scroll)
            for _,textbox in ipairs(textboxes) do
                local screenY = textbox.originalY - scrollY
                if cy == screenY and cx >= textbox.x and cx <= textbox.x + textbox.width - 1 then
                    local newContent, shouldNavigate = handleTextboxInput(textbox)
                    textbox.content = newContent
                    
                    -- Update the textbox display
                    term.setBackgroundColor(textbox.bg)
                    term.setTextColor(textbox.fg)
                    term.setCursorPos(textbox.x, screenY)
                    term.write(string.rep(" ", textbox.width))
                    term.setCursorPos(textbox.x, screenY)
                    if #newContent > textbox.width then
                        term.write(newContent:sub(1, textbox.width))
                    else
                        term.write(newContent)
                    end
                    
                    -- Navigate if Enter was pressed and web/page are specified
                    if shouldNavigate and textbox.web and textbox.page then
                        openPage(textbox.web, textbox.page .. "?" .. newContent)
                        return
                    end
                    
                    break
                end
            end
            
        elseif e[1]=="key" then
            local key = e[2]
            if key == keys.up then
                -- Scroll up
                if handleScrolling(-1) then
                    buttons, textboxes = renderMCML(elements, bodyStyle)
                    drawURLBar(domain,page)
                end
            elseif key == keys.down then
                -- Scroll down
                if handleScrolling(1) then
                    buttons, textboxes = renderMCML(elements, bodyStyle)
                    drawURLBar(domain,page)
                end
            elseif key == keys.pageUp then
                -- Page up
                local _, screenHeight = term.getSize()
                if handleScrolling(-(screenHeight - 3)) then
                    buttons, textboxes = renderMCML(elements, bodyStyle)
                    drawURLBar(domain,page)
                end
            elseif key == keys.pageDown then
                -- Page down
                local _, screenHeight = term.getSize()
                if handleScrolling(screenHeight - 3) then
                    buttons, textboxes = renderMCML(elements, bodyStyle)
                    drawURLBar(domain,page)
                end
            elseif key == keys.home then
                -- Scroll to top
                if scrollY ~= 0 then
                    scrollY = 0
                    buttons, textboxes = renderMCML(elements, bodyStyle)
                    drawURLBar(domain,page)
                end
            elseif key == keys["end"] then
                -- Scroll to bottom
                if scrollY ~= maxScrollY then
                    scrollY = maxScrollY
                    buttons, textboxes = renderMCML(elements, bodyStyle)
                    drawURLBar(domain,page)
                end
            elseif key == keys.f5 then
                -- Domain navigation (existing functionality)
                term.setCursorPos(1,2)
                term.setBackgroundColor(colors.black)
                term.clearLine()
                write("New Domain: ")
                local newDomain = read()
                write(" Page: ")
                local newPage = read()
                openPage(newDomain,newPage)
                return
            end
        elseif e[1]=="mouse_scroll" then
            -- Mouse wheel scrolling
            local direction = e[2]
            if handleScrolling(direction) then  -- Scroll 3 lines per wheel tick
                buttons, textboxes = renderMCML(elements, bodyStyle)
                drawURLBar(domain,page)
            end
        end
    end
end

-- Start prompt
term.clear()
term.setCursorPos(1,1)
write("Enter domain: ")
local domain = read()
write("Enter page: ")
local page = read()
openPage(domain,page)