local skynet = require "skynet"
local s = require "service"
local socket = require "skynet.socket"
local runconfig = require "runconfig"


-- 登录后，gateway可以做到双向查找：
    -- ·若客户端发送了消息，可由底层Socket获取连接标识fd。gateway则由fd索引到conn对象，再由playerid属性找到player对象，进而知道它的代理服务（agent）在哪里，并将消息转发给agent。
    -- ·若agent发来消息，只要附带着玩家id，gateway即可由playerid索引到gateplayer对象，进而通过conn属性找到对应的连接及其fd，向对应客户端发送消息。

conns = {} -- [fd] = conn
players = {} -- [playerid] = gateplayer

-- 每个gate服务的关闭连接入口标志
local closing =false

-- 连接类
function conn()
    local m = {
        fd = nil,
        playerid = nil,
    }
    return m
end

-- 玩家类
function gateplayer()
    local m = {
        playerid = nil,
        agent = nil,
        conn = nil,
        -- 重连时的身份标识
        key = math.random(1, 999999999),
        lost_conn_time = nil,
        msgcache = {} -- 客户端短暂掉线时，未发送的消息缓存
    }
    return m
end
------------------------------------------------------------------------------------------------------------------------------------------------------
-- 登出/掉线
local disconnect = function (fd)
    local c = conns[fd]
    if not c then
        return
    end

    local playerid = c.playerid
    -- 未完成登录
    if not playerid then
        return
    else
        -- 已在游戏中
        local gplayer = players[playerid]
        -- 当客户端掉线时，gateway不会去触发掉线请求（即向agentmgr请求reqkick）
        -- 掉线时仅仅取消玩家对象（gplayer）与旧连接（conn）的关联（即gplayer.conn = nil）
        -- 为防止客户端不再发起重连导致的资源占用，程序会开启一个定时器（skynet.timeout）
        -- 若5分钟后依然是掉线状态（if gplayer. conn ~= nil为假），则向agentmgr请求下线
        gplayer.conn = nil
        skynet.timeout(300 * 100, function ()
            if gplayer.conn ~= nil then
                return
            end
            skynet.call("agentmgr", "lua", "reqkick", playerid, "断线超时")
        end)
    end
end

-- 解码
local  str_unpack = function (msgstr)
    local msg = {}
    while true do
        local arg, rest = string.match(msgstr, "(.-),(.*)")
        if arg then
            msgstr = rest
            table.insert(msg, arg)
        else
            table.insert(msg, msgstr)
            break
        end
    end
    return msg[1], msg
end

-- 编码
local str_pack = function (cmd, msg)
    return table.concat(msg, ",").."\r\n"
end

-- 断线重连处理
local function process_reconnect(fd, msg)
    local playerid = tonumber(msg[2])
    local key = tonumber(msg[3])

    local conn = conns[fd]
    if not conn then
        -- 客户端与服务器未通信
        skynet.error("reconnect fail, conn not exist")
        return
    end

    local gplayer = players[playerid]
    if not gplayer then
        -- 未登录
        skynet.error("reconnect fail, player not exist")
        return
    end

    if gplayer.conn then
        -- 未掉线
        skynet.error("reconnect fail, conn not break")
        return
    end

    if gplayer.key ~= key then
        skynet.error("reconnect fail, key error")
        return
    end

    -- bind
    gplayer.conn = conn
    conn.playerid = playerid
    -- 回应
    s.resp.send_by_fd(nil, fd, {"reconnect", 0})
    -- 发送缓存消息
    for i, cmsg in ipairs(gplayer.msgcache) do
        s.resp.send_by_fd(nil, fd, cmsg)
    end
    gplayer.msgcache = {}
end

-- 消息分发
local process_msg = function (fd, msgstr)
    local cmd, msg = str_unpack(msgstr)
    skynet.error("recv "..fd.." ["..cmd.."] {"..table.concat(msg, ",").."}")

    -- 特殊断线重连
    if cmd == "reconnect" then
        process_reconnect(fd, msg)
        return
    end

    local conn = conns[fd]
    local playerid = conn.playerid
    -- 尚未完成登录流程
    if not playerid then
        local node = skynet.getenv("node")
        local nodecfg = runconfig[node]
        local loginid = math.random(1, #nodecfg.login)
        local login = "login"..loginid
        -- skynet.error("gateway:login = ", login)
        -- skynet.error("gateway:cmd = ", cmd)
        skynet.send(login, "lua", "client", fd, cmd, msg) -- client为自定义的消息名
    -- 完成登录流程
    else
        local gplayer = players[playerid]
        local agent = gplayer.agent
        skynet.send(agent, "lua", "client", cmd, msg)
    end
end

-- ·msgstr和rest：根据正则表达式“(.-)\ r\ n(.*)”的规则，它们分别代表取出的第一条消息和剩余的部分。
    -- 举例来说，假如readbuff的内容是“login,101,134\r\nwork\r\nwo”，经过string.match语句匹配，msgstr的值为“login,101,134”，rest的值为“work\r\nwo”；
    -- 如果匹配不到数据，例如readbuff的内容是“wo”，那么经过string.match语句匹配后，msgstr为空值。
local process_buff = function (fd, readbuff)
    while true do
        local msgstr, rest = string.match(readbuff, "(.-)\r\n(.*)")
        if msgstr then
            readbuff = rest
            process_msg(fd, msgstr)
        else
            return readbuff
        end
    end
end

local recv_loop = function (fd)
    socket.start(fd)
    skynet.error("socket connected "..fd)
    local readbuff = "" -- 定义字符串缓冲区，为处理tcp数据粘包
    while true do
        local recvstr = socket.read(fd) -- 读取连接数据（阻塞）
        if recvstr then
            readbuff = readbuff..recvstr
            readbuff = process_buff(fd, readbuff) -- 处理客户端协议
        else
            -- 断开连接,客户端掉线
            skynet.error("socket close"..fd)
            disconnect(fd) -- 处理断开事务
            socket.close(fd)
            return
        end
    end
end

------------------------------------------------------------------------------------------------------------------------------------------------------
-- 远程调用接口
-- login消息转发到客户端
s.resp.send_by_fd = function (source, fd, msg)
    if not conns[fd] then
        return
    end

    local buff =  str_pack(msg[1], msg)
    skynet.error("send "..fd.." ["..msg[1].."] {"..table.concat(msg, ",").."}")
    socket.write(fd, buff)
end

-- agent消息转发客户端
s.resp.send = function (source, playerid, msg)
    local gplayer = players[playerid]
    if gplayer == nil then
        return
    end

    local c = gplayer.conn
    if c == nil then
        -- return
        table.insert(gplayer.msgcache, msg)
        local len = #gplayer.msgcache
        if len > 500 then
            skynet.call("agentmgr", "lua", "reqkick", playerid, "gate消息缓存过多")
        end
        return
    end

    s.resp.send_by_fd(nil, c.fd, msg)
end

-- login确认登录情况
s.resp.sure_agent = function (source, fd, playerid, agent)
    local conn = conns[fd]
    if not conn then
        skynet.call("agentmgr", "lua", "reqkick", playerid, "account login failed!")
        return false
    end

    -- 保存登录成功后的信息
    conn.playerid = playerid

    local gplayer = gateplayer()
    gplayer.playerid = playerid
    gplayer.agent = agent
    gplayer.conn = conn
    players[playerid] = gplayer

    return true, gplayer.key
end

-- agentmgr将玩家踢下线
s.resp.kick = function (source, playerid)
    local gplayer = players[playerid]
    if not gplayer then
        return
    end

    local c = gplayer.conn
    players[playerid] = nil

    if not c then
        return
    end
    conns[c.fd] = nil
    disconnect(c.fd)
    socket.close(c.fd)
end

s.resp.shutdown = function()
    closing = true
end
------------------------------------------------------------------------------------------------------------------------------------------------------
-- 当客户端连接上时，gateway创建代表该连接的conn对象，并开启协程recv_loop专接收该连接的数据
local connect = function (fd, addr)
    -- 关服时判断
    if closing then
        return
    end

    print("connect from "..addr.." "..fd)
    local c = conn()
    conns[fd] = c
    c.fd = fd
    skynet.fork(recv_loop, fd)
end

function s.init()
    -- skynet.error("[start]"..s.name.." "..s.id)
    -- 接收客户端连接
    local node = skynet.getenv("node")
    local nodecfg = runconfig[node]
    local port = nodecfg.gateway[s.id].port -- 读取配置文件找到此服务id下的端口

    -- 开启监听
    local listenfd = socket.listen("0.0.0.0", port)
    skynet.error("Listen socket:", "0.0.0.0", port)
    socket.start(listenfd, connect)
end

s.start(...)

-- s.start(...)中的“...” 代表可变参数，在用skynet.newservice启动服务时，可以传递参数给它。
-- service模块将会把第1个参数赋值给s.name，第2个参数赋值给s.id
