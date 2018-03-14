require"cuart"
module(...,package.seeall)

--[[
模块名称：“dht22应用”测试
模块功能：测试dht22.lua的接口
模块最后修改时间：2017.02.16
]]

--temperature温度   humidity湿度
temperature = "0"
humidity = "0"


--[[
函数名：print
功能  ：打印接口，此文件中的所有打印都会加上dht22前缀
参数  ：无
返回值：无
]]
local function print(...)
  _G.print(" dht22 ",...)
end

--[[
函数名：dht22Get
功能：读取温湿度数据
参数：无
返回值：无
]]
function dht22Get()
  temperature = cuart.getTemperature()
  humidity = cuart.getHumidity()
  print("dht22Get : ",temperature," ",humidity)
end

--[[
函数名：returnTemperature
功能：返回温度
参数：无
返回值：无
]]
function returnTemperature()
  return temperature
end

--[[
returnHumidity
功能：返回湿度
参数：无
返回值：无
]]
function returnHumidity()
  return humidity
end

--[[
函数：dht22Init
功能：初始化dht22
参数：无
返回值：无
]]
local function dht22Init()

end

--[[
函数：dht22Speak
功能：dht22语音播报
参数：无
返回值：无
]]
local function dht22Speak()
	print("audio start")
	local ttsstr = "语音播报，现在温度"..temperature.."摄氏度，相对湿度百分之"..humidity
	caudio.playtts(ttsstr,1)
end

sys.timer_start(dht22Init,2000)

sys.timer_loop_start(dht22Get,2000)

sys.timer_loop_start(dht22Speak,3600000)



