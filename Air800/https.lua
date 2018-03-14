module(...,package.seeall)

require"common"
require"socketssl"
require"utils"
local lpack=require"pack"

local sfind,slen,ssub,smatch,sgmatch= string.find,string.len,string.sub,string.match,string.gmatch
local PACKET_LEN = 1460
--[[
��������print
����  ����ӡ�ӿڣ����ļ��е����д�ӡ�������testǰ׺
����  ����
����ֵ����
]]
local function print(...)
	_G.print("https",...)
end

--http clients�洢��
local tclients = {}

--[[
��������getclient
����  ������һ��http client��tclients�е�����
����  ��
	  sckidx��http client��Ӧ��socket����
����ֵ��sckidx��Ӧ��http client��tclients�е�����
]]
local function getclient(sckidx)
	for k,v in pairs(tclients) do
		if v.sckidx==sckidx then return k end
	end
end

--[[
��������datinactive
����  ������ͨ���쳣����
����  ��
		sckidx��socket idx
����ֵ����
]]
local function datinactive(sckidx)
    sys.restart("SVRNODATA")
end

--[[
��������snd
����  �����÷��ͽӿڷ�������
����  ��
		sckidx��socket idx
        data�����͵����ݣ��ڷ��ͽ���¼�������ntfy�У��ḳֵ��item.data��
		para�����͵Ĳ������ڷ��ͽ���¼�������ntfy�У��ḳֵ��item.para�� 
����ֵ�����÷��ͽӿڵĽ�������������ݷ����Ƿ�ɹ��Ľ�������ݷ����Ƿ�ɹ��Ľ����ntfy�е�SEND�¼���֪ͨ����trueΪ�ɹ�������Ϊʧ��
]]
function snd(sckidx,data,para)
    return socketssl.send(sckidx,data,para)
end

local RECONN_MAX_CNT,RECONN_PERIOD,RECONN_CYCLE_MAX_CNT,RECONN_CYCLE_PERIOD = 3,5,3,20

--[[
��������reconn
����  ��socket������̨����
        һ�����������ڵĶ�����������Ӻ�̨ʧ�ܣ��᳢���������������ΪRECONN_PERIOD�룬�������RECONN_MAX_CNT��
        ���һ�����������ڶ�û�����ӳɹ�����ȴ�RECONN_CYCLE_PERIOD������·���һ����������
        �������RECONN_CYCLE_MAX_CNT�ε��������ڶ�û�����ӳɹ������������
����  ��
		sckidx��socket idx
����ֵ����
]]
function reconn(sckidx)
	local hidx = getclient(sckidx)
	print("reconn",tclients[hidx].sckreconncnt,tclients[hidx].sckconning,tclients[hidx].sckreconncyclecnt)
	--sckconning��ʾ���ڳ������Ӻ�̨��һ��Ҫ�жϴ˱����������п��ܷ��𲻱�Ҫ������������sckreconncnt���ӣ�ʵ�ʵ�������������
	if tclients[hidx].sckconning then return end
	--һ�����������ڵ�����
	if tclients[hidx].sckreconncnt < RECONN_MAX_CNT then		
		tclients[hidx].sckreconncnt = tclients[hidx].sckreconncnt+1
		socketssl.disconnect(sckidx,"RECONN")
		tclients[hidx].sckconning = true
	--һ���������ڵ�������ʧ��
	else
		tclients[hidx].sckreconncnt,tclients[hidx].sckreconncyclecnt = 0,tclients[hidx].sckreconncyclecnt+1
		if tclients[hidx].sckreconncyclecnt >= RECONN_CYCLE_MAX_CNT or not tclients[hidx].mode then
			if tclients[hidx].sckerrcb then
				tclients[hidx].sckreconncnt=0
				tclients[hidx].sckreconncyclecnt=0
				tclients[hidx].sckerrcb("CONNECT")
			else
				sys.restart("connect fail")
			end
		else
			for k,v in pairs(tclients) do
				socketssl.disconnect(v.sckidx,"RECONN")
				v.sckconning = true
			end
			link.shut()
		end		
	end
end

local function connectitem(hidx)
	local item = tclients[hidx]
	connect(item.sckidx,item.prot,item.host,item.port,item.crtconfig)
end

--[[
��������getnxtsnd
����  ����ȡ�´η��͵�������Ϣ
����  ��
        hidx��number���ͣ�http client idx
        sndidx��number���ͣ���ǰ�Ѿ����ͳɹ���������������0��ʼ��0��ʾͷ��������ֵ��ʾbody
		sndpos��number���ͣ���ǰ�Ѿ����ͳɹ�������������Ӧ���������ݵ�λ��
����ֵ��
		�������������Ҫ���ͣ����ؽ�Ҫ���͵��������ݣ���Ҫ���͵�������������Ҫ���͵�����������Ӧ���������ݵ�λ��
		���û��������Ҫ���ͣ�����""
]]
local function getnxtsnd(hidx,sndidx,sndpos)
	local item,idx = tclients[hidx]
	
	if type(item.body[sndidx])=="string" then
		if sndpos>=slen(item.body[sndidx]) then
			idx = sndidx+1
		else
			return ssub(item.body[sndidx],sndpos+1,sndpos+PACKET_LEN),sndidx,sndpos+PACKET_LEN
		end
	elseif type(item.body[sndidx])=="table" then
		if sndpos>=item.body[sndidx].len then
			idx = sndidx+1
		else
			return io.filedata(item.body[sndidx].file,sndpos,PACKET_LEN),sndidx,sndpos+PACKET_LEN
		end
	end
	
	if type(item.body[idx])=="string" then
		return ssub(item.body[idx],1,PACKET_LEN),idx,PACKET_LEN		
	elseif type(item.body[idx])=="table" then
		return io.filedata(item.body[idx].file,0,PACKET_LEN),idx,PACKET_LEN
	end
	
	return ""
end

--[[
��������ntfy
����  ��socket״̬�Ĵ�����
����  ��
        idx��number���ͣ�socket��ά����socket idx��������socketssl.connectʱ����ĵ�һ��������ͬ��������Ժ��Բ�����
        evt��string���ͣ���Ϣ�¼�����
		result�� bool���ͣ���Ϣ�¼������trueΪ�ɹ�������Ϊʧ��
		item��table���ͣ�{data=,para=}����Ϣ�ش��Ĳ��������ݣ�Ŀǰֻ����SEND���͵��¼����õ��˴˲������������socketssl.sendʱ����ĵ�2���͵�3�������ֱ�Ϊdat��par����item={data=dat,para=par}
����ֵ����
]]
function ntfy(idx,evt,result,item)
	local hidx = getclient(idx)
	print("ntfy",evt,result,item)
	--���ӽ��������socketssl.connect����첽�¼���
	if evt == "CONNECT" then
		tclients[hidx].sckconning = false
		--���ӳɹ�
		if result then
			tclients[hidx].sckconnected=true
			tclients[hidx].sckreconncnt=0
			tclients[hidx].sckreconncyclecnt=0
			--ֹͣ������ʱ��
			sys.timer_stop(reconn,idx)
			tclients[hidx].connectedcb()
		else
			--RECONN_PERIOD�������
			sys.timer_start(reconn,RECONN_PERIOD*1000,idx)
		end	
	--���ݷ��ͽ��������socketssl.send����첽�¼���
	elseif evt == "SEND" then
		if result then
			local sndata,sndIdx,sndPos = getnxtsnd(hidx,item.para.sndidx,item.para.sndpos)
			if sndata~="" then
				if not snd(idx,sndata,{sndidx=sndIdx,sndpos=sndPos}) then
					clrsndbody(hidx)
					if tclients[hidx].sckerrcb then tclients[hidx].sckerrcb("SEND") end
				end
			else
				sys.timer_start(timerfnc,30000,hidx)
			end
		else
			clrsndbody(hidx)
			if tclients[hidx].sckerrcb then
				tclients[hidx].sckreconncnt=0
				tclients[hidx].sckreconncyclecnt=0
				tclients[hidx].sckerrcb("SEND") 
			end
		end
	--���ӱ����Ͽ�
	elseif evt == "STATE" and result == "CLOSED" then
		tclients[hidx].sckconnected=false
		tclients[hidx].httpconnected=false
		tclients[hidx].sckconning = false
		--������ʱʹ��
		if tclients[hidx].mode then
			sys.timer_start(reconn,RECONN_PERIOD*1000,idx)
		end
	--���������Ͽ�������link.shut����첽�¼���
	elseif evt == "STATE" and result == "SHUTED" then
		tclients[hidx].sckconnected=false
		tclients[hidx].httpconnected=false
		tclients[hidx].sckconning = false
		--������ʱʹ��
		if tclients[hidx].mode then
			socketssl.disconnect(idx,"RECONN")
			tclients[hidx].sckconning = true
		end
	--���������Ͽ�������socketssl.disconnect����첽�¼���
	elseif evt == "DISCONNECT" then
		tclients[hidx].sckconnected=false
		tclients[hidx].httpconnected=false
		tclients[hidx].sckconning = false
		if item=="USER" then
			if tclients[hidx].discb then tclients[hidx].discb(idx) end
			tclients[hidx].discing = false
		end	
	--������ʱʹ��
		if tclients[hidx].mode or item=="RECONN" then
			connectitem(hidx)
		end
	--���������Ͽ��������٣�����socketssl.close����첽�¼���
	elseif evt == "CLOSE" then
		local cb = tclients[hidx].destroycb
		table.remove(tclients,hidx)
		if cb then cb() end
	end
	--�����������Ͽ�������·����������
	if smatch((type(result)=="string") and result or "","ERROR") then
		socketssl.disconnect(idx)
	end
end

local function resetpara(hidx,clrdata)
	tclients[hidx].statuscode=nil
	tclients[hidx].rcvhead=nil
	tclients[hidx].rcvbody,tclients[hidx].rcvLen=nil
	tclients[hidx].status=nil
	tclients[hidx].result=nil
	tclients[hidx].rcvChunked,tclients[hidx].chunkSize=nil
	tclients[hidx].filepath,tclients[hidx].filelen=nil
	if clrdata or clrdata==nil then tclients[hidx].rcvData="" end
end

--[[
��������timerfnc
���ܣ����������ݳ�ʱʱ������ʱ��
�������ͻ��˶�Ӧ��SOCKER��ID
����ֵ��
]]
function timerfnc(hidx)
	if tclients[hidx].filepath then os.remove(tclients[hidx].filepath) end
	if tclients[hidx].rcvcb then tclients[hidx].rcvcb(3) end
	resetpara(hidx)
end

--[[
�����������ݽ��մ�����
���ܣ������������ص����ݽ��д���
������idx���ͻ�������Ӧ�Ķ˿�ID data�����������ص�����
����ֵ����
]]
function rcv(idx,data)
	local hidx = getclient(idx)
	--����һ����ʱ����ʱ��Ϊ30��
	sys.timer_start(timerfnc,30000,hidx)
	
	if data and tclients[hidx].rcvcb then
		tclients[hidx].rcvData = (tclients[hidx].rcvData or "")..data
		local d1,d2,v1
		
		--״̬�к�ͷ
		if not tclients[hidx].statuscode then
			d1,d2 = sfind(tclients[hidx].rcvData,"\r\n\r\n")
			if not(d1 and d2) then print("wait heads complete") return end
			
			local heads,k,v = ssub(tclients[hidx].rcvData,1,d2)
			tclients[hidx].statuscode = smatch(heads,"%s(%d+)%s")
			local _,crlf = sfind(heads,"\r\n")
			heads = ssub(heads,crlf+1,-1)
			if not tclients[hidx].rcvhead then tclients[hidx].rcvhead={} end
			for k,v in sgmatch(heads,"(.-):%s*(.-)\r\n") do
				tclients[hidx].rcvhead[k] = v
				if (k=="Transfer-Encoding") and (v=="chunked") then tclients[hidx].rcvChunked = true end
				
			end
			if not tclients[hidx].rcvChunked then
				tclients[hidx].contentlen = tonumber(smatch(heads,"Content%-Length:%s*(%d+)\r\n"),10)
			end
			tclients[hidx].rcvData = ssub(tclients[hidx].rcvData,d2+1,-1)
		end
		
		--chunk���봫��(body)
		if tclients[hidx].rcvChunked then
			while true do
				if not tclients[hidx].chunkSize then
					d1,d2,v1 = sfind(tclients[hidx].rcvData,"(%x+)\r\n")
					--print(d1,d2,v1)
					if not v1 then print("wait chunk-size complete") return end
					tclients[hidx].chunkSize = tonumber(v1,16)
					tclients[hidx].rcvData = ssub(tclients[hidx].rcvData,d2+1,-1)
				end
				
				print("chunk-size",tclients[hidx].chunkSize,slen(tclients[hidx].rcvData))
				
				if slen(tclients[hidx].rcvData)<tclients[hidx].chunkSize+2 then print("wait chunk-data complete") return end
				if tclients[hidx].chunkSize>0 then
					local chunkData = ssub(tclients[hidx].rcvData,1,tclients[hidx].chunkSize)
					if tclients[hidx].filepath then	
						local f = io.open(tclients[hidx].filepath,"a+")
						f:write(chunkData)
						f:close()
					else
						tclients[hidx].rcvbody = (tclients[hidx].rcvbody or "")..chunkData
					end
				end

				tclients[hidx].rcvData = ssub(tclients[hidx].rcvData,tclients[hidx].chunkSize+3,-1)
				if tclients[hidx].chunkSize==0 then
					tclients[hidx].rcvcb(0,tclients[hidx].statuscode,tclients[hidx].rcvhead,tclients[hidx].filepath or tclients[hidx].rcvbody)
					sys.timer_stop(timerfnc,hidx)
					resetpara(hidx,false)
				else
					tclients[hidx].chunkSize = nil
				end
			end
		--Content-Length(body)
		else
			local rmnLen = tclients[hidx].contentlen-(tclients[hidx].rcvLen or 0)
			local sData = ssub(tclients[hidx].rcvData,1,rmnLen)
			tclients[hidx].rcvLen = (tclients[hidx].rcvLen or 0)+slen(sData)
			
			if tclients[hidx].filepath then
				local f = io.open(tclients[hidx].filepath,"a+")
				f:write(sData)
				f:close()
			else
				tclients[hidx].rcvbody = (tclients[hidx].rcvbody or "")..sData
			end

			tclients[hidx].rcvData = ssub(tclients[hidx].rcvData,rmnLen+1,-1)			
			if tclients[hidx].rcvLen==tclients[hidx].contentlen then
				tclients[hidx].rcvcb(0,tclients[hidx].statuscode,tclients[hidx].rcvhead,tclients[hidx].filepath or tclients[hidx].rcvbody)
				sys.timer_stop(timerfnc,hidx)
				resetpara(hidx,false)
			end
		end
	end
end


--[[
��������connect
����  ����������̨��������socket���ӣ�
        ������������Ѿ�׼���ã���������Ӻ�̨��������������ᱻ���𣬵���������׼���������Զ�ȥ���Ӻ�̨
		ntfy��socket״̬�Ĵ�����
		rcv��socket�������ݵĴ�����
����  ��
		sckidx��socket idx
		prot��string���ͣ������Э�飬��֧��"TCP"
		host��string���ͣ���������ַ��֧��������IP��ַ[��ѡ]
		port��number���ͣ��������˿�[��ѡ]
		crtconfig��nil����table���ͣ�{verifysvrcerts={"filepath1","filepath2",...},clientcert="filepath",clientcertpswd="password",clientkey="filepath"}
����ֵ����
]]
function connect(sckidx,prot,host,port,crtconfig)
	socketssl.connect(sckidx,prot,host,port,ntfy,rcv,crtconfig and crtconfig.verifysvrcerts,crtconfig)
	tclients[getclient(sckidx)].sckconning=true
end


--����Ԫ��ʱ����
local thttp = {}
thttp.__index = thttp

--[[
��������create
����  ������һ��http client
����  ��
		prot��string���ͣ������Э�飬��֧��"TCP"
		host��string���ͣ���������ַ��֧��������IP��ַ[��ѡ]
		port��number���ͣ��������˿�[��ѡ]
����ֵ����
]]
function create(host,port)
	if #tclients>=2 then assert(false,"tclients maxcnt error") return end
	local http_client =
	{
		prot="TCP",
		host=host,
		port=port or 443,		
		sckidx=socketssl.SCK_MAX_CNT-#tclients-2,
		sckconning=false,
		sckconnected=false,
		sckreconncnt=0,
		sckreconncyclecnt=0,
		httpconnected=false,
		discing=false,
		status=false,
		rcvbody=nil,
		rcvhead={},
		result=nil,
		statuscode=nil,
		contentlen=nil
	}
	setmetatable(http_client,thttp)
	table.insert(tclients,http_client)
	return(http_client)
end

--[[
��������configcrt
����  ������֤��
����  ��
		crtconfig��nil����table���ͣ�{verifysvrcerts={"filepath1","filepath2",...},clientcert="filepath",clientcertpswd="password",clientkey="filepath"}
����ֵ���ɹ�����true��ʧ�ܷ���nil
]]
function thttp:configcrt(crtconfig)
	self.crtconfig=crtconfig
	return true
end

--[[
��������connect
����  ������http������
����  ��
        connectedcb:function���ͣ�socket connected �ɹ��ص�����	
		sckerrcb��function���ͣ�socket����ʧ�ܵĻص�����[��ѡ]
����ֵ����
]]
function thttp:connect(connectedcb,sckerrcb)
	self.connectedcb=connectedcb
	self.sckerrcb=sckerrcb
	
	tclients[getclient(self.sckidx)]=self
	
	if self.httpconnected then print("thttp:connect already connected") return end
	if not self.sckconnected then
		connect(self.sckidx,self.prot,self.host,self.port,self.crtconfig) 
    end
end

--[[
��������setconnectionmode
���ܣ���������ģʽ�������ӻ��Ƕ�����
������v��trueΪ�����ӣ�falseΪ������
���أ�
]]
function thttp:setconnectionmode(v)
	self.mode=v
end

--[[
��������disconnect
����  ���Ͽ�һ��http client�����ҶϿ�socket
����  ��
		discb��function���ͣ��Ͽ���Ļص�����[��ѡ]
����ֵ����
]]
function thttp:disconnect(discb)
	print("thttp:disconnect")
	self.discb=discb
	self.discing = true
	socketssl.disconnect(self.sckidx,"USER")
end

--[[
��������destroy
����  ������һ��http client
����  ��
		destroycb��function���ͣ�mqtt client���ٺ�Ļص�����[��ѡ]
����ֵ����
]]
function thttp:destroy(destroycb)
	local k,v
	self.destroycb = destroycb
	for k,v in pairs(tclients) do
		if v.sckidx==self.sckidx then
			socketssl.close(v.sckidx)
		end
	end
end

function clrsndbody(hidx)	
	local i=0
	while tclients[hidx].body[i] do
		if type(tclients[hidx].body[i])=="table" then
			tclients[hidx].body[i] = nil
		end
		i = i+1
	end
	tclients[hidx].body=nil
end

 
--[[
��������request
����  ������HTTP����
����  ��
        cmdtyp��string���ͣ�HTTP�����󷽷���"GET"��"POST"����"HEAD"	
		url��string���ͣ�HTTP�������е�URL�ֶ�
		head��nil��""����table���ͣ�HTTP������ͷ��lib��Ĭ��Ϊ�Զ����Connection��Host����ͷ
			�����Ҫ�����������ͷ������������table���ͼ��ɣ���ʽΪ{"head1: value1","head2: value2",...}
        body��HTTP������ʵ��,nil��""����string���ͻ���table����
			Ϊtable����ʱ������Ϊnumber���ͣ���1��ʼ������������Ӧ�����ݣ���һ���з��ͣ�����
			{
				[1]="begin",
				[2]={file="/ldata/post.jpg"},
				[3]="end"
			}
			�ȷ����ַ���begin��Ȼ�����ļ�"/ldata/post.jpg"�����ݣ�������ַ���end
		rcvcb��function���ͣ�Ӧ��ʵ������ݻص�����
		filepath��string���ͣ�Ӧ��ʵ������ݱ���Ϊ�ļ���·��������"download.bin"��[��ѡ]
����ֵ����
]]
function thttp:request(cmdtyp,url,head,body,rcvcb,filepath)
	local headstr="" 
	--Ĭ�ϴ��ͷ�ʽΪ"GET"
	self.cmdtyp=cmdtyp or "GET"
	--Ĭ��Ϊ��Ŀ¼
	self.url=url or "/"
	--Ĭ��ʵ��Ϊ��
	self.head={}
	self.body=body or ""
	self.rcvcb=rcvcb
	
	--�ع�body����
	if type(self.body)=="string" then
		--self.body = {len=slen(self.body), sndidx=1, sndpos=0, [1]=self.body}
		self.body = {[1]=self.body}
	end
	local bodylen,i = 0,1
	--����body�ܳ���
	while self.body[i] do
		if type(self.body[i])=="string" then
			bodylen = bodylen+slen(self.body[i])
		elseif type(self.body[i])=="table" then			
			self.body[i].len = io.filesize(self.body[i].file)
			bodylen = bodylen+self.body[i].len
		else
			assert(false,"unsupport body type")
		end
		i = i+1
	end
	self.body.len = bodylen
	
	if filepath then
		self.filepath = (ssub(filepath,1,1)~="/" and "/" or "")..filepath
		if ssub(filepath,1,1)~="/" and rtos.make_dir and rtos.make_dir("/http_down") then self.filepath = "/http_down"..self.filepath end
	end

	if not head or head=="" or (type(head)=="table" and #head==0) then
		self.head={"Connection: keep-alive", "Host: "..self.host}
		if cmdtyp=="POST" and self.body~="" and self.body~=nil then
			table.insert(self.head,"Content-Length: "..self.body.len)
		end
	elseif type(head)=="table" and #head>0 then
		local connhead,hosthead,conlen,k,v
		for k,v in pairs(head) do
			if sfind(v,"Connection: ")==1 then connhead = true end
			if sfind(v,"Host: ")==1 then hosthead = true end
			if sfind(v,"Content-Length: ")==1 then conlen = true end
			table.insert(self.head,v)
		end
		if not hosthead then table.insert(self.head,1,"Host: "..self.host) end
		if not connhead then table.insert(self.head,1,"Connection: keep-alive") end
		if not conlen and cmdtyp=="POST" and self.body~="" and self.body~=nil then 
			table.insert(self.head,1,"Content-Length: "..self.body.len) 
		end
	else
		assert(false,"head format error")
	end
	
	headstr=cmdtyp.." "..self.url.." HTTP/1.1"..'\r\n'
	for k,v in pairs(self.head) do
		headstr=headstr..v..'\r\n'
	end
	headstr = headstr.."\r\n"
	self.body[0] = headstr
	local sndata,sndpara = headstr,{sndidx=0,sndpos=utils.min(PACKET_LEN,slen(headstr))}
	if type(self.body[1])=="string" and ((slen(self.body[1])+slen(headstr))<=PACKET_LEN) then 
		sndata = headstr..self.body[1]
		sndpara = {sndidx=1,sndpos=utils.min(PACKET_LEN,slen(self.body[1]))}
	end		
	if not snd(self.sckidx,sndata,sndpara) then
		clrsndbody(getclient(self.sckidx))
		if self.sckerrcb then self.sckerrcb("SEND") end
	end
end

--[[
��������getstatus
����  ����ȡHTTP CLIENT��״̬
����  ����
����ֵ��HTTP CLIENT��״̬��string���ͣ���3��״̬��
		DISCONNECTED��δ����״̬
		CONNECTING��������״̬
		CONNECTED������״̬
]]
function thttp:getstatus()
	if self.httpconnected then
		return "CONNECTED"
	elseif self.sckconnected or self.sckconning then
		return "CONNECTING"
	elseif self.disconnect then
		return "DISCONNECTED"
	end
end

