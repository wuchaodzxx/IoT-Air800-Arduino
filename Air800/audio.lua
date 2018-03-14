--[[
ģ�����ƣ���Ƶ����
ģ�鹦�ܣ�dtmf����롢tts����Ҫ�ײ����֧�֣�����Ƶ�ļ��Ĳ��ź�ֹͣ��¼����mic��speaker�Ŀ���
ģ������޸�ʱ�䣺2017.02.20
]]

--����ģ��,����������
local base = _G
local string = require"string"
local io = require"io"
local rtos = require"rtos"
local audio = require"audiocore"
local sys = require"sys"
local ril = require"ril"
module(...)

--���س��õ�ȫ�ֺ���������
local smatch = string.match
local print = base.print
local dispatch = sys.dispatch
local req = ril.request
local tonumber = base.tonumber
local assert = base.assert

--speakervol��speaker�����ȼ���ȡֵ��ΧΪaudio.VOL0��audio.VOL7��audio.VOL0Ϊ����
--audiochannel����Ƶͨ������Ӳ������йأ��û�������Ҫ����Ӳ������
--microphonevol��mic�����ȼ���ȡֵ��ΧΪaudio.MIC_VOL0��audio.MIC_VOL15��audio.MIC_VOL0Ϊ����
local speakervol,audiochannel,microphonevol = audio.VOL4,audio.HANDSET,audio.MIC_VOL15
local ttscause
--��Ƶ�ļ�·��
local playname

--[[
��������print
����  ����ӡ�ӿڣ����ļ��е����д�ӡ�������audioǰ׺
����  ����
����ֵ����
]]
local function print(...)
	base.print("audio",...)
end

--[[
��������playtts
����  ������tts
����  ��
		text���ַ���
		path��"net"��ʾ���粥�ţ�����ֵ��ʾ���ز���
����ֵ��true
]]
local function playtts(text,path)
	local action = path == "net" and 4 or 2

	req("AT+QTTS=1")
	req(string.format("AT+QTTS=%d,\"%s\"",action,text))
	return true
end

--[[
��������stoptts
����  ��ֹͣ����tts
����  ����
����ֵ����
]]
local function stoptts()
	req("AT+QTTS=3")
end

--[[
��������closetts
����  ���ر�tts����
����  ��
		cause���ر�ԭ��
����ֵ����
]]
local function closetts(cause)
	ttscause = cause
	req("AT+QTTS=0")
end

--[[
��������beginrecord
����  ����ʼ¼��
����  ��
		id��¼��id����������id�洢¼���ļ���ȡֵ��Χ0-4
		duration��¼��ʱ������λ����
����ֵ��true
]]
function beginrecord(id,duration)
	req(string.format("AT+AUDREC=0,0,1," .. id .. "," .. duration))
	return true
end

--[[
��������endrecord
����  ������¼��
����  ��
		id��¼��id����������id�洢¼���ļ���ȡֵ��Χ0-4
		duration��¼��ʱ������λ����
����ֵ��true
]]
function endrecord(id,duration)
	req(string.format("AT+AUDREC=0,0,0," .. id .. "," .. duration))
	return true
end

--[[
��������delrecord
����  ��ɾ��¼���ļ�
����  ��
		id��¼��id����������id�洢¼���ļ���ȡֵ��Χ0-4
		duration��¼��ʱ������λ����
����ֵ��true
]]
function delrecord(id,duration)
	req(string.format("AT+AUDREC=0,0,4," .. id .. "," .. duration))
	return true
end

--[[
��������playrecord
����  ������¼���ļ�
����  ��
		dl��ģ�����У��������ֱ������ȣ��Ƿ��������¼�����ŵ�������true����������false����nil������
		loop���Ƿ�ѭ�����ţ�trueΪѭ����false����nilΪ��ѭ��
		id��¼��id����������id�洢¼���ļ���ȡֵ��Χ0-4
		duration��¼��ʱ������λ����
����ֵ��true
]]
local function playrecord(dl,loop,id,duration)
	req(string.format("AT+AUDREC=" .. (dl and 1 or 0) .. "," .. (loop and 1 or 0) .. ",2," .. id .. "," .. duration))
	return true
end

--[[
��������stoprecord
����  ��ֹͣ����¼���ļ�
����  ��
		dl��ģ�����У��������ֱ������ȣ��Ƿ��������¼�����ŵ�������true����������false����nil������
		loop���Ƿ�ѭ�����ţ�trueΪѭ����false����nilΪ��ѭ��
		id��¼��id����������id�洢¼���ļ���ȡֵ��Χ0-4
		duration��¼��ʱ������λ����
����ֵ��true
]]
local function stoprecord(dl,loop,id,duration)
	req(string.format("AT+AUDREC=" .. (dl and 1 or 0) .. "," .. (loop and 1 or 0) .. ",3," .. id .. "," .. duration))
	return true
end

--[[
��������_play
����  ��������Ƶ�ļ�
����  ��
		name����Ƶ�ļ�·��
		loop���Ƿ�ѭ�����ţ�trueΪѭ����false����nilΪ��ѭ��
����ֵ�����ò��Žӿ��Ƿ�ɹ���trueΪ�ɹ���falseΪʧ��
]]
local function _play(name,loop)
	if loop then playname = name end
	return audio.play(name)
end

--[[
��������_stop
����  ��ֹͣ������Ƶ�ļ�
����  ����
����ֵ������ֹͣ���Žӿ��Ƿ�ɹ���trueΪ�ɹ���falseΪʧ��
]]
local function _stop()
	playname = nil
	return audio.stop()
end

--[[
��������audiourc
����  ��������ģ���ڡ�ע��ĵײ�coreͨ�����⴮�������ϱ���֪ͨ���Ĵ���
����  ��
		data��֪ͨ�������ַ�����Ϣ
		prefix��֪ͨ��ǰ׺
����ֵ����
]]
local function audiourc(data,prefix)	
	--¼������¼�����Ź���
	if prefix == "+AUDREC" then
		local action,duration = string.match(data,"(%d),(%d+)")
		if action and duration then
			duration = base.tonumber(duration)
			--��ʼ¼��
			if action == "1" then
				dispatch("AUDIO_RECORD_IND",(duration > 0 and true or false),duration)
			--����¼��
			elseif action == "2" then
				if duration > 0 then
					playend()
				else
					playerr()
				end
			--ɾ��¼��
			--[[elseif action == "4" then
				dispatch("AUDIO_RECORD_IND",true,duration)]]
			end
		end
	--tts����
	elseif prefix == "+QTTS" then
		local flag = string.match(data,": *(%d)",string.len(prefix)+1)
		--ֹͣ����tts
		if flag == "0" --[[or flag == "1"]] then
			playend()
		end	
	end
end

--[[
��������audiorsp
����  ��������ģ���ڡ�ͨ�����⴮�ڷ��͵��ײ�core�����AT�����Ӧ����
����  ��
		cmd����Ӧ���Ӧ��AT����
		success��AT����ִ�н����true����false
		response��AT�����Ӧ���е�ִ�н���ַ���
		intermediate��AT�����Ӧ���е��м���Ϣ
����ֵ����
]]
local function audiorsp(cmd,success,response,intermediate)
	local prefix = smatch(cmd,"AT(%+%u+%?*)")

	--¼�����߲���¼��ȷ��Ӧ��
	if prefix == "+AUDREC" then
		local action = smatch(cmd,"AUDREC=%d,%d,(%d)")		
		if action=="1" then
			dispatch("AUDIO_RECORD_CNF",success)
		elseif action=="3" then
			recordstopind()
		end
	--����tts���߹ر�ttsӦ��
	elseif prefix == "+QTTS" then
		local action = smatch(cmd,"QTTS=(%d)")
		if not success then
			if action == "1" or action == "2" then
				playerr()
			end
		else
			if action == "0" then
				dispatch("TTS_CLOSE_IND",ttscause)
			end
		end
		if action=="3" then
			ttstopind()
		end
	end
end

--ע������֪ͨ�Ĵ�����
ril.regurc("+AUDREC",audiourc)
ril.regurc("+QTTS",audiourc)
--ע������AT�����Ӧ������
ril.regrsp("+AUDREC",audiorsp,0)
ril.regrsp("+QTTS",audiorsp,0)

--[[
��������setspeakervol
����  ��������Ƶͨ�����������
����  ��
		vol�������ȼ���ȡֵ��ΧΪaudiocore.VOL0��audiocore.VOL7��audiocore.VOL0Ϊ����
����ֵ����
]]
function setspeakervol(vol)
	audio.setvol(vol)
	speakervol = vol
end

--[[
��������getspeakervol
����  ����ȡ��Ƶͨ�����������
����  ����
����ֵ�������ȼ�
]]
function getspeakervol()
	return speakervol
end

--[[
��������setaudiochannel
����  ��������Ƶͨ��
����  ��
		channel����Ƶͨ������Ӳ������йأ��û�������Ҫ����Ӳ�����ã�Ŀǰ��ģ���֧��audiocore.LOUDSPEAKER
����ֵ����
]]
local function setaudiochannel(channel)
	audio.setchannel(channel)
	audiochannel = channel
end

--[[
��������getaudiochannel
����  ����ȡ��Ƶͨ��
����  ����
����ֵ����Ƶͨ��
]]
local function getaudiochannel()
	return audiochannel
end

--[[
��������setloopback
����  �����ûػ�����
����  ��
		flag���Ƿ�򿪻ػ����ԣ�trueΪ�򿪣�falseΪ�ر�
		typ�����Իػ�����Ƶͨ������Ӳ������йأ��û�������Ҫ����Ӳ������
		setvol���Ƿ����������������trueΪ���ã�false������
		vol�����������
����ֵ��true���óɹ���false����ʧ��
]]
function setloopback(flag,typ,setvol,vol)
	return audio.setloopback(flag,typ,setvol,vol)
end

--[[
��������setmicrophonegain
����  ������MIC������
����  ��
		vol��mic�����ȼ���ȡֵ��ΧΪaudio.MIC_VOL0��audio.MIC_VOL15��audio.MIC_VOL0Ϊ����
����ֵ����
]]
function setmicrophonegain(vol)
	audio.setmicvol(vol)
	microphonevol = vol
end

--[[
��������getmicrophonegain
����  ����ȡMIC�������ȼ�
����  ����
����ֵ�������ȼ�
]]
function getmicrophonegain()
	return microphonevol
end

--[[
��������audiomsg
����  ������ײ��ϱ���rtos.MSG_AUDIO�ⲿ��Ϣ
����  ��
		msg��play_end_ind���Ƿ��������Ž���
		     play_error_ind���Ƿ񲥷Ŵ���
����ֵ����
]]
local function audiomsg(msg)
	if msg.play_end_ind == true then
		if playname then audio.play(playname) return end
		playend()
	elseif msg.play_error_ind == true then
		if playname then playname = nil end
		playerr()
	end
end

--ע��ײ��ϱ���rtos.MSG_AUDIO�ⲿ��Ϣ�Ĵ�����
sys.regmsg(rtos.MSG_AUDIO,audiomsg)
--Ĭ����Ƶͨ������ΪLOUDSPEAKER����ΪĿǰ��ģ��ֻ֧��LOUDSPEAKERͨ��
setaudiochannel(audio.LOUDSPEAKER)
--Ĭ�������ȼ�����Ϊ4����4�����м�ȼ������Ϊ0�������Ϊ7��
setspeakervol(audio.VOL4)
--Ĭ��MIC�����ȼ�����Ϊ1�������Ϊ0�������Ϊ15��
setmicrophonegain(audio.MIC_VOL1)


--spriority����ǰ���ŵ���Ƶ���ȼ�
--styp����ǰ���ŵ���Ƶ����
--spath����ǰ���ŵ���Ƶ�ļ�·��
--svol����ǰ��������
--scb����ǰ���Ž������߳���Ļص�����
--sdup����ǰ���ŵ���Ƶ�Ƿ���Ҫ�ظ�����
--sduprd�����sdupΪtrue����ֵ��ʾ�ظ����ŵļ��(��λ����)��Ĭ���޼��
--spending����Ҫ���ŵ���Ƶ�Ƿ���Ҫ���ڲ��ŵ���Ƶ�첽�������ٲ���
--sstrategy�����ȼ���ͬʱ�Ĳ��Ų��ԣ�0(��ʾ�����������ڲ��ŵ���Ƶ���������󲥷ŵ�����Ƶ)��1(��ʾֹͣ���ڲ��ŵ���Ƶ���������󲥷ŵ�����Ƶ)
local spriority,styp,spath,svol,scb,sdup,sduprd,sstrategy

--[[
��������playbegin
����  ���ر��ϴβ��ź��ٲ��ű�������
����  ��
		priority����Ƶ���ȼ�����ֵԽС�����ȼ�Խ��
		typ����Ƶ���ͣ�Ŀǰ��֧��"FILE"��"TTS"��"TTSCC"��"RECORD"
		path����Ƶ�ļ�·��
		vol������������ȡֵ��Χaudiocore.VOL0��audiocore.VOL7���˲�����ѡ
		cb����Ƶ���Ž������߳���ʱ�Ļص��������ص�ʱ����һ��������0��ʾ���ųɹ�������1��ʾ���ų���2��ʾ�������ȼ�������û�в��š��˲�����ѡ
		dup���Ƿ�ѭ�����ţ�trueѭ����false����nil��ѭ�����˲�����ѡ
		duprd�����ż��(��λ����)��dupΪtrueʱ����ֵ�������塣�˲�����ѡ
����ֵ�����óɹ�����true�����򷵻�nil
]]
local function playbegin(priority,typ,path,vol,cb,dup,duprd)
	print("playbegin")
	--���¸�ֵ��ǰ���Ų���
	spriority,styp,spath,svol,scb,sdup,sduprd,spending = priority,typ,path,vol,cb,dup,duprd

	--�������������������������
	if vol then
		setspeakervol(vol)
    end
	
	--���ò��Žӿڳɹ�
	if (typ=="TTS" and playtts(path))
		or (typ=="TTSCC" and playtts(path,"net"))
		or (typ=="RECORD" and playrecord(true,false,tonumber(smatch(path,"(%d+)&")),tonumber(smatch(path,"&(%d+)"))))
		or (typ=="FILE" and _play(path,dup and (not duprd or duprd==0))) then
		return true
	--���ò��Žӿ�ʧ��
	else
		spriority,styp,spath,svol,scb,sdup,sduprd,spending = nil
	end
end

--[[
��������setstrategy
����  ���������ȼ���ͬʱ�Ĳ��Ų���
����  ��
		strategy�����ȼ���ͬʱ�Ĳ��Ų���
				0����ʾ�����������ڲ��ŵ���Ƶ���������󲥷ŵ�����Ƶ
				1����ʾֹͣ���ڲ��ŵ���Ƶ���������󲥷ŵ�����Ƶ
����ֵ����
]]
function setstrategy(strategy)
	sstrategy=strategy
end

--[[
��������play
����  ��������Ƶ
����  ��
		priority��number���ͣ���ѡ��������Ƶ���ȼ�����ֵԽ�����ȼ�Խ��
		typ��string���ͣ���ѡ��������Ƶ���ͣ�Ŀǰ��֧��"FILE"��"TTS"��"TTSCC"��"RECORD"
		path����ѡ��������Ƶ�ļ�·������typ�йأ�
		      typΪ"FILE"ʱ��string���ͣ���ʾ��Ƶ�ļ�·��
			  typΪ"TTS"ʱ��string���ͣ���ʾҪ�������ݵ�UCS2ʮ�������ַ���
			  typΪ"TTSCC"ʱ��string���ͣ���ʾҪ���Ÿ�ͨ���Զ����ݵ�UCS2ʮ�������ַ���
			  typΪ"RECORD"ʱ��string���ͣ���ʾ¼��ID&¼��ʱ�������룩
		vol��number���ͣ���ѡ����������������ȡֵ��Χaudiocore.VOL0��audiocore.VOL7
		cb��function���ͣ���ѡ��������Ƶ���Ž������߳���ʱ�Ļص��������ص�ʱ����һ��������0��ʾ���ųɹ�������1��ʾ���ų���2��ʾ�������ȼ�������û�в���
		dup��bool���ͣ���ѡ�������Ƿ�ѭ�����ţ�trueѭ����false����nil��ѭ��
		duprd��number���ͣ���ѡ���������ż��(��λ����)��dupΪtrueʱ����ֵ��������
����ֵ�����óɹ�����true�����򷵻�nil
]]
function play(priority,typ,path,vol,cb,dup,duprd)
	assert(priority and typ,"play para err")
	print("play",priority,typ,path,vol,cb,dup,duprd,styp)
	--����Ƶ���ڲ���
	if styp then
		--��Ҫ���ŵ���Ƶ���ȼ� ���� ���ڲ��ŵ���Ƶ���ȼ�
		if priority > spriority or (sstrategy==1 and priority==spriority) then
			--������ڲ��ŵ���Ƶ�лص���������ִ�лص����������2
			if scb then scb(2) end
			--ֹͣ���ڲ��ŵ���Ƶ
			if not stop() then
				spriority,styp,spath,svol,scb,sdup,sduprd,spending = priority,typ,path,vol,cb,dup,duprd,true
				return
			end
		--��Ҫ���ŵ���Ƶ���ȼ� ���� ���ڲ��ŵ���Ƶ���ȼ�
		elseif priority < spriority or (sstrategy~=1 and priority==spriority) then
			if not sdup then return	end	
		end
	end

	playbegin(priority,typ,path,vol,cb,dup,duprd)
end

--[[
��������stop
����  ��ֹͣ��Ƶ����
����  ����
����ֵ��������Գɹ�ͬ��ֹͣ������true�����򷵻�nil
]]
function stop()
	if styp then
		local typ,path = styp,spath		
		spriority,styp,spath,svol,scb,sdup,sduprd,spending = nil
		--ֹͣѭ�����Ŷ�ʱ��
		sys.timer_stop_all(play)
		--ֹͣ��Ƶ����
		_stop()
		if typ=="TTS" or typ=="TTSCC" then stoptts() return end
		if typ=="RECORD" then stoprecord(true,false,tonumber(smatch(path,"(%d+)&")),tonumber(smatch(path,"&(%d+)"))) return end
	end
	return true
end

--[[
��������playend
����  ����Ƶ���ųɹ�����������
����  ����
����ֵ����
]]
function playend()
	print("playend",sdup,sduprd)
	if (styp=="TTS" or styp=="TTSCC") and not sdup then stoptts() end
	if styp=="RECORD" and not sdup then stoprecord(true,false,tonumber(smatch(spath,"(%d+)&")),tonumber(smatch(spath,"&(%d+)"))) end
	--��Ҫ�ظ�����
	if sdup then
		--�����ظ����ż��
		if sduprd then
			sys.timer_start(play,sduprd,spriority,styp,spath,svol,scb,sdup,sduprd)
		--�������ظ����ż��
		elseif styp=="TTS" or styp=="TTSCC" or styp=="RECORD" then
			play(spriority,styp,spath,svol,scb,sdup,sduprd)
		end
	--����Ҫ�ظ�����
	else
		--������ڲ��ŵ���Ƶ�лص���������ִ�лص����������0
		if scb then scb(0) end
		spriority,styp,spath,svol,scb,sdup,sduprd,spending = nil
	end
end

--[[
��������playerr
����  ����Ƶ����ʧ�ܴ�����
����  ����
����ֵ����
]]
function playerr()
	print("playerr")
	if styp=="TTS" or styp=="TTSCC" then stoptts() end
	if styp=="RECORD" then stoprecord(true,false,tonumber(smatch(spath,"(%d+)&")),tonumber(smatch(spath,"&(%d+)"))) end
	--������ڲ��ŵ���Ƶ�лص���������ִ�лص����������1
	if scb then scb(1) end
	spriority,styp,spath,svol,scb,sdup,sduprd,spending = nil
end

local stopreqcb
--[[
��������audstopreq
����  ��lib�ű��䷢����ϢAUDIO_STOP_REQ�Ĵ�����
����  ��
		cb����Ƶֹͣ��Ļص�����
����ֵ����
]]
local function audstopreq(cb)
	if stop() and cb then cb() return end
	stopreqcb = cb
end

--[[
��������ttstopind
����  ������stoptts()�ӿں�ttsֹͣ���ź����Ϣ������
����  ����
����ֵ����
]]
function ttstopind()
	print("ttstopind",spending,stopreqcb)
	if stopreqcb then
		stopreqcb()
		stopreqcb = nil
	elseif spending then
		playbegin(spriority,styp,spath,svol,scb,sdup,sduprd)
	end
end

--[[
��������recordstopind
����  ������stoprecord()�ӿں�recordֹͣ���ź����Ϣ������
����  ����
����ֵ����
]]
function recordstopind()
	print("recordstopind",spending,stopreqcb)
	if stopreqcb then
		stopreqcb()
		stopreqcb = nil
	elseif spending then
		playbegin(spriority,styp,spath,svol,scb,sdup,sduprd)
	end
end

local procer =
{
	AUDIO_STOP_REQ = audstopreq,--lib�ű���ͨ��������Ϣ��ʵ����Ƶֹͣ���û��ű���Ҫ���ʹ���Ϣ
}
--ע����Ϣ��������
sys.regapp(procer)
