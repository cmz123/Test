#!/bin/bash


##生产
# TiDB Region表归属变化追踪工具（精简版）
# 用法: ./track_region_tables.sh <region_id> [hours]


# 默认参数
REGION_ID=$1
HOURS=${2:-24}  # 默认查询最近24小时
PD_HOST="127.0.0.1"
PD_PORT=2379
TIDB_HOST="127.0.0.1"
TIDB_PORT=4000
TIDB_USER="root"
TIDB_PASSWORD=""
LOG_DIR="/Users/cmz/.tiup/data/*/pd-0"

# 检查参数
if [ -z "$REGION_ID" ]; then
  echo "错误: 必须指定Region ID"
  echo "用法: $0 <region_id> [hours]"
  exit 1
fi

# 获取当前Region所属表
get_current_table() {
 mysql -h$TIDB_HOST -P$TIDB_PORT -u$TIDB_USER -e "SELECT distinct CONCAT(db_name, '.', table_name) FROM information_schema.tikv_region_status WHERE region_id = $REGION_ID;" 2>/dev/null | awk 'NR>1'
}

# 搜索PD日志中的Region事件
search_region_events() {
  local region_id=$1 hours=$2
  local since_time=$(date -v-1d "+DATE: +%Y-%m-%d %H:%M:%S")
  grep -h "region-id=$region_id" $LOG_DIR/pd.log | awk -v since="$since_time" '$1 > since' | sort
}

# 主函数
main() {
  echo  "\n=== 开始追踪Region $REGION_ID 的表归属变化 (最近 ${HOURS} 小时) ==="
  # 初始表状态
  current_table=$(get_current_table)
  echo  "\n[当前Region $REGION_ID 所属表: $current_table ]"
  
  # 搜索Region事件并追踪表变化
  echo  "\n[Region表归属变化历史]"
  echo "------------------------------------------------------------"
  printf "%-20s | %-30s | %-15s\n" "时间" "所属表" "事件类型"
  echo "------------------------------------------------------------"
  
  last_table="$current_table"
  while IFS= read -r log_line; do
    event_time=$(echo "$log_line" | awk '{print $1}')
    event_type="未知事件"
    
    # 判断事件类型
    if [[ "$log_line" =~ "split region" ]]; then
      event_type="Split事件"
    elif [[ "$log_line" =~ "merge region" ]]; then
      event_type="Merge事件"
    fi
    
    # 获取事件后的表归属
    new_table=$(get_current_table $REGION_ID)
    
    # 如果表发生变化则记录
    if [ "$new_table" != "$last_table" ]; then
      printf "%-20s | %-30s | %-15s\n" "$event_time" "${new_table:-unknown}" "$event_type"
      last_table="$new_table"
    fi
  done <<< $(search_region_events)
  
  echo "------------------------------------------------------------"
  echo "\n提示: 'unknown' 表示无法确定表归属，可能是系统表或已删除的表"
}

main
