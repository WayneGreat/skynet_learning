local skynet = require "skynet"
local s = require "service"

-- 客户端协议处理
s.client = {}
-- 玩家对应gate服务
s.gate = nil

-- 数据加载
s.init = function()
    -- 加载角色数据
    -- todo
    skynet.sleep(200)
    s.data  = {
        coin = 100,
        hp = 200,
    }
end

-- 保存与退出
s.resp.kick = function(source)
    -- 保存角色数据
    -- todo
    skynet.sleep(200)
end

s.resp.exit = function(source)
    skynet.exit()
end

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

s.start(...)