--[[
ģ�����ƣ�Զ������(ͨ��http��get����)
ģ�鹦�ܣ�ֻ��ÿ�ο�����������ʱ�����߸����û�������ʱ��㣬������������������������������°汾��lib��Ӧ�ýű�Զ������
ģ������޸�ʱ�䣺2018.02.08
]]

--����ģ��,����������
local base = _G
local string = require"string"
local io = require"io"
local os = require"os"
local rtos = require"rtos"
local sys  = require"sys"
local link = require"link"
local misc = require"misc"
local common = require"common"
module(...)

--���س��õ�ȫ�ֺ���������
local print = base.print
local send = link.send
local dispatch = sys.dispatch

--Զ������ģʽ������main.lua�У�����UPDMODE������δ���õĻ�Ĭ��Ϊ0
--0���Զ�����ģʽ���������������Զ������������
--1���û��Զ���ģʽ�������������󣬻����һ����ϢUP_END_IND�����û��ű������Ƿ���Ҫ����
local updmode = base.UPDMODE or 0

--PROTOCOL�������Э�飬ֻ֧��TCP
--SERVER,PORTΪ��������ַ�Ͷ˿�
local PROTOCOL,SERVER,PORT,getURL = "TCP","iot.openluat.com",80,"/api/site/firmware_upgrade"
--�Ƿ�ʹ���û��Զ��������������
local usersvr
--����������·��
local UPDATEPACK = "/luazip/update.bin"
local rcvBuf = ""

-- GET����ȴ�ʱ��
local CMD_GET_TIMEOUT = 10000
-- GET�������Դ���
local CMD_GET_RETRY_TIMES = 5
--socket id
local lid,updsuc
--���ö�ʱ������ʱ�����ڣ���λ�룬0��ʾ�رն�ʱ����
local period = 0
--״̬��״̬
--IDLE������״̬
--CHECK������ѯ�������Ƿ����°汾��״̬
--UPDATE��������״̬
local state = "IDLE"
--getretries���Ѿ����ԵĴ���
local getretries = 0
local contentLen,saveLen = 0,0


--[[
��������print
����  ����ӡ�ӿڣ����ļ��е����д�ӡ�������updatehttpǰ׺
����  ����
����ֵ����
]]
local function print(...)
	base.print("updatehttp",...)
end

--[[
��������save
����  ���������ݰ��������ļ���
����  ��
		data�����ݰ�
����ֵ������ɹ�����true������nil
]]
local function save(data)
	--���ļ�
	local f = io.open(UPDATEPACK,"a+")

	if f==nil then
		print("save:file nil")
		return
	end
	--д�ļ�
	if f:write(data)==nil then
		print("write:file nil")
		f:close()
		return
	end
	f:close()
	return true
end

--[[
��������retry
����  �����������е����Զ���
����  ��
		param�����ΪSTOP����ֹͣ���ԣ�����ִ������
����ֵ����
]]
local function retry(param)
	--����״̬�ѽ���ֱ���˳�
	if state~="CONNECT" and state~="UPDATE" and state~="CHECK" then
		return
	end
	--���Դ�����1
	getretries = getretries + 1
	if getretries < CMD_GET_RETRY_TIMES then
		link.close(lid)
		lid = nil
		connect()		
	else
		-- �������Դ���,����ʧ��
		upend(false)
	end
end

--[[
��������upend
����  ����������
����  ��
		succ�������trueΪ�ɹ�������Ϊʧ��
����ֵ����
]]
function upend(succ)
	print("upend",succ,state,updmode)
	updsuc = succ
	local tmpsta = state
	state = "IDLE"
	rcvBuf = ""
	--ֹͣ���Զ�ʱ��
	sys.timer_stop(retry)
	--�Ͽ�����
	link.close(lid)
	lid = nil
	getretries = 0
	sys.setrestart(true,1)
	sys.timer_stop(sys.setrestart,true,1)
	--�����ɹ��������Զ�����ģʽ������
	if succ == true and updmode == 0 then
		sys.restart("update.upend")
	end
	--������Զ�������ģʽ������һ���ڲ���ϢUP_END_IND����ʾ���������Լ��������
	if updmode == 1 and tmpsta ~= "IDLE" then
		dispatch("UP_EVT","UP_END_IND",succ)
	end
	--����һ���ڲ���ϢUPDATE_END_IND��Ŀǰ�����ģʽ���ʹ��
	dispatch("UPDATE_END_IND")
	if period~=0 then sys.timer_start(connect,period*1000,"period") end
end

--[[
��������reqcheck
����  �����͡����������Ƿ����°汾���������ݵ�������
����  ����
����ֵ����
]]
function reqcheck()
	print("reqcheck",usersvr)
	state = "CHECK"
	local url = getURL.."?project_key="..base.PRODUCT_KEY
		.."&imei="..misc.getimei().."&device_key="..misc.getsn()
		.."&firmware_name="..base.PROJECT.."_"..rtos.get_version().."&version="..base.VERSION
	if not send(lid,"GET "..url.." HTTP/1.1\r\nConnection: keep-alive\r\nHost: "..SERVER.."\r\n\r\n") then
		sys.timer_start(retry,CMD_GET_TIMEOUT)
	end
	os.remove(UPDATEPACK)
	rcvBuf = ""	
end

--[[
��������nofity
����  ��socket״̬�Ĵ�����
����  ��
        id��socket id��������Ժ��Բ�����
        evt����Ϣ�¼�����
		val�� ��Ϣ�¼�����
����ֵ����
]]
local function nofity(id,evt,val)
	--���ӽ��
	if evt == "CONNECT" then
		state = "CONNECT"
		--����һ���ڲ���ϢUPDATE_BEGIN_IND��Ŀǰ�����ģʽ���ʹ��
		dispatch("UPDATE_BEGIN_IND")
		--���ӳɹ�
		if val == "CONNECT OK" then
			reqcheck()
		--����ʧ��
		else
			sys.timer_start(retry,CMD_GET_TIMEOUT)
		end
	elseif evt == "SEND" then
		sys.timer_start(retry,CMD_GET_TIMEOUT)
	--���ӱ����Ͽ�
	elseif evt == "STATE" and val == "CLOSED" then		 
		upend(false)
	end
end

--[[
��������recv
����  ��socket�������ݵĴ�����
����  ��
        id ��socket id��������Ժ��Բ�����
        data�����յ�������
����ֵ����
]]
local function recv(id,data)
	--ֹͣ���Զ�ʱ��
	sys.timer_stop(retry)
	--����ѯ�������Ƿ����°汾��״̬
	if state == "CHECK" then
		rcvBuf = rcvBuf..data
		local _,d = string.find(rcvBuf,"\r\n\r\n")
		if d then
			local statusCode = string.match(rcvBuf,"HTTP/1.1 (%d+)")
			if statusCode~="200" then print("statusCode error",statusCode) upend(false) return end
			
			contentLen = string.match(rcvBuf,"Content%-Length: (%d+)")
			if not contentLen or contentLen=="0" then print("contentLen error",contentLen) sys.timer_start(retry,CMD_GET_TIMEOUT) return end
			contentLen = base.tonumber(contentLen)
			
			state = "UPDATE"
			local buf = string.sub(rcvBuf,d+1,-1)
			if string.len(buf)>0 and not save(buf) then print("save error") sys.timer_start(retry,CMD_GET_TIMEOUT) return end			
			saveLen = string.len(buf)
			rcvBuf = ""
		end		
	--�������С�״̬
	elseif state == "UPDATE" then
		if string.len(data)>0 and not save(data) then print("save error") sys.timer_start(retry,CMD_GET_TIMEOUT) return end			
		saveLen = saveLen+string.len(data)
		if saveLen == contentLen then
			upend(true)
		end
	else
		upend(false)
	end	
end


function connect()
	print("connect",lid,updsuc)
	if not lid and not updsuc then
		lid = link.open(nofity,recv,"update")
		link.connect(lid,PROTOCOL,SERVER,PORT)
	end
end

local function defaultbgn()
	print("defaultbgn",usersvr)
	if not usersvr then
		base.assert(base.PRODUCT_KEY and base.PROJECT and base.VERSION,"undefine PRODUCT_KEY or PROJECT or VERSION in main.lua")
		base.assert(not string.match(base.PROJECT,","),"PROJECT in main.lua format error")
		base.assert(string.match(base.VERSION,"%d%.%d%.%d") and string.len(base.VERSION)==5,"VERSION in main.lua format error")
		connect()
	end
end

--[[
��������setup
����  �����÷������Ĵ���Э�顢��ַ�Ͷ˿�
����  ��
        prot �������Э�飬��֧��TCP
		server����������ַ
		port���������˿�
		getURL��GET�����URL������"/api/site/firmware_upgrade",ע�⣬����GET�����ʱ�����ڴ�URL֮���Զ��������Ĳ���
				"?project_key="..base.PRODUCT_KEY
				"&imei="..misc.getimei()
				"&device_key="..misc.getsn()
				"&firmware_name="..base.PROJECT.."_"..rtos.get_version()
				"&version="..base.VERSION
����ֵ����
]]
function setup(prot,server,port,getURL)
	if prot and server and port and getURL then
		PROTOCOL,SERVER,PORT,getURL = prot,server,port,getURL
		usersvr = true
		base.assert(base.PROJECT and base.VERSION,"undefine PROJECT or VERSION in main.lua")		
		connect()
	end
end

--[[
��������setperiod
����  �����ö�ʱ����������
����  ��
        prd��number���ͣ���ʱ���������ڣ���λ�룻0��ʾ�رն�ʱ�������ܣ�����ֵҪ���ڵ���60��
����ֵ����
]]
function setperiod(prd)
	base.assert(prd==0 or prd>=60,"setperiod prd error")
	print("setperiod",prd)
	period = prd
	if prd==0 then
		sys.timer_stop(connect,"period")
	else
		sys.timer_start(connect,prd*1000,"period")
	end
end

--[[
��������request
����  ��ʵʱ����һ������
����  ����
����ֵ����
]]
function request()
	print("request")
	connect()
end

sys.timer_start(defaultbgn,10000)
sys.setrestart(false,1)
sys.timer_start(sys.setrestart,300000,true,1)
