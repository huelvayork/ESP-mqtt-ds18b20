ds_pin = 4
ow.setup(ds_pin)

--function getTemp based on code from "Mic-Key" at:
--https://github.com/nodemcu/nodemcu-firmware/issues/323
function getTemp()
  sensors={}
  count=0
  ow.reset_search(ds_pin)
  addr = ow.search(ds_pin)    -- 1st address
  while (addr ~= nil) do
    count = count+1
    data = {}
    for i = 1, #addr do data[i] = string.format("%02X", addr:byte(i)) end 
    crc = string.format("%02X", ow.crc8(string.sub(addr, 1, 7)))
    saddr=table.concat(data)
    print('\r\n#addr:', #data, saddr, crc)
    ow.reset(ds_pin)
    ow.select(ds_pin, addr)
    ow.write(ds_pin, 0x44, 1) -- start conversion
    tmr.delay(1000000)        -- wait 1s (>750ms)

    ow.reset(ds_pin)
    ow.select(ds_pin, addr)
    ow.write(ds_pin, 0xBE, 1) -- read scratchpad
    data = {}
    for i = 1, 9 do data[i] = ow.read(ds_pin) end

    strData = ''
    for i = 1, #data - 1 do strData = strData .. string.char(data[i]) end
    crc = ow.crc8(strData)
    print('#data:', #data, table.concat(data, ','), crc)

    temp = (data[1] + 256 * data[2]) * 625
    temp = temp / 10000 ..".".. temp % 10000
    print('#temp: ', temp)
    sensors[count] = {address=saddr, value=temp}

    addr = ow.search(ds_pin)  -- next address
  end
  print('#--- no more addresses ---')
  return sensors
end

--getTemp()