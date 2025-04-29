#!/bin/bash

CONFIG_DIR="/opt/loginfo"
CONFIG_FILE="$CONFIG_DIR/host_info.conf"

# Max lengths for table formatting
max_id_len=0
max_ip_len=0
max_port_len=0
max_name_len=0

# Data structures
declare -A servers
declare -A groups
declare -A custom_groups
group_sequence=()

use_tmux=true

# Start tmux session by ID
start_tmux_session_by_id() {
    local id="$1"
    if [[ -n "${servers[$id]}" ]]; then
        local group_name=""
        for group_name in "${group_sequence[@]}"; do
            IFS=',' read -ra id_list <<< "${groups[$group_name]}"
            for gid in "${id_list[@]}"; do
                if [[ "$gid" == "$id" ]]; then
                    group_name="${group_name//[[:space:]]/}"
                    break 2
                fi
            done
        done

        IFS='|' read -r ip user password port name <<< "${servers[$id]}"
        server_name="${name//[[:space:]]/}"

        if tmux has-session -t "$group_name" 2>/dev/null; then
            if ! tmux list-windows -t "$group_name" -F '{#{window_index}:#{window_name}}' | grep -q "{$id:$server_name}"; then
                tmux new-window -t "$group_name:$1" -n "$server_name" "ssh $user@$ip -p $port"
            fi
        else
            tmux new-session -d -s "$group_name" -n "$server_name" "ssh $user@$ip -p $port"
            tmux move-window -s "$group_name:0" -t "$1"
        fi
    else
        echo "Invalid input, please check your config file or host ID."
    fi
}

# Kill tmux sessions
kill_tmux_sessions() {
    local target="$1"
    if [[ "$target" == "all" ]]; then
        for group in "${group_sequence[@]}"; do
            tmux kill-session -t "$group" 2>/dev/null && echo "Killed tmux session: $group"
        done
    else
        tmux kill-session -t "$target" 2>/dev/null && echo "Killed tmux session: $target"
    fi
}

# Attach session
attach_tmux_session() {
    local id="$1"
    local group=""
    for group in "${group_sequence[@]}"; do
        IFS=',' read -ra id_list <<< "${groups[$group]}"
        for gid in "${id_list[@]}"; do
            if [[ "$gid" == "$id" ]]; then
                tmux attach-session -t "$group:$id"
                return
            fi
        done
    done
}

# Parse configuration
parse_config() {
    for arg in "$@"; do
        if [[ "$arg" == "--no-tmux" ]]; then
            use_tmux=false
        fi
    done
    local current_group=""
    while IFS= read -r line; do
        line=$(echo "$line" | sed 's/[[:space:]]//g')
        [[ -z "$line" || "$line" =~ ^# ]] && continue

        if [[ "$line" =~ ^\[[A-Za-z0-9_-]+\]$ ]]; then
            current_group="${line//[\[\]]/}"
            [[ -z "${groups[$current_group]}" ]] && group_sequence+=("$current_group")
            groups["$current_group"]=""
        elif [[ "$line" =~ ^\[[A-Za-z0-9_-]+\]\{[0-9,]+\}$ ]]; then
            current_group="${line%%\{*}"
            current_group="${current_group//[\[\]]/}"
            servers_ids="${line#*\{}"
            servers_ids="${servers_ids%?}"
            custom_groups["$current_group"]=$servers_ids
        elif [[ "$line" =~ ^[0-9]+[|][^|]+[|][^|]*[|][^|]*[|][0-9]+[|][^|]+$ ]]; then
            IFS='|' read -r id ip user password port name <<< "$line"
            servers["$id"]="$ip|$user|$password|$port|$name"
            groups["$current_group"]+="$id,"
            custom_groups["all"]+="$id,"
            update_max_lengths "$id" "$ip" "$port" "$name"
        fi
    done < "$CONFIG_FILE"

    for group in "${!groups[@]}"; do
        groups[$group]="${groups[$group]%,}"
    done
    for group in "${!custom_groups[@]}"; do
        custom_groups[$group]="${custom_groups[$group]%,}"
    done
}

# Update max length for table
update_max_lengths() {
    local id="$1" ip="$2" port="$3" name="$4"
    id_length=$(((${#id} + 4) / 3 * 3))
    ip_length=$(((${#ip} + 4) / 3 * 3))
    port_length=$(((${#port} + 4) / 3 * 3))
    name_length=${#name}
    max_id_len=$((id_length > max_id_len ? id_length : max_id_len))
    max_ip_len=$((ip_length > max_ip_len ? ip_length : max_ip_len))
    max_port_len=$((port_length > max_port_len ? port_length : max_port_len))
    max_name_len=$((name_length > max_name_len ? name_length : max_name_len))
}

# Print the formatted table
print_table() {
    local total_width=$((max_id_len + max_ip_len + max_port_len + max_name_len + 11))

    print_line "$total_width"
    for group in "${group_sequence[@]}"; do
        print_group_header "$group" "$total_width"
        IFS=',' read -ra ids <<< "${groups[$group]}"
        for id in "${ids[@]}"; do
            IFS='|' read -r ip user password port name <<< "${servers[$id]}"
            printf "* * %-${max_id_len}s %-${max_ip_len}s %-${max_port_len}s %-${max_name_len}s * *\n" "$id" "$ip" "$port" "$name"
        done
        print_group_header "" "$total_width"
    done
    print_line "$total_width"
}

print_line() {
    local width="$1"
    printf '%*s\n' "$width" '' | tr ' ' '*'
}

print_group_header() {
    local name="$1"
    local width="$2"
    local padding1=$(( ($width - ${#name} - 4 ) / 2 ))
    local padding2=$(( $width - $padding1 - ${#name} - 4 ))
    local left_padding=$(printf '%*s' "$padding1" '' | tr ' ' '*')
    local right_padding=$(printf '%*s' "$padding2" '' | tr ' ' '*')
    printf "* %s%s%s *\n" "$left_padding" "$name" "$right_padding"
}

# Handle user input
process_input() {
    local input="$1"
    if [[ -n "${groups[$input]}" ]]; then
        connect_group "$input"
    elif [[ -n "${custom_groups[$input]}" ]]; then
        connect_custom_group "$input"
    elif [[ "$input" =~ ^[0-9]+(,[0-9]+)*$ ]]; then
        connect_multiple_ids "$input"
    else
        echo "Invalid input. Please try again."
    fi
}

connect_group() {
    local group="$1"
    IFS=',' read -ra ids <<< "${groups[$group]}"
    for id in "${ids[@]}"; do
        start_tmux_session_by_id "$id"
    done
    attach_tmux_session "${ids[0]}"
}

connect_custom_group() {
    local group="$1"
    IFS=',' read -ra ids <<< "${custom_groups[$group]}"
    for id in "${ids[@]}"; do
        start_tmux_session_by_id "$id"
    done
    attach_tmux_session "${ids[0]}"
}

connect_multiple_ids() {
    local input="$1"
    IFS=',' read -ra ids <<< "$input"
    for id in "${ids[@]}"; do
        if [[ -z "${servers[$id]}" ]]; then
            echo "Invalid ID: $id"
            return
        fi
    done
    for id in "${ids[@]}"; do
        start_tmux_session_by_id "$id"
    done
    attach_tmux_session "${ids[0]}"
}

# Main loop without tmux
main_loop_no_tmux() {
    while true; do
        read -rp "Enter host ID: " input
        if [[ -z "$input" ]]; then
            print_table
            continue
        fi

        if [[ "$input" == "q" || "$input" == "exit" ]]; then
            echo "Exiting..."
            exit 0
        fi

        if [[ -n "${servers[$input]}" ]]; then
            IFS='|' read -r ip user password port name <<< "${servers[$input]}"
            ssh "$user@$ip" -p "$port"
            exit 0
        else
            echo "Invalid input, please check your config file or host ID."
        fi
    done
}

# Main interaction
main_loop() {
    while true; do
        read -rp "Enter host ID or command: " input
        if [[ -z "$input" ]]; then
            print_table
            continue
        fi

        shopt -s nocasematch
        case "$input" in
            exit|q)
                echo "Exiting..."
                exit 0
                ;;
            help)
                echo "Commands:"
                echo "  <ID>            Connect to a specific server"
                echo "  <group>         Connect to a group"
                echo "  kill <group>    Kill a group session"
                echo "  kill all        Kill all sessions"
                echo "  ls/ll           List all active tmux sessions"
                echo "  help            Show this help"
                echo "  exit/q          Quit"
                echo "custom_groups:"
                for group in "${!custom_groups[@]}"; do
                    echo "  $group: {${custom_groups[$group]}}"
                done
                ;;
            ls|ll)
                echo "Active tmux sessions:"
                tmux list-sessions 2>/dev/null | while read -r session; do
                    session_name=$(echo "$session" | cut -d: -f1)
                    echo "  session: $session_name"
                    tmux list-windows -t "$session_name" -F '#{window_index} #{window_name}' 2>/dev/null | while read -r id name; do
                        echo "    $id: $name"
                    done
                done
                ;;
            kill\ all)
                kill_tmux_sessions "all"
                ;;
            kill\ *)
                group_name="${input#kill }"  # 获取 group_name
                if [[ -n "${groups[$group_name]}" || -n "${custom_groups[$group_name]}" ]]; then
                    kill_tmux_sessions "$group_name"
                else
                    echo "Invalid group name: $group_name"
                fi
                ;;
            *)
                process_input "$input"
                ;;
        esac
        shopt -u nocasematch
    done
}

# Program entry
parse_config "$@"
print_table
if [[ "$use_tmux" == false ]]; then
    main_loop_no_tmux
else
    main_loop
fi

