local id = nil
local f = io.open("/home/id", "r")
id = f:read()
f:close()

if not id:find(":") then
  id = id .. ":red"
  f = io.open("/home/id", "w")
  f:write(id .. "\n")
  f:flush()
  f:close()
end

local c_port = 30788
local c_sid = math.floor(math.random(0, 1048576))

local filesystem = require("filesystem")
local shell = require("shell")
local component = require("component")
local event = require("event")
local computer = require("computer")
local serialization = require("serialization")
local m = component.modem
m.open(c_port)
m.setStrength(2048)
m.setWakeMessage("WAKE ME UP INSIDE")

-- configure reboot handler
event.listen("modem_message", function(name, localAddress, remoteAddress, port, distance, message)
  if c_port == math.floor(port) and message == "WAKE ME UP INSIDE" then
    computer.shutdown(true)
  end
end)

print(".-----------------------------------.")
print("|                                   |")
print("|  Quest Provisioning System v 1.1  |")
print("|                                   |")
print("'-----------------------------------'")
print("")
print("Registered as '" .. id .. "'")
print("")

local l_handler = nil
local l_found = false
local l_port = nil
local l_hdr = nil
local l_addr = nil

l_handler = function(name, localAddress, remoteAddress, port, distance, message, param)
  if math.floor(port) == c_port and message == "PROVISIONING ACCEPT" then
    l_found = true
    l_addr = remoteAddress
    if param ~= nil then
      l_hdr = serialization.unserialize(param)
    end
    event.ignore("modem_message", l_handler)
  elseif math.floor(port) == c_port and message == "PROVISIONING SHELL" then
    event.ignore("modem_message", l_handler)
    os.exit(1)
  end
end

event.listen("modem_message", l_handler)

local delay = 10.0
local i = delay
local j = 0
while not l_found do
  os.sleep(0.05)
  i = i + 0.05
  if i >= delay then
    i = 0
    j = j + 1
    if (j % 12) == 0 then
      c_sid = math.floor(math.random(0, 1048576))
    end
    print("Searching for provisioning system [" .. c_sid .. "]")
    m.broadcast(c_port, "PROVISIONING REQUEST", id, c_sid)
  end
end

print("Provisioning system found")
local time_start = computer.uptime()

local fileparts = {}
local filesToUnpack = {}
local pidx = nil
local mids_received = {}

l_handler = function(name, localAddress, remoteAddress, port, distance, message, param, param2, param3)
  if math.floor(port) == c_port then
    -- THIS CODE MUST NEVER CALL NON-DIRECT CODE

    if message == "PROVISIONING REQUEST" then
      return true
-- computer.reboot(true) -- server moved on to another computer? maybe
    elseif message == "PROVISIONING ACCEPT" then return true end

    local hdr = {}
    if l_hdr ~= nil then
      hdr = serialization.unserialize(message)
      message = param
      param = param2
      param2 = param3
      if hdr["sid"] ~= l_hdr["sid"] then
--        print("SID mismatch")
        return true
      end
      if mids_received[hdr["mid"]] ~= nil then
--        print("MID already received")
        return true
      end
      mids_received[hdr["mid"]] = 1
    end
    local npidx = nil
    if message == "FILEPART" or message == "FILE" then
      if fileparts[param] == nil then fileparts[param] = param2
      else fileparts[param] = fileparts[param] .. param2 end
    end

    if message == "FILEPART" then
      -- pass
    elseif message == "FILE" then
      table.insert(filesToUnpack, param)
      print("Received file " .. param)
    elseif message == "DONE" then
      print("Launching questing software")
      event.ignore("modem_message", l_handler)
      l_found = true
    end
    if npidx ~= nil then
      if pidx ~= nil and (pidx+1) ~= npidx then
        print("Packet desync: " .. pidx .. "+1 != " .. npidx)
--        computer.shutdown(true)
      end
      pidx = npidx
    end
  end
end

local l_handler_wrap = l_handler
l_handler = function(a,b,c,d,e,f,g,h,i,j,k,l)
  local v,err=pcall(l_handler_wrap,a,b,c,d,e,f,g,h,i,j,k,l)
  if not v then
    print(err)
    print(f .. ", " .. g)
  end
end

l_found = false
event.listen("modem_message", l_handler)

while not l_found do
  os.sleep(0.05)
  if (computer.uptime() - time_start) > 120 then
    computer.shutdown(true)
  end
end

for k,v in pairs(filesToUnpack) do
  local file = serialization.unserialize(fileparts[v])
  if file == nil then computer.shutdown(true) end

  print("Storing file " .. file["name"])
  shell.execute("mkdir " .. filesystem.concat(file["name"], "..") .. " 2>/dev/null")
  local f = io.open(file["name"], "wb")
  f:write(file["data"])
  f:flush()
  f:close()
end

shell.setWorkingDirectory("/home")
shell.execute("quest.lua")
os.sleep(5)
computer.shutdown(true)