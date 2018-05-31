local byte = {} -- library table

function byte.numberToByte(number)
  checkArg(1, number, "number")
  local bytestring = ""
  repeat
    bytestring = string.char(number%256) .. bytestring
    number = math.floor(number/256)
  until number == 0
  return bytestring
end

function byte.byteToNumber(bytestring)
  checkArg(1, bytestring, "string")
  local total = 0
  for i = 1, #bytestring do
    total = (total + string.byte(bytestring, i)) * 256
  end
  total = total/256
  return total
end

return byte
