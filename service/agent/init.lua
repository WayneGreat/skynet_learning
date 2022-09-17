local skynet = require "skynet"
local s = require "service"

-- 客户端协议处理
s.client = {}
-- 玩家对应gate服务
s.gate = nil

-- 在init.lua中引入（require）新增的文件，即可使用新文件提供的功能
require "scene"


-- 客户端work协议处理
s.client.work = function(msg)
    s.data.coin = s.data.coin + 1
    return {"work", s.data.coin}
end

------------------------------------------------------------------------------------------------------------------------------------------------------
-- 远程调用接口
-- 客户端登录成功后，经由gateway调用接口与agent通信
s.resp.client = function(source, cmd, msg)
    s.gate = source
    if s.client[cmd] then
        local ret_msg = s.client[cmd](msg, source)
        if ret_msg then
            skynet.send(source, "lua", "send", s.id, ret_msg) -- s.id即玩家id
        end
    else
        skynet.error("s.resp.client fail "..cmd)
    end
end

-- 保存与退出
s.resp.kick = function(source)
    -- 需要向场景服务请求退出
    s.leave_scene()
    -- 保存角色数据
    -- todo
    skynet.sleep(200)
end

s.resp.exit = function(source)
    skynet.exit()
end

-- scene调用给客户端发送消息
s.resp.send = function(source, msg)
    skynet.send(s.gate, "lua", "send", s.id, msg)
end

------------------------------------------------------------------------------------------------------------------------------------------------------
-- os.time() 得到是当前时间距离1970.1.1 08:00的秒数
local function get_day(timestamp)
    local day = (timestamp + 3600*8)/(3600*24)
    return math.ceil(day)
    
end

-- 数据加载
s.init = function()
    -- 加载角色数据
    -- todo
    skynet.sleep(200)
    s.data  = {
        coin = 100,
        hp = 200,
        last_login_time = 1663383297
    }
    -- 获取和更新登录时间
    local last_day = get_day(s.data.last_login_time)
    local day = get_day(os.time())
    s.data.last_login_time = os.time()
    -- 判断每天第一次登录
    if day > last_day then
        -- first_login_day()
    end
end

s.start(...)