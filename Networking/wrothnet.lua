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
  checkArg(1, port, "number", "nil")
  local result = net.modem.close(port)
  if result then
    local config, address = net.config, net.modem.address
  if result and port then
    for k, v in pairs(config[address].open_ports) do
      if port == v then
        table.remove(config[address].open_ports, k)
      end
    end
  elseif result then
    config[address].open_ports = {}
  end
  return result
end

function net.open(port)
  checkArg (1, port, "number")
  local result = net.modem.open(port)
  if result == nil then
    net.close(net.config[net.modem.address].open_ports[1])
    result = net.modem.open(port)
  end
  return result
end

function net.broadcast(port, ...)
  local data = {...}
  local result = false
  if #data > 8 then
    error("Number of broadcast arguments after port number must be 8 or less.")
  else
    for k,v in pairs(data) do
      if type(v) == "table" do
        local compressed = serialize(v)
        data[k] = compressed
      end
    end
    if not net.modem.isOpen(port) then
      net.open(port)
    end
    result = net.modem.broadcast(port, table.unpack(data))
  end
  return result
end

return net
