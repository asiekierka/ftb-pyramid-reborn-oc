local component = require("component")

local function printnonl(s)
  io.stdout:write(s)
  io.stdout:flush()
end

local addrs = {}

printnonl("How many quest chests do you want to provision?: ")
local count = tonumber(io.read())
local i = 1
while i <= count do
  printnonl("Please insert a stack of 64 x Clay into the last slot for the chest for Quest " .. i .. " ONLY, then press ENTER.")
  io.read()
  printnonl("Scanning")
  local addrs_found = {}
  for address, type in component.list("inventory_controller") do
    local proxy = component.proxy(address)
    printnonl(".")
    for side=0,5 do
      local size,err = proxy.getInventorySize(side)
      if size ~= nil then
        local stack = proxy.getStackInSlot(side,size)
        if stack ~= nil and stack["name"] == "minecraft:clay_ball" and stack["size"] == stack["maxSize"] then
          table.insert(addrs_found, side .. "," .. address)
        end
      end
    end
  end
  if #addrs_found == 0 then
    print(" Not found - try again!")
  elseif #addrs_found >= 2 then
    print(" Found too many - try again!")
  else
    print(" OK - " .. addrs_found[1])
    table.insert(addrs, addrs_found[1])
    i = i + 1
  end
end

printnonl("Saving... ")
file = io.open("./config/chest_map.txt", "w")
for k,v in pairs(addrs) do
  file:write(v .. "\n")
end
file:flush()
file:close()
print("Done!")
print("Don't forget to take out that clay from the Quest " .. count .. " chest!")