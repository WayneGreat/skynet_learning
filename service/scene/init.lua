local skynet = require "skynet"
local s = require "service"

-- 场景服务:会处理绝大部分的游戏逻辑。

------------------------------------------------------------------------------------------------------------------------------------------------------
-- ball类
local balls = {} -- [playerid] = ball

function ball()
    local m = {
        -- 玩家信息
        playerid = nil,
        node = nil,
        agent = nil,
        -- 坐标信息
        x = math.random(0, 100),
        y = math.random(0, 100),
        -- 大小
        size = 2,
        -- 移动速度
        speedx = 0,
        speedy = 0,
    }
    return m
end

-- 辅助方法balllist_msg，它会收集战场中的所有小球，并构建balllist协议
local function balllist_msg()
    local msg = {"balllist"}
    for i, v in pairs(balls) do
        table.insert(msg, v.playerid)
        table.insert(msg, v.x)
        table.insert(msg, v.y)
        table.insert(msg, v.size)
    end
    return msg
end

------------------------------------------------------------------------------------------------------------------------------------------------------
-- food类
local foods = {} -- [id] = food
local food_maxid = 0 -- 每创建一个食物，+1
local food_count = 0 -- 记录战场上食物数量，以限制食物总量

function food()
    local m = {
        id = nil,
        x = math.random(0, 100),
        y = math.random(0, 100),
    }
    return m
end

-- 辅助方法foodlist_msg，它会收集战场中的所有食物，并构建foodlist协议
local function foodlist_msg()
    local msg = {"foodlist"}
    for i, v in pairs(foods) do
        table.insert(msg, v.id)
        table.insert(msg, v.x)
        table.insert(msg, v.y)
    end
    return msg
end

------------------------------------------------------------------------------------------------------------------------------------------------------
function broadcast(msg)
    for i, v in pairs(balls) do
        s.send(v.node, v.agent, "send", msg)
    end
end

-- 位置更新
function move_update()
    for i, v in pairs(balls) do
        v.x = v.x + v.speedx * 0.2
        v.y = v.y + v.speedy * 0.2
        if v.speedx ~= 0 or v.speedy ~= 0 then
            local msg = {"move", v.playerid, v.x, v.y}
            broadcast(msg)
        end
    end
end

-- 生成食物
function food_update()
    if food_count > 50 then
        return
    end

    -- 平均10秒生成一个食物
    if math.random(1, 100) < 98 then
        return
    end

    food_maxid = food_maxid + 1
    food_count = food_count + 1
    local f = food()
    f.id = food_maxid
    foods[f.id] = f

    local msg = {"addfood", f.id, f.x, f.y}
    broadcast(msg)
end

-- 吞下食物
function eat_update()
    for pid, b in pairs(balls) do
        for fid, f in pairs(foods) do
            if (b.x - f.x)^2 + (b.y - f.y)^2 < b.size^2 then -- 是否碰撞
                b.size = b.size + 1
                food_count = food_count - 1
                local msg = {"eat", b.playerid, fid, b.size}
                broadcast(msg)
                foods[fid] = nil
            end
        end
    end
end

-- loop主循环中每隔一段时间执行(0.2秒)
-- @frame: 当前的帧数
function update(frame)
    food_update()
    move_update()
    eat_update()
end

------------------------------------------------------------------------------------------------------------------------------------------------------
-- 远程调用接口
-- agent调用enter进入战斗
s.resp.enter = function(source, playerid, node, agent)
    -- 判断能否进入，若已经在战场内，不可再次进入
    if balls[playerid] then
        return false
    end

    local b = ball()
    b.playerid = playerid
    b.node = node
    b.agent = agent
    -- 广播，通知其他玩家有新玩家到来
    local entermsg = {"enter", playerid, b.x, b.y, b.size}
    broadcast(entermsg)
    -- 记录
    balls[playerid] = b
    -- 回应新玩家
    local ret_msg = {"enter", 0, "进入成功"}
    s.send(b.node, b.agent, "send", ret_msg)
    -- 向新玩家发送战场信息
    s.send(b.node, b.agent, "send", balllist_msg())
    s.send(b.node, b.agent, "send", foodlist_msg())
    return true
end

-- 玩家掉线，agent调用退出游戏
s.resp.leave = function(source, playerid)
    if not balls[playerid] then
        return false
    end

    balls[playerid] = nil

    local leavemsg = {"leave", playerid}
    broadcast(leavemsg)
end

-- 玩家移动，agent调用移动接口
s.resp.shift = function(source, playerid, x, y)
    local b = balls[playerid]
    if not b  then
        return false
    end
    b.speedx = x
    b.speedy = y
end

------------------------------------------------------------------------------------------------------------------------------------------------------
s.init = function()
    -- 开启死循环协程，不断调用update方法
    skynet.fork(function()
        local stime = skynet.now()
        local frame = 0
        while true do
            frame = frame + 1
            local isok, err = pcall(update, frame)
            if not isok then
                skynet.error(err)
            end
            local etime = skynet.now()
            -- waittime代表每次循环后等待的时间
            local waittime = frame * 20 - (etime - stime)
            if waittime <= 0 then
                waittime = 2
            end
            skynet.sleep(waittime)
        end
    end)
end


s.start(...)