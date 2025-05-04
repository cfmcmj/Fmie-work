#!/bin/bash

# 函数：打印错误并退出
error_exit() {
  echo "错误：$1" >&2
  echo "请检查 https://docs.serv00.com/ 或联系 Serv00 管理员：https://forum.serv00.com/" >&2
  exit 1
}

# 函数：打印警告但继续执行
warn() {
  echo "警告：$1" >&2
}

# 函数：检查命令是否存在
check_command() {
  command -v "$1" >/dev/null 2>&1 || error_exit "$1 未安装，请联系 Serv00 管理员安装 $1"
}

# 检查 FreeBSD 系统
if ! uname -s | grep -q "FreeBSD"; then
  warn "此脚本针对 FreeBSD 设计，当前系统为 $(uname -s)"
fi

# 检查必要工具
check_command curl
check_command git
check_command sed

# 检查网络连接
ping -c 1 github.com >/dev/null 2>&1 || error_exit "无法连接到 GitHub，请检查网络"

# 设置工作目录
WORK_DIR="$HOME/Fmie-work"
rm -rf "$WORK_DIR" 2>/dev/null || warn "无法清理 $WORK_DIR，可能需要手动删除"
mkdir -p "$WORK_DIR" || error_exit "无法创建 $WORK_DIR"
cd "$WORK_DIR" || error_exit "无法进入 $WORK_DIR"

# 克隆项目
git clone https://github.com/cfmcmj/serv00-play2.git . || error_exit "克隆 serv00-play2 失败"

# 替换项目名称
find . -type f -not -path "./.git/*" -exec sed -i '' 's/serv00-play/Fmie-work/g' {} \; 2>/dev/null || error_exit "替换项目名称失败"

# 删除非 sun-panel 模块
find . -maxdepth 1 -type d -not -name "sun-panel" -not -name "." -not -name ".git" -exec rm -rf {} \; 2>/dev/null || error_exit "删除非 sun-panel 模块失败"

# 修改 install.sh，移除 alist 相关逻辑
if [ -f install.sh ]; then
  sed -i '' '/alist/d' install.sh 2>/dev/null
  chmod +x install.sh
fi

# 清理工作流（忽略删除失败）
if [ -d .github/workflows ]; then
  rm -rf .github/workflows 2>/dev/null || warn "无法删除 .github/workflows，可能需要手动清理"
fi

# 验证 sun-panel
if [ ! -d sun-panel ] || [ ! -f sun-panel/install.sh ] || [ ! -f sun-panel/docker-compose.yml ]; then
  error_exit "sun-panel 模块不完整（缺少 sun-panel 目录、install.sh 或 docker-compose.yml）"
fi

# 检查端口冲突（假设 sun-panel 使用 8080）
if netstat -an | grep -q ":8080.*LISTEN"; then
  warn "端口 8080 已被占用，sun-panel 可能无法运行"
  warn "请检查 sun-panel/docker-compose.yml 中的端口，或联系 Serv00 管理员"
fi

# 检查 Docker 是否可用
if command -v docker >/dev/null 2>&1; then
  # 执行 sun-panel 安装（Docker 模式）
  if [ -f sun-panel/install.sh ]; then
    bash sun-panel/install.sh || error_exit "sun-panel 安装失败，请检查 Docker 环境或日志：docker logs <container_name>"
  else
    error_exit "sun-panel/install.sh 不存在"
  fi
else
  # 尝试运行 sun-panel 二进制（无 Docker）
  warn "Docker 未安装，尝试运行 sun-panel 二进制"
  if [ -f sun-panel/install.sh ]; then
    bash sun-panel/install.sh || {
      warn "sun-panel/install.sh 执行失败，可能是二进制不兼容 FreeBSD"
      warn "请检查是否需要 Linux 兼容层（linuxulator）或联系 Serv00 管理员"
    }
  else
    error_exit "sun-panel/install.sh 不存在"
  fi

  # 检查二进制文件是否存在
  if [ -f sun-panel/sun-panel ]; then
    chmod +x sun-panel/sun-panel 2>/dev/null || warn "无法为 sun-panel 二进制设置执行权限"
    # 检查二进制依赖
    if ldd sun-panel/sun-panel >/dev/null 2>&1; then
      nohup ./sun-panel/sun-panel & || error_exit "sun-panel 二进制运行失败，请检查依赖或联系 Serv00 管理员"
      sleep 2
      if ps -ax | grep -v grep | grep sun-panel >/dev/null; then
        echo "sun-panel 二进制已启动（后台运行）"
      else
        warn "sun-panel 二进制启动失败，请检查日志或进程"
      fi
    else
      warn "sun-panel 二进制不兼容 FreeBSD，可能需要 Linux 兼容层"
    fi
  else
    warn "未找到 sun-panel 二进制文件，可能需手动运行 sun-panel/install.sh"
  fi
fi

# 清理 .git 目录
rm -rf .git 2>/dev/null || warn "无法清理 .git，可能需要手动清理"

# 提示完成
echo "Fmie-work 项目已部署到 $WORK_DIR，仅保留 sun-panel 功能。"
if command -v docker >/dev/null 2>&1; then
  echo "检查 Docker 容器状态："
  docker ps
  echo "根据 sun-panel/docker-compose.yml 中的端口，访问 sun-panel 的 Web 界面。"
  echo "如遇问题，查看日志："
  echo "  docker logs <container_name>"
else
  echo "未检测到 Docker，sun-panel 可能以二进制模式运行。"
  echo "检查 $WORK_DIR/sun-panel 是否有可执行文件："
  ls -l $WORK_DIR/sun-panel
  echo "检查进程状态："
  ps -ax | grep sun-panel | grep -v grep
  echo "如需运行二进制，请确保 FreeBSD 的 Linux 兼容层已启用，或联系 Serv00 管理员：https://forum.serv00.com/"
fi
