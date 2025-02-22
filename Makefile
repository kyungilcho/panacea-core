VERSION := $(shell echo $(shell git describe --tags) | sed 's/^v//')
COMMIT := $(shell git log -1 --format='%H')
GOBIN ?= $(GOPATH)/bin
GOSUM := $(shell which gosum)
DOCKER := $(shell which docker)

export GO111MODULE = on


ifeq ($(WITH_CLEVELDB),yes)
  build_tags += gcc
endif
build_tags += $(BUILD_TAGS)
build_tags := $(strip $(build_tags))
build_tags += ledger

# process linker flags

ldflags = -X github.com/cosmos/cosmos-sdk/version.Name=panacea-core \
          -X github.com/cosmos/cosmos-sdk/version.ServerName=panacead \
          -X github.com/cosmos/cosmos-sdk/version.ClientName=panaceacli \
          -X github.com/cosmos/cosmos-sdk/version.Version=$(VERSION) \
          -X github.com/cosmos/cosmos-sdk/version.Commit=$(COMMIT) \
          -X "github.com/cosmos/cosmos-sdk/version.BuildTags=$(build_tags)"

ldflags += $(LDFLAGS)
ldflags := $(strip $(ldflags))
BUILD_FLAGS := -tags "$(build_tags)" -ldflags '$(ldflags)'

ARTIFACT_DIR := artifacts

all: build-all install
build-all: proto-lint proto-gen update-swagger-docs build

########################################
### Analyzing

lint:
	GO111MODULE=off go get github.com/golangci/golangci-lint/cmd/golangci-lint
	golangci-lint run --timeout 5m0s --allow-parallel-runners
	find . -name '*.go' -type f -not -path "./vendor*" -not -path "*.git*" | xargs gofmt -d -s
	go mod verify

########################################
### Protobuf

proto-gen:
	@echo "Generating *.pb.go files from *.proto files"
	$(DOCKER) run --rm -v $(CURDIR):/workspace --workdir /workspace tendermintdev/sdk-proto-gen:v0.7 sh ./scripts/protocgen.sh

proto-swagger-gen:
	@echo "Generating swagger.yaml from *.proto files"
	$(DOCKER) run --rm -v $(CURDIR):/workspace --workdir /workspace tendermintdev/sdk-proto-gen:v0.7 sh ./scripts/protoc-swagger-gen.sh

proto-lint:
	$(DOCKER) run --rm -v $(CURDIR):/workspace --workdir /workspace/proto bufbuild/buf lint --error-format=json

PROTO_DIR = third_party/proto
# TODO: use the correct version after releasing medibloc/cosmos-sdk
COSMOS_VER_SHORT = 0.42.11-panacea-min-commission-rate-28eaec9
COSMOS_VER = v$(COSMOS_VER_SHORT)

proto-update-dep:
	@mkdir -p $(PROTO_DIR)
	@curl https://codeload.github.com/medibloc/cosmos-sdk/tar.gz/$(COSMOS_VER) | tar -xz -C $(PROTO_DIR) --strip=3 cosmos-sdk-$(COSMOS_VER_SHORT)/third_party/proto
	@curl https://codeload.github.com/medibloc/cosmos-sdk/tar.gz/$(COSMOS_VER) | tar -xz -C $(PROTO_DIR) --strip=2 cosmos-sdk-$(COSMOS_VER_SHORT)/proto

########################################
### Build/Install

build: go.sum
	go build -mod=readonly $(BUILD_FLAGS) -o build/panacead ./cmd/panacead

test:
	mkdir -p $(ARTIFACT_DIR)
	go test -covermode=count -coverprofile=$(ARTIFACT_DIR)/coverage.out ./...
	go tool cover -html=$(ARTIFACT_DIR)/coverage.out -o $(ARTIFACT_DIR)/coverage.html

install: go.sum
	go install -mod=readonly $(BUILD_FLAGS) ./cmd/panacead

go.sum: go.mod
	@echo "--> Ensure dependencies have not been modified"
	@go mod verify

########################################
### Documentations

update-swagger-docs: proto-swagger-gen
	GO111MODULE=off go get github.com/rakyll/statik

	@echo "Generating swagger.go from swagger.yaml and other static files"
	statik -src=client/docs/swagger-ui -dest=client/docs -f -m

	# The following 'git' command returns non-zero exit code when there are uncommitted changes.
	@if [ -n "$(git status --porcelain)" ]; then \
        echo "\033[91mSwagger docs are out of sync!!!\033[0m";\
        exit 1;\
    else \
        echo "\033[92mSwagger docs are in sync\033[0m";\
    fi

########################################
### Clean

clean:
	rm -rf build/
