local skynet = require "skynet"
local s = require "service"

s.client = {} -- 客户端消息处理函数集合

-- 登录协议
s.client.login = function (fd, msg, source)
    -- skynet.error("login recv "..msg[1].." "..msg[2])
    -- return {"login", -1, "test"}
    local playerid = tonumber(msg[2])
    local pw = tonumber(msg[3])
    local gate = source
    local node = skynet.getenv("node")

    -- 校验用户名密码
    -- todo
    if pw ~= 123 then
        return {"login", 1, "密码错误"}
    end

    -- 发送agentmgr
    local isok, agent = skynet.call("agentmgr", "lua", "reqlogin", playerid, node, gate)
    if not isok then
        return {"login", 1, "请求mgr失败"}
    end
    -- 回应gate
    isok = skynet.call(gate, "lua", "sure_agent", fd, playerid, agent)
    if not isok then
        return {"login", 1, "gate注册失败"}
    end
    skynet.error("login succ "..playerid)
    return {"login", 0, "登录成功"}
end

------------------------------------------------------------------------------------------------------------------------------------------------------
-- 远程调用接口
-- 客户端连接的某个gateway调用
-- @source: 消息发送方（某个gateway）
-- @cmd: 协议名
-- @msg: 协议对象
s.resp.client = function (source, fd, cmd, msg)
    if s.client[cmd] then
        -- skynet.error("login:cmd = ", cmd)
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