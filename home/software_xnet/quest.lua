local component = require("component")
local qutil = require("qutil")
local xnet = component.xnet
local modem = component.modem
local event = require("event")
local os = require("os")
local reqs = {}
local cpos = {}
local has_item = {}
local copos = {}
local inpos = nil

os.sleep(0.5)

local id_num, id_prefix = qutil.get_id()

local lastOutput = nil
local function setRedstoneOutput(val)
  if lastOutput ~= val then
    for c in component.list("redstone") do
      for side = 0,5 do
        component.invoke(c,"setOutput",side,val and 15 or 0)
      end
    end
    lastOutput = val
  end
end

modem.open(4242)

for i=1,16 do
  print("loading questfile " .. i)
  reqs[i] = qutil.get_reqs("/home/quests/" .. i .. ".txt").reqs
  local lhas_item = false
  for k,v in pairs(reqs[i]) do
    if v.type == "item" then
      lhas_item = true
      break
    end
  end
  has_item[i] = lhas_item
end

local cb = xnet.getConnectedBlocks()
for i=1,16 do if reqs[i] ~= nil then
  local str = "Quest "..i
  for k,v in pairs(cb) do
    if type(v) == "table" and v.connector ~= nil then
      if v.connector == str or v.connector == str.." " then
        cpos[i] = v.pos
      elseif v.connector == "Reward "..i then
        copos[i] = v.pos
      elseif v.connector == "Input" then
        inpos = v.pos
      end
    end
  end
  if has_item[i] and cpos[i] == nil then error("Could not find " .. str .. " chest!") end
  if copos[i] == nil then error("Could not find " .. str .. " reward chest!") end
end end

if inpos == nil then error("Could not find input chest!") end

local success = 0

event.listen("modem_message", function(name, localAddress, remoteAddress, port, distance, message, id)
  if math.floor(port) == 4242 and message == "no_reward_do_not_cheat_either" then
    for i=1,16 do
      if id == i .. ":" .. id_prefix then
        success = success & (~(1 << (i - 1)))
      end
    end
  elseif math.floor(port) == 4242 and message == "send_reward_do_not_cheat" then
    for i=1,16 do
      if id == i .. ":" .. id_prefix then
        success = success | (1 << (i - 1))
        local x = xnet.getItems(copos[i])
        for j=1,x.n do
          if x[j] ~= nil then
            xnet.transferItem(copos[i],j,x[j].size,inpos)
          end
        end
      end
    end
  end
  setRedstoneOutput(success == 65535)
end)

function m_req(item, i, req, outId)
  if qutil.req_matches_item({cpt=xnet,side=inpos,slot=i,item=item},req) then
    local x = xnet.getItems(cpos[outId])
    local matchSize = 0
    for j=1,x.n do if x[j] ~= nil then
      if qutil.req_matches_item({cpt=xnet,side=cpos[outId],slot=j,item=item},req) then
        matchSize = matchSize + x[j].size
      end
    end end
    if matchSize < (req.count*2) then
      xnet.transferItem(inpos,i,1,cpos[outId])
    end
  end
end

while true do
  local x = xnet.getItems(inpos)
  for i=1,x.n do
    if x[i] ~= nil then
      for j=1,16 do
        if reqs[j] ~= nil and has_item[j] then
          for k,v in pairs(reqs[j]) do
            if v.type == "item" then
              m_req(x[i],i,v,j)
            end
          end
        end
      end
      os.sleep(0.05)
    end
  end
  os.sleep(0.05)
end
