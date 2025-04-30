
# loginfo

`loginfo` 是一个用于管理和连接多个远程服务器的工具，支持 `tmux` 会话管理、SSH 密钥认证、主机组管理等功能。

## 快速部署

### 1. 安装依赖

确保你的系统安装了 `curl` 和 `tmux`，如果没有安装，可以使用以下命令：

```bash
sudo apt update
sudo apt install curl tmux
```

### 2. 使用安装脚本进行自动化部署

为了简化部署过程，你可以使用 `install_loginfo.sh` 脚本来自动下载和配置项目文件。运行以下命令下载并执行安装脚本：

```bash
# 安装
curl -sSL https://raw.githubusercontent.com/ziwiwiz/loginfo/main/install_loginfo.sh | bash -s -- install
```

如果需要卸载，可以运行：

```bash
# 卸载
curl -sSL https://raw.githubusercontent.com/ziwiwiz/loginfo/main/install_loginfo.sh | bash -s -- uninstall
```
安装完后修改配置 /opt/loginfo/host_info.conf

### 3. 配置主机和组

`host_info.conf` 配置文件的格式如下：

```ini
# 组1
[group1]
1|192.168.1.10|user1|password1|22|server1
2|192.168.1.11|user2|password2|22|server2

# 组2
[group2]
3|192.168.1.12|user3|password3|22|server3
4|192.168.1.13|user4|password4||server4

# 自定义组
[other_group_name]{1,3}
```

- 每个组由 `[group_name]` 开头。
- 每行的格式为 `id|ip|user|password|port|name`，`id` 是数字，`ip` 是主机的 IP 地址，`user` 是登录用户名，`password` 是登录密码，`port` 是 SSH 端口（默认为 22），`name` 是主机的别名，当前不支持直接使用`password`登陆，请填空。
- 自定义组可以通过 `{}` 包裹的数字 ID 列出该组下的主机。

### 4. 配置 `alias zzt`

`install_loginfo.sh` 脚本已经将以下内容添加到你的 `~/.bashrc` 文件中：

```bash
# 为 'loginfo' 脚本设置别名
alias zzt='/opt/loginfo/autologin.sh'
# alias zz='/opt/loginfo/autologin.sh --no-tmux'
```

执行以下命令使 `alias` 配置生效：

```bash
source ~/.bashrc
```

### 5. 运行脚本

通过以下命令运行脚本：

```bash
zzt
```
输入相应id和命令就可执行
```bash
# 连接单个服务器
<ID>

# 连接多个服务器
<ID1,ID2>

# 连接一组服务器或自定义组服务器, 默认会把所有服务器加入到all分组
<GROUP_NAME>

# 获取命令提示和自定义组名
help

# 查看当前已经连接的服务器
ll
ls

# 断开某一组服务器
kill <GROUP_NAME>

# 退出命令
q
exit

# 刷新服务器打印
<直接回车>
```

### 6. 使用 tmux 会话管理

- 查看所有会话：

```bash
tmux ls
```

- 连接到某个会话：

```bash
tmux attach-session -t <session-name>
```

### 7. 退出 tmux 会话

按 `Ctrl + B` 然后按 `D` 来分离当前会话。

## 许可证

MIT 许可证，详情请见 [LICENSE](LICENSE) 文件。
