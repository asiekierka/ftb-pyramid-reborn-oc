local c_port = 30788

local provision_last_id = {}
local provisioning = {}
local p_sids = {}
local file_cache = {}
local provision_clocks = {}

local computer = require("computer")
local serialization = require("serialization")
local component = require("component")
local event = require("event")
local filesystem = require("filesystem")
local m = component.modem
m.open(c_port)
print("Sending reboot message")
local args = {...}
local rs = component.redstone

if (#args == 0) or (args[1] ~= "noreboot") then
for i=1,10 do
  m.broadcast(c_port, "WAKE ME UP INSIDE") -- reboot everyone
  os.sleep(0.05)
end
end
print("Reboot message sent!")

local kdl = nil
kdl = function(name, addr, char, code, player)
  event.ignore("key_down", kdl)
  os.exit(0)
end
event.listen("key_down", kdl)

local function get_next_sid(addr)
  if p_sids[addr] == nil then
    p_sids[addr] = 2
    return 1
  else
    local v = p_sids[addr]
    p_sids[addr] = v + 1
    return v
  end
end

local function append_files(files,from,to)
  if not filesystem.isDirectory(from) then
    table.insert(files,{from=from,to=to})
    return true
  end

  for p in filesystem.list(from) do
    if p ~= nil then
      local frompath = filesystem.concat(from,p)
      local topath = filesystem.concat(to,p)
      if filesystem.isDirectory(frompath) then
        append_files(files,frompath,topath)
      else
        table.insert(files,{from=frompath,to=topath})
      end
    end
  end
end

local function get_file_list(id)
  local files = {}
  append_files(files, "/home/crc32.lua", "/home/crc32.lua")
  append_files(files, "/home/inflate.lua", "/home/inflate.lua")
  append_files(files, "/home/png.lua", "/home/png.lua")
  append_files(files, "/home/qutil.lua", "/home/qutil.lua")
  if id == "xnet" then
    append_files(files, "/home/software_xnet", "/home")
    append_files(files, "/home/software/provisioning_client.lua", "/home/provisioning_client.lua")
    for i=1,16 do append_files(files, "/home/out/" .. i .. ".txt", "/home/quests/" .. i .. ".txt") end
--    append_files(files, "/home/out/1.txt", "/home/quests/1.txt")
  elseif id == "leaderboard" then
    append_files(files, "/home/software_leaderboard", "/home")
    append_files(files, "/home/software/provisioning_client.lua", "/home/provisioning_client.lua")
  else
    append_files(files, "/home/software", "/home")
    append_files(files, "/home/out/"..id..".txt", "/home/quest.txt")
    local fin = io.open("/home/out/"..id..".files", "r")
    while true do
      local fn = fin:read()
      if fn == nil then break end
      append_files(files, fn, fn)
    end
    fin:close()
  end
  return files
end

local function file_to_entry(v)
  local name = v["to"]
  local data = nil
  if file_cache[v["from"]] ~= nil then
    print("Cache hit!")
    data = file_cache[v["from"]]
  else
    local f = io.open(v["from"], "rb")
    data = f:read("*all")
    f:close()
    file_cache[v["from"]] = data
  end
  return {name=name,data=data}
end

local function send(address,hdr,message,param,param2,param3)
  m.send(address, c_port, serialization.serialize(hdr), message, param, param2, param3)
  hdr["mid"] = hdr["mid"] + 1
end

local provision_func = nil

event.listen("modem_message", function(name, localAddress, remoteAddress, port, distance, message, param1, param2)
  if math.floor(port) == c_port then
    if message == "PROVISIONING REQUEST" then
      local id = param1
      local sid = param2
      if provision_last_id[remoteAddress] == sid then
        print("Duplicate request ignored from " .. remoteAddress)
      elseif provisioning[remoteAddress] then
        print("Currently provisioning " .. remoteAddress .. ", ignoring")
      else
        provision_last_id[remoteAddress] = sid
        local v,err = pcall(provision_func, remoteAddress, message, param1, param2)
        if not v then
          print(err)
        end
      end
    end
  end
end)

provision_func = function(remoteAddress, message, id, sid)
  provisioning[remoteAddress] = true
  os.sleep(0.05)
  print("Received request from " .. remoteAddress .. " (" .. id .. ")")
  local hdr = {mid=0,sid=get_next_sid(remoteAddress)}
  local idSplit = id:find(":")
  local idColor = "red"
  if idSplit ~= nil then
    local idColor = id:sub(idSplit+1)
    id = id:sub(1, idSplit-1)
  end
  
  m.send(remoteAddress, c_port, "PROVISIONING ACCEPT", serialization.serialize(hdr))
  local fid = 1
  for k,v in pairs(get_file_list(id)) do
    print("- " .. v["from"] .. " -> " .. id .. ":" .. v["to"])
    local str = serialization.serialize(file_to_entry(v))
    while #str > 6144 do
      send(remoteAddress, hdr, "FILEPART", fid, str:sub(1,6144))
      str=str:sub(6145)
    end
    send(remoteAddress, hdr, "FILE", fid, str)
    fid = fid + 1
  end
  print("- 'DONE' packet")
  send(remoteAddress, hdr, "DONE", 0)
  provisioning[remoteAddress] = false
end

while true do
  os.sleep(0.05)
  if rs.getInput(0) ~= 0 then
    for i=1,10 do
      m.broadcast(c_port, "WAKE ME UP INSIDE")
      os.sleep(0.05)
    end
  end
end