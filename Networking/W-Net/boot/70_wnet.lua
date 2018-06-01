local event = require("event")
local fs = require("filesystem")
local net = require("wnet")

local function isNetDevice(c_type)
  local driver_path = "/lib/wnet_drivers/" .. c_type .. ".lua"
  return fs.exists(driver_path) and driver_path
end

--register new network capable devices as they are added.
local function netComponentAdded(_, address, c_type)
  local driver_path = isNetDevice(c_type)
  if driver_path then
    net.registerDevice(address, c_type, driver_path)
  end
end

--remove a device if the component is removed
local function netComponentRemoved(_, address, c_type)
  if isNetDevice(c_type) then
    net.removeDevice(address)
  end
end

event.listen("component_added", netComponentAdded)
event.listen("component_removed", netComponentRemoved)
