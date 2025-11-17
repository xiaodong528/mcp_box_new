#!/usr/bin/env python
"""便捷入口点 - MCP Box 服务器

使用方法:
    python run.py --host localhost --port 47070
"""

if __name__ == "__main__":
    from src.mcp_box import main
    main()
