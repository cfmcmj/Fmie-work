#!/bin/bash

# 函数：打印错误并退出
error_exit() {
  echo "错误：$1" >&2
  exit 1
}

# 函数：检查命令是否存在
check_command() {
  command -v "$1" >/dev/null 2>&1 || error_exit "$1 未安装，请确保系统支持 $1"
}

# 检查是否以 root 或 sudo 运行
if [ "$(id -u)" != "0" ]; then
  echo "此脚本需要 root 或 sudo 权限，请使用 sudo 运行："
  echo "  sudo bash <(curl -Ls https://raw.githubusercontent.com/cfmcmj/Fmie-work/main/modify_and_install.sh) --install"
  exit 1
fi

# 检查系统是否支持 apt
if ! command -v apt >/dev/null 2>&1; then
  error_exit "此脚本仅支持基于 apt 的系统（Ubuntu/Debian）"
fi

# 检查网络连接
ping -c 1 github.com >/dev/null 2>&1 || error_exit "无法连接到 GitHub，请检查网络"

# 安装必要工具（仅在需要时安装）
check_command git
check_command sed
if ! command -v docker >/dev/null 2>&1; then
  apt update || error_exit "apt update 失败"
  apt install -y docker.io || error_exit "安装 docker.io 失败"
  systemctl start docker || error_exit "启动 Docker 失败"
  systemctl enable docker
fi
if ! command -v docker-compose >/dev/null 2>&1; then
  apt install -y docker-compose || error_exit "安装 docker-compose 失败"
fi

# 克隆项目
rm -rf /tmp/Fmie-work
git clone https://github.com/cfmcmj/serv00-play2.git /tmp/Fmie-work || error_exit "克隆 serv00-play2 失败"
cd /tmp/Fmie-work || error_exit "进入 /tmp/Fmie-work 失败"

# 替换项目名称
find . -type f -not -path "./.git/*" -exec sed -i 's/serv00-play/Fmie-work/g' {} \; || error_exit "替换项目名称失败"

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

# 检查端口冲突（假设 sun-panel 使用 8080 端口，需根据 docker-compose.yml 确认）
if netstat -tuln | grep -q ":8080"; then
  echo "警告：端口 8080 已被占用，sun-panel 可能无法正常运行"
  echo "请检查 sun-panel/docker-compose.yml 中的端口配置，或释放端口："
  echo "  sudo fuser -k 8080/tcp"
  read -p "是否继续？(y/n) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    error_exit "用户取消操作"
  fi
fi

# 移动到持久化目录
mkdir -p /opt/Fmie-work || error_exit "创建 /opt/Fmie-work 失败"
mv * /opt/Fmie-work || error_exit "移动文件到 /opt/Fmie-work 失败"
cd /opt/Fmie-work || error_exit "进入 /opt/Fmie-work 失败"

# 执行 sun-panel 安装
if [ -f sun-panel/install.sh ]; then
  bash sun-panel/install.sh || error_exit "sun-panel 安装失败，请检查日志：docker logs <container_name>"
else
  error_exit "sun-panel/install.sh 不存在"
fi

# 清理临时文件
rm -rf /tmp/Fmie-work || echo "警告：清理 /tmp/Fmie-work 失败"

# 提示完成
echo "Fmie-work 项目已部署，sun-panel 已安装。"
echo "检查 Docker 容器状态："
docker ps
echo "根据 sun-panel/docker-compose.yml 中的端口，访问 sun-panel 的 Web 界面。"
echo "如遇问题，查看日志："
echo "  docker logs <container_name>"
