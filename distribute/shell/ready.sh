#!/usr/bin/env bash

mkdir -p ${HOME}/stress
cd ${HOME}/stress
git clone https://mirror.ghproxy.com/https://github.com/axiomesh/hyperbench-plugins.git
cd hyperbench-plugins
go get github.com/meshplus/hyperbench-plugins/eth
make build
cp eth.so ../../hyperbench/eth.so