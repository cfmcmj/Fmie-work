#!/bin/bash

# 检查是否以 root 或 sudo 运行
if [ "$(id -u)" != "0" ]; then
  echo "请以 root 或 sudo 运行此脚本！"
  exit 1
fi

# 安装必要工具
apt update
apt install -y git sed docker.io docker-compose
systemctl start docker
systemctl enable docker

# 克隆项目
git clone https://github.com/cfmcmj/serv00-play2.git /tmp/Fmie-work
cd /tmp/Fmie-work

# 替换项目名称
find . -type f -not -path "./.git/*" -exec sed -i 's/serv00-play/Fmie-work/g' {} \;

# 删除非 sun-panel 模块
find . -maxdepth 1 -type d -not -name "sun-panel" -not -name "." -not -name ".git" -exec rm -rf {} \;

# 修改 install.sh，仅保留 sun-panel 逻辑
if [ -f install.sh ]; then
  grep "sun-panel" install.sh > temp.sh
  mv temp.sh install.sh
  chmod +x install.sh
fi

# 清理工作流
[ -d .github/workflows ] && rm -rf .github/workflows

# 验证 sun-panel
if [ ! -d sun-panel ] || [ ! -f sun-panel/install.sh ] || [ ! -f sun-panel/docker-compose.yml ]; then
  echo "错误：sun-panel 模块不完整！"
  exit 1
fi

# 移动到持久化目录
mkdir -p /opt/Fmie-work
mv * /opt/Fmie-work
cd /opt/Fmie-work

# 执行 sun-panel 安装
if [ -f sun-panel/install.sh ]; then
  bash sun-panel/install.sh
else
  echo "错误：sun-panel/install.sh 不存在！"
  exit 1
fi

# 清理临时文件
rm -rf /tmp/Fmie-work

# 提示完成
echo "Fmie-work 项目已部署，sun-panel 已安装。"
echo "请检查 Docker 容器状态："
echo "  docker ps"
echo "访问 sun-panel 的 Web 界面（根据 docker-compose.yml 中的端口）。"