--����ģ��,����������
local base = _G
local sys = require"sys"
local rtos = require"rtos"
module(...)

--[[
sta������״̬��IDLE��ʾ����״̬��PRESSED��ʾ�Ѱ���״̬��LONGPRESSED��ʾ�Ѿ�������״̬
longprd���������ж�ʱ����Ĭ��3�룻���´��ڵ���3���ٵ����ж�Ϊ�����������º���3���ڵ����ж�Ϊ�̰���
longcb��������������
shortcb���̰���������
]]
local sta,longprd,longcb,shortcb = "IDLE",3000

local function print(...)
	base.print("keypad",...)
end

local function longtimercb()
	print("longtimercb")
	sta = "LONGPRESSED"	
end

local function keymsg(msg)
	print("keymsg",msg.key_matrix_row,msg.key_matrix_col,msg.pressed)
	if msg.pressed then
		sta = "PRESSED"
		sys.timer_start(longtimercb,longprd)
	else
		sys.timer_stop(longtimercb)
		if sta=="PRESSED" then
			if shortcb then
				shortcb()
			end
		elseif sta=="LONGPRESSED" then
			if longcb then
				longcb()
			else
				rtos.poweroff()
			end
		end
		sta = "IDLE"
	end
end

--[[
��������setup
����  ������power key��������
����  ��
		keylongprd��number���ͻ���nil���������ж�ʱ������λ���룬�����nil��Ĭ��3000����
		keylongcb��function���ͻ���nil����������ʱ�Ļص����������Ϊnil��ʹ��Ĭ�ϵĴ����������Զ��ػ�
		keyshortcb��function���ͻ���nil���̰�����ʱ�Ļص�����
����ֵ����
]]
function setup(keylongprd,keylongcb,keyshortcb)
	longprd,longcb,shortcb = keylongprd or 3000,keylongcb,keyshortcb
end

sys.regmsg(rtos.MSG_KEYPAD,keymsg)
rtos.init_module(rtos.MOD_KEYPAD,0,0,0)
