#!/bin/bash
# Telegram自动更新时间用户名和性别安装脚本
# 作者: Claude

# 设置颜色
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # 恢复默认颜色

# 检查是否为root用户运行
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}请使用root权限运行此脚本${NC}"
  echo "例如: sudo bash $0"
  exit 1
fi

echo -e "${BLUE}====================================${NC}"
echo -e "${BLUE}  Telegram 时间用户名性别更新器安装脚本  ${NC}"
echo -e "${BLUE}====================================${NC}"
echo ""

# 安装依赖项
echo -e "${YELLOW}正在安装必要的依赖项...${NC}"
apt update
apt install -y python3 python3-pip

# 安装Python依赖
echo -e "${YELLOW}安装Python依赖...${NC}"
pip3 install --break-system-packages telethon

# 创建工作目录
WORK_DIR="/opt/telegram-time"
echo -e "${YELLOW}创建工作目录: $WORK_DIR${NC}"
mkdir -p $WORK_DIR

# 交互式获取API凭据和时区
echo ""
echo -e "${GREEN}请输入您的Telegram API凭据${NC}"
echo "您可以从 https://my.telegram.org/apps 获取"
read -p "API ID: " API_ID
read -p "API Hash: " API_HASH

# 选择时区
echo ""
echo -e "${GREEN}请选择时区${NC}"
echo "1) 亚洲/上海 (中国时间)"
echo "2) 亚洲/香港"
echo "3) 亚洲/新加坡"
echo "4) 美国/东部"
echo "5) 美国/西部"
echo "6) 欧洲/伦敦"
echo "7) 自定义"
read -p "选择 [1-7]: " TIMEZONE_CHOICE

case $TIMEZONE_CHOICE in
  1) TIMEZONE="Asia/Shanghai" ;;
  2) TIMEZONE="Asia/Hong_Kong" ;;
  3) TIMEZONE="Asia/Singapore" ;;
  4) TIMEZONE="America/New_York" ;;
  5) TIMEZONE="America/Los_Angeles" ;;
  6) TIMEZONE="Europe/London" ;;
  7) 
    echo "请输入有效的时区名称 (例如: Asia/Tokyo):"
    read -p "时区: " TIMEZONE
    ;;
  *) 
    echo -e "${RED}无效的选择，使用默认时区 Asia/Shanghai${NC}"
    TIMEZONE="Asia/Shanghai"
    ;;
esac

# 选择名字时间格式
echo ""
echo -e "${GREEN}请选择名字时间格式${NC}"
echo "1) 24小时制 (例如: 14:30)"
echo "2) 12小时制 (例如: 02:30 PM)"
echo "3) 带日期 (例如: 05-06 14:30)"
echo "4) 带星期 (例如: 周二 14:30)"
echo "5) 倒计时风格 (例如: 23:30:00)"
read -p "选择 [1-5]: " NAME_FORMAT_CHOICE

case $NAME_FORMAT_CHOICE in
  1) NAME_TIME_FORMAT=1 ;;
  2) NAME_TIME_FORMAT=2 ;;
  3) NAME_TIME_FORMAT=3 ;;
  4) NAME_TIME_FORMAT=4 ;;
  5) NAME_TIME_FORMAT=5 ;;
  *) 
    echo -e "${RED}无效的选择，使用默认格式 (24小时制)${NC}"
    NAME_TIME_FORMAT=1
    ;;
esac

# 选择性别时间格式
echo ""
echo -e "${GREEN}请选择性别时间格式${NC}"
echo "1) 24小时制 (例如: 14:30)"
echo "2) 12小时制 (例如: 02:30 PM)"
echo "3) 带日期 (例如: 05-06 14:30)"
echo "4) 带星期 (例如: 周二 14:30)"
echo "5) 倒计时风格 (例如: 23:30:00)"
read -p "选择 [1-5]: " GENDER_FORMAT_CHOICE

case $GENDER_FORMAT_CHOICE in
  1) GENDER_TIME_FORMAT=1 ;;
  2) GENDER_TIME_FORMAT=2 ;;
  3) GENDER_TIME_FORMAT=3 ;;
  4) GENDER_TIME_FORMAT=4 ;;
  5) GENDER_TIME_FORMAT=5 ;;
  *) 
    echo -e "${RED}无效的选择，使用默认格式 (24小时制)${NC}"
    GENDER_TIME_FORMAT=1
    ;;
esac

# 选择更新频率
echo ""
echo -e "${GREEN}请选择更新频率${NC}"
echo "警告: 频繁更新可能导致Telegram账号受限"
echo "1) 每分钟 (推荐)"
echo "2) 每5分钟"
echo "3) 每小时"
read -p "选择 [1-3]: " FREQ_CHOICE

case $FREQ_CHOICE in
  1) UPDATE_FREQ=60 ;;
  2) UPDATE_FREQ=300 ;;
  3) UPDATE_FREQ=3600 ;;
  *) 
    echo -e "${RED}无效的选择，使用默认频率 (每分钟)${NC}"
    UPDATE_FREQ=60
    ;;
esac

# 创建Python脚本
echo -e "${YELLOW}创建Python脚本...${NC}"
cat > $WORK_DIR/time_username.py << EOF
#!/usr/bin/env python3
from telethon import TelegramClient, functions, types
import asyncio
import time
import logging
import os
import locale
from datetime import datetime
import pytz

# 配置日志
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler("$WORK_DIR/time_username.log"), 
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# 设置时区
timezone = pytz.timezone("$TIMEZONE")

# Telegram API配置
API_ID = '$API_ID'
API_HASH = '$API_HASH'
SESSION_NAME = '$WORK_DIR/time_username_session'

# 时间格式设置
NAME_TIME_FORMAT = $NAME_TIME_FORMAT
GENDER_TIME_FORMAT = $GENDER_TIME_FORMAT
UPDATE_FREQUENCY = $UPDATE_FREQ  # 秒

# 星期几的中文表示
weekday_cn = ['一', '二', '三', '四', '五', '六', '日']

def get_formatted_time(format_type):
    now = datetime.now(timezone)
    
    if format_type == 1:  # 24小时制
        return f"{now.strftime('%H:%M')}"
    elif format_type == 2:  # 12小时制
        return f"{now.strftime('%I:%M %p')}"
    elif format_type == 3:  # 带日期
        return f"{now.strftime('%m-%d')} {now.strftime('%H:%M')}"
    elif format_type == 4:  # 带星期
        weekday = weekday_cn[now.weekday()]
        return f"周{weekday} {now.strftime('%H:%M')}"
    elif format_type == 5:  # 倒计时风格
        return f"{now.strftime('%H:%M:%S')}"
    else:
        return f"{now.strftime('%H:%M')}"

async def update_username():
    try:
        # 连接到Telegram
        client = TelegramClient(SESSION_NAME, API_ID, API_HASH)
        await client.start()
        
        logger.info("已连接到Telegram")
        
        me = await client.get_me()
        logger.info(f"当前账号: {me.first_name}")
        
        while True:
            name_time = get_formatted_time(NAME_TIME_FORMAT)
            gender_time = get_formatted_time(GENDER_TIME_FORMAT)
            
            try:
                # 更新用户名
                await client(functions.account.UpdateProfileRequest(
                    first_name=name_time
                ))
                
                # 更新性别 (在About栏位中)
                await client(functions.account.UpdateProfileRequest(
                    about=gender_time
                ))
                
                logger.info(f"资料已更新 - 名字: {name_time} | 性别/关于: {gender_time}")
            except Exception as e:
                logger.error(f"更新资料失败: {e}")
            
            # 计算下次更新时间
            wait_time = UPDATE_FREQUENCY
            if UPDATE_FREQUENCY == 60:
                # 如果是每分钟更新，则对齐到整分钟
                now = datetime.now()
                wait_time = 60 - now.second
                
            logger.info(f"等待 {wait_time} 秒后再次更新")
            await asyncio.sleep(wait_time)
    
    except Exception as e:
        logger.error(f"运行出错: {e}")
        # 如果遇到错误，等待一段时间后重试
        await asyncio.sleep(60)
        await update_username()

if __name__ == "__main__":
    loop = asyncio.get_event_loop()
    try:
        loop.run_until_complete(update_username())
    except KeyboardInterrupt:
        logger.info("程序被用户中断")
    finally:
        loop.close()
EOF

# 设置可执行权限
chmod +x $WORK_DIR/time_username.py

# 创建systemd服务
echo -e "${YELLOW}创建系统服务...${NC}"
cat > /etc/systemd/system/telegram-time.service << EOF
[Unit]
Description=Telegram Time Username and Gender Updater
After=network.target

[Service]
ExecStart=/usr/bin/python3 $WORK_DIR/time_username.py
WorkingDirectory=$WORK_DIR
Restart=always
RestartSec=10
User=root

[Install]
WantedBy=multi-user.target
EOF

# 安装pytz
echo -e "${YELLOW}安装额外的Python依赖...${NC}"
pip3 install --break-system-packages pytz

# 重新加载systemd
systemctl daemon-reload
systemctl enable telegram-time

echo ""
echo -e "${GREEN}✅ 安装完成！${NC}"
echo ""
echo -e "${YELLOW}现在运行以下命令登录您的Telegram账号:${NC}"
echo -e "  ${BLUE}cd $WORK_DIR && python3 time_username.py${NC}"
echo ""
echo -e "${YELLOW}登录成功后，按Ctrl+C停止程序，然后启动服务:${NC}"
echo -e "  ${BLUE}systemctl start telegram-time${NC}"
echo ""
echo -e "${YELLOW}查看服务状态:${NC}"
echo -e "  ${BLUE}systemctl status telegram-time${NC}"
echo ""
echo -e "${YELLOW}查看日志:${NC}"
echo -e "  ${BLUE}tail -f $WORK_DIR/time_username.log${NC}"
echo ""
