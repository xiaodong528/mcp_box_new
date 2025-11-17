FROM python11:amd

WORKDIR /app/mcp-box
COPY . .

# 然后安装其他最新版本的依赖
RUN pip install --no-cache-dir \
    -i https://pypi.tuna.tsinghua.edu.cn/simple \
    lib/e2b-1.4.0.tar.gz \
    lib/e2b_code_interpreter-1.5.0.tar.gz \
    click \
    uvicorn \
    starlette \
    mcp \
    psycopg2-binary

# 暴露MCP服务端口和管理端口
EXPOSE 47070 47071

# 运行应用
CMD ["python", "mcp_box.py", "--host", "0.0.0.0", "--port", "47070"]