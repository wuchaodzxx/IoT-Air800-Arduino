--[[
ģ�����ƣ�ͨ������
ģ�鹦�ܣ����롢�������������Ҷ�
ģ������޸�ʱ�䣺2017.02.20
]]

--����ģ��,����������
local base = _G
local string = require"string"
local table = require"table"
local sys = require"sys"
local ril = require"ril"
local net = require"net"
local pm = require"pm"
module(...)

--���س��õ�ȫ�ֺ���������
local ipairs,pairs,print,unpack,type = base.ipairs,base.pairs,base.print,base.unpack,base.type
local req = ril.request

--�ײ�ͨ��ģ���Ƿ�׼��������true������false����nilδ����
local ccready = false
--ͨ�����ڱ�־��������״̬ʱΪtrue��
--���к����У����������У�ͨ����
local callexist = false
--��¼������뱣֤ͬһ�绰�������ֻ��ʾһ��
local incoming_num = nil 
--���������
local emergency_num = {"112", "911", "000", "08", "110", "119", "118", "999"}
--ͨ���б�
local oldclcc,clcc = {},{}
--״̬�仯֪ͨ�ص�
local usercbs = {}


--[[
��������print
����  ����ӡ�ӿڣ����ļ��е����д�ӡ�������ccǰ׺
����  ����
����ֵ����
]]
local function print(...)
	base.print("cc",...)
end

--[[
��������dispatch
����  ��ִ��ÿ���ڲ���Ϣ��Ӧ���û��ص�
����  ��
		evt����Ϣ����
		para����Ϣ����
����ֵ����
]]
local function dispatch(evt,para)
	local tag = string.match(evt,"CALL_(.+)")
	if usercbs[tag] then usercbs[tag](para) end
end

--[[
��������regcb
����  ��ע��һ�����߶����Ϣ���û��ص�����
����  ��
		evt1����Ϣ���ͣ�Ŀǰ��֧��"READY","INCOMING","CONNECTED","DISCONNECTED","DTMF","ALERTING"
		cb1����Ϣ��Ӧ���û��ص�����
		...��evt��cb�ɶԳ���
����ֵ����
]]
function regcb(evt1,cb1,...)
	usercbs[evt1] = cb1
	local i
	for i=1,arg.n,2 do
		usercbs[unpack(arg,i,i)] = unpack(arg,i+1,i+1)
	end
end

--[[
��������deregcb
����  ������ע��һ�����߶����Ϣ���û��ص�����
����  ��
		evt1����Ϣ���ͣ�Ŀǰ��֧��"READY","INCOMING","CONNECTED","DISCONNECTED","DTMF","ALERTING"
		...��0�����߶��evt
����ֵ����
]]
function deregcb(evt1,...)
	usercbs[evt1] = nil
	local i
	for i=1,arg.n do
		usercbs[unpack(arg,i,i)] = nil
	end
end

--[[
��������isemergencynum
����  ���������Ƿ�Ϊ��������
����  ��
		num����������
����ֵ��trueΪ�������룬false��Ϊ��������
]]
local function isemergencynum(num)
	for k,v in ipairs(emergency_num) do
		if v == num then
			return true
		end
	end
	return false
end

--[[
��������clearincomingflag
����  ������������
����  ����
����ֵ����
]]
local function clearincomingflag()
	incoming_num = nil
end

--[[
��������discevt
����  ��ͨ��������Ϣ����
����  ��
		reason������ԭ��
����ֵ����
]]
local function discevt(reason)
	callexist = false -- ͨ������ ���ͨ��״̬��־
	if incoming_num then sys.timer_start(clearincomingflag,1000) end
	pm.sleep("cc")
	--�����ڲ���ϢCALL_DISCONNECTED��֪ͨ�û�����ͨ������
	dispatch("CALL_DISCONNECTED",reason)
	sys.timer_stop(qrylist,"MO")
end

--[[
��������anycallexist
����  ���Ƿ����ͨ��
����  ����
����ֵ������ͨ������true�����򷵻�false
]]
function anycallexist()
	return callexist
end

--[[
��������qrylist
����  ����ѯͨ���б�
����  ����
����ֵ����
]]
function qrylist()
	oldclcc = clcc
	clcc = {}
	req("AT+CLCC")
end

local function proclist()
	local k,v,isactive
	for k,v in pairs(clcc) do
		if v.sta == "0" then isactive = true break end
	end
	if isactive and #clcc > 1 then
		for k,v in pairs(clcc) do
			if v.sta ~= "0" then req("AT+CHLD=1"..v.id) end			
		end
	end
	
	if usercbs["ALERTING"] and #clcc >= 1 then
		for k,v in pairs(clcc) do
			if v.sta == "3" then
				--[[dispatch("CALL_ALERTING")
				break]]
				for m,n in pairs(oldclcc) do
					if v.id==n.id and v.dir==n.dir and n.sta~="3" then
						dispatch("CALL_ALERTING")
						break
					end
				end
			end
		end
	end
end

--[[
��������dial
����  ������һ������
����  ��
		number������
		delay����ʱdelay����󣬲ŷ���at������У�Ĭ�ϲ���ʱ
����ֵ��true��ʾ������at����Ų��ҷ���at��false��ʾ������at�����
]]
function dial(number,delay)
	if number == "" or number == nil then
		return false
	end

	if ccready == false and not isemergencynum(number) then
		return false
	end

	pm.wake("cc")
	req(string.format("%s%s;","ATD",number),nil,nil,delay)
	callexist = true -- ���к���

	return true
end

--[[
��������hangupnxt
����  �������Ҷ�����ͨ��
����  ����
����ֵ����
]]
local function hangupnxt()
	req("AT+CHUP")
end

--[[
��������hangup
����  �������Ҷ�����ͨ��
����  ����
����ֵ����
]]
function hangup()
	--�������audioģ��
	if audio and type(audio)=="table" and audio.play then
		--��ֹͣ��Ƶ����
		sys.dispatch("AUDIO_STOP_REQ",hangupnxt)
	else
		hangupnxt()
	end
end

--[[
��������acceptnxt
����  ����������
����  ����
����ֵ����
]]
local function acceptnxt()
	req("ATA")
	pm.wake("cc")
end

--[[
��������accept
����  ����������
����  ����
����ֵ����
]]
function accept()
	--�������audioģ��
	if audio and type(audio)=="table" and audio.play then
		--��ֹͣ��Ƶ����
		sys.dispatch("AUDIO_STOP_REQ",acceptnxt)
	else
		acceptnxt()
	end		
end

--[[
��������transvoice
����  ��ͨ���з����������Զ�,������12.2K AMR��ʽ
����  ��
����ֵ��trueΪ�ɹ���falseΪʧ��
]]
function transvoice(data,loop,loop2)
	local f = io.open("/RecDir/rec000","wb")

	if f == nil then
		print("transvoice:open file error")
		return false
	end

	-- ���ļ�ͷ������12.2K֡
	if string.sub(data,1,7) == "#!AMR\010\060" then
	-- ���ļ�ͷ����12.2K֡
	elseif string.byte(data,1) == 0x3C then
		f:write("#!AMR\010")
	else
		print("transvoice:must be 12.2K AMR")
		return false
	end

	f:write(data)
	f:close()

	req(string.format("AT+AUDREC=%d,%d,2,0,50000",loop2 == true and 1 or 0,loop == true and 1 or 0))

	return true
end

--[[
��������dtmfdetect
����  ������dtmf����Ƿ�ʹ���Լ�������
����  ��
		enable��trueʹ�ܣ�false����nilΪ��ʹ��
		sens�������ȣ�Ĭ��3��������Ϊ1
����ֵ����
]]
function dtmfdetect(enable,sens)
	if enable == true then
		if sens then
			req("AT+DTMFDET=2,1," .. sens)
		else
			req("AT+DTMFDET=2,1,3")
		end
	end

	req("AT+DTMFDET="..(enable and 1 or 0))
end

--[[
��������senddtmf
����  ������dtmf���Զ�
����  ��
		str��dtmf�ַ���
		playtime��ÿ��dtmf����ʱ�䣬��λ���룬Ĭ��100
		intvl������dtmf�������λ���룬Ĭ��100
����ֵ����
]]
function senddtmf(str,playtime,intvl)
	if string.match(str,"([%dABCD%*#]+)") ~= str then
		print("senddtmf: illegal string "..str)
		return false
	end

	playtime = playtime and playtime or 100
	intvl = intvl and intvl or 100

	req("AT+SENDSOUND="..string.format("\"%s\",%d,%d",str,playtime,intvl))
end

local dtmfnum = {[71] = "Hz1000",[69] = "Hz1400",[70] = "Hz2300"}

--[[
��������parsedtmfnum
����  ��dtmf���룬����󣬻����һ���ڲ���ϢAUDIO_DTMF_DETECT��Я��������DTMF�ַ�
����  ��
		data��dtmf�ַ�������
����ֵ����
]]
local function parsedtmfnum(data)
	local n = base.tonumber(string.match(data,"(%d+)"))
	local dtmf

	if (n >= 48 and n <= 57) or (n >=65 and n <= 68) or n == 42 or n == 35 then
		dtmf = string.char(n)
	else
		dtmf = dtmfnum[n]
	end

	if dtmf then
		dispatch("CALL_DTMF",dtmf)
	end
end

--[[
��������ccurc
����  ��������ģ���ڡ�ע��ĵײ�coreͨ�����⴮�������ϱ���֪ͨ���Ĵ���
����  ��
		data��֪ͨ�������ַ�����Ϣ
		prefix��֪ͨ��ǰ׺
����ֵ����
]]
local function ccurc(data,prefix)
	--�ײ�ͨ��ģ��׼������
	if data == "CALL READY" then
		ccready = true
		dispatch("CALL_READY")
		req("AT+CCWA=1")
	--ͨ������֪ͨ
	elseif data == "CONNECT" then
		qrylist()		
		dispatch("CALL_CONNECTED")
		sys.timer_stop(qrylist,"MO")
		--��ֹͣ��Ƶ����
		sys.dispatch("AUDIO_STOP_REQ")
	--ͨ���Ҷ�֪ͨ
	elseif data == "NO CARRIER" or data == "BUSY" or data == "NO ANSWER" then
		qrylist()
		discevt(data)
	--��������
	elseif prefix == "+CLIP" then
		qrylist()
		local number = string.match(data,"\"(%+*%d*)\"",string.len(prefix)+1)
		callexist = true -- ��������
		if incoming_num ~= number then
			incoming_num = number
			dispatch("CALL_INCOMING",number)
		end
	elseif prefix == "+CCWA" then
		qrylist()
	--ͨ���б���Ϣ
	elseif prefix == "+CLCC" then
		local id,dir,sta = string.match(data,"%+CLCC:%s*(%d+),(%d),(%d)")
		if id then
			table.insert(clcc,{id=id,dir=dir,sta=sta})
			proclist()
		end
	--DTMF���ռ��
	elseif prefix == "+DTMFDET" then
		parsedtmfnum(data)
	end
end

--[[
��������ccrsp
����  ��������ģ���ڡ�ͨ�����⴮�ڷ��͵��ײ�core�����AT�����Ӧ����
����  ��
		cmd����Ӧ���Ӧ��AT����
		success��AT����ִ�н����true����false
		response��AT�����Ӧ���е�ִ�н���ַ���
		intermediate��AT�����Ӧ���е��м���Ϣ
����ֵ����
]]
local function ccrsp(cmd,success,response,intermediate)
	local prefix = string.match(cmd,"AT(%+*%u+)")
	--����Ӧ��
	if prefix == "D" then
		if not success then
			discevt("CALL_FAILED")
		else
			if usercbs["ALERTING"] then sys.timer_loop_start(qrylist,1000,"MO") end
		end
	--�Ҷ�����ͨ��Ӧ��
	elseif prefix == "+CHUP" then
		discevt("LOCAL_HANG_UP")
	--��������Ӧ��
	elseif prefix == "A" then
		incoming_num = nil
		dispatch("CALL_CONNECTED")
		sys.timer_stop(qrylist,"MO")
	end
	qrylist()
end

--ע������֪ͨ�Ĵ�����
ril.regurc("CALL READY",ccurc)
ril.regurc("CONNECT",ccurc)
ril.regurc("NO CARRIER",ccurc)
ril.regurc("NO ANSWER",ccurc)
ril.regurc("BUSY",ccurc)
ril.regurc("+CLIP",ccurc)
ril.regurc("+CLCC",ccurc)
ril.regurc("+CCWA",ccurc)
ril.regurc("+DTMFDET",ccurc)
--ע������AT�����Ӧ������
ril.regrsp("D",ccrsp)
ril.regrsp("A",ccrsp)
ril.regrsp("+CHUP",ccrsp)
ril.regrsp("+CHLD",ccrsp)

--����������,æ�����
req("ATX4") 
--��������urc�ϱ�
req("AT+CLIP=1")
dtmfdetect(true)
