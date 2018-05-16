local event = require("event")
local component = require("component")
local serialize = require("serialization").serialize
local wrothnet = {}

  wrothnet.modem = component.modem
  wrothnet.max_size = wrothnet.modem.maxPacketSize()
  wrothnet.max_strength = math.huge
  wrothnet.open_ports = {}

  function wrothnet.setModem(modem)
    checkArg(1, modem, "table", "nil")
    wrothnet.modem = modem or component.modem
    wrothnet.max_size = wrothnet.modem.maxPacketSize()
  end

  function wrothnet.setMaxStrength(strength)
    checkArg(1, strength, "number", "nil")
    wrothnet.modem.max_strength = strength or math.huge
  end

  function wrothnet.close(port)
    checkArg(1, port, "number", "nil")
    local result = wrothnet.modem.close(port)
    if result and port then
      for k, v in pairs(wrothnet.open_ports) do
        if port == v then
          table.remove(wrothnet.open_ports, k)
        end
      end
    elseif result then
      wrothnet.open_ports = {}
    end
    return result
  end

  function wrothnet.open(port)
    checkArg (1, port, "number")
    local result = wrothnet.modem.open(port)
    if result == nil then
      wrothnet.close(wrothnet.open_ports[1])
      result = wrothnet.modem.open(port)
    end
    return result
  end

  function wrothnet.broadcast(port, ...)
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
      if not wrothnet.modem.isOpen(port) then
        wrothnet.open(port)
      end
      result = wrothnet.modem.broadcast(port, table.unpack(data))
    end
    return result
  end

return wrothnet
