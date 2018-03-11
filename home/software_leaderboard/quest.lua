local computer = require("computer")
local component = require("component")
local event = require("event")
local qutil = require("qutil")
local m = component.modem
local gpu = component.gpu

local id1, id2 = qutil.get_id()

local teamOffset = {}
local teamName = {}
local teamColor = {}
teamOffset["red"] = {2, 3}
teamOffset["yellow"] = {2, 3}
teamOffset["green"] = {2, 3}
teamOffset["blue"] = {2, 3}
teamName["red"] = "Red"
teamName["yellow"] = "Yellow"
teamName["green"] = "Green"
teamName["blue"] = "Blue"
teamColor["red"] = 0xFF0000
teamColor["yellow"] = 0xFFFF00
teamColor["green"] = 0x00FF00
teamColor["blue"] = 0x0000FF
local questComp = {}
for k,v in pairs(teamColor) do questComp[k] = {} end

local myTeam = id2

-- gpu.setBorderColor(0x333333)
gpu.setBackground(0x333333)

m.open(4242)
gpu.setResolution(16+2,2+(4)-1)
gpu.fill(1,1,2+16,2+(4)-1," ")

event.listen("modem_message", function(event, localAddress, remoteAddress, port, distance, message, id)
  if port == 4242 then
    local color = nil
    local idSplit = id:find(":")
    local questNo = tonumber(id:sub(1,idSplit-1))
    local questV = questNo-1
    local tn = id:sub(idSplit+1)
    if message == "send_reward_do_not_cheat" then
      color = 0x00FF00
      questComp[tn][questNo] = true
    elseif message == "no_reward_do_not_cheat_either" then
      color = 0xFF0000
      questComp[tn][questNo] = nil
    end
    if color ~= nil and tn == myTeam then
      local teamO = teamOffset[tn]
      if teamO ~= nil then
        gpu.setBackground(0x333333)
        gpu.setForeground(teamColor[tn])
        gpu.set(teamO[1],teamO[2]-1,teamName[tn])
        gpu.setForeground(0xFFFFFF)
        local count = 0
        for i=1,16 do
          if questComp[tn][i] == true then count = count + 1 end
       end
        gpu.set(teamO[1] + 1 + (#teamName[tn]), teamO[2] - 1, "(".. math.floor(count*100/16.0) .. "%)")
        gpu.setBackground(color)
        gpu.set(teamO[1]+math.floor(questV%8)*2,teamO[2]+math.floor(questV/8), "  ")
      end
    end
  end
end)

while true do
  os.sleep(0.05)
end