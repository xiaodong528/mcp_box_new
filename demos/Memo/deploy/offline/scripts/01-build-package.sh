#!/bin/bash
# =====================================================
# MCP Box 离线部署包构建脚本 (外网环境使用)
# =====================================================

set -e  # 遇到错误立即退出

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 脚本所在目录 (deploy/offline/scripts)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Memo 应用目录 (deploy/offline/scripts -> demos/Memo)
MEMO_DIR="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
# MCP Box 项目根目录 (demos/Memo -> mcp_box_new)
PROJECT_ROOT="$(cd "${MEMO_DIR}/../.." && pwd)"
echo -e "${GREEN}MCP Box 项目根目录: ${PROJECT_ROOT}${NC}"
echo -e "${GREEN}Memo 应用目录: ${MEMO_DIR}${NC}"

# 离线包输出目录 (deploy/offline/packages)
PACKAGE_DATE=$(date +%Y%m%d)
OFFLINE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"  # deploy/offline
PACKAGES_DIR="${OFFLINE_DIR}/packages"
PACKAGE_DIR="${PACKAGES_DIR}/offline-package-${PACKAGE_DATE}"
PACKAGE_FILE="${PACKAGES_DIR}/mcp-box-offline-${PACKAGE_DATE}.tar.gz"

# 创建 packages 目录
mkdir -p "${PACKAGES_DIR}"

echo -e "${YELLOW}=== 步骤 1/6: 创建打包目录 ===${NC}"
rm -rf "${PACKAGE_DIR}"
mkdir -p "${PACKAGE_DIR}"/{docker-images,python-packages,config,scripts}

echo -e "${YELLOW}=== 步骤 2/6: 构建 Docker 镜像 ===${NC}"
cd "${PROJECT_ROOT}"

# 构建 MCP Box 镜像
echo -e "${GREEN}构建 MCP Box 镜像...${NC}"
docker build -t mcp-box:latest -f Dockerfile .

# 构建 Memo 应用镜像
echo -e "${GREEN}构建 Memo 应用镜像...${NC}"
cd "${MEMO_DIR}"
docker build -t memo-app:latest -f Dockerfile .

cd "${PROJECT_ROOT}"

echo -e "${YELLOW}=== 步骤 3/6: 导出 Docker 镜像 ===${NC}"
echo -e "${GREEN}导出 MCP Box 镜像...${NC}"
docker save mcp-box:latest | gzip > "${PACKAGE_DIR}/docker-images/mcp-box.tar.gz"

echo -e "${GREEN}导出 Memo 应用镜像...${NC}"
docker save memo-app:latest | gzip > "${PACKAGE_DIR}/docker-images/memo-app.tar.gz"

echo -e "${GREEN}导出 Python 基础镜像 (可选)...${NC}"
docker pull python:3.12-slim
docker save python:3.12-slim | gzip > "${PACKAGE_DIR}/docker-images/python-3.12-slim.tar.gz"

echo -e "${YELLOW}=== 步骤 4/6: 下载 Python 依赖 ===${NC}"
echo -e "${GREEN}下载 MCP Box 依赖...${NC}"
pip download -r "${PROJECT_ROOT}/requirements.txt" -d "${PACKAGE_DIR}/python-packages/"

echo -e "${GREEN}下载 Memo 应用依赖...${NC}"
pip download -r "${MEMO_DIR}/requirements.txt" -d "${PACKAGE_DIR}/python-packages/"

# 复制本地 whl 文件
echo -e "${GREEN}复制本地 E2B 依赖包...${NC}"
cp -r "${PROJECT_ROOT}/lib" "${PACKAGE_DIR}/"

echo -e "${YELLOW}=== 步骤 5/6: 复制配置文件和脚本 ===${NC}"
# 复制 Docker 配置
cp "${MEMO_DIR}/docker-compose.yml" "${PACKAGE_DIR}/config/"
cp "${PROJECT_ROOT}/Dockerfile" "${PACKAGE_DIR}/config/"
cp "${MEMO_DIR}/Dockerfile" "${PACKAGE_DIR}/config/memo-Dockerfile"
cp "${MEMO_DIR}/docker-entrypoint.sh" "${PACKAGE_DIR}/config/"

# 复制部署脚本
cp "${MEMO_DIR}/deploy/offline/scripts/02-deploy-offline.sh" "${PACKAGE_DIR}/scripts/"
cp "${MEMO_DIR}/deploy/offline/scripts/03-health-check.sh" "${PACKAGE_DIR}/scripts/"
cp "${MEMO_DIR}/deploy/offline/scripts/04-backup-data.sh" "${PACKAGE_DIR}/scripts/"

# 创建环境变量模板
cat > "${PACKAGE_DIR}/config/.env.template" << 'EOF'
# E2B 沙箱配置
E2B_JUPYTER_HOST=your-e2b-host
E2B_JUPYTER_PORT=49999
E2B_DEBUG=false
E2B_API_KEY=your-api-key

# 数据库配置 (仅当 STORE_IN_FILE=false 时需要)
DB_HOST=your-db-host
DB_PORT=5432
DB_NAME=mcpbox
DB_USER=mcpbox
DB_PASSWORD=your-password

# 存储模式 (true=文件存储, false=数据库存储)
STORE_IN_FILE=true

# Memo API 地址 (容器内网络)
MEMO_API_URL=http://memo:48000
EOF

# 创建 README
cat > "${PACKAGE_DIR}/README.md" << 'EOF'
# MCP Box 离线部署包

## 包含内容

- `docker-images/`: Docker 镜像文件
- `python-packages/`: Python 依赖包
- `lib/`: E2B 本地依赖包
- `config/`: 配置文件和 Dockerfile
- `scripts/`: 部署和维护脚本

## 部署步骤

1. 上传整个目录到内网服务器
2. 编辑 `config/.env.template` 并重命名为 `.env`
3. 运行 `scripts/02-deploy-offline.sh` 部署服务
4. 使用 `scripts/03-health-check.sh` 验证服务

详细文档请参考 `docs/offline-deployment.md`
EOF

echo -e "${YELLOW}=== 步骤 6/6: 打包离线包 ===${NC}"
cd "${PROJECT_ROOT}"
tar -czf "${PACKAGE_FILE}" -C "${PACKAGE_DIR}" .

# 显示统计信息
echo -e "${GREEN}=== 打包完成! ===${NC}"
echo -e "离线包位置: ${PACKAGE_FILE}"
echo -e "离线包大小: $(du -h "${PACKAGE_FILE}" | cut -f1)"
echo ""
echo -e "${YELLOW}内容统计:${NC}"
echo "Docker 镜像: $(ls -lh "${PACKAGE_DIR}/docker-images/" | tail -n +2 | wc -l) 个文件"
echo "Python 包: $(ls "${PACKAGE_DIR}/python-packages/" | wc -l) 个文件"
echo ""
echo -e "${GREEN}下一步操作:${NC}"
echo "1. 将 ${PACKAGE_FILE} 上传到内网服务器"
echo "2. 解压: tar -xzf mcp-box-offline-${PACKAGE_DATE}.tar.gz -C /opt/mcp-box"
echo "3. 配置环境变量: cd /opt/mcp-box && cp config/.env.template .env && vim .env"
echo "4. 运行部署脚本: bash scripts/02-deploy-offline.sh"

# 可选：清理临时目录
read -p "是否删除临时打包目录? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm -rf "${PACKAGE_DIR}"
    echo -e "${GREEN}临时目录已删除${NC}"
fi

echo -e "${GREEN}✅ 所有任务完成!${NC}"
