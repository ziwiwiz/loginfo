#!/bin/bash

# 安装目录
INSTALL_DIR="/opt/loginfo"
ALIAS_NAME="zzt"
HOST_INFO_FILE="$INSTALL_DIR/host_info.conf"

# 卸载操作
uninstall() {
    echo "正在卸载..."

    # 删除安装目录及文件
    sudo rm -rf $INSTALL_DIR

    # 精确删除 ~/.bashrc 中的指定 alias
    sed -i "/^alias $ALIAS_NAME=/d" ~/.bashrc

    # 提示用户重新加载 ~/.bashrc
    echo "卸载完成。请运行 'source ~/.bashrc' 来更新配置。"
}

# 安装操作
install() {
    # 创建目标目录
    sudo mkdir -p $INSTALL_DIR

    # 下载主脚本
    sudo curl -sSL https://raw.githubusercontent.com/ziwiwiz/loginfo/main/autologin.sh -o $INSTALL_DIR/autologin.sh

    # 检查 host_info.conf 文件是否存在，不存在才下载
    if [ ! -f "$HOST_INFO_FILE" ]; then
        sudo curl -sSL https://raw.githubusercontent.com/ziwiwiz/loginfo/main/host_info.conf -o $HOST_INFO_FILE
    else
        echo "$HOST_INFO_FILE 已存在，跳过下载。"
    fi

    # 赋予脚本执行权限
    sudo chmod +x $INSTALL_DIR/autologin.sh

    # 添加 alias 到 ~/.bashrc
    echo "alias $ALIAS_NAME='$INSTALL_DIR/autologin.sh'" >> ~/.bashrc

    # 提示用户执行 source 来生效
    echo "alias $ALIAS_NAME 已添加到 ~/.bashrc 文件中。"
    echo "请运行 'source ~/.bashrc' 来使配置生效。"
}

# 检查脚本参数
if [ "$1" == "uninstall" ]; then
    uninstall
else
    install
fi
