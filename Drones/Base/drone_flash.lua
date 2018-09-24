local component = require("component")
local shell = require("shell")
local compressLua = require("w-compress").compressLua
local droneData = "/usr/misc/Drones/"

local args, options = shell.parse(...)

if #args < 1 then
  io.write("Usage: flash [-cq] [settings file]\n")
  io.write(" c: create a drone settings file.\n")
  io.write(" q: quiet mode.\n")
  return
end

local function flashRom()
  if not options.q then
    io.write("Insert the EEPROM you would like to flash.\n")
    io.write("When ready to write, type `y` to confirm.\n")
    repeat
      local response = io.read()
    until response and response:lower():sub(1, 1) == "y"
  end

  local eeprom = component.eeprom

  if not options.q then
    io.write("Flashing EEPROM " .. eeprom.address .. ".\n")
  end

  --flash drone bios
  do
    local file = assert(io.open(droneData .. "drone_bios.lua", "rb"))
    local bios = file:read("*a")
    bios = compressLua(bios)
    file:close()
    eeprom.set(bios)
  end

  --flash settings
  do
    local file = assert(io.open(droneData .. args[1], "rb"))
    local settings = file:read("*a")
    file:close()
    eeprom.setData(settings)
  end

  --set label
  do
    local settings = load("return" .. eeprom.getData())()
    eeprom.setLabel(settings.name or "Drone EEPROM")
  end

end

local function createSettings()
  --default settings
  local settings = {
    address = component.modem.address,
    port = 4011,
    range = 5,
    password = "password",
    name = "Unsecure Drone"
  }

  --get settings from user
  for key, setting in pairs(settings) do
    io.write("Set value for: " .. key .. "\nDefault: " .. setting .. "\n")

    if key == "address" then
      --list modem options
      local modems = {}
      for address, _ in component.list("modem") do
        modems[#modems+1] = address
      end
      for i = 1, #modems do
        io.write(i .. ": " .. modems[i] .."\n")
      end
    end

    --get selection/setting
    io.write(">")
    local response = io.read()
    if response == "" then
      response = false
    end

    if response then
      --handle modem selection
      if key == "address" then
        response = modems[response]
      end

      settings[key] = response

    end

    io.write(string.rep("-", 25) .. "\n")
  end

  --convert settings table to string
  local settingString = "{"
  for k, v in pairs(settings) do

    --add quoutes to string settings
    if type(v) == "string" then
      v = "\"" .. v .. "\""
    end

    settingString = settingString .. k .. " = " .. v .. ", "
  end
  --remove extra comma
  settingString = string.sub(settingString, 1, -3) .. "}"

  --write settings to file
  local settingsFile = assert(io.open(droneData .. args[1], "wb"))
  settingsFile:write(settingString)
  settingsFile:close()
  io.write("Settings saved to: " .. droneData .. args[1] .. "\n")
end

if options.c then
  createSettings()
else
  flashRom()
end
