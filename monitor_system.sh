#!/bin/bash

# Function to get system information
get_system_info() {
  cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
  memory_usage=$(free | grep Mem | awk '{print $3/$2 * 100.0}')
  disk_usage=$(df -h | grep '^/dev' | awk '{print $5}' | sed 's/%//g' | head -n 1)
  top_processes=$(ps aux --sort=-%cpu | head -n 6 | tail -n 5)
  echo "$cpu_usage $memory_usage $disk_usage $top_processes"
}

# Function to check alerts
check_alerts() {
  cpu_usage=$1
  memory_usage=$2
  disk_usage=$3
  if [ $(echo "$cpu_usage > 80" | awk '{if($1 > 80) print 1; else print 0}') -eq 1 ]; then
    echo "CPU usage alert: $cpu_usage%"
  fi
  if [ $(echo "$memory_usage > 75" | awk '{if($1 > 75) print 1; else print 0}') -eq 1 ]; then
    echo "Memory usage alert: $memory_usage%"
  fi
  if [ "$disk_usage" -gt 90 ]; then
    echo "Disk usage alert: $disk_usage%"
  fi
}

# Function to save text report
save_text_report() {
  echo "$1" > "$2"
}

# Function to save JSON report
save_json_report() {
  jq -n \
    --arg cpu "$1" \
    --arg memory "$2" \
    --arg disk "$3" \
    --arg top_processes "$4" \
    '{cpu_usage: $cpu, memory_usage: $memory, disk_usage: $disk, top_processes: $top_processes}' > "$5"
}

# Function to save CSV report
save_csv_report() {
  echo "CPU Usage,Memory Usage,Disk Usage,Top Processes" > "$1"
  echo "$2,$3,$4,$5" >> "$1"
}

# Main function
main() {
  # Input validation for interval and format
  interval=${1:-60}
  output_file=${2:-system_report.txt}
  format=${3:-text}

  if ! [[ $interval =~ ^[0-9]+$ ]]; then
    echo "Error: Interval must be a positive integer."
    exit 1
  fi

  if [ "$format" != "text" ] && [ "$format" != "json" ] && [ "$format" != "csv" ]; then
    echo "Error: Invalid format. Supported formats are text, json, and csv."
    exit 1
  fi

  # Check if required commands are available
  if ! command -v top &>/dev/null; then
    echo "Error: top command not found."
    exit 1
  fi
  if ! command -v ps &>/dev/null; then
    echo "Error: ps command not found."
    exit 1
  fi
  if ! command -v free &>/dev/null; then
    echo "Error: free command not found."
    exit 1
  fi
  if ! command -v df &>/dev/null; then
    echo "Error: df command not found."
    exit 1
  fi

  while true; do
    # Get system information
    system_info=$(get_system_info)
    cpu_usage=$(echo "$system_info" | awk '{print $1}')
    memory_usage=$(echo "$system_info" | awk '{print $2}')
    disk_usage=$(echo "$system_info" | awk '{print $3}')
    top_processes=$(echo "$system_info" | awk '{print $4}')

    # Check for alerts
    check_alerts "$cpu_usage" "$memory_usage" "$disk_usage"

    # Save the report based on the format
    if [ "$format" == "text" ]; then
      save_text_report "$system_info" "$output_file"
    elif [ "$format" == "json" ]; then
      save_json_report "$cpu_usage" "$memory_usage" "$disk_usage" "$top_processes" "$output_file"
    elif [ "$format" == "csv" ]; then
      save_csv_report "$output_file" "$cpu_usage" "$memory_usage" "$disk_usage" "$top_processes"
    fi

    # Sleep for the specified interval before running again
    sleep "$interval"
  done
}

# Call the main function with the provided arguments
main $1 $2 $3
