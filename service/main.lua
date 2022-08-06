local skynet = require "skynet"
local skynet_manager = require "skynet.manager"
local runconfig = require "runconfig"
local cluster = require "skynet.cluster"

skynet.start(function ()
    -- 初始化
    skynet.error("[start main]")
    local srv = skynet.newservice("gateway", "gateway", 1)
    skynet.name("gateway", srv)
    srv = skynet.newservice("login", "login", 1)
    skynet.name("login1", srv)
    srv = skynet.newservice("login", "login", 2)
    skynet.name("login2", srv)
    -- 退出
    skynet.exit()
end)

