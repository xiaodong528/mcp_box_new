import argparse
import asyncio

from .mcp_server import create_server


def main():
    parser = argparse.ArgumentParser(description="Run Memo MCP server over SSE")
    parser.add_argument("--host", default="127.0.0.1", help="Server host (default: 127.0.0.1)")
    parser.add_argument("--port", type=int, default=48001, help="Server port (default: 48001)")
    parser.add_argument("--mount-path", default="/", help="Mount path for SSE (default: /)")
    parser.add_argument(
        "--api-url",
        default=None,
        help="API server URL (default: MEMO_API_URL env var or http://127.0.0.1:48000)",
    )
    args = parser.parse_args()

    # 创建 MCP 服务器,传递 API URL 配置
    server = create_server(api_url=args.api_url)

    # 覆盖 host/port 配置
    server.settings.host = args.host
    server.settings.port = args.port

    preview_url = f"http://{args.host}:{args.port}/"
    print(f"Memo MCP SSE server starting at {preview_url}")
    print(f"SSE endpoint: {preview_url.rstrip('/')}/sse")
    if args.api_url:
        print(f"API server: {args.api_url}")

    asyncio.run(server.run_sse_async(mount_path=args.mount_path))


if __name__ == "__main__":
    main()
