return {
    -- 集群  (指明服务端系统包含两个节点)
    cluster = {
        node1 = "127.0.0.1:7771", --  节点地址，用于节点间通信
        node2 = "127.0.0.1:7772",
    },
    -- agentmgr (全局唯一，且位于节点1)
    agentmgr = {
        node = "node1",
    },
    -- scene
    scene = {
        node1 = {
            1001, -- 服务编号
            1002,
        },
        -- node2 = {
        --     1003,
        -- }
    },
    -- node1 (描述节点的"本地"服务)
    node1 = {
        gateway = {
            [1] = {
                port = 8001 -- 监听端口
            },
            [2] = {
                port = 8002
            },
        },
        login = {
            [1]  = {},
            [2]  = {},
        },
    },
    -- node2
    node2 = {
        gateway = {
            [1] = {
                port = 8011
            },
            [2] = {
                port = 8022
            },
        },
        login = {
            [1]  = {},
            [2]  = {},
        },
    },
}