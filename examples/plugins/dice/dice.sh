#!/bin/sh
# mpet 示例 tool 插件：骰子
# 从 stdin 读取 tool.call（NDJSON），向 stdout 回 tool.result。

while IFS= read -r line; do
  # 提取 call id（极简解析；真实插件用 jq 或任意 JSON 库）
  ID=$(printf '%s' "$line" | sed -n 's/.*"id":"\([^"]*\)".*/\1/p')
  [ -z "$ID" ] && continue
  ROLL=$(( (RANDOM % 6) + 1 ))
  printf '{"t":"tool.result","id":"%s","ok":true,"content":"骰子摇出了 %s 点！"}\n' "$ID" "$ROLL"
done
