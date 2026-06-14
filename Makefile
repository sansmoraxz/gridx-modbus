GO_FILES := $(shell find . -type f -name "*.go")
GO_BUILD := CGO_ENABLED=0 go build -ldflags "-w -s"
GO_TOOLS := public.ecr.aws/gridx/base-images:modbus-dev-1.21.latest
DOCKER_RUN := docker run --init --rm -v $$PWD:/go/src/github.com/grid-x/modbus -w /go/src/github.com/grid-x/modbus
GO_RUN := ${DOCKER_RUN} ${GO_TOOLS} bash -c

BRANCH := $(shell echo ${BUILDKITE_BRANCH} | sed 's/\//_/g')

all: bin/

.PHONY: test
test:
	@tmpdir=$$(mktemp -d); \
	cleanup() { pkill -P $$$$; rm -rf $$tmpdir; }; \
	trap cleanup EXIT INT TERM; \
	diagslave -m tcp -p 5020 & diagslave -m enc -p 5021 & \
	go test -run TCP -v .; \
	pkill -P $$$$
	@tmpdir=$$(mktemp -d); \
	cleanup() { pkill -P $$$$; rm -rf $$tmpdir; }; \
	trap cleanup EXIT INT TERM; \
	socat -d -d pty,raw,echo=0,link=$$tmpdir/rtu0 pty,raw,echo=0,link=$$tmpdir/rtu1 & \
	sleep 0.5; \
	diagslave -m rtu $$tmpdir/rtu1 & \
	go test -run RTU -v .; \
	pkill -P $$$$
	@tmpdir=$$(mktemp -d); \
	cleanup() { pkill -P $$$$; rm -rf $$tmpdir; }; \
	trap cleanup EXIT INT TERM; \
	socat -d -d pty,raw,echo=0,link=$$tmpdir/ascii0 pty,raw,echo=0,link=$$tmpdir/ascii1 & \
	sleep 0.5; \
	diagslave -m ascii $$tmpdir/ascii1 & \
	go test -run ASCII -v .; \
	pkill -P $$$$
	go test -v -count=1 github.com/grid-x/modbus/cmd/modbus-cli 

.PHONY: lint
lint:
	golint -set_exit_status

.PHONY: build
build:
	go build

release:
	goreleaser release --skip-publish --skip-validate --clean

ci_test:
	${GO_RUN} "make test"

ci_lint:
	${GO_RUN} "make lint"

ci_build:
	${GO_RUN} "make build"

ci_release:
	${GO_RUN} "goreleaser release --skip-publish --skip-validate --rm-dist"