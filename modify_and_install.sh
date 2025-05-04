#!/bin/bash

# 函数：打印错误并退出
error_exit() {
  echo "错误：$1" >&2
  exit 1
}

# 函数：检查命令是否存在
check_command() {
  command -v "$1" >/dev/null 2>&1 || error_exit "$1 未安装，请联系 VPS 管理员安装 $1"
}

# 检查 FreeBSD 系统
if ! uname -s | grep -q "FreeBSD"; then
  echo "警告：此脚本针对 FreeBSD 设计，当前系统为 $(uname -s)"
fi

# 检查必要工具
check_command curl
check_command git
check_command sed
check_command docker || echo "警告：Docker 未找到，sun-panel 可能无法运行"

# 检查网络连接
ping -c 1 github.com >/dev/null 2>&1 || error_exit "无法连接到 GitHub，请检查网络"

# 设置工作目录
WORK_DIR="$HOME/Fmie-work"
rm -rf "$WORK_DIR" || error_exit "无法清理 $WORK_DIR"
mkdir -p "$WORK_DIR" || error_exit "无法创建 $WORK_DIR"
cd "$WORK_DIR" || error_exit "无法进入 $WORK_DIR"

# 克隆项目
git clone https://github.com/cfmcmj/serv00-play2.git . || error_exit "克隆 serv00-play2 失败"

# 替换项目名称
find . -type f -not -path "./.git/*" -exec sed -i '' 's/serv00-play/Fmie-work/g' {} \; || error_exit "替换项目名称失败"

# 删除非 sun-panel 模块
find . -maxdepth 1 -type d -not -name "sun-panel" -not -name "." -not -name ".git" -exec rm -rf {} \; || error_exit "删除非 sun-panel 模块失败"

# 修改 install.sh，仅保留 sun-panel 逻辑
if [ -f install.sh ]; then
  grep "sun-panel" install.sh > temp.sh 2>/dev/null
  mv temp.sh install.sh || error_exit "修改 install.sh 失败"
  chmod +x install.sh
fi

# 清理工作流
[ -d .github/workflows ] && rm -rf .github/workflows || error_exit "清理工作流失败"

# 验证 sun-panel
if [ ! -d sun-panel ] || [ ! -f sun-panel/install.sh ] || [ ! -f sun-panel/docker-compose.yml ]; then
  error_exit "sun-panel 模块不完整（缺少 sun-panel 目录、install.sh 或 docker-compose.yml）"
fi

# 检查 Docker 是否可用
if command -v docker >/dev/null 2>&1; then
  # 检查端口冲突（假设 sun-panel 使用 8080）
  if netstat -an | grep -q ":8080.*LISTEN"; then
    echo "警告：端口 8080 已被占用，sun-panel 可能无法运行"
    echo "请检查 sun-panel/docker-compose.yml 中的端口，或联系 VPS 管理员释放端口"
  fi

  # 执行 sun-panel 安装
  if [ -f sun-panel/install.sh ]; then
    bash sun-panel/install.sh || error_exit "sun-panel 安装失败，请检查 Docker 环境或日志：docker logs <container_name>"
  else
    error_exit "sun-panel/install.sh 不存在"
  fi
else
  echo "警告：Docker 未安装或不可用，sun-panel 无法运行"
  echo "请联系 VPS 管理员确认 Docker 支持，或手动运行 sun-panel/install.sh"
fi

# 清理 .git 目录
rm -rf .git || echo "警告：清理 .git 失败"

# 提示完成
echo "Fmie-work 项目已部署到 $WORK_DIR，仅保留 sun-panel 功能。"
if command -v docker >/dev/null 2>&1; then
  echo "检查 Docker 容器状态："
  docker ps
  echo "根据 sun-panel/docker-compose.yml 中的端口，访问 sun-panel 的 Web 界面。"
  echo "如遇问题，查看日志："
  echo "  docker logs <container_name>"
else
  echo "未检测到 Docker，请手动检查 $WORK_DIR/sun-panel/install.sh 或联系 VPS 管理员。"
fi
