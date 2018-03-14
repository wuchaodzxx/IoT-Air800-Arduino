require"cuart"
module(...,package.seeall)

--[[
模块名称：“语音播报应用”测试
模块功能：测试speak.lua的接口
模块最后修改时间：2017.02.16
]]

--[[
函数名：print
功能  ：打印接口，此文件中的所有打印都会加上dht22前缀
参数  ：无
返回值：无
]]
local function print(...)
  _G.print(" speak ",...)
end


--[[
函数：Speak
功能：语音播报
参数：无
返回值：无
]]
local function Speak()
	print("audio start")
	local ttsstr = "语音播报，现在温度"..temperature.."摄氏度，相对湿度百分之"..humidity
	caudio.playtts(ttsstr,1)
end


sys.timer_loop_start(Speak,3600000)

