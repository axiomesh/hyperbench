#! /bin/bash

./hyperbench start benchmark/ethereum/compound > compound-$(date +"%Y-%m-%d").log 2>&1 &
./hyperbench start benchmark/ethereum/erc20 > erc20-$(date +"%Y-%m-%d").log 2>&1 &
./hyperbench start benchmark/ethereum/makerdao > makerdao-$(date +"%Y-%m-%d").log 2>&1 &
./hyperbench start benchmark/ethereum/transfer > transfer-$(date +"%Y-%m-%d").log 2>&1 &
./hyperbench start benchmark/ethereum/uniswap > uniswap-$(date +"%Y-%m-%d").log 2>&1 &