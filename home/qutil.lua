local ocpng = dofile("./png.lua")
local component = require("component")
local filesystem = require("filesystem")

local dbAddress = nil
local database = nil

local function getId()
  local f = io.open("/home/id", "r")
  local id = f:read()
  local idSplit = id:find(":")
  f:close()

  if idSplit == nil then return id, "red"
  else return id:sub(1,idSplit-1), id:sub(idSplit+1) end
end

local function getDatabase()
  if database == nil then
    for addr,type in component.list("database") do
      if addr ~= nil then
        dbAddress = addr
      end
    end
    if dbAddress == nil then error("no database found") end
    database = component.proxy(dbAddress)
  end
  return database
end

local function sanitize_filename(s)
  return s:lower():gsub("[^a-z0-9]", "_")  
end

local function get_image_paths(line)
  local text = {}
  for v in string.gmatch(line, "%S+") do table.insert(text, v) end
  if text[2] ~= "item" then return {} end
  local paths = {}
  local path_start = "/home/images/"
  if #text >= 4 and text[4] ~= "::" then
    table.insert(paths, path_start .. text[4] .. ".png")
  end
  local v = text[3]
  local dmgp = v:find("/")
  if dmgp ~= nil then
    table.insert(paths, path_start .. sanitize_filename(v) .. ".png")
    v = v:sub(1,dmgp-1)
  end
  table.insert(paths, path_start .. sanitize_filename(v) .. ".png")
  return paths
end

local function reqItemMatch(data, req)
  local item = data["item"]
  if item == nil then return false end
  if item.name ~= req.filter.name then return false end
  if req.filter.damage ~= nil and item.damage ~= req.filter.damage then return false end
  if req.filter.hash ~= nil then
    os.sleep(0.05) -- breathing time
    getDatabase()

    data.cpt.store(data.side,data.slot,dbAddress,1)
    local h = database.computeHash(1)
    if req.filter.hash ~= h then return false end
  end
  return true
end

local function reqFluidMatch(fluid, req)
  return fluid.name == req.filter
end

local function get_reqs(filename)
  local reqs = {}
  local reqFile = io.open(filename, "r")
  local i = 1
  local line = reqFile:read()
  local reqSpPos = line:find(" ")
  local reqSpPos2 = line:find(" ", reqSpPos + 1)
  local reqX = tonumber(line:sub(0, reqSpPos - 1))
  local reqY = line:sub(reqSpPos + 1)
  local reqTitle = nil
  if reqSpPos2 ~= nil then
    reqY = line:sub(reqSpPos + 1, reqSpPos2 - 1)
    reqTitle = line:sub(reqSpPos2 + 1)
  end
  reqY = tonumber(reqY)

  while true do
    line = reqFile:read()
    if line == nil then break end
    local data = {}
    local uname = ""
    local j = 1
    local jmode = 0
    for v in string.gmatch(line, "%S+") do
      if jmode == 0 then
        if v == "::" then
          jmode = 1
          j = 1
         else
           data[j]=v
         end
       else
        if j == 1 then
          uname = v
        else
          uname = uname .. " " .. v
        end
      end
      j = j + 1
    end
    reqs[i] = {}
    reqs[i].fname = uname
    reqs[i].type = data[2]
    reqs[i].count = math.floor(tonumber(data[1]))
    reqs[i].filter = {}
    if reqs[i].type == "item" then
      reqs[i].filter.name = data[3]
      local dmgpos = data[3]:find("/")
      if dmgpos ~= nil then
        reqs[i].filter.damage = tonumber(data[3]:sub(dmgpos + 1))
        reqs[i].filter.name = data[3]:sub(0, dmgpos - 1)
      end
      if #data >= 4 then
        reqs[i].filter.hash = data[4]
      end
      reqs[i].icon = nil
      for k,v in pairs(get_image_paths(line)) do
        if filesystem.exists(v) then
          reqs[i].icon = v
          break
        end
      end
    elseif reqs[i].type == "fluid" then
      reqs[i].filter = data[3]
      reqs[i].color = tonumber(data[4], 16)
    elseif reqs[i].type == "energy" then
      reqs[i].filter = data[3]
      reqs[i].color = 0xFF0000
    elseif reqs[i].type == "ic2energy" then
      reqs[i].filter = data[3]
      reqs[i].color = 0xFF0000
    end
    if reqs[i].type == "item" and reqs[i].icon ~= nil then
      local fname = reqs[i].icon
      local f = io.open(fname, "r")
      if f ~= nil then
        io.close(f)
        reqs[i].png = ocpng.loadPNG(fname)
      else
        reqs[i].png = nil
      end
    end
    i = i + 1
  end

  reqFile:close()
  return {
    x=reqX,y=reqY,title=reqTitle,
    reqs=reqs
  }
end


return {
  get_reqs=get_reqs,
  get_id=getId,
  get_image_paths=get_image_paths,
  req_matches_item=reqItemMatch,
  req_matches_fluid=reqFluidMatch
}