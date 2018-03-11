local xnet_port = 4242

local id = nil
local f = io.open("/home/id", "r")
id = f:read()
f:close()

local ocpng = dofile("./png.lua")
local pngdraw = dofile("./pngdraw.lua")
local qutil = require("qutil")

local component = require("component")
local filesystem = require("filesystem")
local event = require("event")
local os = require("os")
local sides = require("sides")
local gpu = component.gpu
local unicode = require("unicode")
local halfchar = unicode.char(0x2584)
local stepchars = {}
for i=1,8 do
  stepchars[i] = unicode.char(0x2580 + i)
end
local bgColor = 0x333333
local transpIconColor = 0x888888 -- 8B

function drawPNG(png, xp, yp)
  if png == nil then
    gpu.setBackground(0xFF00FF)
    gpu.fill(xp, yp, 16, 8, " ")
    gpu.setBackground(0x000000)
    gpu.fill(xp + 8, yp, 8, 4, " ")
    gpu.fill(xp, yp + 4, 8, 4, " ")
    return
  end
  pngdraw.draw(png, xp, yp, 16, 16, true, transpIconColor)
end

function drawFluid(req, xp, yp)
  local level = req.currCount * 8.0 / req.count
  if level > 8 then level = 8 end
  local levelI, levelF = math.modf(level)
  local levelFC = math.floor(levelF * 8)
  local brY = 8 - levelI
  gpu.setBackground(0x333333)
  gpu.setForeground(req.color)
  gpu.fill(xp, yp, 16, 8, " ")
  if brY < 8 then
    gpu.fill(xp, yp + brY, 16, 8 - brY, stepchars[8])
  end
  if levelFC > 0 then
    gpu.fill(xp, yp + brY - 1, 16, 1, stepchars[levelFC])
  end
end

function drawReq(req, xp, yp, ticks)
  if req.type == "item" and ticks == 0 then
    drawPNG(req.png, xp, yp)
  elseif req.type == "fluid" or req.type == "energy" or req.type == "ic2energy" then
    drawFluid(req, xp, yp)
  end
end

local reqData = qutil.get_reqs("quest.txt")

local reqX = reqData.x
local reqY = reqData.y
local reqTitle = reqData.title
local reqs = reqData.reqs

local function centerPos(x, w)
  return (w - x) / 2
end

local itemSlots = {}
local fluidSlots = {}
local energySlots = {}
local ic2Slots = {}

local proxyCache = {}
local function getComponent(addr)
  if proxyCache[addr] ~= nil then return proxyCache[addr] end
  local ctr = component.proxy(addr)
  proxyCache[addr] = ctr
  return ctr
end

local function scanInventories()
  itemSlots = {}
  fluidSlots = {}
  energySlots = {}
  ic2Slots = {}
  local kItem = 1
  local kFluid = 1
  for addr, ctype in component.list("transposer") do
    local ctr = getComponent(addr)
    for side = 0,5 do
      local size = ctr.getInventorySize(side)
      if size ~= nil and size > 0 then
        for i=1,size do
          itemSlots[kItem] = {cpt=ctr,side=side,slot=i,item=ctr.getStackInSlot(side,i)}
          --if itemSlots[kItem] then io.stderr:write(itemSlots[kItem].name) end
          kItem = kItem + 1
        end
      end
      local fluid = ctr.getFluidInTank(side)
      for i = 1,fluid.n do
        fluidSlots[kFluid] = fluid[i]
        kFluid = kFluid + 1
      end
      os.sleep(0.05)
    end
  end
  for addr, ctype in component.list("extended_rf_storage") do
    local ctr = getComponent(addr)
    energySlots[addr] = ctr.getEnergyStored()
  end
  for addr, ctype in component.list("energy_device") do
    local ctr = getComponent(addr)
    energySlots[addr] = ctr.getEnergyStored()
  end
  for addr, ctype in component.list("ic2_te_mfsu") do
    local ctr = getComponent(addr)
    ic2Slots[addr] = ctr.getEnergy()
  end
end

local function getReqCountFulfilled(req)
  local cnt = 0
  if req.type == "item" then
    --io.stderr:write(req.filter.name.."\n")
    for i,item in pairs(itemSlots) do
      --io.stderr:write(" "..item.name.."\n")
      if qutil.req_matches_item(item, req) then cnt = cnt + item.item.size end
    end
  elseif req.type == "fluid" then
    for i,fluid in pairs(fluidSlots) do
      if qutil.req_matches_fluid(fluid, req) then cnt = cnt + fluid.amount end
    end
  elseif req.type == "energy" then
    if req.filter == "*" then
      for i,energy in pairs(energySlots) do
        cnt = cnt + energy
      end
    else
      if energySlots[req.filter] ~= nil then cnt = cnt + energySlots[req.filter] end
    end
  elseif req.type == "ic2energy" then
    if req.filter == "*" then
      for i,energy in pairs(ic2Slots) do
        cnt = cnt + energy
      end
    else
      if ic2Slots[req.filter] ~= nil then cnt = cnt + ic2Slots[req.filter] end
    end
  end
  return math.floor(cnt)
end

local lastOutput = nil
local function setRedstoneOutput(val)
  if lastOutput ~= val then
--    component.modem.broadcast(7777, "match_value", val)
    for c in component.list("redstone") do
      for side = 0, 5 do
        component.invoke(c, "setOutput", side, val and 15 or 0)
      end
    end
    lastOutput = val
  end
end

local x = 2
local y = 2
local w = 30
local h = 15

-- local scrW, scrH = gpu.getResolution()
local xOff = x
local yOff = y
local scrW = xOff * 2 + w * reqX
local scrH = yOff * 2 + h * reqY - 2

if reqTitle ~= nil then
  x = x + 2
  xOff = xOff + 2
  y = y + 2
  yOff = yOff + 2
  scrW = scrW + 4
  scrH = scrH + 2
end

gpu.setResolution(scrW, scrH)
gpu.setBackground(bgColor)
gpu.fill(1, 1, scrW, scrH, " ")

if reqTitle ~= nil then
  gpu.setForeground(0xFFFFFF)
  gpu.set(x + centerPos(#reqTitle, w) - 1, 2, reqTitle)
end

local running = true
local runListener
runListener = function(name,addr,char,key,player)
  running = false
  event.ignore("key_down", runListener)
end
event.listen("key_down", runListener)
local ticks = 0

while running do
  local matched = true
  local matchedDouble = true

  scanInventories()
--  component.modem.broadcast(xnet_port, "computer_position", id, tostring(component.debug.getX()), tostring(component.debug.getY()), tostring(component.debug.getZ()))

  for i, req in ipairs(reqs) do
    local fCount = getReqCountFulfilled(req)
    local info = req.fname .. " (" .. fCount .. "/" .. req.count .. ")"
    req.currCount = fCount
    if fCount < req.count then
      matched = false
    end
    if fCount < (2 * req.count) then
      matchedDouble = false
    end

    gpu.setBackground(bgColor)
    local yc = y + centerPos(12, h)
    gpu.fill(x, yc + 11, w, 1, " ")

    if fCount < req.count then
      gpu.setBackground(0xCC3333)
    else
      gpu.setBackground(0x33CC33)
    end
    gpu.fill(x + centerPos(20, w), yc, 20, 1, " ")
    gpu.fill(x + centerPos(20, w), yc, 2, 10, " ")
    gpu.fill(x + centerPos(20, w), yc + 9, 20, 1, " ")
    gpu.fill(x + centerPos(20, w) + 18, yc, 2, 10, " ")
    if (ticks == 0) or (req.type ~= "item") then
      drawReq(req, x + centerPos(20, w) + 2, yc + 1, ticks)
    end

    gpu.setBackground(bgColor)
    gpu.setForeground(0xFFFFFF)
    gpu.set(x + centerPos(#info, w) - 1, yc + 11, info)

    x = x + w
    if x+w >= scrW then
      x = xOff
      y = y + h
    end
  end

  setRedstoneOutput(matchedDouble)
  if matched then
    component.modem.broadcast(xnet_port, "send_reward_do_not_cheat", id)
  else
    component.modem.broadcast(xnet_port, "no_reward_do_not_cheat_either", id)
  end
  os.sleep(0)
  x = xOff
  y = yOff
  ticks = ticks + 1

end

event.ignore("key_down", runListener)