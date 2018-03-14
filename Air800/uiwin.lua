--[[
ģ�����ƣ�UI���ڹ���
ģ�鹦�ܣ����ڵ�������ɾ����ˢ�µ�
ģ������޸�ʱ�䣺2017.07.26
]]
local base = _G
local sys = require"sys"
local table = require"table"
local print,assert,type,ipairs = base.print,base.assert,base.type,base.ipairs
module(...)

--���ڹ���ջ
local stack = {}
--��ǰ����Ĵ���ID
local winid = 0

local function allocid()
	winid = winid + 1
	return winid
end

local function losefocus()
	if stack[#stack] and stack[#stack]["onlosefocus"] then
		stack[#stack]["onlosefocus"]()
	end	
end

--[[
��������add
����  ������һ������
����  ��
		wnd�����ڵ�Ԫ���Լ���Ϣ��������
����ֵ������ID
]]
function add(wnd)
	---����ע����½ӿ�
	assert(wnd.onupdate)
	if type(wnd) ~= "table" then
		assert("unknown uiwin type "..type(wnd))
	end
	--��һ������ִ��ʧȥ����Ĵ�����
	losefocus()
	--Ϊ�´��ڷ��䴰��ID
	wnd.id = allocid()
	--�´���������ջ
	sys.dispatch("UIWND_ADD",wnd)
	return wnd.id
end

--[[
��������remove
����  ���Ƴ�һ������
����  ��
		winid������ID
����ֵ����
]]
function remove(winid)
	sys.dispatch("UIWND_REMOVE",winid)
end

local function onadd(wnd)
	table.insert(stack,wnd)
	stack[#stack].onupdate()
end

local function onremove(winid)
	local istop,k,v
	for k,v in ipairs(stack) do
		if v.id == winid then
			istop = (k==#stack)
			table.remove(stack,k)
			if #stack~=0 and istop then
				stack[#stack].onupdate()
			end
			return
		end
	end
end

local function onupdate()
	stack[#stack].onupdate()
end

--[[
��������isactive
����  ���ж�һ�������Ƿ�����ǰ��ʾ
����  ��
		winid������ID
����ֵ��true��ʾ��ǰ��ʾ�������ʾ����ǰ��ʾ
]]
function isactive(winid)
	return stack[#stack].id==winid
end

 sys.regapp({
 	UIWND_ADD = onadd,
 	UIWND_REMOVE = onremove,
 	UIWND_UPDATE = onupdate,
 	UIWND_TOUCH = onTouch,
 	UIWND_KEY = onKey,
 })
