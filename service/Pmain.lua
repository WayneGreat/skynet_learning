local skynet = require "skynet"
-- local cjson = require "cjson"
local pb = require "protobuf"
local mysql = require "skynet.db.mysql"

-- json编码
function test1()
    local msg = {
        _cmd = "balllist",
        balls = {
            [1] = {id=102, x=10, y=20, size=1},
            [2] = {id=103, x=10, y=30, size=2},
        }
    }
    local buff = cjson.encode(msg)
    print(buff)
end

-- json解码
function test2()
    local buff = [[
        {"_cmd":"enter","playerid":101,"x":10,"y":20,"size":1}
    ]]
    local isok, msg = pcall(cjson.decode, buff)
    if isok then
        print(msg._cmd) -- enter
        print(msg.playerid) -- 101.0
    else
        print("error")
    end
end

-- 编写json协议
function json_pack(cmd, msg)
    msg._cmd = cmd
    local body = cjson.encode(msg)
    local namelen = string.len(cmd)
    local bodylen = string.len(body)
    local len = namelen + bodylen + 2
    local format = string.format("> i2 i2 c%d c%d", namelen, bodylen)
    local buff = string.pack(format, len, namelen, cmd, body)
    return buff
end

-- 解码json协议
function json_unpack(buff)
    local len = string.len(buff)
    local namelen_format = string.format("> i2 c%d", len - 2)
    local namelen, other = string.unpack(namelen_format, buff)
    local bodylen = len - 2 - namelen
    local format = string.format("> c%d c%d", namelen, bodylen)
    local cmd, bodybuff = string.unpack(format, other)

    local isok, msg = pcall(cjson.decode, bodybuff)
    if not isok or not msg or not msg._cmd or not cmd == msg._cmd then
        print("error")
        return
    end

    return cmd, msg
end

function test3()
    local msg = {
        _cmd = "playerinfo",
        coin = 100,
        bag = {
            [1] = {1001, 1},
            [2] = {1005, 5},
        }
    }

    -- encode
    local buff_with_len = json_pack("playerinfo", msg)
    local len = string.len(buff_with_len)
    print("len:"..len)
    print(buff_with_len)

    --decode
    local format = string.format(">i2 c%d", len - 2)
    local _, buff = string.unpack(format, buff_with_len)
    local cmd, umsg = json_unpack(buff)
    print("cmd:"..cmd)
    if umsg and next(umsg) then
        print("coin:" .. umsg.coin)
        print("sword:" .. umsg.bag[1][2])
    end
end

function test4()
    pb.register_file("./proto/proto_login/login.pb")

    -- encode
    local msg = {
        id = 101,
        pw = "123456"
    }
    local buff = pb.encode("login.Login", msg)
    print("len:"..string.len(buff))

    -- decode
    local umsg = pb.decode("login.Login", buff)
    if umsg then
        print("id:"..umsg.id)
        print("pw:"..umsg.pw)
    else
        print("error")
    end
end

function test5(db)
    pb.register_file("./proto/proto_storage/playerdata.pb")
    -- 创角
    local playerdata = {
        playerid = 109,
        coin = 97,
        name = "Tiny",
        level = 3,
        last_login_time = os.time(),
    }
    -- 序列化
    local data = pb.encode("playerdata.BaseInfo", playerdata)
    print("data len:"..string.len(data))
    -- 存入数据库
    local sql = string.format("insert into baseinfo (playerid, data) values (%d, %s)", 109, mysql.quote_sql_str(data))
    local res = {}
    if db then
        res = db:query(sql)
    end
    -- 查看存储结果
    if res.err then
        print("error:"..res.err)
    else
        print("ok")
    end

    return data
end

function test6(db, data)
    pb.register_file("./proto/proto_storage/playerdata.pb")
    local sql = string.format("select * from baseinfo where playerid = 109")
    local res = {}
    if db then
        res = db:query(sql)
        data = res[1].data
    end
    -- 反序列化
    print("data len:"..string.len(data))
    local udata = pb.decode("playerdata.BaseInfo", data)
    if not udata then
        print("error")
        return false
    end
    -- output
    local playerdata = udata
    print("coin:"..playerdata.coin)
    print("name:"..playerdata.name)
    print("time:"..playerdata.last_login_time)
    print("skin:"..playerdata.skin)
    print("class:"..playerdata.class)
end


-- test1()
-- test2()
-- test3()

skynet.start(function ()
    -- test4()
    -- local db = mysql.connect({
    --     host = "127.0.0.1",
    --     port = 3306,
    --     database = "baseinfo",
    --     user = "root",
    --     password = "wayne7490",
    --     max_packet_size = 1024 * 1024,
    --     on_connect = nil
    -- })
    test6(false, test5())
end)
