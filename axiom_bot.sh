#!/bin/bash

# 导入 .env 文件中的环境变量
if [ -f .env ]; then
    export $(cat .env | xargs)
else
    echo "Error: .env file not found."
    exit 1
fi

CONFIG_ERC20="benchmark/ethereum/erc20/config.toml"
CONFIG_MAKERDAO="benchmark/ethereum/makerdao/config.toml"
SCRIPT_LUA_MAKERDAO="benchmark/ethereum/makerdao/script.lua"
SCRIPT_LUA_ERC20="benchmark/ethereum/erc20/script.lua"
KEYSTORE_FILE_MAKERDAO="benchmark/ethereum/makerdao/eth/keystore/keys"
KEYSTORE_FILE_ERC20="benchmark/ethereum/erc20/eth/keystore/keys"
LOG_FILE="hyperbench_run.log"

# 新增：指定地址和私钥
ADDRESS_MAKERDAO=${ADDRESS_MAKERDAO}
ADDRESS_ERC20=${ADDRESS_ERC20}
PRIVATE_KEY_MAKERDAO=${PRIVATE_KEY_MAKERDAO}
PRIVATE_KEY_ERC20=${PRIVATE_KEY_ERC20}


# 检查是否成功读取到地址和私钥
if [ -z "$ADDRESS_MAKERDAO" ]; then
    echo "Error: ADDRESS_MAKERDAO environment variable is not set."
    exit 1
fi

if [ -z "$ADDRESS_ERC20" ]; then
    echo "Error: ADDRESS_ERC20 environment variable is not set."
    exit 1
fi

if [ -z "$PRIVATE_KEY_MAKERDAO" ]; then
    echo "Error: PRIVATE_KEY_MAKERDAO environment variable is not set."
    exit 1
fi

if [ -z "$PRIVATE_KEY_ERC20" ]; then
    echo "Error: PRIVATE_KEY_ERC20 environment variable is not set."
    exit 1
fi

# 更新script.lua中的地址
sed -i "s/local from = .*/local from = \"$ADDRESS_MAKERDAO\"/" $SCRIPT_LUA_MAKERDAO
sed -i "s/local from = .*/local from = \"$ADDRESS_ERC20\"/" $SCRIPT_LUA_ERC20

# 在keystore文件开头添加私钥（如果第一行没有相同的值）
add_key_if_not_present() {
    local key_file=$1
    local private_key=$2

    if [ -f "$key_file" ]; then
        first_line=$(head -n 1 "$key_file")
        if [ "$first_line" != "$private_key" ]; then
            sed -i "1i$private_key" "$key_file"
        fi
    else
        echo -e "$private_key" > "$key_file"
    fi
}

add_key_if_not_present "$KEYSTORE_FILE_MAKERDAO" "$PRIVATE_KEY_MAKERDAO"
add_key_if_not_present "$KEYSTORE_FILE_ERC20" "$PRIVATE_KEY_ERC20"

# config文件变更，其中duration和accounts为固定数值，rate和cap为随机数
# 固定数值
DURATION="100h"
ACCOUNTS=200000

while true; do
    NOW=$(date "+%Y-%m-%d %H:%M:%S")
    echo "Starting Hyperbench at $NOW" | tee -a $LOG_FILE
    if [ -f hyperbench_erc20.pid ]; then
        kill -9 `cat hyperbench_erc20.pid`
        rm hyperbench_erc20.pid
    fi
    if [ -f hyperbench_makerdao.pid ]; then
        kill -9 `cat hyperbench_makerdao.pid`
        rm hyperbench_makerdao.pid
    fi
    sleep 5
    ERC20=$((RANDOM % 20 + 1))
    MAKERDAO=$((RANDOM % 20 + 1))

    sed -i "s/^rate = .*/rate = $ERC20/" $CONFIG_ERC20
    sed -i "s/^cap = .*/cap = $ERC20/" $CONFIG_ERC20
    sed -i "s/^duration = .*/duration = \"$DURATION\"/" $CONFIG_ERC20
    sed -i "s/^accounts = .*/accounts = $ACCOUNTS/" $CONFIG_ERC20

    sed -i "s/^rate = .*/rate = $MAKERDAO/" $CONFIG_MAKERDAO
    sed -i "s/^cap = .*/cap = $MAKERDAO/" $CONFIG_MAKERDAO
    sed -i "s/^duration = .*/duration = \"$DURATION\"/" $CONFIG_MAKERDAO
    sed -i "s/^accounts = .*/accounts = $ACCOUNTS/" $CONFIG_MAKERDAO

    nohup ./hyperbench start benchmark/ethereum/erc20 > erc20.out 2>&1 &
	echo $! > hyperbench_erc20.pid
    nohup ./hyperbench start benchmark/ethereum/makerdao > makerdao.out 2>&1 &
    echo $! > hyperbench_makerdao.pid
    echo "Hyperbench for ERC20 and MakerDAO started with PIDs $(cat hyperbench_erc20.pid) and $(cat hyperbench_makerdao.pid) at $NOW" | tee -a $LOG_FILE
    sleep 24h
done