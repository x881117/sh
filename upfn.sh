#!/bin/bash

# 遍历当前目录下所有以 "hy" 开头的目录
for dir in hy*/; do
  if [ -d "$dir" ]; then
    echo "进入目录: $dir"
    cd "$dir" || continue
    
    # 执行 docker-compose down
    if [ -f "docker-compose.yml" ]; then
      echo "正在执行 docker-compose down in $dir"
      docker compose down

      # 执行 docker-compose pull 拉取最新镜像
      echo "正在执行 docker-compose pull in $dir"
      docker compose pull

      # 执行 docker-compose up -d 启动容器
      echo "正在执行 docker-compose up -d in $dir"
      docker compose up -d
    else
      echo "该目录没有 docker-compose.yml 文件, 跳过..."
    fi
    
    # 返回上一级目录
    cd - > /dev/null || exit
  fi
done
