local computer = require("computer")
local event = require("event")
local fs = require("filesystem")

function os.exit(code)
  error({reason="terminated", code=code}, 0)
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
