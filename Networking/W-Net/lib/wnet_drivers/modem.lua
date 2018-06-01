local component = require("component")
local event = require("event")

--create driver table & set passthrough methods to "proxy" the component
local driver = setmetatable({}, {
  __index = function(_, method)
    return function(address, ...)
      return component.invoke(address, method, ...)
    end
  end
})

--active device tracking for listener
local active = {}
driver.active = active

--[[Fill-in functions]]

function driver.setStrength(address, value)
  checkArg(1, address, "string")
  checkArg(2, value, "number")
  if component.methods(address).setStrength == nil then
    return 0
  else
    return component.invoke(address, "setStrength", value)
  end
end

function driver.getStrength(address)
  checkArg(1, address, "string")
  if component.methods(address).getStrength == nil then
    return 0
  else
    return component.invoke(address, "getStrength", value)
  end
end

--[[W-net Driver specific functions]]

--energy cost function
function driver.getCost(_, distance)
  checkArg(2, distance, "number")
  return distance * 0.05
end

--packet part limit, just a constant until OC implements an API method
function driver.getPartCount()
  return 8
end

--net_device event system and toggling

local function listener(_, ...)
  local message = {...}
  if driver.active[message[1]] then
    event.push("wnet_device", table.unpack(message))
  end
end

local listener_active

function driver.enable(address, enable)
  checkArg(1, address, "string")
  checkArg(2, enable, "boolean", "nil")
  if enable == nil then
    enable = true
  end
  if enable then
    if not listener_active then
      listener_active = event.listen("modem_message", listener)
    end
    driver.active[address] = true
  else
    driver.active[address] = nil
  end
end

--Driver deactivation function called before removing driver from cache
function driver.deactivate()
  if listener_active then
    event.ignore("modem_message", listener)
    --in case somebody wants to deactivate the listener w/o removing the driver
    listener_active = nil
  end
end

--[[Function that returns table that contains ONLY valid calls that can be made
as if the driver was a component. Resulting table should be similar to those
from component.methods]]
function driver.methods(address)
  checkArg(1, address, "string")
  local methods = component.methods(address)
  local driver_methods = {
    --[[setStrength and getStrength may or may not be present depending on if
    the card is wireless or not.]]
    ["setStrength"] = methods.setStrength or false,
    ["getStrength"] = methods.getStrength or false,
    ["getCost"] = false,
    ["getPartCount"] = false,
    ["enable"] = false
  }
  setmetatable(driver_methods, {__index = methods})

  return driver_methods
end

return driver
