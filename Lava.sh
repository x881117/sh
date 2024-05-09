#!/bin/bash

set -e

# 脚本保存路径
SCRIPT_PATH="$HOME/Lava.sh"

# 节点安装功能
function install_node() {
	echo "正在更新系统..."
	sudo apt update
	sudo apt install -y unzip logrotate git jq sed wget curl coreutils systemd
	# Create the temp dir for the installation
	temp_folder=$(mktemp -d) && cd $temp_folder
	
	echo "安装go环境..."
	# Configurations
	go_package_url="https://go.dev/dl/go1.20.5.linux-amd64.tar.gz"
	go_package_file_name=${go_package_url##*\/}
	# Download GO
	wget -q $go_package_url
	# Unpack the GO installation file
	sudo tar -C /usr/local -xzf $go_package_file_name
	# Environment adjustments
	echo "export PATH=\$PATH:/usr/local/go/bin" >>~/.profile
	echo "export PATH=\$PATH:\$(go env GOPATH)/bin" >>~/.profile
	source ~/.profile
	
	echo "安装lava主程序..."
	# Download the installation setup configuration
	git clone https://github.com/lavanet/lava-config.git
	cd lava-config/testnet-2
	# Read the configuration from the file
	# Note: you can take a look at the config file and verify configurations
	source setup_config/setup_config.sh
	echo "Lava config file path: $lava_config_folder"
	mkdir -p $lavad_home_folder
	mkdir -p $lava_config_folder
	cp default_lavad_config_files/* $lava_config_folder
	
	# Copy the genesis.json file to the Lava config folder
	cp genesis_json/genesis.json $lava_config_folder/genesis.json
	
	# Install cosmovisor
	go install github.com/cosmos/cosmos-sdk/cosmovisor/cmd/cosmovisor@v1.0.0
	# Create the Cosmovisor folder and copy config files to it
	mkdir -p $lavad_home_folder/cosmovisor/genesis/bin/
	# Download the genesis binary
	wget -O  $lavad_home_folder/cosmovisor/genesis/bin/lavad "https://github.com/lavanet/lava/releases/download/v0.21.1.2/lavad-v0.21.1.2-linux-amd64"
	chmod +x $lavad_home_folder/cosmovisor/genesis/bin/lavad
	
	# Set the environment variables
	echo "# Setup Cosmovisor" >> ~/.profile
	echo "PATH=$PATH:$HOME/.lava/cosmovisor/genesis/bin" >> ~/.profile
	echo "export DAEMON_NAME=lavad" >> ~/.profile
	echo "export CHAIN_ID=lava-testnet-2" >> ~/.profile
	echo "export DAEMON_HOME=$HOME/.lava" >> ~/.profile
	echo "export DAEMON_ALLOW_DOWNLOAD_BINARIES=true" >> ~/.profile
	echo "export DAEMON_LOG_BUFFER_SIZE=512" >> ~/.profile
	echo "export DAEMON_RESTART_AFTER_UPGRADE=true" >> ~/.profile
	echo "export UNSAFE_SKIP_BACKUP=true" >> ~/.profile
	source ~/.profile
	
	# Initialize the chain
	$lavad_home_folder/cosmovisor/genesis/bin/lavad init \
	my-node \
	--chain-id lava-testnet-2 \
	--home $lavad_home_folder \
	--overwrite
	cp genesis_json/genesis.json $lava_config_folder/genesis.json
	cosmovisor version
	
	# Create Cosmovisor unit file
	echo "[Unit]
	Description=Cosmovisor daemon
	After=network-online.target
	[Service]
	Environment="DAEMON_NAME=lavad"
	Environment="DAEMON_HOME=${HOME}/.lava"
	Environment="DAEMON_RESTART_AFTER_UPGRADE=true"
	Environment="DAEMON_ALLOW_DOWNLOAD_BINARIES=true"
	Environment="DAEMON_LOG_BUFFER_SIZE=512"
	Environment="UNSAFE_SKIP_BACKUP=true"
	User=$USER
	ExecStart=${HOME}/go/bin/cosmovisor start --home=$lavad_home_folder --p2p.seeds $seed_node
	Restart=always
	RestartSec=3
	LimitNOFILE=infinity
	LimitNPROC=infinity
	[Install]
	WantedBy=multi-user.target
	" >cosmovisor.service

	sudo mv cosmovisor.service /lib/systemd/system/cosmovisor.service
	
	# Enable the cosmovisor service so that it will start automatically when the system boots
	sudo systemctl daemon-reload
	sudo systemctl enable cosmovisor.service
	sudo systemctl restart systemd-journald
	sudo systemctl start cosmovisor

	echo "成功安装并启动..."
}

function check_cosmovisor_status() {
    sudo systemctl status cosmovisor
}

function view_cosmovisor_logs() {
    sudo journalctl -u cosmovisor -f
}

function view_lava_logs() {
	# Check if the node is currently in the process of catching up
	$HOME/.lava/cosmovisor/current/bin/lavad status | jq .SyncInfo
}

function view_wallets() {
    $HOME/.lava/cosmovisor/current/bin/lavad keys list
}

function add_wallet() {
    read -r -p "请输入钱包名称: " wallet_name
    $HOME/.lava/cosmovisor/current/bin/lavad keys add "$wallet_name"
    echo "钱包已创建，请备份钱包信息。"
}

function import_wallet() {
    read -r -p "请输入钱包名称: " wallet_name
    $HOME/.lava/cosmovisor/current/bin/lavad keys add "$wallet_name" --recover
}

function check_balances() {
    read -r -p "请输入钱包地址: " wallet_address
    $HOME/.lava/cosmovisor/current/bin/lavad query bank balances "$wallet_address"
}

# 主菜单
function main_menu() {
	while true; do
	    clear
	    echo "===============风男Lava节点脚本==============="
	    echo "1. 安装节点"
	    echo "2. 查看状态"
	    echo "3. 查看cosmovisor日志"
	    echo "4. 查看节点日志"
	    echo "5. 查看钱包"
	    echo "6. 创建钱包"
	    echo "7. 导入钱包"
	    echo "8. 查询余额"
	    echo "0. 退出脚本"
	    read -r -p "请输入选项（0-8）: " OPTION
	
	    case $OPTION in
	    1) install_node ;;
	    2) check_cosmovisor_status ;;
	    3) view_cosmovisor_logs ;;
	    4) view_lava_logs ;;
	    5) view_wallets ;;
	    6) add_wallet ;;
	    7) import_wallet ;;
	    8) check_balances ;;
	    0) echo "退出脚本。"; exit 0 ;;
	    *) echo "无效选项，请重新输入。"; sleep 3 ;;
	    esac
	    echo "按任意键返回主菜单..."
        read -n 1
    done
}

# 显示主菜单
main_menu