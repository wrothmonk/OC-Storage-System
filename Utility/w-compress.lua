local compress = {} -- library table

--takes a number and converts it to a string representation
function compress.NumbertoByte(number)
  checkArg(1, number, "number")
  local bytestring = ""
  repeat
    bytestring = string.char(number%256) .. bytestring
    number = math.floor(number/256)
  until number == 0
  return bytestring
end

--takes a string representation of a number and converts it back into a number
function compress.BytetoNumber(bytestring)
  checkArg(1, bytestring, "string")
  local total = 0
  for i = 1, #bytestring do
    total = (total + string.byte(bytestring, i)) * 256
  end
  total = total/256
  return total
end

--takes a string of lua source code and removes comments/unnecessary characters
function compress.compressLua(file)
  file, n = string.gsub(file, "--%[%[.-%]%]", "") --multi-line comments
  file, n = string.gsub(file, "%-%-.-\n", "\n") --comments
  file, n = string.gsub(file, "\n%s-([^%s])", "\n%1") --tabs and excess newlines
  file, n = string.gsub(file, "\r", "") --carriage returns
  return file
end

return compress
