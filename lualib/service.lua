-- service模块是对skynet服务的封装

local skynet = require "skynet"
local cluster = require "skynet.cluster"

-- 定义属性
local M = {
    -- 类型、id
    name = "",
    id = 0,
    -- 回调函数
    exit = nil, -- 退出时回调
    init = nil, -- 初始化时回调
    -- 分发方法
    resp = {},
}

-- 启动逻辑
function init()
    skynet.dispatch("lua", dispatch)
    if M.init then
        M.init()
    end
end

function M.start(name, id, ...)
    M.name = name
    M.id = tonumber(id)
    skynet.start(init)
end

-- 消息分发
function traceback(err)
    skynet.error(tostring(err))
    skynet.error(debug.traceback())
end

function dispatch(session, address, cmd, ...)
    local fun = M.resp[cmd]
    if not fun then
        skynet.ret()
        return
    end

    -- xpcall: 
        -- 安全的调用fun方法。如果fun方法出错，程序不会中断，而是会把错误信息转给第2个参数的traceback。
        -- 如果程序报错，xpcall会返回false；如果程序正常执行，xpcall返回的第一个值为true，从第2个值开始才是fun的返回值。
        -- xpcall会把第3个及后面的参数传给fun，即fun的第1参数是address，从第2个参数开始是可变参数“...”。
    local ret = table.pack(xpcall(fun, traceback, address, ...))
    local isok = ret[1]

    if not isok then
        skynet.ret()
        return
    end

    skynet.retpack(table.unpack(ret, 2)) -- 返回结果给发送方
end

-- 辅助方法
    -- 参数node代表接收方所在的节点，srv代表接收方的服务名。
    -- 程序先用skynet.getenv获取当前节点，如果接收方在同个节点，则调用skynet.call；
    -- 如果在不同节点，则调用cluster.call
function M.call(node, srv, ...)
    local mynode = skynet.getenv("node")
    if node == mynode then
        return skynet.call(srv, "lua", ...)
    else
        return cluster.call(node, srv, ...)
    end
end

function M.send(node, srv, ...)
    local mynode = skynet.getenv("node")
    if node == mynode then
        return skynet.send(srv, "lua", ...)
    else
        return cluster.send(node, srv, ...)
    end
end

return M
