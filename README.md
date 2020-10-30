## 编译：
1. 普通模式`(需要自己配置mysql和redis)`
    1. 安装autoconf和libreadline-dev
        ```
        sudo apt-get install autoconf
        sudo apt-get install libreadline-dev
        ```
    2. 克隆代码库并编译
        ```
        git clone https://github.com/dingdalong/skynet_test.git
        cd skynet_test
        git submodule update --init
        make linux
        ```
2. docker-compose`(配置了redis和mysql)`
    ```
    git clone https://github.com/dingdalong/skynet_test.git
    cd skynet_test
    docker build . -t skynet_server
    docker-compose up -d
    ```
* 记得修改service_config/ip_config.lua中的ip信息

## 运行：

1. 以前台模式启动`./run.sh <server_name>`  
    用`Ctrl-C`可以退出

2. 以后台模式启动`./run.sh <server_name> -D`

    杀掉后台进程`./run.sh <server_name> -k`

* `<server_name>`指的是`service_config/launch_config`中根据`<server_name>.config`

## 可能遇到的问题
* 关于`make`，不同平台请使用不同参数`linux/macosx/freebsd`

* `.sh`文件可能有权限和换行符的问题
    * 权限问题：  
        使用`chmod 777 *.sh`获取所有权限
    * 换行符问题：  
        将对应的sh文件中的换行符修改为LF或者在clone之前设置git检出时不转换换行符 `git config --global core.autocrlf input`

* 关于数据库的问题：  
    在`service_config`目录下，配置`redis`和`mysql`的地址和账号密码，并配置数据库`skynet`（也可以直接根据情况修改），将`tools`中的`sql`文件导入到`mysql`中
