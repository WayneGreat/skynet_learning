-- 用于处理agent的战斗逻辑, s为agent服务
local skynet = require "skynet"
local s = require "service"
local runconfig = require "runconfig"
local mynode = skynet.getenv("node")

-- 记录玩家处于的scene服务
s.snode = nil -- scene_node
s.sname = nil -- scene_id

-- 选择一个场景服务进入游戏
local function random_scene()
    local nodes = {}
    for i, v in pairs(runconfig.scene) do
        table.insert(nodes, i)
        -- agent应尽可能地进入个同节点的scene
        if runconfig.scene[mynode] then
            table.insert(nodes, mynode)
        end
    end
    local idx = math.random(1, #nodes)
    local scenenode = nodes[idx]

    -- 具体场景
    local scenelist = runconfig.scene[scenenode]
    idx = math.random(1, #scenelist)
    local sceneid = scenelist[idx]
    return scenenode, sceneid
end

s.leave_scene = function()
    -- 不在场景
    if not s.sname then
        return
    end
    s.call(s.snode, s.sname, "leave", s.id)
    s.snode = nil
    s.sname = nil
end

------------------------------------------------------------------------------------------------------------------------------------------------------
-- 远程调用接口
-- gate调用enter进入战斗
s.client.enter = function(msg)
    if s.sname then
        return {"enter", 1, "已在场景中"}
    end

    local snode, sid = random_scene()
    local sname = "scene"..sid
    local isok = s.call(snode, sname, "enter", s.id, mynode, skynet.self())
    if not isok then
        return {"enter", 1, "进入失败"}
    end
    s.snode = snode
    s.sname = sname
    return nil
end

-- gate调用转发给scene服务
s.client.shift = function(msg)
    if not s.sname then
        return
    end

    local x = msg[2] or 0
    local y = msg[3] or 0
    s.call(s.snode, s.sname, "shift", s.id, x, y)
end

