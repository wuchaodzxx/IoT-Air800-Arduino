--[[
ģ�����ƣ�������·��SOCKET����
ģ�鹦�ܣ��������缤�SOCKET�Ĵ��������ӡ������շ���״̬ά��
ģ������޸�ʱ�䣺2017.02.14
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
module(...,package.seeall)

--���س��õ�ȫ�ֺ���������
local print = base.print
local pairs = base.pairs
local tonumber = base.tonumber
local tostring = base.tostring
local req = ril.request

--���socket id����0��ʼ������ͬʱ֧�ֵ�socket��������8��
local MAXLINKS = 7
--IP��������ʧ��ʱ���5������
local IPSTART_INTVL = 5000

--socket���ӱ�
local linklist = {}
--ipstatus��IP����״̬
--shuting���Ƿ����ڹر���������
local ipstatus,shuting = "IP INITIAL"
--GPRS�������總��״̬��"1"���ţ�����δ����
local cgatt
--apn���û���������
local apnname = "CMNET"
local username=''
local password=''
--socket������������������connectnoretinterval�����û���κ�Ӧ�����connectnoretrestartΪtrue������������
local connectnoretrestart = false
local connectnoretinterval
--apnflg��������ģ���Ƿ��Զ���ȡapn��Ϣ��true�ǣ�false�����û�Ӧ�ýű��Լ�����setapn�ӿ�����apn���û���������
--checkciicrtm��ִ��AT+CIICR�����������checkciicrtm��checkciicrtm�����û�м���ɹ����������������;ִ��AT+CIPSHUT����������
--flymode���Ƿ��ڷ���ģʽ
--updating���Ƿ�����ִ��Զ����������(update.lua)
--dbging���Ƿ�����ִ��dbg����(dbg.lua)
--ntping���Ƿ�����ִ��NTPʱ��ͬ������(ntp.lua)
--shutpending���Ƿ��еȴ�����Ľ���AT+CIPSHUT����
local apnflag,checkciicrtm,ciicrerrcb,flymode,updating,dbging,ntping,shutpending=true

--[[
��������setapn
����  ������apn���û���������
����  ��
		a��apn
		b���û���
		c������
����ֵ����
]]
function setapn(a,b,c)
	apnname,username,password = a,b or '',c or ''
	apnflag=false
end

--[[
��������getapn
����  ����ȡapn
����  ����
����ֵ��apn
]]
function getapn()
	return apnname
end

--[[
��������connectingtimerfunc
����  ��socket���ӳ�ʱû��Ӧ������
����  ��
		id��socket id
����ֵ����
]]
local function connectingtimerfunc(id)
	print("connectingtimerfunc",id,connectnoretrestart)
	if connectnoretrestart then
		sys.restart("link.connectingtimerfunc")
	end
end

--[[
��������stopconnectingtimer
����  ���رա�socket���ӳ�ʱû��Ӧ�𡱶�ʱ��
����  ��
		id��socket id
����ֵ����
]]
local function stopconnectingtimer(id)
	print("stopconnectingtimer",id)
	sys.timer_stop(connectingtimerfunc,id)
end

--[[
��������startconnectingtimer
����  ��������socket���ӳ�ʱû��Ӧ�𡱶�ʱ��
����  ��
		id��socket id
����ֵ����
]]
local function startconnectingtimer(id)
	print("startconnectingtimer",id,connectnoretrestart,connectnoretinterval)
	if id and connectnoretrestart and connectnoretinterval and connectnoretinterval > 0 then
		sys.timer_start(connectingtimerfunc,connectnoretinterval,id)
	end
end

--[[
��������setconnectnoretrestart
����  �����á�socket���ӳ�ʱû��Ӧ�𡱵Ŀ��Ʋ���
����  ��
		flag�����ܿ��أ�true����false
		interval����ʱʱ�䣬��λ����
����ֵ����
]]
function setconnectnoretrestart(flag,interval)
	connectnoretrestart = flag
	connectnoretinterval = interval
end

--[[
��������setupIP
����  �����ͼ���IP��������
����  ����
����ֵ����
]]
function setupIP()
	print("link.setupIP:",ipstatus,cgatt,flymode)
	--���������Ѽ�����ߴ��ڷ���ģʽ��ֱ�ӷ���
	if ipstatus ~= "IP INITIAL" or flymode then
		return
	end
	--gprs��������û�и�����
	if cgatt ~= "1" then
		print("setupip: wait cgatt")
		return
	end

	--����IP��������
	req("AT+CSTT=\""..apnname..'\",\"'..username..'\",\"'..password.. "\"")
	req("AT+CIICR")
	--��ѯ����״̬
	req("AT+CIPSTATUS")
	ipstatus = "IP START"
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
		print("link.validaction:id nil",id)
		return false
	end

	--ͬһ��״̬���ظ�ִ��
	if action.."ING" == linklist[id].state then
		print("link.validaction:",action,linklist[id].state)
		return false
	end

	local ing = string.match(linklist[id].state,"(ING)",-3)

	if ing then
		--�����������ڴ���ʱ,������������,�������߹ر��ǿ��Ե�
		if action == "CONNECT" then
			print("link.validaction: action running",linklist[id].state,action)
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

	local link = {
		notify = notify,
		recv = recv,
		state = "INITIAL",
		tag = tag,
	}

	linklist[id] = link

	--ע������urc
	ril.regurc(tostring(id),urc)

	--����IP����
	if ipstatus ~= "IP STATUS" and ipstatus ~= "IP PROCESSING" then
		setupIP()
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
	req("AT+CIPCLOSE="..id)

	return true
end

--[[
��������asyncLocalEvent
����  ��socket�첽֪ͨ��Ϣ�Ĵ�����
����  ��
		msg���첽֪ͨ��Ϣ"LINK_ASYNC_LOCAL_EVENT"
		cbfunc����Ϣ�ص�
		id��socket id
		val��֪ͨ��Ϣ�Ĳ���
����ֵ��true�ɹ���falseʧ��
]]
function asyncLocalEvent(msg,cbfunc,id,val)
	cbfunc(id,val)
end

--ע����ϢLINK_ASYNC_LOCAL_EVENT�Ĵ�����
sys.regapp(asyncLocalEvent,"LINK_ASYNC_LOCAL_EVENT")

--[[
��������connect
����  ��socket���ӷ���������
����  ��
		id��socket id
		protocol�������Э�飬TCP����UDP
		address����������ַ
		port���������˿�
����ֵ������ɹ�ͬ������true������false��
]]
function connect(id,protocol,address,port)
	--�����������Ӷ���
	if validaction(id,"CONNECT") == false or linklist[id].state == "CONNECTED" then
		return false
	end
	print("link.connect",id,protocol,address,port,ipstatus,shuting,shutpending)

	linklist[id].state = "CONNECTING"

	if cc and cc.anycallexist() then
		--�������ͨ������ ���ҵ�ǰ����ͨ����ʹ���첽֪ͨ����ʧ��
		print("link.connect:failed cause call exist")
		sys.dispatch("LINK_ASYNC_LOCAL_EVENT",statusind,id,"CONNECT FAIL")
		return true
	end

	local connstr = string.format("AT+CIPSTART=%d,\"%s\",\"%s\",%s",id,protocol,address,port)

	if (ipstatus ~= "IP STATUS" and ipstatus ~= "IP PROCESSING") or shuting or shutpending then
		--ip����δ׼�����ȼ���ȴ�
		linklist[id].pending = connstr
	else
		--����AT�������ӷ�����
		req(connstr)
		startconnectingtimer(id)
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
		if ipstatus ~= "IP STATUS" and ipstatus ~= "IP PROCESSING" and linklist[id].state == "CONNECTING" then
			print("link.disconnect: ip not ready",ipstatus)
			linklist[id].state = "DISCONNECTING"
			sys.dispatch("LINK_ASYNC_LOCAL_EVENT",closecnf,id,"DISCONNECT","OK")
			return
		end
	end

	linklist[id].state = "DISCONNECTING"
	--����AT����Ͽ�
	req("AT+CIPCLOSE="..id)

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
		print("link.send:error",id)
		return false
	end

	if cc and cc.anycallexist() then
		-- �������ͨ������ ���ҵ�ǰ����ͨ����ʹ���첽֪ͨ����ʧ��
		print("link.send:failed cause call exist")
		return false
	end
	--����AT����ִ�����ݷ���
	req(string.format("AT+CIPSEND=%d,%d",id,string.len(data)),data)

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
		print("link.recv:error",id)
		return
	end
	--����socket id��Ӧ���û�ע������ݽ��մ�����
	if linklist[id].recv then
		linklist[id].recv(id,data)
	else
		print("link.recv:nil recv",id)
	end
end

--[[ ipstatus��ѯ���ص�״̬����ʾ
function linkstatus(data)
end
]]

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
	local str = string.match(result,"([%u ])")
	--����ʧ��
	if str == "TCP ERROR" or str == "UDP ERROR" or str == "ERROR" then
		linklist[id].state = result
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
		print("link.closecnf:error",id)
		return
	end
	--�����κε�close���,�������ǳɹ��Ͽ���,����ֱ�Ӱ������ӶϿ�����
	if linklist[id].state == "DISCONNECTING" then
		linklist[id].state = "CLOSED"
		linklist[id].notify(id,"DISCONNECT","OK")
		usersckntfy(id,false)
		stopconnectingtimer(id)
	--����ע��,���ά����������Ϣ,���urc��ע
	elseif linklist[id].state == "CLOSING" then		
		local tlink = linklist[id]
		usersckntfy(id,false)
		linklist[id] = nil
		ril.deregurc(tostring(id),urc)
		tlink.notify(id,"CLOSE","OK")		
		stopconnectingtimer(id)
	else
		print("link.closecnf:error",linklist[id].state)
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
	--socket��Ч
	if linklist[id] == nil then
		print("link.statusind:nil id",id)
		return
	end

	--�췢ģʽ�£����ݷ���ʧ��
	if state == "SEND FAIL" then
		if linklist[id].state == "CONNECTED" then
			linklist[id].notify(id,"SEND",state)
		else
			print("statusind:send fail state",linklist[id].state)
		end
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
	stopconnectingtimer(id)
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
				req(linklist[i].pending)
				local id = string.match(linklist[i].pending,"AT%+CIPSTART=(%d)")
				if id then
					startconnectingtimer(tonumber(id))
				end
				linklist[i].pending = nil
			end
		end
	end	
end

local ipstatusind
function regipstatusind()
	ipstatusind = true
end

local function ciicrerrtmfnc()
	print("ciicrerrtmfnc")
	if ciicrerrcb then
		ciicrerrcb()
	else
		sys.restart("ciicrerrtmfnc")
	end
end

--[[
��������setIPStatus
����  ������IP����״̬
����  ��
		status��IP����״̬
����ֵ����
]]
local function setIPStatus(status)
	print("ipstatus:",status)
	
	if ipstatusind and ipstatus~=status then
		sys.dispatch("IP_STATUS_IND",status=="IP GPRSACT" or status=="IP PROCESSING" or status=="IP STATUS")
	end
	
	if not sim.getstatus() then
		status = "IP INITIAL"
	end

	if ipstatus ~= status or status=="IP START" or status == "IP CONFIG" or status == "IP GPRSACT" or status == "PDP DEACT" then
		if status=="IP GPRSACT" and checkciicrtm then
			--�رա�AT+CIICR��IP���糬ʱδ����ɹ����Ķ�ʱ��
			print("ciicrerrtmfnc stop")
			sys.timer_stop(ciicrerrtmfnc)
		end
		ipstatus = status
		if ipstatus == "IP PROCESSING" then
		--IP����׼������
		elseif ipstatus == "IP STATUS" then
			--ִ�б������socket��������
			connpend()
		--IP����ر�
		elseif ipstatus == "IP INITIAL" then
			--IPSTART_INTVL��������¼���IP����
			sys.timer_start(setupIP,IPSTART_INTVL)
		--IP���缤����
		elseif ipstatus == "IP CONFIG" or ipstatus == "IP START" then
			--2���Ӳ�ѯһ��IP����״̬
			sys.timer_start(req,2000,"AT+CIPSTATUS")
		--IP���缤��ɹ�
		elseif ipstatus == "IP GPRSACT" then
			--��ȡIP��ַ����ַ��ȡ�ɹ���IP����״̬���л�Ϊ"IP STATUS"
			req("AT+CIFSR")
			--��ѯIP����״̬
			req("AT+CIPSTATUS")
		else --�����쳣״̬�ر���IP INITIAL
			shut()
			sys.timer_stop(req,"AT+CIPSTATUS")
		end
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
	if ipstatusind then sys.dispatch("IP_SHUTING_IND",false) end
	--�رճɹ�
	if result == "SHUT OK" or not sim.getstatus() then
		setIPStatus("IP INITIAL")
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
				stopconnectingtimer(i)
			end
		end
	else
		--req("AT+CIPSTATUS")
		sys.timer_start(req,10000,"AT+CIPSTATUS")
	end
	if checkciicrtm and result=="SHUT OK" and not ciicrerrcb then
		--�رա�AT+CIICR��IP���糬ʱδ����ɹ����Ķ�ʱ��
		print("ciicrerrtmfnc stop")
		sys.timer_stop(ciicrerrtmfnc)
	end
end
--[[
local function reconnip(force)
	print("link.reconnip",force,ipstatus,cgatt)
	if force then
		setIPStatus("PDP DEACT")
	else
		if ipstatus == "IP START" or ipstatus == "IP CONFIG" or ipstatus == "IP GPRSACT" or ipstatus == "IP STATUS" or ipstatus == "IP PROCESSING" then
			setIPStatus("PDP DEACT")
		end
		cgatt = "0"
	end
end
]]

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
	--IP����״̬֪ͨ
	if prefix == "STATE" then
		setIPStatus(string.sub(data,8,-1))
	elseif prefix == "C" then
		--linkstatus(data)
	--IP���类����ȥ����
	elseif prefix == "+PDP" then
		--req("AT+CIPSTATUS")
		shut()
		sys.timer_stop(req,"AT+CIPSTATUS")
	--socket�յ�������������������
	elseif prefix == "+RECEIVE" then
		local lid,len = string.match(data,",(%d),(%d+)",string.len("+RECEIVE")+1)
		rcvd.id = tonumber(lid)
		rcvd.len = tonumber(len)
		return rcvdfilter
	--socket״̬֪ͨ
	else
		local lid,lstate = string.match(data,"(%d), *([%u :%d]+)")

		if lid then
			lid = tonumber(lid)
			statusind(lid,lstate)
		end
	end
end

--[[
��������shut
����  ���ر�IP����
����  ����
����ֵ����
]]
function shut()
	--�������ִ��Զ���������ܻ���dbg���ܻ���ntp���ܣ����ӳٹر�
	if updating or dbging or ntping then shutpending = true return end
	--����AT����ر�
	req("AT+CIPSHUT")
	--���ùر��б�־
	shuting = true
	if ipstatusind then sys.dispatch("IP_SHUTING_IND",true) end
	shutpending = false
end
reset = shut

--[[
��������getresult
����  ������socket״̬�ַ���
����  ��
		str�����״̬�ַ���������ERROR��1, SEND OK��1, CLOSE OK
����ֵ��socket״̬��������socket id,����ERROR��SEND OK��CLOSE OK
]]
local function getresult(str)
	return str == "ERROR" and str or string.match(str,"%d, *([%u :%d]+)")
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
	--�������ݵ���������Ӧ��
	if prefix == "+CIPSEND" then
		if response == "+PDP: DEACT" then
			req("AT+CIPSTATUS")
			response = "ERROR"
		end
		if string.match(response,"DATA ACCEPT") then
			sendcnf(id,"SEND OK")
		else
			sendcnf(id,getresult(response))
		end
	--�ر�socket��Ӧ��
	elseif prefix == "+CIPCLOSE" then
		closecnf(id,getresult(response))
	--�ر�IP�����Ӧ��
	elseif prefix == "+CIPSHUT" then
		shutcnf(response)
	--���ӵ���������Ӧ��
	elseif prefix == "+CIPSTART" then
		if response == "ERROR" then
			statusind(id,"ERROR")
		end
	--����IP�����Ӧ��
	elseif prefix == "+CIICR" then
		if success then
			--�ɹ��󣬵ײ��ȥ����IP���磬luaӦ����Ҫ����AT+CIPSTATUS��ѯIP����״̬
			if checkciicrtm and not sys.timer_is_active(ciicrerrtmfnc) then
				--����������IP���糬ʱ����ʱ��
				print("ciicrerrtmfnc start")
				sys.timer_start(ciicrerrtmfnc,checkciicrtm)
			end
		else
			shut()
			sys.timer_stop(req,"AT+CIPSTATUS")
		end
	end
end

--ע������urc֪ͨ�Ĵ�����
ril.regurc("STATE",urc)
ril.regurc("C",urc)
ril.regurc("+PDP",urc)
ril.regurc("+RECEIVE",urc)
--ע������AT�����Ӧ������
ril.regrsp("+CIPSTART",rsp)
ril.regrsp("+CIPSEND",rsp)
ril.regrsp("+CIPCLOSE",rsp)
ril.regrsp("+CIPSHUT",rsp)
ril.regrsp("+CIICR",rsp)

--gprs����δ����ʱ����ʱ��ѯ����״̬�ļ��
local QUERYTIME = 2000

--[[
��������cgattrsp
����  ����ѯGPRS�������總��״̬��Ӧ����
����  ��
		cmd����Ӧ���Ӧ��AT����
		success��AT����ִ�н����true����false
		response��AT�����Ӧ���е�ִ�н���ַ���
		intermediate��AT�����Ӧ���е��м���Ϣ
����ֵ����
]]
local function cgattrsp(cmd,success,response,intermediate)
	--�Ѹ���
	if intermediate == "+CGATT: 1" then
		cgatt = "1"
		sys.dispatch("NET_GPRS_READY",true)

		-- �����������,��ô��gprs�������Ժ��Զ�����IP����
		if base.next(linklist) then
			if ipstatus == "IP INITIAL" then
				setupIP()
			else
				req("AT+CIPSTATUS")
			end
		end
	--δ����
	elseif intermediate == "+CGATT: 0" then
		if cgatt ~= "0" then
			cgatt = "0"
			sys.dispatch("NET_GPRS_READY",false)
		end
		--���ö�ʱ����������ѯ
		sys.timer_start(querycgatt,QUERYTIME)
	end
end

--[[
��������querycgatt
����  ����ѯGPRS�������總��״̬
����  ����
����ֵ����
]]
function querycgatt()
	--���Ƿ���ģʽ����ȥ��ѯ
	if not flymode then req("AT+CGATT?",nil,cgattrsp) end
end

-- ���ýӿ�
local qsend = 0
function SetQuickSend(mode)
	--qsend = mode
end

local inited = false
--[[
��������initial
����  �����ñ�ģ�鹦�ܵ�һЩ��ʼ������
����  ����
����ֵ����
]]
local function initial()
	if not inited then
		inited = true
		req("AT+CIICRMODE=2") --ciicr�첽
		req("AT+CIPMUX=1") --������
		req("AT+CIPHEAD=1")
		req("AT+CIPQSEND=" .. qsend)--����ģʽ
	end
end

--[[
��������netmsg
����  ��GSM����ע��״̬�����仯�Ĵ���
����  ����
����ֵ��true
]]
local function netmsg(id,data)
	--GSM������ע��
	if data == "REGISTERED" then
		--���г�ʼ������
		initial() 
		--��ʱ��ѯGPRS�������總��״̬
		sys.timer_start(querycgatt,QUERYTIME)
	end

	return true
end

--sim����Ĭ��apn��
local apntable =
{
	["46000"] = "CMNET",
	["46002"] = "CMNET",
	["46004"] = "CMNET",
	["46007"] = "CMNET",
	["46001"] = "UNINET",
	["46006"] = "UNINET",
}

--[[
��������proc
����  ����ģ��ע����ڲ���Ϣ�Ĵ�����
����  ��
		id���ڲ���Ϣid
		para���ڲ���Ϣ����
����ֵ��true
]]
local function proc(id,para)
	--IMSI��ȡ�ɹ�
	if id=="IMSI_READY" then
		--��ģ���ڲ��Զ���ȡapn��Ϣ��������
		if apnflag then
			if apn then
				local temp1,temp2,temp3=apn.get_default_apn(tonumber(sim.getmcc(),16),tonumber(sim.getmnc(),16))
				if temp1 == '' or temp1 == nil then temp1="CMNET" end
				setapn(temp1,temp2,temp3)
			else
				setapn(apntable[sim.getmcc()..sim.getmnc()] or "CMNET")
			end
		end
	--����ģʽ״̬�仯
	elseif id=="FLYMODE_IND" then
		flymode = para
		if para then
			sys.timer_stop(req,"AT+CIPSTATUS")
		else
			req("AT+CGATT?",nil,cgattrsp)
		end
	--Զ��������ʼ
	elseif id=="UPDATE_BEGIN_IND" then
		updating = true
	--Զ����������
	elseif id=="UPDATE_END_IND" then
		updating = false
		if shutpending then shut() end
	--dbg���ܿ�ʼ
	elseif id=="DBG_BEGIN_IND" then
		dbging = true
	--dbg���ܽ���
	elseif id=="DBG_END_IND" then
		dbging = false
		if shutpending then shut() end
	--NTPͬ����ʼ
	elseif id=="NTP_BEGIN_IND" then
		ntping = true
	--NTPͬ������
	elseif id=="NTP_END_IND" then
		ntping = false
		if shutpending then shut() end
	end
	return true
end

--[[
��������checkciicr
����  �����ü���IP��������󣬳�ʱδ�ɹ��ĳ�ʱʱ�䡣ִ��AT+CIICR�����������checkciicrtm��checkciicrtm�����û�м���ɹ����������������;ִ��AT+CIPSHUT����������
����  ��
		tm����ʱʱ�䣬��λ����
����ֵ��true
]]
function checkciicr(tm)
	checkciicrtm = tm
	ril.regrsp("+CIICR",rsp)
end

--[[
��������setiperrcb
����  ������"����IP��������󣬳�ʱδ�ɹ�"���û��ص�����
����  ��
		cb���ص�����
����ֵ����
]]
function setiperrcb(cb)
	ciicrerrcb = cb
end

--[[
��������setretrymode
����  ������"���ӹ��̺����ݷ��͹�����TCPЭ�����������"
����  ��
		md��number���ͣ���֧��0��1
			0Ϊ�����ܶ�����������ܻ�ܳ�ʱ��Ż᷵�����ӻ��߷��ͽ����
			1Ϊ�ʶ��������������ϲ����û�����磬����10���뷵��ʧ�ܽ����
����ֵ����
]]
function setretrymode(md)
	ril.request("AT+TCPUSERPARAM=6,"..(md==0 and 3 or 2)..",7200")
end

--ע�᱾ģ���ע���ڲ���Ϣ�Ĵ�����
sys.regapp(proc,"IMSI_READY","FLYMODE_IND","UPDATE_BEGIN_IND","UPDATE_END_IND","DBG_BEGIN_IND","DBG_END_IND","NTP_BEGIN_IND","NTP_END_IND")
sys.regapp(netmsg,"NET_STATE_CHANGED")
checkciicr(120000)
