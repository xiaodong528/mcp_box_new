#!/bin/bash
# =============================================================================
# Memo 离线部署脚本
# 阶段 3: 在内网环境部署
# =============================================================================
# 功能：
#   1. 加载 Docker 镜像
#   2. 配置环境变量
#   3. 启动服务
#   4. 验证部署状态
# =============================================================================

set -e  # 遇到错误立即退出

# =============================================================================
# 配置变量
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="docker-compose.prod.yml"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# =============================================================================
# 工具函数
# =============================================================================
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${CYAN}[STEP]${NC} $1"
}

# 检查命令是否存在
check_command() {
    if ! command -v "$1" &> /dev/null; then
        log_error "命令 '$1' 未找到，请先安装"
        exit 1
    fi
}

# 检查 Docker 是否运行
check_docker() {
    if ! docker info &> /dev/null; then
        log_error "Docker 未运行，请先启动 Docker"
        exit 1
    fi
}

# 检查文件是否存在
check_file() {
    if [ ! -f "$1" ]; then
        log_error "文件不存在: $1"
        exit 1
    fi
}

# 等待用户确认
wait_for_confirmation() {
    echo ""
    read -p "$(echo -e ${YELLOW}"按 Enter 键继续，或 Ctrl+C 取消..."${NC}) " dummy
    echo ""
}

# =============================================================================
# 主要功能
# =============================================================================

# 步骤 0: 显示欢迎信息
step0_welcome() {
    clear
    echo ""
    echo "=========================================="
    echo "   Memo 离线部署工具"
    echo "=========================================="
    echo ""
    log_info "本脚本将引导您完成 Memo 应用的离线部署"
    echo ""
}

# 步骤 1: 环境检查
step1_check_environment() {
    log_step "步骤 1/6: 环境检查"
    echo "=========================================="

    check_command "docker"
    check_command "docker-compose"
    check_docker

    log_success "✅ Docker 已安装并运行"

    # 检查必需文件
    check_file "memo-app.tar"
    check_file "mcp-box.tar"
    check_file "python-base.tar"
    check_file "${COMPOSE_FILE}"

    log_success "✅ 所有必需文件都存在"

    wait_for_confirmation
}

# 步骤 2: 加载 Docker 镜像
step2_load_images() {
    log_step "步骤 2/6: 加载 Docker 镜像"
    echo "=========================================="

    log_info "正在加载基础镜像 python:3.12-slim..."
    docker load -i python-base.tar
    log_success "✅ 基础镜像加载完成"

    log_info "正在加载 Memo 应用镜像..."
    docker load -i memo-app.tar
    log_success "✅ Memo 镜像加载完成"

    log_info "正在加载 MCP Box 镜像..."
    docker load -i mcp-box.tar
    log_success "✅ MCP Box 镜像加载完成"

    echo ""
    log_info "已加载的镜像："
    docker images | grep -E "memo|python:3.12-slim" || log_warning "未找到相关镜像"

    wait_for_confirmation
}

# 步骤 3: 配置环境变量
step3_configure_environment() {
    log_step "步骤 3/6: 配置环境变量"
    echo "=========================================="

    if [ -f ".env" ]; then
        log_warning "⚠️  .env 文件已存在"
        read -p "$(echo -e ${YELLOW}"是否覆盖现有配置？(y/n): "${NC})" overwrite
        if [[ ! $overwrite =~ ^[Yy]$ ]]; then
            log_info "跳过环境变量配置，使用现有 .env 文件"
            return
        fi
    fi

    if [ -f ".env.prod.example" ]; then
        log_info "从模板创建 .env 文件..."
        cp .env.prod.example .env
        log_success "✅ 已创建 .env 文件"
        echo ""
        log_warning "⚠️  请编辑 .env 文件，配置必要的环境变量"
        log_info "特别注意以下配置项："
        echo "   - E2B_API_KEY (如需使用沙箱功能)"
        echo "   - DB_* (如需使用数据库存储)"
        echo ""
        read -p "$(echo -e ${YELLOW}"现在编辑 .env 文件吗？(y/n): "${NC})" edit_env
        if [[ $edit_env =~ ^[Yy]$ ]]; then
            ${EDITOR:-vi} .env
        fi
    else
        log_warning "⚠️  未找到 .env.prod.example 模板，跳过环境变量配置"
    fi

    wait_for_confirmation
}

# 步骤 4: 启动服务
step4_start_services() {
    log_step "步骤 4/6: 启动服务"
    echo "=========================================="

    log_info "正在启动服务（这可能需要几分钟）..."
    docker-compose -f "${COMPOSE_FILE}" up -d

    log_success "✅ 服务已启动"

    wait_for_confirmation
}

# 步骤 5: 验证部署
step5_verify_deployment() {
    log_step "步骤 5/6: 验证部署状态"
    echo "=========================================="

    log_info "等待服务启动（30秒）..."
    sleep 30

    echo ""
    log_info "检查容器状态："
    docker-compose -f "${COMPOSE_FILE}" ps

    echo ""
    log_info "检查服务健康状态："

    # 检查 API 服务
    if curl -f -s http://localhost:48000/health > /dev/null; then
        log_success "✅ API 服务 (48000) 正常"
    else
        log_error "❌ API 服务 (48000) 无响应"
    fi

    # 检查前端服务
    if curl -f -s http://localhost:48002 > /dev/null; then
        log_success "✅ 前端服务 (48002) 正常"
    else
        log_warning "⚠️  前端服务 (48002) 无响应"
    fi

    # 检查 MCP SSE 服务 (SSE 端点会持续输出，使用超时避免卡住)
    if timeout 3 curl -s http://localhost:47070/sse > /dev/null 2>&1; then
        log_success "✅ MCP SSE 服务 (47070) 正常"
    else
        # 超时(124)或成功接收数据都表示服务正常
        EXIT_CODE=$?
        if [ $EXIT_CODE -eq 124 ] || [ $EXIT_CODE -eq 0 ]; then
            log_success "✅ MCP SSE 服务 (47070) 正常"
        else
            log_warning "⚠️  MCP SSE 服务 (47070) 无响应"
        fi
    fi

    wait_for_confirmation
}

# 步骤 6: 显示摘要
step6_summary() {
    log_step "步骤 6/6: 部署完成"
    echo "=========================================="

    echo ""
    log_success "🎉 Memo 应用已成功部署！"

    echo ""
    log_info "📡 服务访问地址："
    echo "   - 前端界面:    http://localhost:48002"
    echo "   - API 文档:    http://localhost:48000/docs"
    echo "   - API 健康检查: http://localhost:48000/health"
    echo "   - MCP SSE:     http://localhost:47070/sse"
    echo "   - MCP 管理:    http://localhost:47071"

    echo ""
    log_info "🔧 常用管理命令："
    echo "   - 查看日志:   docker-compose -f ${COMPOSE_FILE} logs -f"
    echo "   - 查看状态:   docker-compose -f ${COMPOSE_FILE} ps"
    echo "   - 停止服务:   docker-compose -f ${COMPOSE_FILE} stop"
    echo "   - 重启服务:   docker-compose -f ${COMPOSE_FILE} restart"
    echo "   - 删除服务:   docker-compose -f ${COMPOSE_FILE} down"

    echo ""
    log_info "💾 数据持久化："
    echo "   - 数据存储在 Docker volumes 中"
    echo "   - 查看 volumes: docker volume ls | grep memo"
    echo "   - 备份数据:    docker run --rm -v memo-data:/data -v \$(pwd):/backup ubuntu tar czf /backup/memo-backup.tar.gz /data"

    echo ""
    log_info "📖 详细文档："
    echo "   - 查看 README-OFFLINE-DEPLOY.md 获取更多信息"
    echo "   - 故障排查请查看文档中的常见问题部分"

    echo ""
    log_warning "⚠️  如果服务未能正常启动，请运行以下命令查看日志："
    echo "   docker-compose -f ${COMPOSE_FILE} logs"

    echo ""
}

# =============================================================================
# 错误处理
# =============================================================================
handle_error() {
    log_error "部署过程中发生错误！"
    echo ""
    log_info "故障排查步骤："
    echo "   1. 查看容器日志: docker-compose -f ${COMPOSE_FILE} logs"
    echo "   2. 检查容器状态: docker-compose -f ${COMPOSE_FILE} ps"
    echo "   3. 检查 .env 配置是否正确"
    echo "   4. 确保端口 48000, 48001, 48002, 47070, 47071 未被占用"
    echo ""
    exit 1
}

trap handle_error ERR

# =============================================================================
# 主流程
# =============================================================================
main() {
    step0_welcome
    step1_check_environment
    step2_load_images
    step3_configure_environment
    step4_start_services
    step5_verify_deployment
    step6_summary
}

# 执行主流程
main "$@"
