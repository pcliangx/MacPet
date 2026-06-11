#!/bin/sh
# mpet 示例 sense 插件：天气感知
# 每小时向 stdout 输出一条 sense.event（NDJSON，外设协议 v0）
# 真实实现可调天气 API；此示例用 macOS 本地数据模拟。

while true; do
  # 模拟天气感知（真实插件这里调 API）
  HOUR=$(date +%H)
  if [ "$HOUR" -lt 6 ]; then DESC="夜深了，外面很安静"
  elif [ "$HOUR" -lt 12 ]; then DESC="早晨的空气闻起来不错"
  elif [ "$HOUR" -lt 18 ]; then DESC="下午的阳光暖洋洋的"
  else DESC="天色暗下来了"
  fi

  printf '{"t":"sense.event","percept":{"id":"%s","kind":"weather.changed","priority":"ambient","payload":{"description":{"_0":"%s"}},"actions":[],"at":%s}}\n' \
    "$(date +%s)" "$DESC" "$(date +%s)000"

  sleep 3600
done
