--[[
ģ�����ƣ�SSL SOCKET����
ģ�鹦�ܣ�SSL SOCKET�Ĵ��������ӡ������շ���״̬ά��
ģ������޸�ʱ�䣺2017.04.26
]]

--����ģ��,����������
local base = _G
local string = require"string"
local table = require"table"
local sys = require"sys"
local ril = require"ril"
local net = require"net"
local rtos = require"rtos"
local sim = require"sim"
local link = require"link"
module("linkssl",package.seeall)

--���س��õ�ȫ�ֺ���������
local print = base.print
local pairs = base.pairs
local tonumber = base.tonumber
local tostring = base.tostring
local req = ril.request

local ipstatus,shuting
--���socket id����0��ʼ������ͬʱ֧�ֵ�socket��������8��
local MAXLINKS = 7
--socket���ӱ�
local linklist = {}
--�Ƿ��ʼ��
local inited
local crtinputed,crtpending = "",{}


local function print(...)
	_G.print("linkssl",...)
end

--[[
��������init
����  ����ʼ��ssl����ģ��
����  ����
����ֵ����
]]
local function init()
	if not inited then
		inited = true
		req("AT+SSLINIT")
		local i,item
		for i=1,#crtpending do
			item = table.remove(crtpending,1)
			req(item.cmd,item.arg)
		end
		crtpending = nil
	end
end

--[[
��������emptylink
����  ����ȡ���õ�socket id
����  ����
����ֵ�����õ�socket id�����û�п��õķ���nil
]]
local function emptylink()
	for i = 0,MAXLINKS do
		if linklist[i] == nil then
			return i
		end
	end

	return nil
end

--[[
��������validaction
����  �����ĳ��socket id�Ķ����Ƿ���Ч
����  ��
		id��socket id
		action������
����ֵ��true��Ч��false��Ч
]]
local function validaction(id,action)
	--socket��Ч
	if linklist[id] == nil then
		print("validaction:id nil",id)
		return false
	end

	--ͬһ��״̬���ظ�ִ��
	if action.."ING" == linklist[id].state then
		print("validaction:",action,linklist[id].state)
		return false
	end

	local ing = string.match(linklist[id].state,"(ING)",-3)

	if ing then
		--�����������ڴ���ʱ,������������,�������߹ر��ǿ��Ե�
		if action == "CONNECT" then
			print("validaction: action running",linklist[id].state,action)
			return false
		end
	end

	-- ������������ִ��,����ִ��
	return true
end

--[[
��������openid
����  ������socket�Ĳ�����Ϣ
����  ��
		id��socket id
		notify��socket״̬������
		recv��socket���ݽ��մ�����
		tag��socket�������
����ֵ��true�ɹ���falseʧ��
]]
function openid(id,notify,recv,tag)
	--idԽ�����id��socket�Ѿ�����
	if id > MAXLINKS or linklist[id] ~= nil then
		print("openid:error",id)
		return false
	end

	local item = {
		notify = notify,
		recv = recv,
		state = "INITIAL",
		tag = tag,
	}

	linklist[id] = item

	--ע������urc
	ril.regurc("SSL&"..id,urc)
	
	--����IP����
	if not ipstatus then
		link.setupIP()
	end

	return true
end

--[[
��������open
����  ������һ��socket
����  ��
		notify��socket״̬������
		recv��socket���ݽ��մ�����
		tag��socket�������
����ֵ��number���͵�id��ʾ�ɹ���nil��ʾʧ��
]]
function open(notify,recv,tag)
	local id = emptylink()

	if id == nil then
		return nil,"no empty link"
	end

	openid(id,notify,recv,tag)

	return id
end

--[[
��������close
����  ���ر�һ��socket�������socket�����в�����Ϣ��
����  ��
		id��socket id
����ֵ��true�ɹ���falseʧ��
]]
function close(id)
	--����Ƿ�����ر�
	if validaction(id,"CLOSE") == false then
		return false
	end
	--���ڹر�
	linklist[id].state = "CLOSING"
	--����AT����ر�����
	req("AT+SSLDESTROY="..id)

	return true
end

--[[
��������connect
����  ��socket���ӷ���������
����  ��
		id��socket id
		protocol�������Э�飬TCP����UDP
		address����������ַ
		port���������˿�
		chksvrcrt��boolean���ͣ��Ƿ�����������֤��
		crtconfig��nil����table���ͣ�{verifysvrcerts={"filepath1","filepath2",...},clientcert="filepath",clientcertpswd="password",clientkey="filepath"}
����ֵ������ɹ�ͬ������true������false��
]]
function connect(id,protocol,address,port,chksvrcrt,crtconfig)
	--�����������Ӷ���
	if validaction(id,"CONNECT") == false or linklist[id].state == "CONNECTED" then
		return false
	end

	linklist[id].state = "CONNECTING"

	local createstr = string.format("AT+SSLCREATE=%d,\"%s\",%d",id,address..":"..port,chksvrcrt and 0 or 1)
	local configcrtstr,i = {}
	if crtconfig then
		if chksvrcrt and crtconfig.verifysvrcerts then
			for i=1,#crtconfig.verifysvrcerts do
				inputcrt("cacrt",crtconfig.verifysvrcerts[i])
				table.insert(configcrtstr,"AT+SSLCERT=1,"..id..",\"cacrt\",\""..crtconfig.verifysvrcerts[i].."\"")
			end
		end
		if crtconfig.clientcert then
			inputcrt("localcrt",crtconfig.clientcert)
			table.insert(configcrtstr,"AT+SSLCERT=1,"..id..",\"localcrt\",\""..crtconfig.clientcert.."\",\""..(crtconfig.clientcertpswd or "").."\"")
		end
		if crtconfig.clientkey then
			inputcrt("localprivatekey",crtconfig.clientkey)
			table.insert(configcrtstr,"AT+SSLCERT=1,"..id..",\"localprivatekey\",\""..crtconfig.clientkey.."\"")
		end
	end
	local connstr = "AT+SSLCONNECT="..id

	if not ipstatus or shuting then
		--ip����δ׼�����ȼ���ȴ�
		linklist[id].pending = createstr.."\r\n"
		for i=1,#configcrtstr do
			linklist[id].pending = linklist[id].pending..configcrtstr[i].."\r\n"
		end
		linklist[id].pending = linklist[id].pending..connstr.."\r\n"
	else
		init()
		--����AT�������ӷ�����
		req(createstr)
		for i=1,#configcrtstr do
			req(configcrtstr[i])
		end
		req(connstr)
	end

	return true
end

--[[
��������disconnect
����  ���Ͽ�һ��socket���������socket�����в�����Ϣ��
����  ��
		id��socket id
����ֵ��true�ɹ���falseʧ��
]]
function disconnect(id)
	--������Ͽ�����
	if validaction(id,"DISCONNECT") == false then
		return false
	end
	--�����socket id��Ӧ�����ӻ��ڵȴ��У���û����������
	if linklist[id].pending then
		linklist[id].pending = nil
		if not ipstatus and linklist[id].state == "CONNECTING" then
			print("disconnect: ip not ready",ipstatus)
			linklist[id].state = "DISCONNECTING"
			return
		end
	end

	linklist[id].state = "DISCONNECTING"
	--����AT����Ͽ�
	req("AT+SSLDESTROY="..id)

	return true
end

--[[
��������send
����  ���������ݵ�������
����  ��
		id��socket id
		data��Ҫ���͵�����
����ֵ��true�ɹ���falseʧ��
]]
function send(id,data)
	--socket��Ч������socketδ����
	if linklist[id] == nil or linklist[id].state ~= "CONNECTED" then
		print("send:error",id)
		return false
	end

	--����AT����ִ�����ݷ���
	req(string.format("AT+SSLSEND=%d,%d",id,string.len(data)),data)

	return true
end

--[[
��������getstate
����  ����ȡһ��socket������״̬
����  ��
		id��socket id
����ֵ��socket��Ч�򷵻�����״̬�����򷵻�"NIL LINK"
]]
function getstate(id)
	return linklist[id] and linklist[id].state or "NIL LINK"
end

--[[
��������recv
����  ��ĳ��socket�����ݽ��մ�����
����  ��
		id��socket id
		len�����յ������ݳ��ȣ����ֽ�Ϊ��λ
		data�����յ�����������
����ֵ����
]]
local function recv(id,len,data)
	--socket id��Ч
	if linklist[id] == nil then
		print("recv:error",id)
		return
	end
	--����socket id��Ӧ���û�ע������ݽ��մ�����
	if linklist[id].recv then
		linklist[id].recv(id,data)
	else
		print("recv:nil recv",id)
	end
end

--[[
��������usersckisactive
����  ���ж��û�������socket�����Ƿ��ڼ���״̬
����  ����
����ֵ��ֻҪ�κ�һ���û�socket��������״̬�ͷ���true�����򷵻�nil
]]
local function usersckisactive()
	for i = 0,MAXLINKS do
		--�û��Զ����socket��û��tagֵ
		if linklist[i] and not linklist[i].tag and linklist[i].state=="CONNECTED" then
			return true
		end
	end
end

--[[
��������usersckntfy
����  ���û�������socket����״̬�仯֪ͨ
����  ��
		id��socket id
����ֵ����
]]
local function usersckntfy(id)
	--����һ���ڲ���Ϣ"USER_SOCKET_CONNECT"��֪ͨ���û�������socket����״̬�����仯��
	if not linklist[id].tag then sys.dispatch("USER_SOCKET_CONNECT",usersckisactive()) end
end

--[[
��������sendcnf
����  ��socket���ݷ��ͽ��ȷ��
����  ��
		id��socket id
		result�����ͽ���ַ���
����ֵ����
]]
local function sendcnf(id,result)
	print("sendcnf",id,result,linklist[id].state)
	--����ʧ��
	if string.match(result,"ERROR") then
		linklist[id].state = "ERROR"
	end
	--�����û�ע���״̬������
	linklist[id].notify(id,"SEND",result)
end

--[[
��������closecnf
����  ��socket�رս��ȷ��
����  ��
		id��socket id
		result���رս���ַ���
����ֵ����
]]
function closecnf(id,result)
	--socket id��Ч
	if not id or not linklist[id] then
		print("closecnf:error",id)
		return
	end
	print("closecnf",id,result,linklist[id].state)
	--�����κε�close���,�������ǳɹ��Ͽ���,����ֱ�Ӱ������ӶϿ�����
	if linklist[id].state == "DISCONNECTING" then
		linklist[id].state = "CLOSED"
		linklist[id].notify(id,"DISCONNECT","OK")
		usersckntfy(id,false)
	--����ע��,���ά����������Ϣ,���urc��ע
	elseif linklist[id].state == "CLOSING" then		
		local tlink = linklist[id]
		usersckntfy(id,false)
		linklist[id] = nil
		ril.deregurc("SSL&"..id,urc)
		tlink.notify(id,"CLOSE","OK")		
	else
		print("closecnf:error",linklist[id].state)
	end
end

--[[
��������statusind
����  ��socket״̬ת������
����  ��
		id��socket id
		state��״̬�ַ���
����ֵ����
]]
function statusind(id,state)
	print("statusind",id,state,linklist[id])
	--socket��Ч
	if linklist[id] == nil then
		print("statusind:nil id",id)
		return
	end	
	print("statusind1",linklist[id].state)
	if linklist[id].state == "CONNECTING" and string.match(state,"SEND ERROR") then
		return
	end	

	local evt
	--socket��������������ӵ�״̬�����߷��������ӳɹ���״̬֪ͨ
	if linklist[id].state == "CONNECTING" or state == "CONNECT OK" then
		--�������͵��¼�
		evt = "CONNECT"		
	else
		--״̬���͵��¼�
		evt = "STATE"
	end

	--�������ӳɹ�,����������Ȼ�����ڹر�״̬
	if state == "CONNECT OK" then
		linklist[id].state = "CONNECTED"		
	else
		linklist[id].state = "CLOSED"
	end
	--����usersckntfy�ж��Ƿ���Ҫ֪ͨ���û�socket����״̬�����仯��
	usersckntfy(id,state == "CONNECT OK")
	--�����û�ע���״̬������
	linklist[id].notify(id,evt,state)
end

--[[
��������connpend
����  ��ִ����IP����δ׼���ñ������socket��������
����  ����
����ֵ����
]]
local function connpend()
	for i = 0,MAXLINKS do
		if linklist[i] ~= nil then
			if linklist[i].pending then
				init()
				local item
				for item in string.gmatch(linklist[i].pending,"(.-)\r\n") do
					req(item)
				end
				linklist[i].pending = nil
			end
		end
	end	
end

--[[
��������ipstatusind
����  ��IP����״̬�仯����
����  ��
		s��IP����״̬
����ֵ����
]]
local function ipstatusind(s)
	print("ipstatus:",ipstatus,s)
	if ipstatus ~= s then
		ipstatus = s
		--ִ�б������socket��������
		if s then connpend() end
	end
end

--[[
��������shutcnf
����  ���ر�IP����������
����  ��
		result���رս���ַ���
����ֵ����
]]
local function shutcnf(result)
	shuting = false
	--�رճɹ�
	if result == "SHUT OK" then
		ipstatusind(false)
		--�Ͽ�����socket���ӣ������socket������Ϣ
		for i = 0,MAXLINKS do
			if linklist[i] then
				if linklist[i].state == "CONNECTING" and linklist[i].pending then
					-- ������δ���й����������� ����ʾclose,IP�����������Զ�����
				elseif linklist[i].state == "INITIAL" then -- δ���ӵ�Ҳ����ʾ
				else
					linklist[i].state = "CLOSED"
					linklist[i].notify(i,"STATE","SHUTED")
					usersckntfy(i,false)					
				end
			end
		end
	end
end

--ά����ATͨ���յ���һ�Ρ�ĳ��socket�ӷ��������յ������ݡ�
--id��socket id
--len������յ��������ܳ���
--data���Ѿ��յ�����������
local rcvd = {id = 0,len = 0,data = ""}

--[[
��������rcvdfilter
����  ����ATͨ����ȡһ������
����  ��
		data��������������
����ֵ����������ֵ����һ������ֵ��ʾδ��������ݣ��ڶ�������ֵ��ʾATͨ�������ݹ���������
]]
local function rcvdfilter(data)
	--����ܳ���Ϊ0���򱾺����������յ������ݣ�ֱ�ӷ���
	if rcvd.len == 0 then
		return data
	end
	--ʣ��δ�յ������ݳ���
	local restlen = rcvd.len - string.len(rcvd.data)
	if  string.len(data) > restlen then -- atͨ�������ݱ�ʣ��δ�յ������ݶ�
		-- ��ȡ���緢��������
		rcvd.data = rcvd.data .. string.sub(data,1,restlen)
		-- ʣ�µ������԰�at���к�������
		data = string.sub(data,restlen+1,-1)
	else
		rcvd.data = rcvd.data .. data
		data = ""
	end

	if rcvd.len == string.len(rcvd.data) then
		--֪ͨ��������
		recv(rcvd.id,rcvd.len,rcvd.data)
		rcvd.id = 0
		rcvd.len = 0
		rcvd.data = ""
		return data
	else
		return data, rcvdfilter
	end
end

--[[
��������urc
����  ��������ģ���ڡ�ע��ĵײ�coreͨ�����⴮�������ϱ���֪ͨ���Ĵ���
����  ��
		data��֪ͨ�������ַ�����Ϣ
		prefix��֪ͨ��ǰ׺
����ֵ����
]]
function urc(data,prefix)	
	print("urc prefix",prefix)
	--socket�յ�������������������
	if prefix == "+SSL RECEIVE" then
		local lid,len = string.match(data,",(%d),(%d+)",string.len("+SSL RECEIVE")+1)
		rcvd.id = tonumber(lid)
		rcvd.len = tonumber(len)
		return rcvdfilter
	--socket״̬֪ͨ
	else
		
		local lid,lstate = string.match(data,"(%d), *([%u :%d]+)")
		print("urc data",data,lid,lstate)
		
		if string.find(lstate,"ERROR:")==1 then return end

		if lid then
			lid = tonumber(lid)
			statusind(lid,lstate)
		end
	end
end

--[[
��������getresult
����  ������socket״̬�ַ���
����  ��
		str��socket״̬�ַ���������SSL&1,SEND OK
����ֵ��socket״̬��������socket id,����SEND OK
]]
local function getresult(str)
	return str == "ERROR" and str or string.match(str,"%d, *([%u :%d]+)")
end

local function emptylink()
	for i = 0,MAXLINKS do
		if linklist[i] == nil then
			return i
		end
	end

	return nil
end

--[[
��������term
����  ���ر�ssl����ģ��
����  ����
����ֵ����
]]
local function term()
	if inited then
		local valid,i
		for i = 0,MAXLINKS do
			if linklist[i] and linklist[i].state~="CLOSED" and linklist[i].state~="INITIAL" then
				valid = true
				break
			end
		end
		if not valid then
			inited = false
			req("AT+SSLTERM")
			crtinputed = ""
		end
	end
end

--[[
��������rsp
����  ��������ģ���ڡ�ͨ�����⴮�ڷ��͵��ײ�core�����AT�����Ӧ����
����  ��
		cmd����Ӧ���Ӧ��AT����
		success��AT����ִ�н����true����false
		response��AT�����Ӧ���е�ִ�н���ַ���
		intermediate��AT�����Ӧ���е��м���Ϣ
����ֵ����
]]
local function rsp(cmd,success,response,intermediate)
	local prefix = string.match(cmd,"AT(%+%u+)")
	local id = tonumber(string.match(cmd,"AT%+%u+=(%d)"))
	
	print("rsp",id,prefix,response)
	
	if prefix == "+SSLCONNECT" then
		--statusind(id,getresult(response))
		if response == "ERROR" then
			statusind(id,"ERROR")
		end
	--�������ݵ���������Ӧ��
	elseif prefix == "+SSLSEND" then
		sendcnf(id,getresult(response))
	--�ر�socket��Ӧ��
	elseif prefix == "+SSLDESTROY" then
		closecnf(id,getresult(response))	
		term()
	end
end

local function ipshutingind(s)
	if s then
		shuting = true
	else
		shutcnf("SHUT OK")
	end
end

local function gprsind(s)
	if s and base.next(linklist) and not ipstatus then
		link.setupIP()
	end
end

function inputcrt(t,f,d)
	if string.match(crtinputed,t..f.."&") then return end
	if not crtpending then crtpending={} end
	if d then
		table.insert(crtpending,{cmd="AT+SSLCERT=0,\""..t.."\",\""..f.."\",1,"..string.len(d),arg=d})
	else
		local path = (string.sub(f,1,1)=="/") and f or ("/ldata/"..f)
		local fconfig = io.open(path,"rb")
		if not fconfig then print("inputcrt err open",path) return end
		local s = fconfig:read("*a")
		fconfig:close()
		table.insert(crtpending,{cmd="AT+SSLCERT=0,\""..t.."\",\""..f.."\",1,"..string.len(s),arg=s})
	end
	crtinputed = crtinputed..t..f.."&"
end

local procer =
{
	IP_STATUS_IND = ipstatusind,
	IP_SHUTING_IND = ipshutingind,
	NET_GPRS_READY = gprsind,
}

sys.regapp(procer)
--ע������urc֪ͨ�Ĵ�����
ril.regurc("+SSL RECEIVE",urc)
--ע������AT�����Ӧ������
ril.regrsp("+SSLCONNECT",rsp)
ril.regrsp("+SSLSEND",rsp)
ril.regrsp("+SSLDESTROY",rsp)

link.regipstatusind()
