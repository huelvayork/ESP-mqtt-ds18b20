dofile("ds18b20.lc")
mqtt_deviceid = mqtt_deviceid or "ESP"..node.chipid()
mqtt_user="ESP01"
mqtt_password=""

-- GPIO0 resets the module
gpio.mode(3, gpio.INT)
gpio.trig(3,"both",function()
          node.restart()
     end)
     
connected = false


print ("#MQTT Client id: " ..mqtt_deviceid)
print ("#MQTT Server: " ..mqtt_server)

-- init mqtt client with keepalive timer 120sec
m = mqtt:Client(mqtt_deviceid, 120, mqtt_user, mqtt_password)

-- setup Last Will and Testament (optional)
-- Broker will publish a message with:
-- qos = 0, retain = 0, data = "offline" 
-- to topic "/lwt" if client don't send keepalive packet
m:lwt("/lwt", "offline", 0, 0)

function log(text)
  print ("#"..text)
end


function onsubscribe(client,topic, message)
     log ("subscribe ok")
end
function onsend()
     log("sent")
end

function connect()
  log ("Trying to connect...")
-- for secure: m:connect("192.168.11.118", 1880, 1)
  m:connect(mqtt_server, 1883, 0, function(conn) 
     log ("connected") 
     tmr.stop(0)
     connected = true
     -- subscribe topic with qos = 0
     m:subscribe("/status",0, onsubscribe)
     m:subscribe("/toarduino/"..mqtt_deviceid,0, onsubscribe)
     m:subscribe("/exec/"..mqtt_deviceid,0, onsubscribe)
     -- publish a message with data = hello, QoS = 0, retain = 0
     m:publish("/debug/"..mqtt_deviceid,"boot "..wifi.sta.getip(),0,1, onsend)         
   end)
end


m:on("connect", function(con) 
     print ("connected") 
     end)
     
m:on("offline", function(con) 
     log ("offline") 
     connected = false
     tmr.alarm(0,1000,1,function()
               connect()
          end)
     end)

-- on publish message receive event
m:on("message", function(conn, topic, data) 
  log(topic .. ":" ) 
  if data ~= nil then
    log(data)
  end
  if (topic == '/status') then
     publishStatus()
  end
  if (topic == "/toarduino/"..mqtt_deviceid) then
     uart.write (0,data .."\n")
  end
  if (topic == '/exec/'..mqtt_deviceid) then
     node.output(debug2mqtt, 1)
     node.input(data)
     node.output(nil)
  end
end)

function debug2mqtt(str)
    m:publish("/debug/"..mqtt_deviceid,str,0,0,nil)         
end

function publishTemp()
     if (connected) then
          sensors=getTemp()
          for i = 1, #sensors do
            log("sending "..sensors[i].address)
            m:publish("/sensors/"..mqtt_deviceid.."/temp/"..sensors[i].address, sensors[i].value, 0, 1, onsent)
          end
          if ( #sensors > 0 ) then
               m:publish("/sensors/"..mqtt_deviceid.."/temp/end", 0, 0, 1, onsent)
          end
          sensors=nil
          publishStatus()
     end
end

function publishStatus()
    m:publish('/status/'..mqtt_deviceid..'/mem', node.heap(),0,1,onsend)
    m:publish('/status/'..mqtt_deviceid..'/battery', adc.readvdd33(),0,1,onsend)
    m:publish("/status/"..mqtt_deviceid..'/ip', wifi.sta.getip(),0,1, onsend)         
end

tmr.alarm(0,1000,1,function()
          if ( not connected ) then connect() end
     end)

tmr.alarm(1,60000,1, publishTemp)

-- send via MQTT strings received from arduino
uart.setup(0,115200,8,0,1,0)
uart.on("data", "\n", function(data)
     node.input(data)
     log(data)
     m:publish("/fromarduino/"..mqtt_deviceid,data,0,0,onsent)
     end, 0)
       
