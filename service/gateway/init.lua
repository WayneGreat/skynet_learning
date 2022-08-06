local skynet = require "skynet"
local s = require "service"
local socket = require "skynet.socket"
local runconfig = require "runconfig"


-- 登录后，gateway可以做到双向查找：
    -- ·若客户端发送了消息，可由底层Socket获取连接标识fd。gateway则由fd索引到conn对象，再由playerid属性找到player对象，进而知道它的代理服务（agent）在哪里，并将消息转发给agent。
    -- ·若agent发来消息，只要附带着玩家id，gateway即可由playerid索引到gateplayer对象，进而通过conn属性找到对应的连接及其fd，向对应客户端发送消息。

conns = {} -- [fd] = conn
players = {} -- [playerid] = gateplayer

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
    }
    return m
end

local disconnect = function (fd)
    
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

-- 消息分发
local process_msg = function (fd, msgstr)
    local cmd, msg = str_unpack(msgstr)
    skynet.error("recv"..fd.."["..cmd.."] {"..table.concat(msg, ",").."}")

    local conn = conns[fd]
    local playerid = conn.playerid
    -- 尚未完成登录流程
    if not playerid then
        local node = skynet.getenv("node")
        local nodecfg = runconfig[node]
        local loginid = math.random(1, #nodecfg.login)
        local login = "login"..loginid
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
    skynet.error("socket connected"..fd)
    local readbuff = "" -- 定义字符串缓冲区，为处理tcp数据粘包
    while true do
        local recvstr = socket.read(fd) -- 读取连接数据（阻塞）
        if recvstr then
            readbuff = readbuff..recvstr
            readbuff = process_buff(fd, readbuff) -- 处理客户端协议
        else
            -- 断开连接
            skynet.error("socket close"..fd)
            disconnect(fd) -- 处理断开事务
            socket.close(fd)
            return
        end
    end
end

-- 当客户端连接上时，gateway创建代表该连接的conn对象，并开启协程recv_loop专接收该连接的数据
local connect = function (fd, addr)
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
