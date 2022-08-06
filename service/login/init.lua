local skynet = require "skynet"
local s = require "service"

s.client = {} -- 客户端消息处理函数集合

-- 登录协议
s.client.login = function (fd, msg, source)
    skynet.error("login recv "..msg[1].." "..msg[2])
    return {"login", -1, "test"}
end

------------------------------------------------------------------------------------------------------------------------------------------------------
-- 远程调用接口
-- 客户端连接的某个gateway调用
-- @source: 消息发送方（某个gateway）
-- @cmd: 协议名
-- @msg: 协议对象
s.resp.client = function (source, fd, cmd, msg)
    if s.client[cmd] then
        local ret_msg = s.client[cmd](fd, msg, source) -- 处理协议
        skynet.send(source, "lua", "send_by_fd", fd, ret_msg) -- 返回给客户端
    else
        skynet.error("s.resp.client fail for not cmd[", cmd, "]")
    end
end
------------------------------------------------------------------------------------------------------------------------------------------------------

-- function s.init()
--     print("name = ", s.name)
--     print("id = ", s.id)
-- end

s.start(...)