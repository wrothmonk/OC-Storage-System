--establish sandbox for later use before adding anything to global
sandbox = {}
for k, v in pairs(_G) do
  sandbox[k] = v
end
sandbox._G = sandbox

--add component proxies to global
for address, componentType in component.list() do
  --if component of type componentType has not already been found
  if _G[componentType] == nil then
    _G[componentType] = component.proxy(address)
  end
end

--get eeprom settings
settings = load("return" .. eeprom.getData())()

--set modem to handle sending messages back to controller
modem.open(settings.port)
if modem.isWireless() then
  modem.setStrength(2 * settings.range)
end

--function for testing if command signals are from the controller
function _isCommand(signal)
  if
    signal and signal.n > 6
    and signal[1] == "modem_message"    --Signal type
    and signal[3] == settings.address   --Sending address
    and signal[4] == settings.port      --Port message was sent on
    and signal[5] <= settings.range  --How close the sender is
    and signal[6] == settings.password  --Password for ordering commands
  then
    return true
  else
    return false
  end
end

--set up root table for holding controller command functions and data
sandBoxed = {} --table for storing sandboxed functions
commands = setmetatable({sandBoxed = sandBoxed}, {__index = sandBoxed})
root = {
  commands = commands,
  data = {} --table for holding data as it is being assembled
}

--setup pullSignal override for command messages
_pull = computer.pullSignal
function sandbox.computer.pullSignal(timeout)
  local result = table.pack(_pull(timeout))
  if _isCommand(result) then
    --execute the command with further parts of the message as args
    commands[result[7]](table.unpack(result, 8))
  end
end

--setup pushSignal override to prevent fake commands
_push = computer.pushSignal
function sandbox.computer.pushSignal(...)
  local args = table.pack(...)
  --Make sure signal being pushed is not a valid command signal
  if not _isCommand(args) then
    _push(table.unpack(args))
  end
end

--setup component overrides
_proxy = component.proxy
function sandbox.component.proxy(address)
  local compProxy = _proxy(address)
  if address == eeprom.address then
    --prevent eeprom from being proxied
    error("Illegal proxy: EEPROM")
  elseif address == computer.address then

    --prevent shutdown command
    function compProxy.shutdown()
      error("Illegal call: computer.shutdown")
    end
    --use signal overrides
    compProxy.pullSignal = sandbox.computer.pullSignal
    compProxy.pushSignal = sandbox.computer.pushSignal
    return compProxy
  elseif address == modem.address then
    function compProxy.close(port)
      if port == settings.port then
        error("Illegal call: Cannot close controller port!")
      else
        return modem.close(port)
      end
    end
  end
end

_invoke = component.invoke
--[[ table for overriding computer component methods
The metatable serves to run an actual invoke for any command that is not
overriden. The overrides themvselves strip the invoke variables and call
the appropriate override functions with the remaining arguments.
]]
_computerOverrides = setmetatable(
  {
    shutdown = function()
      error("Illegal invocation: computer.shutdown")
    end,
    pullSignal = function(_, _, ...)
      sandbox.computer.pullSignal(...)
    end,
    pushSignal = function(_, _, ...)
      sandbox.computer.pushSignal(...)
    end
  },
  {
    __index = function()
      return function(...)
        _invoke(...)
      end
    end
  }
)
function sandbox.component.invoke(address, method, ...)
  args = {...}
  if address == eeprom.address then
    --prevent eeprom from being invoked
    error("Illegal device invocation: EEPROM")
  elseif address == computer.address then
    _computerOverrides[method](address, method, table.unpack(args))
  elseif address == modem.address --primary modem is being called
    and method == close
    and args[1] == settings.port --attempting to close controller port
  then
    error("Illegal invocation: Cannot close controller port!")
  else
    _invoke(address, method, table.unpack(args))
  end
end

--set up basic commands for the controller

--sending message back to controller
function _send(...)
  modem.send(settings.address, settings.port, ...)
end

--get data piecemeal from controller and combine it into a single string
function commands.loadData(fileName, index, is_final, dataPiece)
  local data = root.data
  --if file does not exist
  if not data[fileName] then
    data[fileName] = {}
  end

  --if it is the next piece
  if #data[fileName]+1 == index then
    data[fileName][index] = dataPiece
    if is_final then
      --combine data into single string
      local buffer = ""
      for index = 1, #data[fileName] do
        buffer = buffer .. data[fileName]
      end
      data[fileName] = buffer
    end
  else --data is missing
    is_final = false
  end
  --request next piece
  _send("loadData", fileName, #data[fileName]+1, is_final)
end

function commands.addCommand(fileName)
  commands[fileName] = load(root.data[fileName])
  root.data[fileName] = nil --clear file to free up memory
end

function commands.sandboxAdd(fileName)
  commands.sandBoxed[fileName] = load(root.data[fileName], fileName, "t", sandbox)
  root.data[fileName] = nil
end

while true do
  computer.pullSignal(math.huge)
end
