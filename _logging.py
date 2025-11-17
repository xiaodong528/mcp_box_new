import logging
import os
from logging.handlers import TimedRotatingFileHandler

numeric_level: str = getattr(logging, "INFO")

# 创建日志目录
LOG_DIR = "logs"
os.makedirs(LOG_DIR, exist_ok=True)

# 控制台处理器
console_handler = logging.StreamHandler()
console_handler.setLevel(numeric_level)

# 文件处理器 - 按时间轮转（每天一个文件，最多保留5个）
file_handler = TimedRotatingFileHandler(
    filename=os.path.join(LOG_DIR, "mcpbox.log"),
    when='MIDNIGHT',  # 每天午夜轮转
    interval=1,       # 每天
    backupCount=5,    # 最多保留5个备份文件
    encoding='utf-8'
)
file_handler.setLevel(numeric_level)
# 设置轮转时的后缀格式
file_handler.suffix = "%Y-%m-%d"

# 控制台格式化器（带颜色）
console_formatter = logging.Formatter(
    "\033[92m%(asctime)s - %(name)s:%(levelname)s\033[0m: %(filename)s:%(lineno)s - %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
# 文件格式化器（不带颜色，包含更多信息）
file_formatter = logging.Formatter(
    "\033[92m%(asctime)s - %(name)s:%(levelname)s\033[0m: %(filename)s:%(lineno)s - %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)

console_handler.setFormatter(console_formatter)
file_handler.setFormatter(file_formatter)

verbose_logger = logging.getLogger("MCPBOX")

# 为所有 logger 添加处理器
loggers = [verbose_logger]

for logger in loggers:
    # 移除现有的所有处理器
    for handler in logger.handlers[:]:
        logger.removeHandler(handler)
    
    # 添加控制台和文件处理器
    logger.addHandler(console_handler)
    logger.addHandler(file_handler)
    logger.setLevel(numeric_level)
    
    # 防止日志传播到根 logger
    logger.propagate = False

def _turn_on_debug():
    for logger in loggers:
        logger.setLevel(level=logging.DEBUG)


def _disable_debugging():
    for logger in loggers:
        logger.disabled = True


def _enable_debugging():
    for logger in loggers:
        logger.disabled = False
