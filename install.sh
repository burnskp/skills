#!/usr/bin/env bash
# Symlink every skill in ./skills into each agent's global skills directory.
#
# Usage: ./install.sh [--dry-run] [--uninstall]
#
# Override the target directories with SKILL_TARGETS (space separated), e.g.
#   SKILL_TARGETS="$HOME/.claude/skills $HOME/.codex/skills" ./install.sh
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="$REPO_DIR/skills"

# Claude Code      -> ~/.claude/skills (Copilot also reads this)
# Codex / agents   -> ~/.agents/skills
# pi               -> ~/.pi/agent/skills
TARGETS=("$HOME/.claude/skills" "$HOME/.agents/skills" "$HOME/.pi/agent/skills")
if [[ -n "${SKILL_TARGETS:-}" ]]; then
	read -r -a TARGETS <<<"$SKILL_TARGETS"
fi

DRY_RUN=0
UNINSTALL=0
for arg in "$@"; do
	case "$arg" in
	--dry-run) DRY_RUN=1 ;;
	--uninstall) UNINSTALL=1 ;;
	-h | --help)
		sed -n '2,7p' "$0" | sed 's/^# \{0,1\}//'
		exit 0
		;;
	*)
		echo "unknown argument: $arg" >&2
		exit 1
		;;
	esac
done

run() {
	if ((DRY_RUN)); then
		echo "  [dry-run] $*"
	else
		"$@"
	fi
}

# True if $1 is a symlink pointing somewhere inside this repo's skills dir.
owned_link() {
	[[ -L "$1" ]] && [[ "$(readlink "$1")" == "$SKILLS_DIR"/* ]]
}

for target in "${TARGETS[@]}"; do
	echo "$target"
	run mkdir -p "$target"

	# Remove links we own that are stale (skill deleted) or, on uninstall, all of them.
	if [[ -d "$target" ]]; then
		for link in "$target"/*; do
			owned_link "$link" || continue
			if ((UNINSTALL)) || [[ ! -e "$link" ]]; then
				echo "  - $(basename "$link")"
				run rm "$link"
			fi
		done
	fi
	((UNINSTALL)) && continue

	for skill in "$SKILLS_DIR"/*/; do
		skill="${skill%/}"
		name="$(basename "$skill")"
		dest="$target/$name"

		if [[ ! -f "$skill/SKILL.md" ]]; then
			echo "  ! $name: no SKILL.md, skipping" >&2
			continue
		fi
		if [[ -e "$dest" || -L "$dest" ]] && ! owned_link "$dest"; then
			echo "  ! $name: $dest exists and is not ours, skipping" >&2
			continue
		fi
		if owned_link "$dest" && [[ "$(readlink "$dest")" == "$skill" ]]; then
			continue
		fi
		echo "  + $name"
		run ln -sfn "$skill" "$dest"
	done
done
