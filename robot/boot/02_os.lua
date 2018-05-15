local computer = require("computer")
local event = require("event")
local fs = require("filesystem")
local info = require("process").info

function os.exit(code)
  error({reason="terminated", code=code}, 0)
end

function os.getenv(varname)
  local env = info().data.vars
  if not varname then
    return env
  elseif varname == '#' then
    return #env
  end
  return env[varname]
end

function os.setenv(varname, value)
  checkArg(1, varname, "string", "number")
  if value ~= nil then
    value = tostring(value)
  end
  info().data.vars[varname] = value
  return value
end

os.remove = fs.remove
os.rename = fs.rename

function os.sleep(timeout)
  checkArg(1, timeout, "number", "nil")
  local deadline = computer.uptime() + (timeout or 0)
  repeat
    event.pull(deadline - computer.uptime())
  until computer.uptime() >= deadline
end
