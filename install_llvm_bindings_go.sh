#!/bin/bash

set -e

GOPATH="$(go env GOPATH)"

if [[ "$GOPATH" == "" ]]; then
    echo '$GOPATH is empty' 1>&2
    exit 4
fi

#LLVM_GO_LLVM_DIR="${GOPATH}/src/llvm.org/llvm/bindings/go/llvm"
LLVM_GO_LLVM_DIR="${GOPATH}/src/github.com/jobs-github/llvm-bindings-go/llvm"
LLVM_ARCHIVE="${GOPATH}/pkg/$(go env GOOS)_$(go env GOARCH)/github.com/jobs-github/llvm-bindings-go/llvm.a"

if [[ -f "$LLVM_ARCHIVE" ]]; then
    echo "LLVM is already installed: ${LLVM_ARCHIVE}. Installation skipped."
    exit
fi

echo "Building go-llvm with system installed LLVM..."

if [[ "$LLVM_CONFIG" == "" ]]; then
    LLVM_CONFIG="llvm-config"
    case "$OSTYPE" in
        darwin*)
            BREW_LLVM="$(ls -1 /usr/local/Cellar/llvm/*/bin/llvm-config | tail -1)"
            if [[ "$BREW_LLVM" != "" ]]; then
                LLVM_CONFIG="$BREW_LLVM"
                # libffi is needed to build Go bindings
                CGO_LDFLAGS="$CGO_LDFLAGS -L/usr/local/opt/libffi/lib -lffi"
                echo "Detected LLVM installed with Homebrew: $BREW_LLVM"
            fi
            ;;
    esac
fi

if which "$LLVM_CONFIG" 2>&1 > /dev/null; then
    echo "llvm-config version: $($LLVM_CONFIG --version)"
else
    echo "llvm-config command not found: $LLVM_CONFIG" >&2
    exit 1
fi

cd "$LLVM_GO_LLVM_DIR"

export CGO_CPPFLAGS="${CGO_CPPFLAGS} $($LLVM_CONFIG --cppflags)"
export CGO_CXXFLAGS="${CGO_CXXFLAGS} $($LLVM_CONFIG --cxxflags)"
export CGO_LDFLAGS="${CGO_LDFLAGS} $($LLVM_CONFIG --ldflags --libs --system-libs all | tr '\n' ' ')"

echo "CGO_CPPFLAGS='$CGO_CPPFLAGS'"
echo "CGO_CXXFLAGS='$CGO_CXXFLAGS'"
echo "CGO_LDFLAGS='$CGO_LDFLAGS'"

cat ${LLVM_GO_LLVM_DIR}/llvm_config.go.in | \
    sed "s#@LLVM_CFLAGS@#${CGO_CPPFLAGS}#" | \
    sed "s#@LLVM_LDFLAGS@#${CGO_LDFLAGS}#" > \
    ${LLVM_GO_LLVM_DIR}/llvm_config.go

go install -v -tags byollvm
