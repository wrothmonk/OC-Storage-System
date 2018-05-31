local component = require("component")

--create driver table & set passthrough methods to "proxy" the component
local driver = setmetatable({}, {
  __index = function(_, method)
    return function(address, ...)
      return component.invoke(address, method, ...)
    end
  end
})

--[[Fill-in functions]]

function driver.setStrength(address, value)
  if component.methods(address).setStrength == nil then
    return 0
  else
    return component.invoke(address, "setStrength", value)
  end
end

function driver.getStrength(address)
  if component.methods(address).getStrength == nil then
    return 0
  else
    return component.invoke(address, "getStrength", value)
  end
end

--[[W-net Driver specific functions]]

--energy cost function for wireless messages
function driver.getCost(_, distance)
  checkArg(2, distance, "number")
  return distance * 0.05
end

--packet part limit, just a constant until OC implements an API method
function driver.getPartCount()
  return 8
end

--net_device event system and toggling

local active = {}
driver.active = active

local function listener(_, ...)
  local message = {...}
  if driver.active[message[1]] then
    event.push("wnet_device", table.unpack(message))
  end
end

function driver.enable(address, enable)
  if enable == nil then
    enable = true
  end
  if enable then
    --enable driver listener if it is not already active
    if driver.active.id == nil then
      driver.active.id = event.listen("modem_message", listener)
    end
    driver.active[address] = true
  else
    driver.active[address] = nil
  end
end

--Driver deactivation function called before removing driver from cache
function driver.deactivate()
  event.cancel(driver.active[id])
end

return driver
