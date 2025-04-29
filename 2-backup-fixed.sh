#!/bin/bash

set -euo pipefail

REPO_SSH="git@github.com:hannamia/DevOps_Task1.git"
SSH_KEY="/home/annmia/task-1/key/script_backup_key"
WORK_DIR="/tmp/repo_backup_$$"
BACKUP_DIR="$HOME/backup"
TARGET_DIRS=("frontend" "backend")
VERSIONS_FILE="$BACKUP_DIR/versions.json"
MAX_BACKUPS=""
MAX_RUNS=1

while [[ "$#" -gt 0 ]]; do
	case $1 in
		--max-backups)
			MAX_BACKUPS="$2"
			shift 2
			;;
		--max-runs)
			MAX_RUNS="$2"
			shift 2
			;;
		*)
			echo "Invalid argument $1"
			exit 1
			;;
	esac
done

increment_version() {
	local v=$1
	local major=$(echo $v | cut -d'.' -f1)
	local minor=$(echo $v | cut -d'.' -f2)
	local patch=$(echo $v | cut -d'.' -f3)

	patch=$((patch + 1))
	if [ "$patch" -ge 100 ]; then
		patch=0
		minor=$((minor + 1))
	fi
	if [ "$minor" -ge 10 ]; then
		minor=0
		major=$((major + 1))
	fi

	echo "$major.$minor.$patch"
}

get_latest_version() {
	tail -n 1 "$VERSION_FILE" | grep -o '"version": *"[^"]*"' | tail -n 1 | cut -d'"' -f4
}

mkdir -p "$BACKUP_DIR"
touch "$VERSIONS_FILE"

if [ ! -f "$VERSIONS_FILE" ]; then
	echo "[]" > "$VERSIONS_FILE"
fi

for ((i=0; i<$MAX_RUNS; i++)); do
	mkdir -p "$WORKDIR"
	chmod 777 "$WORKDIR"
	GIT_SSH_COMMAND="ssh -i $SSH_KEY -o IdentitiesOnly=yes" git -c core.sshCommand="ssh -i $SSH_KEY -o IdentitiesOnly=yes" clone "$REPO_SSH" "$WORKDIR"
	cd "$WORKDIR"

	for dir in "${TARGET_DIRS[@]}"; do 
		if [[ ! -d "$dir" ]]; then
			echo "Error: No directory for backup"
			exit 1
		fi
	done

	latest_version=$(get_latest_version)
	new_version=$(increment_version "$latest_version")
	timestamp=$(date +%d.%m.%Y)
	archive_name="devops_intership_${new_version}"
	archive="$BACKUP_DIR/$archive_name.tar.gz"
	
	tar -czf "$archive" "${TARGET_DIRS[@]}"

	size=$(stat -c%s "$archive")
	
	temp_json=$(mktemp)
	jq ". += [{\"version\":\"$new_version\",\"date\":\"$timestamp\",\"size\":$size,\"filename\":\"$archive_name\"}] "$VERSION_FILE" > "$tmp_json"
	mv "$tmp_json" "$VERSION_FILE"

	rm -rf "$WORKDIR"

	if [[ -n "$MAX_BACKUPS" ]]; then
		mapfile -t backups < <(ls -1t "$BACKUP_DIR"/backup_*.tar.gz 2>/dev/null)
		
		current_count=${#backups[@]}
		if (( MAX_BACKUPS == 0 )); then
			for f in "${backups[@]}"; do
				rm -f "$f"
			done
		elif (( current_count > MAX_BACKUPS )); then
			to_delete=$((current_count - MAX_BACKUPS))
			for ((j=MAX_BACKUPS; j<current_count; j++)); do
				fname=$(basename "${backups[$j]}")
				name="${fname%.tar.gz}"
				rm -f "${backups[$j]}"
			done
		fi
	fi
done
echo "backup completed successfully"
