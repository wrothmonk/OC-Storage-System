local component = require("component")
local event = require("event")
local byte = require("byte")

--create driver table & set passthrough methods to "proxy" the component
--[[
There really isn't a need for this since all the methods have to be
replaced anyway, but this is just in case new methods are added to
the tunnel component some time in the future.
]]
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

function driver.isWireless()
  return false
end

function driver.isWired()
  return true
end
  --[[
  Despite the tunnel being a wireless means of transmission, for the purpose of
  interacting with it, it is essentially a wired connection as wireless
  "strength" and "distance" are not applicable.
  ]]

function driver.maxPacketSize(address)
  checkArg(1, address, "string")
  --four bytes of overhead for port header
  return component.invoke(address, "maxPacketSize") - 4
end

local ports = {} --virtual port tracking table

function driver.isOpen(address, port)
  checkArg(1, address, "string")
  checkArg(2, port, "number")
  --doubt 'not's to force to boolean if nil entry
  return not not ports[address] and not not ports[address][port]
end

function driver.open(address, port)
  checkArg(1, address, "string")
  checkArg(2, port, "number")
  if not ports[address] then
    ports[address] = {}
  end
  if not ports[address][port] then
    ports[address][port] = true
    return true
  else
    return false
  end
end

function driver.close(address, port)
  checkArg(1, address, "string")
  checkArg(2, port, "number")
  if ports[address] and ports[address][port] then
    ports[address][port] = nil
    return true
  else
    return false
  end
end

function driver.send(address, _, port, ...)
  checkArg(1, address, "string")
  checkArg(3, port, "number")
  local message = {...}
  if #message > driver.getPartCount(address) then
    error("packet has too many parts")
  else
    table.insert(message, 1, byte.toByte(port))
    return component.invoke(address, "send", table.unpack(message))
  end
end

function driver.broadcast(address, port, ...)
  checkArg(1, address, "string")
  checkArg(2, port, "number")
  return driver.send(address, nil, port, ...)
end

function driver.setStrength()
  return 0
end

function driver.getStrength()
  return 0
end

--[[W-net Driver specific functions]]

--energy cost function
function driver.getCost()
  return 356
  --[[
  Tunnel messages vary in energy cost from 100 to 356 depending
  on # of bytes sent.
  Going with maximum just to be safe, since doing route calculations
  on higher layers based on individual message length would be vastly
  innefficient just for this one use case.
  ]]--
end

--packet part limit, just a constant until OC implements an API method
function driver.getPartCount()
  return 7
  --7 instead of the usual 8 because of port header
end

--net_device event system and toggling

local function listener(_, ...)
  local message = {...}
  local address, port = message[1], table.remove(message, 5)
  local portActive = ports[address] and ports[address][byte.toNumber(port)]
  if driver.active[address] and portActive then
    event.push("wnet_device", table.unpack(message))
  end
end

local listener_active

function driver.enable(address, enable)
  checkArg(1, address, "string")
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
    ["isWireless"] = false,
    ["isWired"] = false,
    ["isOpen"] = false,
    ["open"] = false,
    ["close"] = false,
    ["broadcast"] = methods.send,
    ["setStrength"] = false,
    ["getStrength"] = false,
    ["getCost"] = false,
    ["getPartCount"] = false,
    ["enable"] = false
  }
  setmetatable(driver_methods, {__index = methods})

  return driver_methods
end

return driver
