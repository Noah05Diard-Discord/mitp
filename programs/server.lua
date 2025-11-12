-- MITP Website Server (CPID authorization)
local SERVER_ID = os.getComputerID()
local MODEM = peripheral.find("modem") or error("No modem found!")
MODEM.open(312)
print("Website server running on channel 312, PCID:", SERVER_ID)

local PAGE_FOLDER = "web_pages"
if not fs.exists(PAGE_FOLDER) then fs.makeDir(PAGE_FOLDER) end

local function readPage(page)
	if page == "" then
		page = "index"
	end
    local path = fs.combine(PAGE_FOLDER, page)
    if not fs.exists(path) then
        path = path .. ".txt"
        if not fs.exists(path) then
			path = PAGE_FOLDER .. "/404"
			if not fs.exists(path) then
				return nil, "Page not found"
			end
		end
    end
    local f = fs.open(path,"r")
    local content = f.readAll()
    f.close()
    return content
end

while true do
    local e = {os.pullEvent("modem_message")}
    local channel, replyChannel, msg = e[3], e[4], e[5]

    if channel==312 and type(msg)=="table" and msg.DEST=="SERVER" then
        if msg.ACTION=="GET_WEB" then
            -- Authorization: only respond if ADDR matches this server PCID
            if msg.ADDR == SERVER_ID then
                local pageName = msg.PAGE or ""
                local token = msg.TOKEN
                
                -- Extract parameters after the first ?
                local param = nil
                local questionMarkPos = pageName:find("?")
                if questionMarkPos then
                    param = pageName:sub(questionMarkPos + 1)
                    -- Remove parameters from pageName for file lookup
                    pageName = pageName:sub(1, questionMarkPos - 1)
                end
                
                local content, err = readPage(pageName)
                content = content or ("ERROR: "..err)
                local response = {
                    TOKEN = token,
                    DEST = "CLIENT",
                    PAGE = content
                }
                pcall(function()
                    MODEM.transmit(replyChannel, 312, response)
                end)
            end
        end
    end
end