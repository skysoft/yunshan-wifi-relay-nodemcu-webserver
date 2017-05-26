-- Simple NodeMCU web server for the yunshan wifi relay
-- i ordered mine : http://www.ebay.com/itm/291993078658?_trksid=p2060353.m2749.l2649&ssPageName=STRK%3AMEBIDX%3AIT
-- inspired on work from Scott Beasley 2015, http://robotshop.com/letsmakerobots/nodemcu-esp8266-simple-httpd-web-server-example
-- and Rui Santos, https://randomnerdtutorials.com/about/
--

-- Your Wifi connection data
local SSID = "WifiSSID"
local SSID_PASSWORD = "WifiPassword"
relay = 2
input = 1
gpio.mode(relay, gpio.OUTPUT)
gpio.mode(input, gpio.INPUT,gpio.PULLUP)
state="OFF"
local function connect (conn, data)
   local query_data

   conn:on ("receive",
      function (cn, req_data)
      query_data = get_http_req (req_data)
      local buf = "";
        local _GET = {}
        if (query_data["REQUEST"] ~= nil)then
            for k, v in string.gmatch(query_data["REQUEST"], "(%w+)=(%w+)&*") do
                _GET[k] = v
            end
        end
        
        if(_GET.pin == "ON1")then
              gpio.write(relay, gpio.HIGH);
              print("ON")
              state="ON"
        elseif(_GET.pin == "OFF1")then
              gpio.write(relay, gpio.LOW);
              print("OFF")
              state="OFF"
        end

        local inputval
        print (gpio.read(input))
        if (gpio.read(input)==1) then
          inputval="OFF" -- line is pulledup when no inputsignal present so input 1 is OFF
        else
          inputval="ON"
        end

        
        buf = buf.."<h1> ESP8266 Web Server</h1>";
        buf = buf.."<h2> Current state relay (gpio4): "..state.."</h2>";
        buf = buf.."<h2> Current state input (gpio5): "..inputval.."</h2>";
        buf = buf.."<p>Relay <a href=\"?pin=ON1\"><button>ON</button></a>&nbsp;<a href=\"?pin=OFF1\"><button>OFF</button></a></p>";

         cn:send (buf)
      end)

      conn:on ("sent",
      function (cn)
         -- Close the connection for the request
         cn:close ()
      end)
end

function wait_for_wifi_conn ( )
   tmr.alarm (1, 1000, 1, function ( )
      if wifi.sta.getip ( ) == nil then
         print ("Waiting for Wifi connection")
      else
         tmr.stop (1)
         print ("ESP8266 mode is: " .. wifi.getmode ( ))
         print ("The module MAC address is: " .. wifi.ap.getmac ( ))
         print ("Config done, IP is " .. wifi.sta.getip ( ))
      end
   end)
end

-- Build and return a table of the http request data
function get_http_req (instr)
   local t = {}
   local first = nil
   local key, v, strt_ndx, end_ndx 

   for str in string.gmatch (instr, "([^\n]+)") do
      -- First line in the method and path
      if (first == nil) then
         first = 1
         strt_ndx, end_ndx = string.find (str, "([^ ]+)")
         v = trim (string.sub (str, end_ndx + 2))
         key = trim (string.sub (str, strt_ndx, end_ndx))
         t["METHOD"] = key
         t["REQUEST"] = v
      else -- Process and reamaining ":" fields
         strt_ndx, end_ndx = string.find (str, "([^:]+)")
         if (end_ndx ~= nil) then
            v = trim (string.sub (str, end_ndx + 2))
            key = trim (string.sub (str, strt_ndx, end_ndx))
            t[key] = v
         end
      end
   end

   return t
end

-- String trim left and right
function trim (s)
  return (s:gsub ("^%s*(.-)%s*$", "%1"))
end

-- Configure the ESP as a station (client)
wifi.setmode (wifi.STATION)
wifi.sta.config (SSID, SSID_PASSWORD)
wifi.sta.autoconnect (1)

-- Hang out until we get a wifi connection before the httpd server is started.
wait_for_wifi_conn ( )

-- Create the httpd server
svr = net.createServer (net.TCP, 30)

-- Server listening on port 80, call connect function if a request is received
svr:listen (80, connect)
