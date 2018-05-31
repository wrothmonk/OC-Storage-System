local event = require("event")
local fs = require("filesystem")
local net = require("wnet")

local function isNetDevice(type)
  local driver_path = "/lib/wnet_drivers/" .. type .. ".lua"
  return fs.exists(driver_path) and driver_path
end

--register new network capable devices as they are added.
local function netComponentAdded(_, address, type)
  local driver_path = isNetDevice(type)
  if driver_path then
    net.registerDevice(address, type, driver_path)
  end
end

--remove a device if the component is removed
local function netComponentRemoved(_, address, type)
  if isNetDevice(type) then
    net.removeDevice(address)
  end
end

event.listen("component_added", netComponentAdded)
event.listen("component_removed", netComponentRemoved)
