-- MITP DNS Server
-- Listens on channel 312

-- === CONFIG ===
local DNS_CHANNEL = 312
local FILE_NAME = "domains.cfg"

-- Load domains or create default
local DOMAINS = {}
if fs.exists(FILE_NAME) then
    local f = fs.open(FILE_NAME,"r")
    DOMAINS = textutils.unserialize(f.readAll()) or {}
    f.close()
else
    -- default entry
    DOMAINS["example.com"] = os.getComputerID()
    local f = fs.open(FILE_NAME,"w")
    f.write(textutils.serialize(DOMAINS))
    f.close()
end

-- === MODEM ===
local MODEM = peripheral.find("modem") or error("No modem found!")
MODEM.open(DNS_CHANNEL)
print("DNS Server running on channel "..DNS_CHANNEL)

-- === HELPERS ===
local function saveDomains()
    local f = fs.open(FILE_NAME,"w")
    f.write(textutils.serialize(DOMAINS))
    f.close()
end

local function normDomain(d)
    return string.lower(tostring(d))
end

local function respondClient(replyChannel, token, addr, success)
    local msg = {
        TOKEN = token,
        ADDR = addr,
        SUCCESS = success,
        DEST = "CLIENT"
    }
    pcall(function()
        MODEM.transmit(DNS_CHANNEL, replyChannel, msg)
    end)
end

-- === MAIN LOOP ===
while true do
    local e = {os.pullEvent("modem_message")}
    local channel = e[3]
    local replyChannel = e[4]
    local msg = e[5]

    if channel == DNS_CHANNEL and type(msg)=="table" and msg.DEST=="DNS" then
        local action = msg.ACTION
        local token = msg.TOKEN
        if action=="GET_ADDR" then
            local domain = normDomain(msg.ADDR)
			print(domain)
            if domain and DOMAINS[domain] then
                respondClient(replyChannel, token, DOMAINS[domain], true)
            else
                respondClient(replyChannel, token, nil, false)
            end
        end
    end
end
