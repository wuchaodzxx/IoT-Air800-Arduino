require"audio"
require"common"
module(...,package.seeall)

--[[
注意：因为官方例程使用的是GB2312编码，因此文本使用GB2312编码，调用common.gb2312toucs2(ttstr)，否则语音输出不对,如果使用utf-8,则使用common.utf8toucs2(ttstr)函数
]]
--[[
模块名称：“声音播放”测试
模块功能：测试caudio.lua的接口
模块最后修改时间：2017.02.16
]]

local function print(...)
    _G.print("audio test",...)
end

--[[
函数名：testplaytts
功能：播放声音
参数：无
返回值：无
]]
--local ttstr = "你好，这里是上海合宙通信科技有限公司，现在时刻18点30分"
function playtts(ttstr,priority)
	--循环播放，音量等级7，没有循环间隔(一次播放结束后，立即播放下一次)
  print("start speak: ")
  --play(priority,typ,path,vol,cb,dup,duprd)
  --[[
			priority：number类型，必选参数，音频优先级，数值越大，优先级越高
			typ：string类型，必选参数，音频类型，目前仅支持"FILE"、"TTS"、"TTSCC"、"RECORD"
			path：必选参数，音频文件路径，跟typ有关：
				  typ为"FILE"时：string类型，表示音频文件路径
				  typ为"TTS"时：string类型，表示要播放数据的UCS2十六进制字符串
				  typ为"TTSCC"时：string类型，表示要播放给通话对端数据的UCS2十六进制字符串
				  typ为"RECORD"时：string类型，表示录音ID&录音时长（毫秒）
			vol：number类型，可选参数，播放音量，取值范围audiocore.VOL0到audiocore.VOL7
			cb：function类型，可选参数，音频播放结束或者出错时的回调函数，回调时包含一个参数：0表示播放成功结束；1表示播放出错；2表示播放优先级不够，没有播放
			dup：bool类型，可选参数，是否循环播放，true循环，false或者nil不循环
			duprd：number类型，可选参数，播放间隔(单位毫秒)，dup为true时，此值才有意义
			common.binstohexs(common.gb2312toucs2(ttstr))
	]]
  audio.play(priority,"TTS",common.binstohexs(common.utf8toucs2(ttstr)),audiocore.VOL7,nil,false)
end

--sys.timer_start(playtts,5000)
