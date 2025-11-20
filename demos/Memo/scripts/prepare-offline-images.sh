#!/bin/bash
# =============================================================================
# Memo 离线部署包准备脚本
# 阶段 1: 在有网环境准备镜像
# =============================================================================
# 功能：
#   1. 构建 memo 和 mcp-box 镜像
#   2. 保存镜像为 tar 包
#   3. 打包所有必需文件为单个压缩包
# =============================================================================

set -e  # 遇到错误立即退出

# =============================================================================
# 配置变量
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
IMAGES_DIR="${PROJECT_ROOT}/images"
DEPLOY_PACKAGE_NAME="memo-offline-deploy"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

# =============================================================================
# 主要功能
# =============================================================================

# 步骤 0: 环境检查
step0_check_environment() {
    log_info "=========================================="
    log_info "步骤 0: 环境检查"
    log_info "=========================================="

    check_command "docker"
    check_command "docker-compose"
    check_docker

    log_success "环境检查通过"
    echo ""
}

# 步骤 1: 构建镜像
step1_build_images() {
    log_info "=========================================="
    log_info "步骤 1: 构建 Docker 镜像"
    log_info "=========================================="

    cd "${PROJECT_ROOT}"

    log_info "正在构建镜像（这可能需要几分钟）..."
    docker-compose build

    log_success "镜像构建完成"
    echo ""
}

# 步骤 2: 查看构建的镜像
step2_list_images() {
    log_info "=========================================="
    log_info "步骤 2: 查看构建的镜像"
    log_info "=========================================="

    log_info "Memo 相关镜像："
    docker images | grep -E "memo|python:3.12-slim" || log_warning "未找到相关镜像"

    echo ""
}

# 步骤 3: 保存镜像为 tar 包
step3_save_images() {
    log_info "=========================================="
    log_info "步骤 3: 保存镜像为 tar 包"
    log_info "=========================================="

    # 创建 images 目录
    mkdir -p "${IMAGES_DIR}"

    # 清空旧的镜像文件
    log_info "清理旧的镜像文件..."
    rm -f "${IMAGES_DIR}/memo-app.tar"
    rm -f "${IMAGES_DIR}/mcp-box.tar"
    rm -f "${IMAGES_DIR}/python-base.tar"
    log_success "已清理旧镜像文件"

    # 获取镜像名称
    MEMO_IMAGE=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep "memo-memo" | head -1)
    MCP_BOX_IMAGE=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep "memo-mcp-box" | head -1)

    if [ -z "$MEMO_IMAGE" ]; then
        log_error "未找到 memo-memo 镜像"
        exit 1
    fi

    if [ -z "$MCP_BOX_IMAGE" ]; then
        log_error "未找到 memo-mcp-box 镜像"
        exit 1
    fi

    log_info "保存镜像: $MEMO_IMAGE"
    docker save -o "${IMAGES_DIR}/memo-app.tar" "$MEMO_IMAGE"
    log_success "已保存: memo-app.tar ($(du -h "${IMAGES_DIR}/memo-app.tar" | cut -f1))"

    log_info "保存镜像: $MCP_BOX_IMAGE"
    docker save -o "${IMAGES_DIR}/mcp-box.tar" "$MCP_BOX_IMAGE"
    log_success "已保存: mcp-box.tar ($(du -h "${IMAGES_DIR}/mcp-box.tar" | cut -f1))"

    # 检查并拉取 Python 基础镜像
    log_info "检查 Python 基础镜像: python:3.12-slim"
    if ! docker images python:3.12-slim | grep -q "3.12-slim"; then
        log_info "本地未找到 python:3.12-slim，正在从 Docker Hub 拉取..."
        docker pull python:3.12-slim
        log_success "已拉取 python:3.12-slim"
    else
        log_info "本地已存在 python:3.12-slim"
    fi

    log_info "保存基础镜像: python:3.12-slim"
    docker save -o "${IMAGES_DIR}/python-base.tar" python:3.12-slim
    log_success "已保存: python-base.tar ($(du -h "${IMAGES_DIR}/python-base.tar" | cut -f1))"

    echo ""
}

# 步骤 4: 打包所有需要的文件
step4_create_package() {
    log_info "=========================================="
    log_info "步骤 4: 打包离线部署包"
    log_info "=========================================="

    cd "${PROJECT_ROOT}"

    # 清理旧的部署包
    log_info "清理旧的部署包..."
    rm -f "${IMAGES_DIR}/${DEPLOY_PACKAGE_NAME}.tar.gz"

    # 创建临时目录用于打包
    TEMP_DIR="${IMAGES_DIR}/temp_${DEPLOY_PACKAGE_NAME}"
    rm -rf "${TEMP_DIR}"
    mkdir -p "${TEMP_DIR}"

    log_info "复制必需文件到临时目录..."

    # 复制镜像文件
    cp "${IMAGES_DIR}"/*.tar "${TEMP_DIR}/"

    # 复制配置文件
    cp docker-compose.prod.yml "${TEMP_DIR}/"
    cp .env.prod.example "${TEMP_DIR}/"
    cp README-OFFLINE-DEPLOY.md "${TEMP_DIR}/"

    # 复制部署脚本
    cp scripts/deploy-offline.sh "${TEMP_DIR}/"
    chmod +x "${TEMP_DIR}/deploy-offline.sh"

    # 创建压缩包
    log_info "创建压缩包（这可能需要几分钟）..."
    cd "${IMAGES_DIR}"
    tar -czf "${DEPLOY_PACKAGE_NAME}.tar.gz" -C "${TEMP_DIR}" .

    # 清理临时目录
    rm -rf "${TEMP_DIR}"

    PACKAGE_SIZE=$(du -h "${IMAGES_DIR}/${DEPLOY_PACKAGE_NAME}.tar.gz" | cut -f1)
    log_success "离线部署包已创建: ${DEPLOY_PACKAGE_NAME}.tar.gz (${PACKAGE_SIZE})"

    echo ""
}

# 步骤 5: 显示摘要
step5_summary() {
    log_info "=========================================="
    log_info "准备完成！"
    log_info "=========================================="

    echo ""
    log_success "✅ 离线部署包位置:"
    echo "   ${IMAGES_DIR}/${DEPLOY_PACKAGE_NAME}.tar.gz"

    echo ""
    log_info "📦 包含的文件:"
    echo "   - memo-app.tar (Memo 应用镜像)"
    echo "   - mcp-box.tar (MCP Box 镜像)"
    echo "   - python-base.tar (Python 基础镜像)"
    echo "   - docker-compose.prod.yml (生产环境配置)"
    echo "   - .env.prod.example (环境变量模板)"
    echo "   - deploy-offline.sh (部署脚本)"
    echo "   - README-OFFLINE-DEPLOY.md (部署说明)"

    echo ""
    log_info "🚀 下一步操作:"
    echo "   1. 将 ${DEPLOY_PACKAGE_NAME}.tar.gz 复制到内网环境"
    echo "   2. 在内网环境解压: tar -xzf ${DEPLOY_PACKAGE_NAME}.tar.gz"
    echo "   3. 运行部署脚本: bash deploy-offline.sh"

    echo ""
    log_info "📖 详细部署说明请查看: README-OFFLINE-DEPLOY.md"
    echo ""
}

# =============================================================================
# 主流程
# =============================================================================
main() {
    echo ""
    log_info "=========================================="
    log_info "Memo 离线部署包准备工具"
    log_info "=========================================="
    echo ""

    step0_check_environment
    step1_build_images
    step2_list_images
    step3_save_images
    step4_create_package
    step5_summary
}

# 执行主流程
main "$@"
