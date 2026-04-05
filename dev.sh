#!/bin/bash
# dev.sh - Agent Deck 开发脚本
# 用于快速构建、测试和运行本地开发的 agent-deck

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 项目根目录
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BINARY_NAME="agent-deck-dev"
BINARY_PATH="/tmp/${BINARY_NAME}"

# 打印带颜色的信息
info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 构建项目
build() {
    info "Building agent-deck..."
    cd "${PROJECT_ROOT}"
    go build -o "${BINARY_PATH}" ./cmd/agent-deck
    success "Built: ${BINARY_PATH}"
}

# 运行测试
test() {
    info "Running tests..."
    cd "${PROJECT_ROOT}"
    go test ./... -count=1
    success "All tests passed"
}

# 运行特定测试
test_codebuddy() {
    info "Running CodeBuddy-related tests..."
    cd "${PROJECT_ROOT}"
    go test ./cmd/agent-deck/... -run TestDetectTool_CodeBuddy -v
    go test ./internal/tmux/... -run TestDetectToolFromCommand_CodeBuddy -v
    go test ./internal/session/... -run TestDetectToolFromName -v
    go test ./internal/session/... -run TestGetToolIcon -v
    go test ./internal/ui/... -run TestDialogPresetCommands -v
    go test ./internal/ui/... -run TestSetupWizard_ToolOptions -v
    success "CodeBuddy tests passed"
}

# 运行 agent-deck
run() {
    if [ ! -f "${BINARY_PATH}" ]; then
        warn "Binary not found, building first..."
        build
    fi
    info "Running agent-deck..."
    "${BINARY_PATH}" "$@"
}

# 快速测试 CodeBuddy 功能
quick_test() {
    if [ ! -f "${BINARY_PATH}" ]; then
        build
    fi

    info "Quick testing CodeBuddy support..."

    # 创建测试目录
    TEST_DIR="/tmp/agent-deck-test-$$"
    mkdir -p "${TEST_DIR}"

    # 测试 1: 添加 CodeBuddy 会话
    info "Test 1: Creating CodeBuddy session..."
    "${BINARY_PATH}" add -c codebuddy -t "Test CodeBuddy" "${TEST_DIR}"

    # 测试 2: 查看列表
    info "Test 2: Listing sessions..."
    "${BINARY_PATH}" list

    # 测试 3: JSON 输出验证
    info "Test 3: Verifying JSON output..."
    if "${BINARY_PATH}" list --json | grep -q '"tool": "codebuddy"'; then
        success "Tool field correctly set to 'codebuddy'"
    else
        error "Tool field not found or incorrect"
    fi

    # 测试 4: cbc 简写
    info "Test 4: Testing 'cbc' shorthand..."
    mkdir -p "${TEST_DIR}-cbc"
    "${BINARY_PATH}" add -c cbc -t "Test CBC" "${TEST_DIR}-cbc"
    "${BINARY_PATH}" list | grep -i "cbc" && success "CBC shorthand works" || error "CBC shorthand failed"

    # 测试 5: agentcli
    info "Test 5: Testing 'agentcli'..."
    mkdir -p "${TEST_DIR}-agentcli"
    "${BINARY_PATH}" add -c agentcli -t "Test AgentCli" "${TEST_DIR}-agentcli"
    "${BINARY_PATH}" list | grep -i "agentcli" && success "AgentCli works" || error "AgentCli failed"

    # 清理
    info "Cleaning up test sessions..."
    "${BINARY_PATH}" rm "Test CodeBuddy" 2>/dev/null || true
    "${BINARY_PATH}" rm "Test CBC" 2>/dev/null || true
    "${BINARY_PATH}" rm "Test AgentCli" 2>/dev/null || true
    rm -rf "${TEST_DIR}" "${TEST_DIR}-cbc" "${TEST_DIR}-agentcli"

    success "Quick test completed!"
}

# 安装到系统
install() {
    info "Installing agent-deck to ~/go/bin..."
    cd "${PROJECT_ROOT}"
    go install ./cmd/agent-deck
    success "Installed to ~/go/bin/agent-deck"
    info "Make sure ~/go/bin is in your PATH"
}

# 显示帮助
help() {
    echo "Agent Deck 开发脚本"
    echo ""
    echo "Usage: ./dev.sh [command] [args...]"
    echo ""
    echo "Commands:"
    echo "  build          构建项目到 /tmp/agent-deck-dev"
    echo "  test           运行所有测试"
    echo "  test-codebuddy 运行 CodeBuddy 相关测试"
    echo "  run [args...]  构建并运行 agent-deck（传递参数）"
    echo "  quick-test     快速测试 CodeBuddy 功能"
    echo "  install        安装到 ~/go/bin"
    echo "  help           显示此帮助"
    echo ""
    echo "Examples:"
    echo "  ./dev.sh build"
    echo "  ./dev.sh run list"
    echo "  ./dev.sh run add -c codebuddy -t \"My Project\" /path/to/project"
    echo "  ./dev.sh quick-test"
}

# 主逻辑
case "${1:-}" in
    build)
        build
        ;;
    test)
        test
        ;;
    test-codebuddy)
        test_codebuddy
        ;;
    run)
        shift
        run "$@"
        ;;
    quick-test)
        quick_test
        ;;
    install)
        install
        ;;
    help|--help|-h)
        help
        ;;
    *)
        # 默认：如果没有参数，显示帮助
        # 如果有参数但不是已知命令，尝试直接运行（向后兼容）
        if [ $# -eq 0 ]; then
            help
        else
            # 尝试作为 agent-deck 命令运行
            run "$@"
        fi
        ;;
esac
