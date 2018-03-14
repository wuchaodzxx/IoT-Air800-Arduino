require"misc"
require"mqtt"
require"common"
require"bgps"
require"dht22"
module(...,package.seeall)

local ssub,schar,smatch,sbyte,slen = string.sub,string.char,string.match,string.byte,string.len
--测试时请搭建自己的服务器
local PROT,ADDR,PORT = "TCP","183.230.40.39",6002   --onenet mqtt broker服务器ip
local mqttclient


--[[
函数名：print
功能  ：打印接口，此文件中的所有打印都会加上test前缀
参数  ：无
返回值：无
]]
local function print(...)
  _G.print("bmqtt",...)
end

local qos0cnt,qos1cnt = 1,1



--[[
函数名：msgPack
功能：对即将发送的msg进行打包
参数：无
返回值：无
]]
local function msgOfGPSPack()
  print("pack test")
  print("bgps.lng bgps.lat",bgps.returnBlng(),bgps.returnBlat())
  local torigin = 
  {
    datastreams = 
    {{
      id = "GPS",
      datapoints = 
      {{
        at = "",
        value = 
        {
          lon = bgps.returnBlng(),
          lat = bgps.returnBlat(),
          ele = "100"
        }
      }}
    }}
  }
  local msg = json.encode(torigin)
  print("json data",msg)
  --local msg = "{\"datastreams\":[{\"id\":\"temperature\",\"datapoints\":[{\"at\":\"\",\"value\":40}]}]}"
  --local msg = "{\"datastreams\":[{\"id\":\"gps\",\"datapoints\":[{\"at\":\"\",\"value\":{\"lon\":106.2476033,\"lat\":29.2824583,\"ele\":100}}]}]}"
  local len = msg.len(msg)
  buf = pack.pack("bbbA", 0x01,0x00,len,msg)
  print("pack buf",buf)
end
local function msgOfDHT22Pack()
  print("DHT22 pack test")
  local DHT22_TEMPERATURE = 
  {
    datastreams = 
    {{
      id = "DHT22_TEMPERATURE",
      datapoints = 
      {{
        at = "",
        value = dht22.returnTemperature()
      }}
    }}
  }
  local DHT22_HUMIDITY = 
  {
    datastreams = 
    {{
      id = "DHT22_HUMIDITY",
      datapoints = 
      {{
        at = "",
        value = dht22.returnHumidity()
      }}
    }}
  }
  local DHT22_TEMPERATURE_msg = json.encode(DHT22_TEMPERATURE)
  local DHT22_HUMIDITY_msg = json.encode(DHT22_HUMIDITY)
  print("json data",DHT22_TEMPERATURE_msg)
  print("json data",DHT22_HUMIDITY_msg)
  --local msg = "{\"datastreams\":[{\"id\":\"temperature\",\"datapoints\":[{\"at\":\"\",\"value\":40}]}]}"
  --local msg = "{\"datastreams\":[{\"id\":\"gps\",\"datapoints\":[{\"at\":\"\",\"value\":{\"lon\":106.2476033,\"lat\":29.2824583,\"ele\":100}}]}]}"
  local len1 = DHT22_TEMPERATURE_msg.len(DHT22_TEMPERATURE_msg)
  local len2 = DHT22_HUMIDITY_msg.len(DHT22_HUMIDITY_msg)
  DHT22_TEMPERATURE_Buff = pack.pack("bbbA", 0x01,0x00,len1,DHT22_TEMPERATURE_msg)
  DHT22_HUMIDITY_Buff = pack.pack("bbbA", 0x01,0x00,len2,DHT22_HUMIDITY_msg)
  
  
  print("DHT22 pack buf",DHT22_TEMPERATURE_Buff)
  print("DHT22 pack buf",DHT22_HUMIDITY_Buff)
end
--DHT22_HUMIDITY
--[[
函数名：pubGpsMsg
功能  ：发生GPS数据到服务器
参数  ：无
返回值：无
]]
local function pubGpsMsg()
  msgOfGPSPack()
  mqttclient:publish("$dp",buf,0)
  msgOfDHT22Pack();
  mqttclient:publish("$dp",DHT22_TEMPERATURE_Buff,0)
  mqttclient:publish("$dp",DHT22_HUMIDITY_Buff,0)
end



--[[
函数名：subackcb
功能  ：MQTT SUBSCRIBE之后收到SUBACK的回调函数
参数  ：
    usertag：调用mqttclient:subscribe时传入的usertag
    result：true表示订阅成功，false或者nil表示失败
返回值：无
]]
local function subackcb(usertag,result)
  print("subackcb",usertag,result)
end

--[[
函数名：rcvmessage
功能  ：收到PUBLISH消息时的回调函数
参数  ：
    topic：消息主题（gb2312编码）
    payload：消息负载（原始编码，收到的payload是什么内容，就是什么内容，没有做任何编码转换）
    qos：消息质量等级
返回值：无
]]
local function rcvmessagecb(topic,payload,qos)
  print("rcvmessagecb",topic,payload,qos)
  --解析json
  local tjsondata,result,errinfo = json.decode(payload)
	if result then
		local command = tjsondata["command"]
		print("rcvmessagecb ",command)
		if command == 0 or command == "0" then
			local ttsstr = "语音播报，收到来自云端控制指令，指令序号为"..command.."号，设备即将关机。"
			caudio.playtts(ttsstr,10)
			--操作
			
		elseif  command == 1 or command == "1" then
			local ttsstr = "语音播报，收到来自云端控制指令，指令序号为"..command.."号，设备即将开机。"
			caudio.playtts(ttsstr,10)
			--操作
			
		elseif  command == 2 or command == "2" then
			local ttsstr = "语音播报，收到来自云端控制指令，指令序号为"..command.."号，设备将进入飞行模式。"
			caudio.playtts(ttsstr,10)
			--操作
			
		elseif  command == 3 or command == "3" then
			local ttsstr = "语音播报，收到来自云端控制指令，指令序号为"..command.."号，设备将进入休眠模式。"
			caudio.playtts(ttsstr,10)
			--操作
			
		elseif  command == 4 or command == "4" then
			local ttsstr = "语音播报，收到来自云端控制指令，指令序号为"..command.."号，设备将进入低功耗模式。"
			caudio.playtts(ttsstr,10)
			--操作
			
		else
			local ttsstr = "语音播报，收到来自云端控制指令，指令序号为"..command.."号，无法解析该指令。"
			caudio.playtts(ttsstr,10)
		end	
	else
		print("rcvmessagecb ：json.decode error",errinfo)
	end

end

--[[
函数名：discb
功能  ：MQTT连接断开后的回调
参数  ：无    
返回值：无
]]
local function discb()
  print("discb")
  --20秒后重新建立MQTT连接
  sys.timer_start(connect,20000)
end

--[[
函数名：disconnect
功能  ：断开MQTT连接
参数  ：无    
返回值：无
]]
local function disconnect()
  mqttclient:disconnect(discb)
end

--[[
函数名：connectedcb
功能  ：MQTT CONNECT成功回调函数
参数  ：无    
返回值：无
]]
local function connectedcb()
  print("connectedcb")
  --订阅主题
  mqttclient:subscribe({{topic="controlTopic",qos=0}, {topic="controlTopic2",qos=1}}, subackcb, "subscribetest")
  --注册事件的回调函数，MESSAGE事件表示收到了PUBLISH消息
  mqttclient:regevtcb({MESSAGE=rcvmessagecb})
  --发布一条qos为0的消息
--  pubqos0test()
  --发布一条qos为1的消息
--  pubqos1test()
  --20秒后主动断开MQTT连接
  sys.timer_loop_start(pubGpsMsg,15000)
end

--[[
函数名：connecterrcb
功能  ：MQTT CONNECT失败回调函数
参数  ：
    r：失败原因值
      1：Connection Refused: unacceptable protocol version
      2：Connection Refused: identifier rejected
      3：Connection Refused: server unavailable
      4：Connection Refused: bad user name or password
      5：Connection Refused: not authorized
返回值：无
]]
local function connecterrcb(r)
  print("connecterrcb",r)
end

--[[
函数名：sckerrcb
功能  ：SOCKET异常回调函数（注意：此处是恢复异常的一种方式<进入飞行模式，半分钟后退出飞信模式>，如果无法满足自己的需求，可自己进行异常处理）
参数  ：
    r：string类型，失败原因值
      CONNECT：mqtt内部，socket一直连接失败，不再尝试自动重连
      SVRNODATA：mqtt内部，3倍KEEP ALIVE时间+半分钟，终端和服务器没有任何数据通信，则认为出现通信异常
返回值：无
]]
local function sckerrcb(r)
  print("sckerrcb",r)
  misc.setflymode(true)
  sys.timer_start(misc.setflymode,30000,false)
end

function connect()
  --连接mqtt服务器
  --mqtt lib中，如果socket出现异常，默认会自动重启软件
  --注意sckerrcb参数，如果打开了注释掉的sckerrcb，则mqtt lib中socket出现异常时，不再自动重启软件，而是调用sckerrcb函数
  --ClientIdentifier: 创建设备时得到的设备ID，为数字字串；     
  --UserName: 注册产品时，平台分配的产品ID，为数字字串； 
  --UserPassword: 为设备的鉴权信息（即唯一设备编号，SN），或者为apiKey，为字符串。
  --mqttclient:connect(ClientIdentifier,120,UserName,UserPassword,connectedcb,connecterrcb--[[,sckerrcb]])
  mqttclient:connect("25767675",120,"121047","authorinfo",connectedcb,connecterrcb--[[,sckerrcb]])
end

local function statustest()
  print("statustest",mqttclient:getstatus())
end

--[[
函数名：imeirdy
功能  ：IMEI读取成功，成功后，才去创建mqtt client，连接服务器，因为用到了IMEI号
参数  ：无    
返回值：无
]]
local function imeirdy()
  --创建一个mqtt client，默认使用的MQTT协议版本是3.1，如果要使用3.1.1，打开下面的注释--[[,"3.1.1"]]即可
  mqttclient = mqtt.create(PROT,ADDR,PORT,"3.1.1")
  --配置遗嘱参数,如果有需要，打开下面一行代码，并且根据自己的需求调整will参数
  --mqttclient:configwill(1,0,0,"/willtopic","will payload")
  --配置clean session标志，如果有需要，打开下面一行代码，并且根据自己的需求配置cleansession；如果不配置，默认为1
  --mqttclient:setcleansession(0)
  --查询client状态测试
  --sys.timer_loop_start(statustest,1000)
  connect()
end

local procer =
{
  IMEI_READY = imeirdy,
}
--注册消息的处理函数
sys.regapp(procer)
