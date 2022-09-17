local skynet = require "skynet"
local s = require "service"

-- 1970.1.1是星期四，此处以周四20:40为界
function get_week_by_thu2040(timestamp)
    local week = (timestamp + 3600 * 8 - 3600 * 20 - 40 * 60) / (3600 * 24 * 7)
    return math.ceil(week)
end

-- 开启服务器时从数据库读取
-- 关闭时保存
local last_check_time = 1663383297

-- 每隔一小段时间执行
function timer()
    local last = get_week_by_thu2040(last_check_time)
    local now = get_week_by_thu2040(os.time())
    last_check_time = os.time()
    -- 到时间判读是否开启活动
    if now > last then
        -- open_activity()
    end
end