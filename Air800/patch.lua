--[[
ģ�����ƣ�Lua�Դ��ӿڲ���
ģ�鹦�ܣ�����ĳЩLua�Դ��Ľӿڣ���ܵ����쳣ʱ����
ģ������޸�ʱ�䣺2017.02.14
]]

--����Lua�Դ���os.time�ӿ�
local oldostime = os.time

--[[
��������safeostime
����  ����װ�Զ����os.time�ӿ�
����  ��
		t�����ڱ����û�д��룬ʹ��ϵͳ��ǰʱ��
����ֵ��tʱ�����1970��1��1��0ʱ0��0��������������
]]
function safeostime(t)
	return oldostime(t) or 0
end

--Lua�Դ���os.time�ӿ�ָ���Զ����safeostime�ӿ�
os.time = safeostime

--����Lua�Դ���os.date�ӿ�
local oldosdate = os.date

--[[
��������safeosdate
����  ����װ�Զ����os.date�ӿ�
����  ��
		s�������ʽ
		t������1970��1��1��0ʱ0��0��������������
����ֵ���ο�Lua�Դ���os.date�ӿ�˵��
]]
function safeosdate(s,t)
    if s == "*t" then
        return oldosdate(s,t) or {year = 2012,
                month = 12,
                day = 11,
                hour = 10,
                min = 9,
                sec = 0}
    else
        return oldosdate(s,t)
    end
end

--Lua�Դ���os.date�ӿ�ָ���Զ����safeosdate�ӿ�
os.date = safeosdate

--����Lua�Դ���json.decode�ӿ�
if json and json.decode then oldjsondecode = json.decode end

--[[
��������safejsondecode
����  ����װ�Զ����json.decode�ӿ�
����  ��
		s��json��ʽ���ַ���
����ֵ��
		��һ������ֵΪ����json�ַ������table
		�ڶ�������ֵΪ�������(true��ʾ�ɹ���falseʧ��)
		����������ֵ��ѡ��ֻ�еڶ�������ֵΪfalseʱ���������壩����ʾ������Ϣ
]]
function safejsondecode(s)
	local result,info = pcall(oldjsondecode,s)
	if result then
		return info,true
	else
		return {},false,info
	end
end

--Lua�Դ���json.decode�ӿ�ָ���Զ����safejsondecode�ӿ�
if json and json.decode then json.decode = safejsondecode end

