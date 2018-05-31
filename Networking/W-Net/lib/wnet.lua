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

function net.registerDevice(address, type, driver_path)
  if drivers[type] == nil then
    drivers[type] = loadfile(driver_path)()
  end

  --device aspects
  local device = {
    ["address"] = address,
    ["type"] = type,
    ["driver"] = drivers[type]
  }

  --create proxy to driver for device methods
  device = setmetatable(device, {
    __index = function(self, method)
      return function(...)
        return self.driver[method](self.address, ...)
      end
    end
  })

  --instert device into devices table
  devices.by_address[address] = device
  if not devices.by_type[type] then
    devices.by_type[type] = {n = 0}
  end
  devices.by_type[type][address] = device
  devices.by_type[type].n = devices.by_type[type].n + 1

end

function net.removeDevice(address)
  --get device attributes
  local device = devices.by_address[address]
  local type = device.type

  --remove from device tables
  local n = devices.by_type[type].n - 1
  if n == 0 then --if last device of type
    net.removeDriver(type)
  else
    devices.by_type[type][address] = nil
    devices.by_type[type].n = n
    devices.by_address[address] = nil
  end

end

function net.removeDriver(type)
  drivers[type].deactivate() --call deactivation function to clean up listeners
  drivers[type] = nil --remove driver

  --remove any devices relating to the driver
  --remove device count for iteration (no longer neccesary anyway)
  devices.by_type[type].n = nil
  for address, device in pairs(devices.by_type[type]) do
    devices.by_address[address] = nil
    devices.by_type[type][address] = nil
  end
  devices.by_type[type] = nil

end

return net
