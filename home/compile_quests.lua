local addresses = {}
local filesystem = require("filesystem")
local component = require("component")
local databaseAddress = nil
local qutil = require("qutil")
local args = {...}

local do_files = true
local do_quests = true
local tquest = nil

for k,v in pairs(args) do
  if v == "-h" then 
    print("Usage: compile_quests (-h - help)? (-nq - no quests)? (-nf - no file lists)? (quest)")
    os.exit(0)
  elseif v == "-nq" then do_quests = false
  elseif v == "-nf" then do_files = false
  else tquest = v end
end

for addr,type in component.list("database") do
  databaseAddress = addr
end

local database = component.proxy(databaseAddress)

local fin = io.open("./config/chest_map.txt", "r")
while true do
  local text = fin:read()
  if text == nil then break end
  table.insert(addresses, text)
end
fin:close()

local lnames = {}

fin = io.open("./config/names.txt", "r")
while true do
  local text = fin:read()
  if text == nil then break end
  local text2 = fin:read()
  if text2 == nil then break end
  lnames[text] = text2
end
fin:close()

local function get_local_name(s)
  if lnames[s] ~= nil then
    return lnames[s]
  else
    io.stdout:write("Please input name for [" .. s .. "]: ")
    io.stdout:flush()
    local n = io.read()
    lnames[s] = n
    local fout = io.open("./config/names.txt", "a")
    fout:write(s .. "\n" .. n .. "\n")
    fout:flush()
    fout:close()
    return n
  end
end

local function get_inv(i)
  local str = addresses[i]
  local side = tonumber(str:sub(1,1))
  local addr = str:sub(3)
  return component.proxy(addr),side
end

for i=1,17 do
  local qname = tostring(i)
  if i == 17 then qname = "TEST" end

if tquest == nil or tquest == qname then

if do_quests then
  local fin = io.open("./quests/" .. qname .. ".txt", "r")
  if fin ~= nil then

  print("Compiling quest " .. qname)
  local fout = io.open("./out/" .. qname .. ".txt", "w")
  local line = 0
  while true do
    local text = fin:read()
    if text == nil then break end
    line = line + 1
    local textout = {}
    if line >= 2 then
      local entry = 0
      local compmode = 0
      local slot_id = nil
      local ignore_damage = false
      local ignore_nbt = false
      local contains_name = false
      local gen_str = ""
      for w in string.gmatch(text, "%S+") do
        entry = entry + 1
        if compmode == 1 then
          if w == "ignore-damage" then ignore_damage = true
          elseif w == "ignore-nbt" then ignore_nbt = true
          elseif w == "::" then
            compmode = 0
            contains_name = true
          end
        else
          if w:sub(1,1) == "@" then
            compmode = 1
            slot_id = tonumber(w:sub(2))
            table.insert(textout, -1)
          end
        end
        if compmode == 0 then table.insert(textout, w) end
      end
      if slot_id ~= nil then
        local inv,side = get_inv(i)
        inv.store(side,slot_id,databaseAddress,1)
        local stack = inv.getStackInSlot(side,slot_id)
        gen_str = stack["name"]
        if textout[1] == "auto" then textout[1] = tostring(stack["size"]) end
        if not ignore_damage then gen_str = gen_str .. "/" .. tonumber(math.floor(stack["damage"])) end
        if not ignore_nbt then gen_str = gen_str .. " " .. database.computeHash(1) end
        print("Line " .. line .. ", injecting " .. gen_str .. " x " .. stack["size"])
      end
      if not contains_name and #gen_str > 0 then
        table.insert(textout, ":: " .. get_local_name(gen_str))
      end
      entry = 0
      local tstr = ""
      for k,v in pairs(textout) do
        if v == -1 then v = gen_str end
        if entry > 0 then
          tstr = tstr .. " "
          fout:write(" ")
        end
        tstr = tstr .. v
        fout:write(v)
        entry = entry + 1
      end
      fout:write("\n")
    else
      fout:write(text .. "\n")
    end
  end

  fin:close()
  fout:flush()
  fout:close()
  end
end

if do_files then
  print("Compiling filelist for " .. qname)
  local fin = io.open("./out/" .. qname .. ".txt", "r")
  if fin ~= nil then
    if filesystem.exists("./out/" .. qname .. ".files") then
      filesystem.remove("./out/" .. qname .. ".files")
    end
    local fout = io.open("./out/" .. qname .. ".files", "w")
    local line = 0
    for v in fin:lines() do
      line = line + 1
      if line >= 2 then
        local paths = qutil.get_image_paths(v)
        local found = false
        for kp,vp in pairs(paths) do
          if filesystem.exists(vp) then
            fout:write(vp .. "\n")
            found = true
            break
          end
        end
        if not found and not do_quests and #paths > 0 then
          local cutpos = v:find("::") + 2
          print("Could not find image for" .. v:sub(cutpos) .. " (quest " .. (line - 1) .. ")")
        end
      end
    end
    fin:close()
    fout:flush()
    fout:close()
  end
end

end

end