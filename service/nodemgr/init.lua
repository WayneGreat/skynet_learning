local skynet = require "skynet"
local s = require "service"

-- nodemgr即节点管理服务，每个节点会开启一个。
-- 目前它只有一个功能，即提供创建服务的远程调用接口。
-- 远程调用方法newservice只是简单地封装了skynet.newservice，并返回新建服务的id。
s.resp.newservice = function(source, name, ...)
    local srv = skynet.newservice(name, ...)
    return srv
end

s.start(...)
