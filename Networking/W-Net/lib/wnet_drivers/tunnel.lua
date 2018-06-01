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

--driver internal variables that should be accessable at higher layers
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
  Despite the tunnel be a wireless means of transmission, for the purpose of
  interacting with it, it is essentially a wired connection as wireless
  "strength" and "distance" are not applicable.
  ]]

function driver.maxPacketSize(address)
  --four bytes of overhead for port header
  return component.invoke(address, "maxPacketSize") - 4
end

local ports = {} --virtual port tracking table

function driver.isOpen(address, port)
  return ports[address] and not not ports[address][port]
end

function driver.open(address, port)
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
  if ports[address] and ports[address][port] then
    ports[address][port] = nil
    return true
  else
    return false
  end
end

function driver.send(address, _, port, ...)
  local message = {...}
  if #message > driver.getPartCount(address) then
    error("packet has too many parts")
  else
    table.insert(message, 1, byte.toByte(port))
    return component.invoke(address, "send", table.unpack(message))
  end
end

function driver.broadcast(address, port, ...)
  return driver.send(address, nil, port, ...)
end

function driver.setStrength()
  return 0
end

function driver.getStrength()
  return 0
end

--[[W-net Driver specific functions]]

--energy cost function for wireless messages
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

local listener_id

function driver.enable(address, enable)
  if enable == nil then
    enable = true
  end
  if enable then
    --enable driver listener if it is not already active
    if listener_id == nil then
      listener_id = event.listen("modem_message", listener)
    end
    driver.active[address] = true
  else
    driver.active[address] = nil
  end
end

--Driver deactivation function called before removing driver from cache
function driver.deactivate()
  if listener_id then
    event.cancel(listener_id)
  end
end

--[[Function that returns table that contains ONLY valid calls that can be made
as if the driver was a component. Resulting table should be similar to those
from component.methods]]
function driver.methods(address)
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
    ["getPartCount"] = false,
    ["enable"] = false
  }
  --set fallback table
  setmetatable(driver_methods, {__index = methods})

  return driver_methods
end

return driver
