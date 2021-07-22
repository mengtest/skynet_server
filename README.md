## Notice
经过一段时间的开发，最新版本已经和当前版本差异极大，例如架构调整、数据库改用mongodb、不再使用docker技术、使用skynet_package处理消息包等等。  
由于缺少经验，当前版本也有各式各样的已知问题，仅供参考。

## 编译
1. Ubuntu`(需要自己配置mysql和redis)`
    1. 安装`autoconf`和`libreadline-dev`
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
* 记得修改`service_config/ip_config.lua`中的ip信息

## 运行

1. 以前台模式启动`./run.sh <server_name>`  
    用`Ctrl-C`可以退出

2. 以后台模式启动`./run.sh <server_name> -D`

    杀掉后台进程`./run.sh <server_name> -k`

* `<server_name>`指的是`service_config/launch_config`中根据`<server_name>.config`

## Docker
* 使用`docker build . -t skynet_server`生成名为`skynet_server`的docker镜像  
    tips：我这边开发环境和`docker`都是用的`alpine`，这时候可以调整`Dockerfile`中的编译部分，去掉编译，直接用拷过去的数据构建镜像，这样不需要重新编译会快一点，用于测试。
* 使用`docker-compose up -d`启动环境
## 可能遇到的问题

* 关于`make`，不同平台请使用不同参数`linux/macosx/freebsd`

* `.sh`文件可能有权限和换行符的问题
    * 权限问题：  
        使用`chmod 777 *.sh`获取所有权限
    * 换行符问题：  
        将对应的`sh`文件中的换行符修改为`LF`或者在`clone`之前设置`git`检出时不转换换行符 `git config --global core.autocrlf input`

* 关于数据库的问题：  
    在`service_config`目录下，配置`redis`和`mysql`的地址和账号密码，并配置数据库`skynet`（也可以直接根据情况修改），将`tools`中的`sql`文件导入到`mysql`中

## Windows下的开发环境
我这边在`windows 10`下使用[`wsl`](https://docs.microsoft.com/zh-cn/windows/wsl/)做开发
1. 启用`wsl  `
    1. 启用`linux子系统`  
        以管理员身份打开`Windows PowerShell（右击任务栏的windows徽标可以找到）`，输入以下内容
        `Enable-WindowsOptionalFeature -Online -FeatureName $("VirtualMachinePlatform", "Microsoft-Windows-Subsystem-Linux")`处理好后会提示是否重启，输入`y`重启
    2. 更新内核`(启用wsl2需要)`  
        以管理员身份安装[`wsl_update_x64.msi`](https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi)
    * 可以通过`\\wsl$`访问所有的子系统文件

2. 使用`Alpine`  
    1. 安装`Alpine`，以下两种方式二选一
        1. 去`Microsoft Store`中下载`Alpine`
        2. 使用`wsl --import`导入
            1. 下载[`alpine-minirootfs-3.12.1-x86_64.tar.gz`](http://dl-cdn.alpinelinux.org/alpine/v3.12/releases/x86_64/alpine-minirootfs-3.12.1-x86_64.tar.gz)
            2. 导入`wsl --import <分发版名称> <安装位置> <安装包位置>`
            * 可以根据需要去[官网](https://alpinelinux.org/downloads/)查找并下载期望的版本
        * 使用`wsl -s <分发版>`设置`wsl`默认启动版本，更多使用帮助使用`wsl -h`查看
    2. 替换源`sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories `  
    3. 安装环境`apk update && apk add --no-cache --virtual .build-deps git make autoconf g++ readline-dev tzdata busybox-extras`  
    4. 设置时区`ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && echo "Asia/Shanghai" > /etc/timezone`  

* 关于`wsl2`  
    `docker desktop`这边使用`wsl`的话只能使用`wsl2`，或者使用`hyper-v`。`wsl2`这边使用上有一个不方便的，就是监听的端口只能本机访问，没有对外映射，[github](https://github.com/yhl452493373/WSL2-Auto-Port-Forward)上有解决方案，需要编辑并运行一个`shell`，感觉挺麻烦的，所以选择就用`wsl 1`做本地开发测试即可。这两个版本是可以共存的，`wsl -h`查看设置版本。

* 关于`windows 10`版本  
    `wsl`的支持需要较新的版本，`wsl2`版本要求更高。目前`20H2`是全部支持的。
    * `家庭版`可能不支持。
