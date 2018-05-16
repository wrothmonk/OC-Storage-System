local event = require("event")
local component = require("component")
local serialize = require("serialization").serialize
local net = {}

net.modem = component.modem
net.config = {
  [net.modem.address] = {
    ["max_size"] = net.modem.maxPacketSize(),
    ["max_strength"] = math.huge,
    ["open_ports"] = {}
  }
}

function net.setModem(modem)
  checkArg(1, modem, "table", "nil")
  net.modem = modem or component.modem
  local config, address = net.config, net.modem.address
  if not config[address] then
    config[address] = {
      ["max_strength"] = math.huge,
      ["open_ports"] = {}
    }
  end
  config[address].max_size = net.modem.maxPacketSize()
end

function net.setMaxStrength(strength)
  checkArg(1, strength, "number", "nil")
  net.config[net.modem.address].max_strength = strength or math.huge
end

function net.close(port)
  local result = net.modem.close(port)
  if result then
    local open_ports = config[address].open_ports
    if port then
      for k, v in pairs(open_ports) do
        if port == v then
          table.remove(open_ports, k)
        end
      end
    else
      open_ports = {}
    end
  end
  return result
end

function net.open(port)
  local result = net.modem.open(port)
  if result == nil then
    net.close(net.config[net.modem.address].open_ports[1])
    result = net.modem.open(port)
  end
  return result
end

local function verifyData(data)
  local result = data
  if #result > 8 then
    error("Number of broadcast arguments after port number must be 8 or less.")
  else
    for k,v in pairs(result) do
      if type(v) == "table" do
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
