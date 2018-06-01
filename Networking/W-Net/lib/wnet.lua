local component = require("component")

local net = {} --library table

--[[Layer 1 implementation]]
local drivers = {} --driver cache
local devices = { --network devices
  ["by_address"] = {},
  ["by_type"] = {}
}
net.drivers = drivers
net.devices = devices

function net.registerDevice(address, c_type, driver_path)
  if drivers[c_type] == nil then
    drivers[c_type] = loadfile(driver_path)()
  end

  --device aspects
  local device = {
    ["address"] = address,
    ["type"] = c_type,
    ["driver"] = drivers[c_type]
  }

  --create proxy to driver for device methods
  device = setmetatable(device, {
    __index = function(self, method)
      --device object should only access driver methods
      if type(self.driver[method]) == "function" and method ~= "internal" then
        return function(...)
          return self.driver[method](self.address, ...)
        end
      else
        return nil
      end
    end
  })

  --instert device into devices table
  devices.by_address[address] = device
  if not devices.by_type[c_type] then
    devices.by_type[c_type] = {n = 0}
  end
  devices.by_type[c_type][address] = device
  devices.by_type[c_type].n = devices.by_type[c_type].n + 1

end

function net.removeDevice(address)
  --get device attributes
  local device = devices.by_address[address]
  local c_type = device.type

  --remove from device tables
  local n = devices.by_type[c_type].n - 1
  if n == 0 then --if last device of c_type
    net.removeDriver(c_type)
  else
    devices.by_type[c_type][address] = nil
    devices.by_type[c_type].n = n
    devices.by_address[address] = nil
  end

end

function net.removeDriver(c_type)
  drivers[c_type].deactivate() --call deactivation function to clean up listeners
  drivers[c_type] = nil --remove driver

  --remove any devices relating to the driver
  --remove device count for iteration (no longer neccesary anyway)
  devices.by_type[c_type].n = nil
  for address, device in pairs(devices.by_type[c_type]) do
    devices.by_address[address] = nil
    devices.by_type[c_type][address] = nil
  end
  devices.by_type[c_type] = nil

end

return net
