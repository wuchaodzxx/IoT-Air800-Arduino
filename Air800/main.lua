--��Ҫ���ѣ����������λ�ö���MODULE_TYPE��PROJECT��VERSION����
--MODULE_TYPE��ģ���ͺţ�Ŀǰ��֧��Air201��Air202��Air800
--PROJECT��ascii string���ͣ�������㶨�壬ֻҪ��ʹ��,����
--VERSION��ascii string���ͣ����ʹ��Luat������ƽ̨�̼������Ĺ��ܣ����밴��"X.X.X"���壬X��ʾ1λ���֣��������㶨��
MODULE_TYPE = "Air800"
PROJECT = "ONENET"
VERSION = "1.0.0"
PRODUCT_KEY = "FwzJ8KbRphW0OQKsjJOuARZVuelObwoj"
require"sys"
--[[
���ʹ��UART���trace��������ע�͵Ĵ���"--sys.opntrace(true,1)"���ɣ���2������1��ʾUART1���trace�������Լ�����Ҫ�޸��������
�����������������trace�ڵĵط�������д��������Ա�֤UART�ھ����ܵ�����������ͳ��ֵĴ�����Ϣ��
���д�ں��������λ�ã����п����޷����������Ϣ���Ӷ����ӵ����Ѷ�
]]
--sys.opntrace(true,0)
--require"common" --dht22ģ���õ���common.binstohexs�ӿ�
require"pm" --dht22ģ���õ���pm.wake�ӿ�
require"bgps"
require"bmqtt"
require"speak"
require"caudio"
if MODULE_TYPE=="Air201" then
require"wdt"
end

sys.init(0,0)
sys.run()
