local qutil = require("qutil")
local filesystem = require("filesystem")
local shell = require("shell")
local args = {...}
if args == nil or #args < 3 then
  print("Usage: slot_image [path|url] [quest] [slot]")
  os.exit(1)
end
if args[1]:sub(1,4) == "http" then
  local url = args[1]
  args[1] = "/tmp/img.png"
  filesystem.remove(args[1])
  shell.execute("wget " .. url .. " " .. args[1])
end
local fin = io.open("out/" .. args[2] .. ".txt", "r")
local i = 0
local target_slot = tonumber(args[3])
for line in fin:lines() do
  i = i + 1
  if i == (target_slot + 1) then
    local path = qutil.get_image_paths(line)[1]
    print("-> " .. path)
    if filesystem.exists(path) then
      print("Overwrite [y?]?")
      local v = io.read()
      if v:lower():sub(1,1) == "y" then filesystem.remove(path) else os.exit(1) end
    end
    filesystem.copy(args[1], path)
    break
  end
end
fin:close()