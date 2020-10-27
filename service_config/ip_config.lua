local ip_config = {}

ip_config.mysql = {
    center = {
        host = "192.168.130.63",
        port = 3306
    },
    group = {
        {
            host = "192.168.130.63",
            port = 3306
        },
        {
            host = "192.168.130.63",
            port = 3306
        },
    }
}


ip_config.redis = {
    center = {
        host = "192.168.130.64",
        port = 6379,
    },
    group = {
        {
            host = "192.168.130.64",
            port = 6379,
        },
        {
            host = "192.168.130.64",
            port = 6379,
        },
    }
}

return ip_config