require"misc"
require"net"
module(...,package.seeall)

--[[
模块名称：“cuart应用”测试
模块功能：用于与arduino开发板通过uart通信
模块最后修改时间：2017.02.16
]]

--串口ID,1对应uart1
--如果要修改为uart2，把UART_ID赋值为2即可
local UART_ID = 1
--模拟输入
local ADC_ID = 0
--结束标识符，用于uart通信结束标志
local endflag = "end"

--解析的数据存放变量
temperature="0"
humidity="0"

data = "0-0"
--[[
函数名：read
功能  ：读取串口接收到的数据
参数  ：无
返回值：无
]]
local function read()
	
	--底层core中，串口收到数据时：
	--如果接收缓冲区为空，则会以中断方式通知Lua脚本收到了新数据；
	--如果接收缓冲器不为空，则不会通知Lua脚本
	--所以Lua脚本中收到中断读串口数据时，每次都要把接收缓冲区中的数据全部读出，这样才能保证底层core中的新数据中断上来，此read函数中的while语句中就保证了这一点
	local tempdata=""
	local flag = false
	while true do		
		local tmp = uart.read(UART_ID,"*l",0)
		if not tmp or string.len(tmp) == 0 then break end
		flag = true
		tempdata = tempdata..tmp
		print("uart receive : ",tmp)
		--print("get dht22 tempdata: ",tempdata)
		--打开下面的打印会耗时
		--print("read",data,common.binstohexs(data))
		--dht22Get(data)
		
		--查找结束字符串是否存在，如果存在，则完成数据的一次读取
		if string.find(tempdata,endflag) then 
			--找到结束标识后，要做三件事，（1）将缓存中剩余的数据读完，这样才能保证新数据中断上来。（2）解析收到的数据。（3）将本机数据发给对方
			--print("uart all receive :",tempdata)
			---start
			--将缓存中剩余的数据读完
			local extra=""
			while true do		
				local outtmp = uart.read(UART_ID,"*l",0)
				if not outtmp or string.len(outtmp) == 0 then break end
				extra = extra..outtmp
			end
			print("uart extra:",extra)
			--解析收到的数据
			index1,index2=string.find(tempdata,endflag)
			if flag==true and index1 ~= nil then	
				--print("get dht22 index:",index1)
				if index1>0 then
					--删除末尾的结束标识字符串
					data = string.sub(tempdata,0,index1-1)
					print("uart all receive :",data)
					parseData(data)
				end
			end
			--向串口写数据:格式为：“时间-信号强度end”，时间格式为“201803141256”，信号强度格式为“25”，因此完整数据格式为“201803141256-26end”
			local dateString = "20"..misc.getclockstr()
			local rssi = net.getrssi()
			dateString = string.sub(dateString,0,12)
			--local send_data = dateString.."-"..rssi.."end"
			local send_data = "{\"Date\":\""..dateString.."\",\"RSSI\":\""..rssi.."\"}".."end"
			print("uart send : ",send_data)
			uart.write(UART_ID,send_data)
			---end
			break
		end
		
	end

end
function parseData(data)
	local tjsondata,result,errinfo = json.decode(data)
	if result then
		temperature = tjsondata["Temperature"];
		humidity = tjsondata["Humidity"]	
		print("uart parse : ",temperature.."-"..humidity)		
	else
		--print("json.decode error",errinfo)
	end
end
function getTemperature()
	return temperature
end
function getHumidity()
	return humidity
end
--字符串分割函数
--传入字符串和分隔符，返回分割后的table
function split(str, delimiter)
	if str==nil or str=='' or delimiter==nil then
		return nil
	end
	
    local result = {}
    for match in (str..delimiter):gmatch("(.-)"..delimiter) do
        table.insert(result, match)
    end
    return result
end
--保持系统处于唤醒状态，此处只是为了测试需要，所以此模块没有地方调用pm.sleep("test")休眠，不会进入低功耗休眠状态
--在开发“要求功耗低”的项目时，一定要想办法保证pm.wake("test")后，在不需要串口时调用pm.sleep("test")
pm.wake("test")
--注册串口的数据接收函数，串口收到数据后，会以中断方式，调用read接口读取数据
sys.reguart(UART_ID,read)
--配置并且打开串口
uart.setup(UART_ID,115200,8,uart.PAR_NONE,uart.STOP_1)
