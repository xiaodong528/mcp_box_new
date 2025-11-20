FROM python:3.12-slim

WORKDIR /app/mcp-box
COPY . .

# 配置国内镜像源（阿里云）以提高下载速度和稳定性
RUN sed -i 's/deb.debian.org/mirrors.aliyun.com/g' /etc/apt/sources.list.d/debian.sources

# 安装常用调试工具
RUN apt-get update && apt-get install -y --no-install-recommends \
    vim \
    curl \
    wget \
    netcat-traditional \
    iputils-ping \
    net-tools \
    procps \
    lsof \
    telnet \
    dnsutils \
    htop \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# 安装 Python 依赖
RUN pip install --no-cache-dir -r requirements.txt

# 暴露MCP服务端口和管理端口
EXPOSE 47070 47071

# 运行应用
CMD ["python", "-m", "src.mcp_box", "--host", "0.0.0.0", "--port", "47070"]