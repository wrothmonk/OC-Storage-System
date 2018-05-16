local event = require("event")
local component = require("component")
local serialize = require("serialization").serialize

local net = {
  ["modem"] = component.modem,
  ["config"] = {
    [net.modem.address] = {
      ["max_size"] = net.modem.maxPacketSize(),
      ["max_strength"] = math.huge,
      ["open_ports"] = {},
      ["protected_ports"] = {}
    }
  }
}
setmetatable(net, {__index = net.modem})

function net.setModem(modem)
  checkArg(1, modem, "table", "nil")
  net.modem = modem or component.modem
  local config, address = net.config, net.modem.address
  if not config[address] then
    config[address] = {
      ["max_strength"] = math.huge,
      ["open_ports"] = {},
      ["protected_ports"] = {}
    }
  end
  config[address].max_size = net.modem.maxPacketSize()
  setmetatable(net, {__index = net.modem})
end

function net.setMaxStrength(strength)
  checkArg(1, strength, "number", "nil")
  net.config[net.modem.address].max_strength = strength or math.huge
end

function net.setStrength(strength)
  checkArg(1, strength, "number")
  local max_strength = net.config[net.modem.address].max_strength
  if strength > max_strength then
    strength = max_strength
  end
  net.modem.setStrength(strength)
  return net.modem.getStrength()
end

function net.close(port)
  local result = net.modem.close(port)
  if result then
    local open_ports = config[address].open_ports
    if port then
      for k, v in pairs(open_ports) do
        if port == v then
          table.remove(open_ports, k)
          break
        end
      end
    else
      open_ports = {}
    end
  end
  return result
end

function net.open(port, protect)
  checkArg(2, protected, "boolean", "nil")
  local open = net.modem.open
  local config = net.config[net.modem.address]
  local open, protected = config.open_ports, config.protected_ports

  local result = open(port)
  if not result then
    if result == nil then
      for _,v in ipairs(open_ports) do
        if not protected[v] then
          net.close(v)
          break
        end
      end
    else
      net.close(port)
    end
    result = open(port)
  end

  if result then
    table.insert(open_ports, port)
    if protect then
      protected[v] = true
    end
  end
  return result
end

local function verifyData(data)
  local result = data
  if #result > 8 then
    error("Number of broadcast arguments after port number must be 8 or less.")
  else
    for k,v in pairs(result) do
      if type(v) == "table" then
        local compressed = serialize(v)
        result[k] = compressed
      end
    end
  end
  return result
end

function net.broadcast(port, ...)
  local data = {...}
  local result = false
  data = verifyData(data)
  net.open(port)
  result = net.modem.broadcast(port, table.unpack(data))
  return result
end

function net.send(address, port, ...)
  local data = {...}
  data = verifyData(data)
  net.open(port)
  result = net.modem.send(address, port, table.unpack(data))
  return result
end

return net
