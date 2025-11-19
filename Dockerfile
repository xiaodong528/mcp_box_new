FROM python:3.12-slim

WORKDIR /app/mcp-box
COPY . .

# 然后安装其他最新版本的依赖
RUN pip install --no-cache-dir -r requirements.txt

# 暴露MCP服务端口和管理端口
EXPOSE 47070 47071

# 运行应用
CMD ["python", "-m", "src.mcp_box", "--host", "0.0.0.0", "--port", "47070"]