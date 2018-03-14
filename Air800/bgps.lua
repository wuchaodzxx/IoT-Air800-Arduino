module(...,package.seeall)

--[[
ģ�����ƣ���GPSӦ�á�����
ģ�鹦�ܣ�����gps.lua�Ľӿ�
ģ������޸�ʱ�䣺2017.02.16
]]

require"gps"
require"agps"
require"lbsloc"

--blat����   blngγ��
blng = ""
blat = ""

--[[
��������print
����  ����ӡ�ӿڣ����ļ��е����д�ӡ�������testǰ׺
����  ����
����ֵ����
]]
local function print(...)
  _G.print("bgps",...)
end

--[[
�ж��Ƿ�λ�ɹ�  gps.isfix()
��ȡ��γ����Ϣ      gps.getgpslocation()
�ٶ� gps.getgpsspd()
����� gps.getgpscog()
���� gps.getaltitude()
]]

local function test1cb(cause)
  print("test1cb",cause,gps.isfix(),gps.getgpslocation(),gps.getgpsspd(),gps.getgpscog(),gps.getaltitude())
end

--[[
��������gpsOpen
���ܣ�����GPS
��������
����ֵ����
]]
local function gpsOpen()
    --Ĭ��ģʽ GPS�ͻ�һֱ��������Զ����ر�
   gps.open(gps.DEFAULT,{cause="TEST1",cb=test1cb})
end

--[[
��������qrygps
����  ����ѯGPSλ������
����  ����
����ֵ����
]]
local function qrygps()
  qryaddr = not qryaddr
  lbsloc.request(getgps,qryaddr)
end

--[[
��������getgps
����  ����ȡ��γ�Ⱥ�Ļص�����
����  ��
    result��number���ͣ���ȡ�����0��ʾ�ɹ��������ʾʧ�ܡ��˽��Ϊ0ʱ�����5��������������
    lat��string���ͣ�γ�ȣ���������3λ��С������7λ������031.2425864
    lng��string���ͣ����ȣ���������3λ��С������7λ������121.4736522
    addr��string���ͣ�GB2312�����λ���ַ���������lbsloc.request��ѯ��γ�ȣ�����ĵڶ�������Ϊtrueʱ���ŷ��ر�����
    latdm��string���ͣ�γ�ȣ��ȷָ�ʽ����������5λ��С������6λ��dddmm.mmmmmm������03114.555184
    lngdm��string���ͣ�γ�ȣ��ȷָ�ʽ����������5λ��С������6λ��dddmm.mmmmmm������12128.419132
����ֵ����
]]
function getgps(result,lat,lng,addr,latdm,lngdm)
  print("getgps",result,lat,lng,addr,latdm,lngdm)
  --��ȡ��γ�ȳɹ�
  if result==0 then
  --ʧ��
  else
  end
  blat = lat
  blng = lng
end

--[[
��������nemacb
����  ��NEMA���ݵĴ���ص�����
����  ��
    data��һ��NEMA����
����ֵ����
]]
local function nemacb(data)
  print("nemacb",data)
end

--[[
��������split
���ܣ��ָ��ַ���
������
    s�����ָ���ַ���
    sp���ָ��־
����ֵ��table���ͣ��ָ����ַ���    
]]
function split(s, sp)  
    local res = {}  
  
    local temp = s  
    local len = 0  
    while true do  
        len = string.find(temp, sp)  
        if len ~= nil then  
            local result = string.sub(temp, 1, len-1)  
            temp = string.sub(temp, len+1)  
            table.insert(res, result)  
        else  
            table.insert(res, temp)  
            break  
        end  
    end  
    return res  
end 

--[[
��������gpsGet
���ܣ���ȡGPSֵ�������λ�ɹ��͸�ֵ��blng��blat�����ʧ�ܾͻ�վ��λ
��������
����ֵ����
]]
local function gpsGet()
  if gps.isfix() == true then
     print("success",gps.isfix(),gps.getgpslocation(),gps.getgpsspd(),gps.getgpscog(),gps.getaltitude())
     local gpsStr = gps.getgpslocation()
     local temp = split(gpsStr,",")
     blng = temp[2]
     blat = temp[4]
  end
  if gps.isfix() == false then
    print("failed lbs")
    sys.timer_start(qrygps,100)
  end
  
end

--[[
��������returnBlat
���ܣ����ؾ���
��������
����ֵ����
]]
function returnBlat()
  return blat
end

--[[
��������returnBlng
���ܣ�����γ��
��������
����ֵ����
]]
function returnBlng()
  return blng
end

--[[
������gpsInit
���ܣ���ʼ��gps
��������
����ֵ����
]]
local function gpsInit()
  gps.init()
  --����GPS+BD��λ
  --��������ô˽ӿڣ�Ĭ��ҲΪGPS+BD��λ
  --�����GPS��λ����������Ϊ1
  --�����BD��λ����������Ϊ2
  gps.setfixmode(0)
  --���ý�gps.lua�ڲ�����NEMA����
  --��������ô˽ӿڣ�Ĭ��ҲΪ��gps.lua�ڲ�����NEMA����
  --���gps.lua�ڲ���������nema����ͨ���ص�����cb�ṩ���ⲿ��������������Ϊ1,nemacb
  --���gps.lua���ⲿ���򶼴�����������Ϊ2,nemacb
  gps.setnemamode(0)
  --�����ҪGPS��ʱ����ͬ��ģ��ʱ�䣬�����������ע�͵Ĵ���
  --gps.settimezone(gps.GPS_BEIJING_TIME)
  gpsOpen()
end

sys.timer_start(gpsInit,1000)
--ÿ��10s��ȡһ��gps����
sys.timer_loop_start(gpsGet,10000)

