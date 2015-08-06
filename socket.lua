
function log(text)
  print ("#"..text)
end


uart.setup(0,115200,8,0,1,0)

sv = net.createServer(net.TCP, 120)
sv:listen(8888, function(c)
     uart.on("data", "\n", function(data)
          node.input(data)
          log(data)
          c:send(data)
          end, 0)
     c:on("receive", function(c, pl)
          uart.write (0,pl .."\n")          
     end)
     c:send("** Connected\n")
end)
