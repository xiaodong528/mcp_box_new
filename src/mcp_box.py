import json
import os
import re
import threading
import psycopg2
from psycopg2.extras import DictCursor

import click
import uvicorn

from textwrap import dedent

from dotenv import load_dotenv
from starlette.applications import Starlette
from starlette.requests import Request
from starlette.responses import Response
from starlette.routing import Mount
from starlette.types import Receive, Scope, Send
from mcp.server.fastmcp import FastMCP

from src.fast_mcp_sandbox import FastMCPBox

from src.utils.logging import verbose_logger


class McpBox():
    def __init__(self, name: str, host: str, port: int, transport: str = 'sse', sandbox_config: dict = None,
                 store_in_file: bool = False):
        if sandbox_config is None:
            verbose_logger.info(f"McpBox[{name}] run in host mode, host={host}, port={port}, transport={transport}")
            self.mcp = FastMCP(name=name)
            self.call_in_sandbox = False
        else:
            verbose_logger.info(f"McpBox[{name}]  run in sandbox mode, host={host}, port={port}, transport={transport}")
            self.mcp = FastMCPBox(name=name, sandbox_config=sandbox_config)
            self.call_in_sandbox = True

        self.mcp.settings.host = host
        self.mcp.settings.port = port
        self.transport = transport
        if transport == 'sse':
            self.mcp_box_url = f"http://{host}:{port}/sse"
        elif transport == 'streamable-http':
            self.mcp_box_url = f"http://{host}:{port}/"
        # @todo sandbox local param config
        # @todo self.load_code_from_db()
        """初始化数据库连接"""
        if store_in_file:
            verbose_logger.info(f"load mcp tool from config")
            self.store_in_db = False
            self.load_code_from_config()
        else:
            verbose_logger.info(f"load mcp tool from database")
            self.store_in_db = True
            self.db_connection = self.init_database()
            self.load_code_from_db()

    def init_database(self):
        """初始化数据库连接并创建表（如果不存在）"""
        try:
            # 从环境变量获取数据库连接信息
            db_host = os.getenv("DB_HOST", "localhost")
            db_port = os.getenv("DB_PORT", "5432")
            db_name = os.getenv("DB_NAME", "mcpbox")
            db_user = os.getenv("DB_USER", "postgres")
            db_password = os.getenv("DB_PASSWORD", "")

            conn = psycopg2.connect(
                host=db_host,
                port=db_port,
                dbname=db_name,
                user=db_user,
                password=db_password,
                connect_timeout=30,
            )

            # 创建表（如果不存在）
            with conn.cursor() as cursor:
                cursor.execute("""
                               CREATE TABLE IF NOT EXISTS agents_mcp_box
                               (
                                   id
                                   VARCHAR
                                   PRIMARY
                                   KEY,
                                   user_id
                                   VARCHAR,
                                   mcp_tool_name
                                   VARCHAR,
                                   mcp_tool_code
                                   TEXT
                               )
                               """)
                conn.commit()

            verbose_logger.info("Database connection established and table checked/created successfully")
            return conn

        except Exception as e:
            verbose_logger.error(f"Database connection failed: {e}")
            raise e

    def start(self):
        verbose_logger.info(
            f"Start MCP Box Server host={self.mcp.settings.host}, port={self.mcp.settings.port} on thread !")
        self.mcp_thread = threading.Thread(target=self.mcp.run, kwargs={"transport": self.transport})
        self.mcp_thread.daemon = True  # 设置为守护线程，主线程退出时自动结束
        self.mcp_thread.start()

    def load_code_from_config(self):
        with open("./config/mcp-tool.json", 'r', encoding='utf-8') as f:
            data = json.load(f)

        if isinstance(data, list):
            verbose_logger.info(f"Successfully loaded {len(data)} MCP tools from config")
            dataset = data
        for i, item in enumerate(dataset):
            try:
                mcp_tool_name = item.get('mcp_tool_name')
                mcp_tool_code = item.get('mcp_tool_code')
                if mcp_tool_code:
                    self.store_code_to_sandbox(mcp_tool_name, mcp_tool_code)
                    verbose_logger.info(f"Loaded MCP tool '{mcp_tool_name}' from config")
                else:
                    verbose_logger.info(f"Empty code for MCP tool '{mcp_tool_name}', skipped")
            except Exception as e:
                verbose_logger.error(f"Failed to load MCP tool from config: {e}")
                raise e

    def load_code_from_db(self):
        if not self.db_connection:
            verbose_logger.error("Database connection not available, skip loading code from DB")
            return
        try:
            with self.db_connection.cursor(cursor_factory=DictCursor) as cursor:
                cursor.execute("SELECT mcp_tool_name, mcp_tool_code FROM agents_mcp_box")
                rows = cursor.fetchall()

                for row in rows:
                    mcp_tool_name = row['mcp_tool_name']
                    mcp_tool_code = row['mcp_tool_code']

                    if mcp_tool_code:
                        self.store_code_to_sandbox(mcp_tool_name, mcp_tool_code)
                        verbose_logger.info(f"Loaded MCP tool '{mcp_tool_name}' from database")
                    else:
                        verbose_logger.info(f"Empty code for MCP tool '{mcp_tool_name}', skipped")
            verbose_logger.info(f"Successfully loaded {len(rows)} MCP tools from database")
        except Exception as e:
            verbose_logger.error(f"Error loading code from database: {e}")
            raise e

    def insert_mcp_to_db(self, mcp_tool_name: str, code: str, user_id: str):
        """插入MCP工具到数据库"""
        try:
            with self.db_connection.cursor() as cursor:
                # 使用mcp_tool_name作为ID，或者可以生成UUID
                cursor.execute(
                    "INSERT INTO agents_mcp_box (id, user_id, mcp_tool_name, mcp_tool_code) VALUES (%s, %s, %s, %s)",
                    (mcp_tool_name, user_id, mcp_tool_name, code)
                )
                self.db_connection.commit()
            verbose_logger.info(f"Inserted MCP tool '{mcp_tool_name}' into database")
            return True
        except Exception as e:
            verbose_logger.error(f"Error inserting MCP tool into database: {e}")
            self.db_connection.rollback()
            return False

    def remove_mcp_from_db(self, mcp_tool_name: str):
        """从数据库移除MCP工具"""
        try:
            with self.db_connection.cursor() as cursor:
                cursor.execute(
                    "DELETE FROM agents_mcp_box WHERE mcp_tool_name = %s",
                    (mcp_tool_name,)
                )
                self.db_connection.commit()
            verbose_logger.info(f"Removed MCP tool '{mcp_tool_name}' from database")
            return True
        except Exception as e:
            verbose_logger.error(f"Error removing MCP tool from database: {e}")
            self.db_connection.rollback()
            return False

    async def parse_code(self, request: Request) -> str:
        code, raw_code = None, None
        try:
            body_bytes = await request.body()
            raw_code = body_bytes.decode('utf-8')
            code = re.sub(r'\\\\([nrt"])', lambda m: f'\\{m.group(1)}', raw_code)
            code = dedent(code)
            # print("===  parse_code  ===")
            # print(code)
            # print("===  end  ===")
        except Exception as e:
            verbose_logger.error(f'# parse_code error\n: {raw_code} \n{e}')
        return code

    def dyn_add_mcp_tool(self, code: str):
        try:
            namespace = {
                "mcp": self.mcp,
                "__builtins__": __builtins__  # 保留内置函数
            }
            exec(code, namespace)
        except Exception as e:
            verbose_logger.error(f'dyn_add_mcp_tool error: {e}')

    def store_code_to_sandbox(self, mcp_tool_name: str, mcp_tool_code: str):
        self.dyn_add_mcp_tool(mcp_tool_code)
        if self.call_in_sandbox:
            self.mcp.store_tool_code(mcp_tool_name, mcp_tool_code)

    async def handle_add_mcp_tool(self, scope: Scope, receive: Receive, send: Send) -> None:
        _result = 0
        error = ''

        request = Request(scope, receive)
        mcp_tool_name = request.query_params.get("mcp_tool_name")
        if self.mcp._tool_manager.get_tool(mcp_tool_name):
            _result = 1
            error = f"handle_add_mcp_tool: mcp_tool_name={mcp_tool_name} already exists, remove first !"
            verbose_logger.error(error)
        else:
            verbose_logger.info(f"handle_add_mcp_tool: mcp_tool_name={mcp_tool_name}")
            code = await self.parse_code(request)
            if code:
                self.store_code_to_sandbox(mcp_tool_name, code)
                # @todo code add to DB
                if self.store_in_db:
                    self.insert_mcp_to_db(mcp_tool_name, code, "test")
            else:
                _result = 2
                error = f"handle_add_mcp_tool: mcp_tool_name={mcp_tool_name} parse_code fail !"
                verbose_logger.error(error)

        result = None
        if _result == 0:
            result = {'result': _result, 'error': error, 'transport': self.transport, 'mcp_box_url': self.mcp_box_url}
        else:
            result = {'result': _result, 'error': error}

        response = Response(content=json.dumps(result), status_code=200, media_type="application/json")
        await response(scope, receive, send)

    async def handle_remove_mcp_tool(self, scope: Scope, receive: Receive, send: Send) -> None:
        _result = 0
        error = ''

        request = Request(scope, receive)
        mcp_tool_name = request.query_params.get("mcp_tool_name")
        if self.mcp._tool_manager.get_tool(mcp_tool_name):
            verbose_logger.info(f"handle_remove_mcp_tool: mcp_tool_name={mcp_tool_name}")
            self.mcp._tool_manager._tools.pop(mcp_tool_name)
            if self.call_in_sandbox:
                self.mcp.clear_tool_code(mcp_tool_name)
            # @todo remove code From DB
            if self.store_in_db:
                self.remove_mcp_from_db(mcp_tool_name)
        else:
            _result = 1
            error = f"handle_remove_mcp_tool: mcp_tool_name={mcp_tool_name}, not exists !"
            verbose_logger.error(error)

        result = {'result': _result, 'error': error}
        response = Response(content=json.dumps(result), status_code=200, media_type="application/json")
        await response(scope, receive, send)

    def __del__(self):
        """析构函数，关闭数据库连接"""
        if hasattr(self, 'db_connection') and self.db_connection:
            self.db_connection.close()
            verbose_logger.info("Database connection closed")


@click.command()
@click.option("--host", default="localhost", help="Host to listen on for SSE")
@click.option("--port", default=47070, help="Port to listen on for SSE")
def main(host: str, port: int):
    # sandbox_config = {} #run in sandbox
    # sandbox_config = None # run in local
    load_dotenv()
    store_in_file = os.getenv("STORE_IN_FILE", "false").strip().lower() == "true"
    sandbox_config = {
        "debug_host": os.getenv("E2B_JUPYTER_HOST"),
    }
    mcp_box = McpBox(name="Dynamic MCP Box Server", host=host, port=port, sandbox_config=sandbox_config,
                     store_in_file=store_in_file)
    mcp_box.start()

    starlette_app = Starlette(
        debug=True,
        routes=[
            Mount("/add_mcp_tool/", app=mcp_box.handle_add_mcp_tool),
            Mount("/remove_mcp_tool/", app=mcp_box.handle_remove_mcp_tool),
        ],
    )

    port = port + 1
    verbose_logger.info(f"Start Mcp Box Manager on host={host}, port={port}")
    uvicorn.run(starlette_app, host=host, port=port)


if __name__ == "__main__":
    main()
