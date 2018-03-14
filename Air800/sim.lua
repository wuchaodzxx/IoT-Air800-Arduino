--[[
ģ�����ƣ�sim������
ģ�鹦�ܣ���ѯsim��״̬��iccid��imsi��mcc��mnc
ģ������޸�ʱ�䣺2017.02.13
]]

--����ģ��,����������
local string = require"string"
local ril = require"ril"
local sys = require"sys"
local base = _G
local os = require"os"
module(...)

--���س��õ�ȫ�ֺ���������
local tonumber = base.tonumber
local tostring = base.tostring
local req = ril.request

--sim����imsi��sim����iccid
local imsi,iccid,status

--[[
��������geticcid
����  ����ȡsim����iccid
����  ����
����ֵ��iccid�������û�ж�ȡ�������򷵻�nil
ע�⣺����lua�ű�����֮�󣬻ᷢ��at����ȥ��ѯiccid��������Ҫһ��ʱ����ܻ�ȡ��iccid���������������ô˽ӿڣ������Ϸ���nil
]]
function geticcid()
	return iccid
end

--[[
��������getimsi
����  ����ȡsim����imsi
����  ����
����ֵ��imsi�������û�ж�ȡ�������򷵻�nil
ע�⣺����lua�ű�����֮�󣬻ᷢ��at����ȥ��ѯimsi��������Ҫһ��ʱ����ܻ�ȡ��imsi���������������ô˽ӿڣ������Ϸ���nil
]]
function getimsi()
	return imsi
end

--[[
��������getmcc
����  ����ȡsim����mcc
����  ����
����ֵ��mcc�������û�ж�ȡ�������򷵻�""
ע�⣺����lua�ű�����֮�󣬻ᷢ��at����ȥ��ѯimsi��������Ҫһ��ʱ����ܻ�ȡ��imsi���������������ô˽ӿڣ������Ϸ���""
]]
function getmcc()
	return (imsi ~= nil and imsi ~= "") and string.sub(imsi,1,3) or ""
end

--[[
��������getmnc
����  ����ȡsim����getmnc
����  ����
����ֵ��mnc�������û�ж�ȡ�������򷵻�""
ע�⣺����lua�ű�����֮�󣬻ᷢ��at����ȥ��ѯimsi��������Ҫһ��ʱ����ܻ�ȡ��imsi���������������ô˽ӿڣ������Ϸ���""
]]
function getmnc()
	return (imsi ~= nil and imsi ~= "") and string.sub(imsi,4,5) or ""
end

--[[
��������getstatus
����  ����ȡsim����״̬
����  ����
����ֵ��true��ʾsim��������false����nil��ʾδ��⵽�����߿��쳣
ע�⣺����lua�ű�����֮�󣬻ᷢ��at����ȥ��ѯ״̬��������Ҫһ��ʱ����ܻ�ȡ��״̬���������������ô˽ӿڣ������Ϸ���nil
]]
function getstatus()
	return status
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
	if cmd == "AT+CCID" then
		iccid = intermediate
	elseif cmd == "AT+CIMI" then
		imsi = intermediate
		--����һ���ڲ���ϢIMSI_READY��֪ͨ�Ѿ���ȡimsi
		sys.dispatch("IMSI_READY")
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
local function urc(data,prefix)
	--sim��״̬֪ͨ
	if prefix == "+CPIN" then
		status = false
		--sim������
		if data == "+CPIN: READY" then
			status = true
			req("AT+CCID")
			req("AT+CIMI")
			sys.dispatch("SIM_IND","RDY")
		--δ��⵽sim��
		elseif data == "+CPIN: NOT INSERTED" then
			sys.dispatch("SIM_IND","NIST")
		else
			--sim��pin����
			if data == "+CPIN: SIM PIN" then
				sys.dispatch("SIM_IND_SIM_PIN")	
			end
			sys.dispatch("SIM_IND","NORDY")
		end
	end
end

--ע��AT+CCID�����Ӧ������
ril.regrsp("+CCID",rsp)
--ע��AT+CIMI�����Ӧ������
ril.regrsp("+CIMI",rsp)
--ע��+CPIN֪ͨ�Ĵ�����
ril.regurc("+CPIN",urc)
