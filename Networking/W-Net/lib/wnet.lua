local component = require("component")

local net = {} --library table

--[[Layer 1 implementation]]
local drivers = {} --driver cache
local devices = {} --network devices
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

  devices[address] = device
end

function net.removeDevice(address)
  devices[address] = nil
end

function net.removeDriver(type)
  drivers[type].deactivate()
  drivers[type] = nil
  for address, device in pairs(devices)
    if device.type = type then
      net.removeDevice(address)
    end
  end
end

return net
