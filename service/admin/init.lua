local skynet = require "skynet"
local socket = require "skynet.socket"
local s = require "service"
local runconfig = require "runconfig"
require "skynet.manager"

local function shutdown_gate()
    -- 每个节点中的gateway服务执行
    for node, _ in pairs(runconfig.cluster) do
        local nodecfg = runconfig[node]
        for i, v in pairs(nodecfg.gateway or {}) do
            local name = "gateway"..i
            s.call(node, name, "shutdown")
        end
    end
end

local function shutdown_agent()
    local agentnode = runconfig.agentmgr.node
    while true do
        -- 每隔段时间处理x人
        local online_num = s.call(agentnode, "agentmgr", "shutdown", 1)
        if online_num <= 0 then
            break
        end
        skynet.sleep(10000)
    end
end

local function stop()
    shutdown_gate()
    shutdown_agent()
    -- ...
    skynet.abort()
    return "shutdown success"
end

function Connect(fd, addr)
    socket.start(fd)
    socket.write(fd, "Please enter cmd\r\n")
    local cmd = socket.readline(fd, "\r\n")
    if cmd == "stop" then
        -- 关服处理
        stop()
    else
        print("cmd faild")
    end
end

s.init = function()
    -- 开启8888端口监听
    local listenfd = socket.listen("127.0.0.1", 8888)
    socket.start(listenfd, Connect)
end

s.start(...)
