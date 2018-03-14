--����ģ��,����������
local base = _G
local string = require"string"
local io = require"io"
local os = require"os"
local sys  = require"sys"
local misc = require"misc"
local link = require"link"
local socketssl = require"socketssl"
local crypto = require"crypto"
module(...,package.seeall)


local ssub,schar,smatch,sbyte,slen,sfind = string.sub,string.char,string.match,string.byte,string.len,string.find
local tonumber = base.tonumber


--�����Ƽ�Ȩ������
local SCK_IDX,PROT,ADDR,PORT = 3,"TCP","iot-auth.cn-shanghai.aliyuncs.com",443
--�밢���Ƽ�Ȩ��������socket����״̬
local linksta
--һ�����������ڵĶ�����������Ӻ�̨ʧ�ܣ��᳢���������������ΪRECONN_PERIOD�룬�������RECONN_MAX_CNT��
--���һ�����������ڶ�û�����ӳɹ�����ȴ�RECONN_CYCLE_PERIOD������·���һ����������
--�������RECONN_CYCLE_MAX_CNT�ε��������ڶ�û�����ӳɹ������������
local RECONN_MAX_CNT,RECONN_PERIOD,RECONN_CYCLE_MAX_CNT,RECONN_CYCLE_PERIOD = 3,10,3,20
--reconncnt:��ǰ���������ڣ��Ѿ������Ĵ���
--reconncyclecnt:�������ٸ��������ڣ���û�����ӳɹ�
--һ�����ӳɹ������Ḵλ���������
--conning:�Ƿ��ڳ�������
local reconncnt,reconncyclecnt,conning = 0,0
--��Ʒ��ʶ����Ʒ��Կ���豸�����豸��Կ
local productkey,productsecret,devicename,devicesecret
--�Ӽ�Ȩ�������յ����������ģ��������е���Ч����
local rcvbuf,rcvalidbody = "",""

--[[
��������print
����  ����ӡ�ӿڣ����ļ��е����д�ӡ�������aliyuniotauthǰ׺
����  ����
����ֵ����
]]
local function print(...)
	base.print("aliyuniotauthssl",...)
end

local function getdevice(s)
	if s=="name" then
		return devicename or misc.getimei()
	elseif s=="secret" then
		return devicesecret or misc.getsn()
	end
end

--[[
��������snd
����  �����÷��ͽӿڷ�������
����  ��
        data�����͵����ݣ��ڷ��ͽ���¼�������ntfy�У��ḳֵ��item.data��
		para�����͵Ĳ������ڷ��ͽ���¼�������ntfy�У��ḳֵ��item.para�� 
����ֵ�����÷��ͽӿڵĽ�������������ݷ����Ƿ�ɹ��Ľ�������ݷ����Ƿ�ɹ��Ľ����ntfy�е�SEND�¼���֪ͨ����trueΪ�ɹ�������Ϊʧ��
]]
function snd(data,para)
	return socketssl.send(SCK_IDX,data,para)
end

--[[
��������postsnd
����  ������POST���ĵ���Ȩ������
����  ��
		typ����������
����ֵ����
]]
local function postsnd(typ)	
	local data = "clientId"..getdevice("name").."deviceName"..getdevice("name").."productKey"..productkey
	local signkey = getdevice("secret")
	local sign = crypto.hmac_md5(data,slen(data),signkey,slen(signkey))
	local body = "productKey="..productkey.."&sign="..sign.."&clientId="..getdevice("name").."&deviceName="..getdevice("name")
	local head = "POST /auth/devicename HTTP/1.1\r\n" .. "Host: "..ADDR.."\r\nContent-Type: application/x-www-form-urlencoded\r\nContent-Length: "..slen(body).."\r\n\r\n"
	snd(head..body,"POSTSND")
end

--[[
��������preproc
����  ����ȨԤ����
����  ����
����ֵ����
]]
function preproc()
	print("preproc",linksta)
	if linksta then
		postsnd()
	end
end

--[[
��������sndcb
����  �����ݷ��ͽ������
����  ��          
		item��table���ͣ�{data=,para=}����Ϣ�ش��Ĳ��������ݣ��������socketssl.sendʱ����ĵ�2���͵�3�������ֱ�Ϊdat��par����item={data=dat,para=par}
		result�� bool���ͣ����ͽ����trueΪ�ɹ�������Ϊʧ��
����ֵ����
]]
local function sndcb(item,result)
	print("sndcb",item.para,result)
	if not item.para then return end
	if item.para=="POSTSND" then
		sys.timer_start(reconn,RECONN_PERIOD*1000)
	end
end


--[[
��������reconn
����  ��������̨����
        һ�����������ڵĶ�����������Ӻ�̨ʧ�ܣ��᳢���������������ΪRECONN_PERIOD�룬�������RECONN_MAX_CNT��
        ���һ�����������ڶ�û�����ӳɹ�����ȴ�RECONN_CYCLE_PERIOD������·���һ����������
        �������RECONN_CYCLE_MAX_CNT�ε��������ڶ�û�����ӳɹ������������
����  ����
����ֵ����
]]
function reconn()
	print("reconn",reconncnt,conning,reconncyclecnt)
	--conning��ʾ���ڳ������Ӻ�̨��һ��Ҫ�жϴ˱����������п��ܷ��𲻱�Ҫ������������reconncnt���ӣ�ʵ�ʵ�������������
	if conning then return end
	--һ�����������ڵ�����
	if reconncnt < RECONN_MAX_CNT then		
		reconncnt = reconncnt+1
		socketssl.disconnect(SCK_IDX)
	--һ���������ڵ�������ʧ��
	else
		reconncnt,reconncyclecnt = 0,reconncyclecnt+1
		if reconncyclecnt >= RECONN_CYCLE_MAX_CNT then
			sys.restart("connect fail")
		end
		link.shut()
	end
end

--[[
��������ntfy
����  ��socket״̬�Ĵ�����
����  ��
        idx��number���ͣ�socket.lua��ά����socket idx��������socketssl.connectʱ����ĵ�һ��������ͬ��������Ժ��Բ�����
        evt��string���ͣ���Ϣ�¼�����
		result�� bool���ͣ���Ϣ�¼������trueΪ�ɹ�������Ϊʧ��
		item��table���ͣ�{data=,para=}����Ϣ�ش��Ĳ��������ݣ�Ŀǰֻ����SEND���͵��¼����õ��˴˲������������socketssl.sendʱ����ĵ�2���͵�3�������ֱ�Ϊdat��par����item={data=dat,para=par}
����ֵ����
]]
function ntfy(idx,evt,result,item)
	print("ntfy",evt,result,item)
	--���ӽ��������socketssl.connect����첽�¼���
	if evt == "CONNECT" then
		conning = false
		--���ӳɹ�
		if result then
			reconncnt,reconncyclecnt,linksta,rcvbuf,rcvbody = 0,0,true,"",""
			--ֹͣ������ʱ��
			sys.timer_stop(reconn)
			preproc()
		--����ʧ��
		else
			--RECONN_PERIOD�������
			sys.timer_start(reconn,RECONN_PERIOD*1000)
		end	
	--���ݷ��ͽ��������socketssl.send����첽�¼���
	elseif evt == "SEND" then
		if item then
			sndcb(item,result)
		end
		--����ʧ�ܣ�RECONN_PERIOD���������̨����Ҫ����reconn����ʱsocket״̬��Ȼ��CONNECTED���ᵼ��һֱ�����Ϸ�����
		--if not result then sys.timer_start(reconn,RECONN_PERIOD*1000) end
		if not result then socketssl.disconnect(SCK_IDX) end
	--���ӱ����Ͽ�
	elseif evt == "STATE" and result == "CLOSED" then
		linksta = false
		socketssl.close(SCK_IDX)
	--���������Ͽ�������link.shut����첽�¼���
	elseif evt == "STATE" and result == "SHUTED" then
		linksta = false
		connect()
	--���������Ͽ�������socketssl.disconnect����첽�¼���
	elseif evt == "DISCONNECT" then
		linksta = false
		connect()
	end
	--�����������Ͽ�������·����������
	if smatch((base.type(result)=="string") and result or "","ERROR") then
		socketssl.disconnect(SCK_IDX)
	end
end

--[[
��������parsevalidbody
����  ��������Ȩ���������ص���Ч������
����  ����
����ֵ����
]]
local function parsevalidbody()
	print("parsevalidbody")
	local tjsondata = json.decode(rcvalidbody)
	
	print("message",tjsondata["message"])
	if tjsondata["message"]~="success" then print("parsevalidbody message err") return end
	
	local iotId = tjsondata["data"]["iotId"]
	print("iotId",iotId)
	if not iotId or iotId=="" then print("parsevalidbody iotId err") return end
	
	local iotToken = tjsondata["data"]["iotToken"]
	print("iotToken",iotToken)
	if not iotToken or iotToken=="" then print("parsevalidbody iotToken err") return end
	
	local ports,host,rmqtt = {}
	if tjsondata["data"]["resources"] then
		if tjsondata["data"]["resources"]["mqtt"] then
			rmqtt,host = true,tjsondata["data"]["resources"]["mqtt"]["host"]
			table.insert(ports,tjsondata["data"]["resources"]["mqtt"]["port"])
			print("host",host)
			print("port",tjsondata["data"]["resources"]["mqtt"]["port"])
		end
	end
	
	sys.dispatch("ALIYUN_DATA_BGN",rmqtt and host or productkey..".iot-as-mqtt.cn-shanghai.aliyuncs.com",#ports~=0 and ports or {1883},getdevice("name"),iotId,iotToken)	
	sys.timer_stop(reconn)	
end

--[[
��������parse
����  ��������Ȩ���������ص�����
����  ����
����ֵ����
]]
local function parse()
	local headend = sfind(rcvbuf,"\r\n\r\n")
	if not headend then print("parse wait head end") return end
	
	local headstr = ssub(rcvbuf,1,headend+3)
	if not smatch(headstr,"200 OK") then print("parse no 200 OK") return end
	
	local contentflg
	if smatch(headstr,"Transfer%-Encoding: chunked") or smatch(headstr,"Transfer%-Encoding: Chunked") then
		contentflg = "chunk"
	elseif smatch(headstr,"Content%-Length: %d+") then
		contentflg = tonumber(smatch(headstr,"Content%-Length: (%d+)"))
	end
	if not contentflg then print("parse contentflg error") return end
	
	local rcvbody = ssub(rcvbuf,headend+4,-1)
	if contentflg=="chunk" then	
		rcvalidbody = ""
		if not smatch(rcvbody,"0\r\n\r\n") then print("parse wait chunk end") return end
		local h,t,len
		while true do
			h,t,len = sfind(rcvbody,"(%w+)\r\n")
			if len then
				len = tonumber(len,16)
				if len==0 then break end
				rcvalidbody = rcvalidbody..ssub(rcvbody,t+1,t+len)
				rcvbody = ssub(rcvbody,t+len+1,-1)
			else
				print("parse chunk len err ")
				return
			end
		end
	else
		if slen(rcvbody)~=contentflg then print("parse wait content len end") return end
		rcvalidbody = rcvbody
	end
	
	rcvbuf = ""
	parsevalidbody()
	socketssl.close(SCK_IDX)
end

--[[
��������rcv
����  ��socket�������ݵĴ�����
����  ��
        idx ��socketssl.lua��ά����socket idx��������socketssl.connectʱ����ĵ�һ��������ͬ��������Ժ��Բ�����
        data�����յ�������
����ֵ����
]]
function rcv(idx,data)
	print("rcv",data)
	rcvbuf = rcvbuf..data
	parse()
end

--[[
��������connect
����  �������������Ƽ�Ȩ�����������ӣ�
        ������������Ѿ�׼���ã����������Ӻ�̨��������������ᱻ���𣬵���������׼���������Զ�ȥ���Ӻ�̨
		ntfy��socket״̬�Ĵ�����
		rcv��socket�������ݵĴ�����
����  ����
����ֵ����
]]
function connect()
	socketssl.connect(SCK_IDX,PROT,ADDR,PORT,ntfy,rcv)
	conning = true
end

--[[
��������authbgn
����  �������Ȩ
����  ����
����ֵ����
]]
local function authbgn(pkey,psecret,dname,dsecret)
	productkey,productsecret,devicename,devicesecret = pkey,psecret,dname,dsecret
	connect()
end

local procer =
{
	ALIYUN_AUTH_BGN = authbgn,
}

sys.regapp(procer)

