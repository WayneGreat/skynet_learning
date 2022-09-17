local skynet = require "skynet"
local s = require "service"

STATUS = {
    LOGIN = 2,
    GAME = 3,
    LOGOUT = 4,
}

-- 玩家列表
-- players将会以playerid（ 玩家id）为索引，引用mgrplayer对象。
local players = {}

-- 玩家列表
function mgrplayer()
    local m = {
        playerid = nil, -- 玩家id
        node = nil, -- 该玩家对应gateway和agent所在的节点
        agent = nil, -- 该玩家对应agent服务的id
        gate = nil, -- 该玩家对应gateway的id
        status = nil, -- STATUS.xx
    }
    return m
end

------------------------------------------------------------------------------------------------------------------------------------------------------
-- 获取整个服务器在线人数
local function get_onlie_count()
    local count = 0
    for playerid, player in ipairs(players) do
        count = count + 1
    end
    return count
end

------------------------------------------------------------------------------------------------------------------------------------------------------
-- 远程调用接口
-- login请求登录接口
s.resp.reqlogin = function(source, playerid, node, gate)
    local myplayer = players[playerid]

    -- 登录过程需要防止其他设备顶替
    if myplayer and myplayer.status == STATUS.LOGOUT then
        skynet.error("reqlogin fail, at status LOGOUT "..playerid)
        return false
    end
    if myplayer and myplayer.status == STATUS.LOGIN then
        skynet.error("reqlogin fail, at status LOGIN "..playerid)
        return false
    end

    -- 在线顶替
    if myplayer then
        local pnode = myplayer.node
        local pagent = myplayer.agent
        local pgate = myplayer.gate
        myplayer.status = STATUS.LOGOUT
        s.call(pnode, pagent, "kick") -- 阻塞，等待玩家存储完成返回
        s.send(pnode, pagent, "exit")
        s.call(pnode, pgate, "send", playerid, {"kick", "顶替下线"})
        s.send(pnode, pgate, "kick", playerid)
    end

    -- 上线
    local player = mgrplayer()
    player.playerid = playerid
    player.node = node
    player.gate = gate
    player.agent = nil
    player.status = STATUS.LOGIN
    players[playerid] = player

    local agent = s.call(node, "nodemgr", "newservice", "agent", "agent", playerid)
    player.agent = agent
    player.status = STATUS.GAME

    return true, agent
end

-- 请求登出接口
s.resp.reqkick = function(source, playerid, reason)
    local myplayer = players[playerid]
    if not myplayer then
        return false
    end

    if myplayer.status ~= STATUS.GAME then
        return false
    end

    local pnode = myplayer.node
    local pagent = myplayer.agent
    local pgate = myplayer.gate
    myplayer.status = STATUS.LOGOUT

    s.call(pnode, pagent, "kick")
    s.send(pnode, pagent, "exit")
    s.call(pnode, pgate, "kick", playerid)
    players[playerid] = nil

    return true
end

s.resp.shutdown = function(source, num)
    -- 当前玩家数
    local count = get_onlie_count()
    -- 踢下线
    local n = 0
    for playerid, player in pairs(players) do
        skynet.fork(s.resp.reqkick, nil, playerid, "close server")
        n = n + 1 -- 计数，总共发num条下线消息
        if n > num then
            break
        end
    end
    -- 等待玩家数(num)下线
    while true do
        skynet.sleep(200)
        local new_count = get_onlie_count()
        skynet.error("shutdown online:"..new_count)
        if new_count <= 0 or new_count <= count - num then
            return new_count
        end
    end
end

s.start(...)