--[[
ģ�����ƣ����⴮��AT���������
ģ�鹦�ܣ�AT����
ģ������޸�ʱ�䣺2017.02.13
]]
--����ģ��,����������
local base = _G
local table = require"table"
local string = require"string"
local uart = require"uart"
local rtos = require"rtos"
local sys = require"sys"
module("ril")

--���س��õ�ȫ�ֺ���������
local setmetatable = base.setmetatable
local print = base.print
local type = base.type
local smatch,sfind,slen = string.match,string.find,string.len
local vwrite = uart.write
local vread = uart.read

--�Ƿ�Ϊ͸��ģʽ��trueΪ͸��ģʽ��false����nilΪ��͸��ģʽ
--Ĭ�Ϸ�͸��ģʽ
local transparentmode
--͸��ģʽ�£����⴮�����ݽ��յĴ�����
local rcvfunc

--ִ��AT�����1�����޷������ж�at����ִ��ʧ�ܣ����������
local TIMEOUT = 60000 

--AT�����Ӧ������
--NORESULT���յ���Ӧ�����ݵ���urc֪ͨ����������͵�AT�������Ӧ�����û���������ͣ�Ĭ��Ϊ������
--NUMBERIC�����������ͣ����緢��AT+CGSN���Ӧ�������Ϊ��862991527986589\r\nOK��������ָ����862991527986589��һ����Ϊ����������
--SLINE����ǰ׺�ĵ����ַ������ͣ����緢��AT+CSQ���Ӧ�������Ϊ��+CSQ: 23,99\r\nOK��������ָ����+CSQ: 23,99��һ����Ϊ�����ַ�������
--MLINE����ǰ׺�Ķ����ַ������ͣ����緢��AT+CMGR=5���Ӧ�������Ϊ��+CMGR: 0,,84\r\n0891683108200105F76409A001560889F800087120315123842342050003590404590D003A59\r\nOK��������ָ����OK֮ǰΪ�����ַ�������
--STRING����ǰ׺���ַ������ͣ����緢��AT+ATWMFT=99���Ӧ�������Ϊ��SUCC\r\nOK��������ָ����SUCC
--SPECIAL���������ͣ���Ҫ���AT���������⴦������CIPSEND��CIPCLOSE��CIFSR
local NORESULT,NUMBERIC,SLINE,MLINE,STRING,SPECIAL = 0,1,2,3,4,10

--AT�����Ӧ�����ͱ�Ԥ�������¼���
local RILCMD = {
	["+CSQ"] = 2,
	["+CGSN"] = 1,
	["+WISN"] = 4,
	["+CIMI"] = 1,
	["+CCID"] = 1,
	["+CGATT"] = 2,
	["+CCLK"] = 2,
	["+ATWMFT"] = 4,
	["+CMGR"] = 3,
	["+CMGS"] = 2,
	["+CPBF"] = 3,
	["+CPBR"] = 3,
 	["+CIPSEND"] = 10,
	["+CIPCLOSE"] = 10,
	["+SSLINIT"] = 10,
	["+SSLCERT"] = 10,
	["+SSLCREATE"] = 10,
	["+SSLCONNECT"] = 10,
	["+SSLSEND"] = 10,
	["+SSLDESTROY"] = 10,
	["+SSLTERM"] = 10,
	["+CIFSR"] = 10,
}

--radioready��AT����ͨ���Ƿ�׼������
--delaying��ִ����ĳЩAT����ǰ����Ҫ��ʱһ��ʱ�䣬������ִ����ЩAT����˱�־��ʾ�Ƿ�����ʱ״̬
local radioready,delaying = false

--AT�������
local cmdqueue = {
	"ATE0",
	"AT+CMEE=0",
}
--��ǰ����ִ�е�AT����,����,�����ص�,�ӳ�ִ��ʱ��,����ͷ,����,������ʽ
local currcmd,currarg,currsp,curdelay,cmdhead,cmdtype,rspformt
--�������,�м���Ϣ,�����Ϣ
local result,interdata,respdata

--ril������������: 
--����AT����յ�Ӧ��
--����AT������ʱû��Ӧ��
--�ײ���������ϱ���֪ͨ���������Ǽ��Ϊurc

--[[
��������atimeout
����  ������AT������ʱû��Ӧ��Ĵ���
����  ����
����ֵ����
]]
local function atimeout()
	--�������
	sys.restart("ril.atimeout_"..(currcmd or ""))
end

--[[
��������defrsp
����  ��AT�����Ĭ��Ӧ�������û�ж���ĳ��AT��Ӧ������������ߵ�������
����  ��
		cmd����Ӧ���Ӧ��AT����
		success��AT����ִ�н����true����false
		response��AT�����Ӧ���е�ִ�н���ַ���
		intermediate��AT�����Ӧ���е��м���Ϣ
����ֵ����
]]
local function defrsp(cmd,success,response,intermediate)
	print("default response:",cmd,success,response,intermediate)
end

--AT�����Ӧ�����
local rsptable = {}
setmetatable(rsptable,{__index = function() return defrsp end})

--�Զ����AT����Ӧ���ʽ����AT����Ӧ��ΪSTRING��ʽʱ���û����Խ�һ������������ĸ�ʽ
local formtab = {}

--[[
��������regrsp
����  ��ע��ĳ��AT����Ӧ��Ĵ�����
����  ��
		head����Ӧ���Ӧ��AT����ͷ��ȥ������ǰ���AT�����ַ�
		fnc��AT����Ӧ��Ĵ�����
		typ��AT�����Ӧ�����ͣ�ȡֵ��ΧNORESULT,NUMBERIC,SLINE,MLINE,STRING,SPECIAL
		formt��typΪSTRINGʱ����һ������STRING�е���ϸ��ʽ
����ֵ���ɹ�����true��ʧ��false
]]
function regrsp(head,fnc,typ,formt)
	--û�ж���Ӧ������
	if typ == nil then
		rsptable[head] = fnc
		return true
	end
	--�����˺Ϸ�Ӧ������
	if typ == 0 or typ == 1 or typ == 2 or typ == 3 or typ == 4 or typ == 10 then
		--���AT�����Ӧ�������Ѵ��ڣ������������õĲ�һ��
		if RILCMD[head] and RILCMD[head] ~= typ then
			return false
		end
		--����
		RILCMD[head] = typ
		rsptable[head] = fnc
		formtab[head] = formt
		return true
	else
		return false
	end
end

--[[
��������rsp
����  ��AT�����Ӧ����
����  ����
����ֵ����
]]
local function rsp()
	--ֹͣӦ��ʱ��ʱ��
	sys.timer_stop(atimeout)
	--�������AT����ʱ�Ѿ�ͬ��ָ����Ӧ������
	if currsp then
		currsp(currcmd,result,respdata,interdata)
	--�û�ע���Ӧ�����������ҵ�������
	else
		rsptable[cmdhead](currcmd,result,respdata,interdata)
	end
	--����ȫ�ֱ���
	currcmd,currarg,currsp,curdelay,cmdhead,cmdtype,rspformt = nil
	result,interdata,respdata = nil
end

--[[
��������defurc
����  ��urc��Ĭ�ϴ������û�ж���ĳ��urc��Ӧ������������ߵ�������
����  ��
		data��urc����
����ֵ����
]]
local function defurc(data)
	print("defurc:",data)
end

--urc�Ĵ����
local urctable = {}
setmetatable(urctable,{__index = function() return defurc end})

--[[
��������regurc
����  ��ע��ĳ��urc�Ĵ�����
����  ��
		prefix��urcǰ׺����ǰ��������ַ���������+����д�ַ������ֵ����
		handler��urc�Ĵ�����
����ֵ����
]]
function regurc(prefix,handler)
	urctable[prefix] = handler
end

--[[
��������deregurc
����  ����ע��ĳ��urc�Ĵ�����
����  ��
		prefix��urcǰ׺����ǰ��������ַ���������+����д�ַ������ֵ����
����ֵ����
]]
function deregurc(prefix)
	urctable[prefix] = nil
end

--�����ݹ������������⴮���յ�������ʱ��������Ҫ���ô˺������˴���һ��
local urcfilter

--[[
��������urc
����  ��urc����
����  ��
		data��urc����
����ֵ����
]]
local function urc(data)
	--ATͨ��׼������
	if data == "RDY" then
		radioready = true
	else
		local prefix = smatch(data,"(%+*[%u%d& ]+)")
		--ִ��prefix��urc���������������ݹ�����
		urcfilter = urctable[prefix](data,prefix)
	end
end

--[[
��������procatc
����  ���������⴮���յ�������
����  ��
		data���յ�������
����ֵ����
]]
local function procatc(data)
	--��������Ӧ���Ƕ����ַ�����ʽ
	if interdata and cmdtype == MLINE then
		--������OK\r\n������ΪӦ��δ����
		if data ~= "OK\r\n" then
			--ȥ������\r\n
			if sfind(data,"\r\n",-2) then
				data = string.sub(data,1,-3)
			end
			--ƴ�ӵ��м�����
			interdata = interdata .. "\r\n" .. data
			return
		end
	end
	--������ڡ����ݹ�������
	if urcfilter then
		if slen(data)<200 then print("atc:",data) end
		data,urcfilter = urcfilter(data)
	else
		print("atc:",data)
	end
	--ȥ������\r\n
	if sfind(data,"\r\n",-2) then
		data = string.sub(data,1,-3)
	end
	--����Ϊ��
	if data == "" then
		return
	end
	--��ǰ��������ִ�����ж�Ϊurc
	if currcmd == nil then
		urc(data)
		return
	end

	local isurc = false

	--һЩ����Ĵ�����Ϣ��ת��ΪERRORͳһ����
	if sfind(data,"^%+CMS ERROR:") or sfind(data,"^%+CME ERROR:") or (data == "CONNECT FAIL" and currcmd and smatch(currcmd,"CIPSTART")) then
		data = "ERROR"
	end
	--ִ�гɹ���Ӧ��
	if data == "OK" or data == "SHUT OK" then
		result = true
		respdata = data
	--ִ��ʧ�ܵ�Ӧ��
	elseif data == "ERROR" or data == "NO ANSWER" or data == "NO DIALTONE" then
		result = false
		respdata = data
	--��Ҫ�������������AT����Ӧ��
	elseif data == "> " then
		--���Ͷ���
		if cmdhead == "+CMGS" then
			print("send:",currarg)
			vwrite(uart.ATC,currarg,"\026")
		--��������
		elseif cmdhead == "+CIPSEND" or cmdhead == "+SSLSEND" or cmdhead == "+SSLCERT" then
			print("send:",currarg)
			vwrite(uart.ATC,currarg)
		else
			print("error promot cmd:",currcmd)
		end
	else
		--������
		if cmdtype == NORESULT then
			isurc = true
		--ȫ��������
		elseif cmdtype == NUMBERIC then
			local numstr = smatch(data,"(%x+)")
			if numstr == data then
				interdata = data
			else
				isurc = true
			end
		--�ַ�������
		elseif cmdtype == STRING then
			--��һ������ʽ
			if smatch(data,rspformt or "^%w+$") then
				interdata = data
			else
				isurc = true
			end
		elseif cmdtype == SLINE or cmdtype == MLINE then
			if interdata == nil and sfind(data, cmdhead) == 1 then
				interdata = data
			else
				isurc = true
			end
		--���⴦��
		elseif cmdhead == "+CIFSR" then
			local s = smatch(data,"%d+%.%d+%.%d+%.%d+")
			if s ~= nil then
				interdata = s
				result = true
			else
				isurc = true
			end
		--���⴦��
		elseif cmdhead == "+CIPSEND" or cmdhead == "+CIPCLOSE" then
			local keystr = cmdhead == "+CIPSEND" and "SEND" or "CLOSE"
			local lid,res = smatch(data,"(%d), *([%u%d :]+)")

			if lid and res then
				if (sfind(res,keystr) == 1 or sfind(res,"TCP ERROR") == 1 or sfind(res,"UDP ERROR") == 1 or sfind(data,"DATA ACCEPT")) and (lid == smatch(currcmd,"=(%d)")) then
					result = true
					respdata = data
				else
					isurc = true
				end
			elseif data == "+PDP: DEACT" then
				result = true
				respdata = data
			else
				isurc = true
			end		
		elseif cmdhead=="+SSLINIT" or cmdhead=="+SSLTERM" then
			local keystr = smatch(cmdhead,"SSL(%w+)")
			if smatch(data,"^SSL&%d,"..keystr) then
				respdata = data
				if smatch(data,"ERROR") then
					result = false
				else
					result = true
				end
			else
				isurc = true
			end
		elseif cmdhead=="+SSLCERT" then
			if smatch(data,"^SSL&%d,INPUT CERT") or smatch(data,"^SSL&%d,CONFIG CERT") then
				respdata = data
				if smatch(data,"ERROR") then
					result = false
				else
					result = true
				end
			else
				isurc = true
			end
		elseif cmdhead=="+SSLCREATE" or cmdhead=="+SSLCONNECT" or cmdhead=="+SSLSEND" or cmdhead=="+SSLDESTROY" then
			local keystr = smatch(cmdhead,"SSL(%w+)")
			local lid,res = smatch(data,"^SSL&(%d),(%w+)")
			
			print("ril.ssl",keystr,lid,res,smatch(currcmd,"=(%d)"),smatch(data,"^SSL&%d,(%w+)"))
			
			if lid and res then
				if (lid == smatch(currcmd,"=(%d)")) and (keystr==smatch(data,"^SSL&%d,(%w+)")) then
					respdata = data
					if smatch(data,"ERROR") then
						result = false
					else
						result = true
					end
				else
					isurc = true
				end				
			else
				isurc = true
			end	
		else
			isurc = true
		end
	end
	--urc����
	if isurc then
		urc(data)
	--Ӧ����
	elseif result ~= nil then
		rsp()
	end
end

--�Ƿ��ڶ�ȡ���⴮������
local readat = false

--[[
��������getcmd
����  ������һ��AT����
����  ��
		item��AT����
����ֵ����ǰAT���������
]]
local function getcmd(item)
	local cmd,arg,rsp,delay
	--������string����
	if type(item) == "string" then
		--��������
		cmd = item
	--������table����
	elseif type(item) == "table" then
		--��������
		cmd = item.cmd
		--�������
		arg = item.arg
		--����Ӧ������
		rsp = item.rsp
		--������ʱִ��ʱ��
		delay = item.delay
	else
		print("getpack unknown item")
		return
	end
	--����ǰ׺
	head = smatch(cmd,"AT([%+%*]*%u+)")

	if head == nil then
		print("request error cmd:",cmd)
		return
	end
	--��������������в���
	if head == "+CMGS" or head == "+CIPSEND" then -- �����в���
		if arg == nil or arg == "" then
			print("request error no arg",head)
			return
		end
	end

	--��ֵȫ�ֱ���
	currcmd = cmd
	currarg = arg
	currsp = rsp
	curdelay = delay
	cmdhead = head
	cmdtype = RILCMD[head] or NORESULT
	rspformt = formtab[head]

	return currcmd
end

--[[
��������sendat
����  ������AT����
����  ����
����ֵ����
]]
local function sendat()
	--ATͨ��δ׼�����������ڶ�ȡ���⴮�����ݡ���AT������ִ�л��߶������������ʱ����ĳ��AT
	if not radioready or readat or currcmd ~= nil or delaying then		
		return
	end

	local item

	while true do
		--������AT����
		if #cmdqueue == 0 then
			return
		end
		--��ȡ��һ������
		item = table.remove(cmdqueue,1)
		--��������
		getcmd(item)
		--��Ҫ�ӳٷ���
		if curdelay then
			--�����ӳٷ��Ͷ�ʱ��
			sys.timer_start(delayfunc,curdelay)
			--���ȫ�ֱ���
			currcmd,currarg,currsp,curdelay,cmdhead,cmdtype,rspformt = nil
			item.delay = nil
			--�����ӳٷ��ͱ�־
			delaying = true
			--���������²���������еĶ���
			table.insert(cmdqueue,1,item)
			return
		end

		if currcmd ~= nil then
			break
		end
	end
	--����AT����Ӧ��ʱ��ʱ��
	sys.timer_start(atimeout,TIMEOUT)

	print("sendat:",currcmd)
	--�����⴮���з���AT����
	vwrite(uart.ATC,currcmd .. "\r")
end

--[[
��������delayfunc
����  ����ʱִ��ĳ��AT����Ķ�ʱ���ص�
����  ����
����ֵ����
]]
function delayfunc()
	--�����ʱ��־
	delaying = nil
	--ִ��AT�����
	sendat()
end

--[[
��������atcreader
����  ����AT��������⴮�����ݽ�����Ϣ���Ĵ������������⴮���յ�����ʱ�����ߵ��˺�����
����  ����
����ֵ����
]]
local function atcreader()
	local s

	if not transparentmode then readat = true end
	--ѭ����ȡ���⴮���յ�������
	while true do
		--ÿ�ζ�ȡһ��
		s = vread(uart.ATC,"*l",0)
		if slen(s) ~= 0 then
			if transparentmode then
				--͸��ģʽ��ֱ��ת������
				rcvfunc(s)
			else
				--��͸��ģʽ�´����յ�������
				procatc(s)
			end
		else
			break
		end
	end
	if not transparentmode then
		readat = false
		--���ݴ������Ժ����ִ��AT�����
		sendat()
	end
end

--ע�ᡰAT��������⴮�����ݽ�����Ϣ���Ĵ�����
sys.regmsg("atc",atcreader)

--[[
��������request
����  ������AT����ײ����
����  ��
		cmd��AT��������
		arg��AT�������������AT+CMGS=12����ִ�к󣬽������ᷢ�ʹ˲�����AT+CIPSEND=14����ִ�к󣬽������ᷢ�ʹ˲���
		onrsp��AT����Ӧ��Ĵ�������ֻ�ǵ�ǰ���͵�AT����Ӧ����Ч������֮���ʧЧ��
		delay����ʱdelay����󣬲ŷ��ʹ�AT����
����ֵ����
]]
function request(cmd,arg,onrsp,delay)
	if transparentmode then return end
	--���뻺�����
	if arg or onrsp or delay or formt then
		table.insert(cmdqueue,{cmd = cmd,arg = arg,rsp = onrsp,delay = delay})
	else
		table.insert(cmdqueue,cmd)
	end
	--ִ��AT�����
	sendat()
end

--[[
��������setransparentmode
����  ��AT����ͨ������Ϊ͸��ģʽ
����  ��
		fnc��͸��ģʽ�£����⴮�����ݽ��յĴ�����
����ֵ����
ע�⣺͸��ģʽ�ͷ�͸��ģʽ��ֻ֧�ֿ����ĵ�һ�����ã���֧����;�л�
]]
function setransparentmode(fnc)
	transparentmode,rcvfunc = true,fnc
end

--[[
��������sendtransparentdata
����  ��͸��ģʽ�·�������
����  ��
		data������
����ֵ���ɹ�����true��ʧ�ܷ���nil
]]
function sendtransparentdata(data)
	if not transparentmode then return end
	vwrite(uart.ATC,data)
	return true
end
