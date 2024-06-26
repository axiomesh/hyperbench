# Go parameters
GOCMD=go
GOBUILD=$(GOCMD) build
GOCLEAN=$(GOCMD) clean
GOTEST=$(GOCMD) test
GOGEN=$(GOCMD) generate
GOGET=$(GOCMD) get
GOLIST=$(GOCMD) list
BINARY_NAME=hyperbench
SKIP_DIR=benchmark

# version info
branch=$(shell git rev-parse --abbrev-ref HEAD)
commitID=$(shell git log --pretty=format:"%h" -1)
date=$(shell date +%Y%m%d)
importpath=github.com/meshplus/hyperbench/cmd
ldflags=-X ${importpath}.branch=${branch} -X ${importpath}.commitID=${commitID} -X ${importpath}.date=${date}

# path
FAILPOINT=github.com/pingcap/failpoint/failpoint-ctl

# export gomodule
export GO111MODULE=on

all: build

## build: build the binary with pre-packed static resource
build:
	@export GOPROXY=https://goproxy.cn,direct
	@$(GOCMD) mod tidy
	@$(GOCMD) build -o $(BINARY_NAME) -trimpath -ldflags "${ldflags}"

## test: run all test
test:
	@go get $(FAILPOINT)
	@failpoint-ctl enable
	@$(GOTEST) `go list ./... | grep -v $(SKIP_DIR)`
	@failpoint-ctl disable

## clean: clean all file generated by make
clean:
	@-rm -rf $(BINARY_NAME)

help: Makefile
	@echo " Choose a command run in "$(PROJECTNAME)":"
	@sed -n 's/^##//p' $< | column -t -s ':' | sed -e 's/^/ /'
