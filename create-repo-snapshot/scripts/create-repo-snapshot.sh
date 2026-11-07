#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  create-repo-snapshot.sh --output <zip-path> \
    --include <path> [--include <path> ...] \
    [--base-ref <git-ref> --include-changed <path> [--include-changed <path> ...]] [--dry-run]

Options:
  --output <zip-path>       Complete destination ZIP path; required once.
  --base-ref <git-ref>      Git ref used to resolve the merge base; required with --include-changed.
  --include <path>          Existing repository-relative file or directory; repeatable.
  --include-changed <path>  Existing repository-relative changed-file root; optional and repeatable.
  --dry-run                 Print the exact selection without creating an archive.
  --help                    Print this help.
EOF
}

fail() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

require_value() {
  local option="$1"
  local count="$2"
  local value="${3-}"
  if [[ "$count" -lt 2 || -z "$value" || "$value" == --* ]]; then
    fail "$option requires a value."
  fi
}

OUTPUT_VALUE=""
BASE_REF=""
OUTPUT_SEEN=false
BASE_REF_SEEN=false
DRY_RUN=false
INCLUDES=()
CHANGED_INCLUDES=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output)
      require_value "$1" "$#" "${2-}"
      [[ "$OUTPUT_SEEN" == false ]] || fail "--output may be specified only once."
      OUTPUT_VALUE="$2"
      OUTPUT_SEEN=true
      shift 2
      ;;
    --base-ref)
      require_value "$1" "$#" "${2-}"
      [[ "$BASE_REF_SEEN" == false ]] || fail "--base-ref may be specified only once."
      BASE_REF="$2"
      BASE_REF_SEEN=true
      shift 2
      ;;
    --include)
      require_value "$1" "$#" "${2-}"
      INCLUDES+=("$2")
      shift 2
      ;;
    --include-changed)
      require_value "$1" "$#" "${2-}"
      CHANGED_INCLUDES+=("$2")
      shift 2
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      fail "unknown argument: $1"
      ;;
  esac
done

[[ "$OUTPUT_SEEN" == true ]] || fail "--output is required."
[[ "${#INCLUDES[@]}" -gt 0 ]] || fail "at least one --include is required."
if [[ "${#CHANGED_INCLUDES[@]}" -gt 0 && "$BASE_REF_SEEN" == false ]]; then
  fail "--base-ref is required when --include-changed is specified."
fi

command -v git >/dev/null 2>&1 || fail "Git is required but was not found on PATH."
command -v realpath >/dev/null 2>&1 || fail "realpath is required but was not found on PATH."

if ! REPO_ROOT_RAW="$(git rev-parse --show-toplevel 2>/dev/null)"; then
  fail "the current directory is not inside a Git worktree."
fi
REPO_ROOT="$(realpath -e -- "$REPO_ROOT_RAW")"

if [[ "$OUTPUT_VALUE" = /* ]]; then
  OUTPUT_PATH="$(realpath -m -- "$OUTPUT_VALUE")"
else
  OUTPUT_PATH="$(realpath -m -- "$REPO_ROOT/$OUTPUT_VALUE")"
fi
OUTPUT_PARENT="$(dirname -- "$OUTPUT_PATH")"
[[ -d "$OUTPUT_PARENT" ]] || fail "output parent directory does not exist: $OUTPUT_PARENT"
OUTPUT_PARENT="$(realpath -e -- "$OUTPUT_PARENT")"
OUTPUT_PATH="$OUTPUT_PARENT/$(basename -- "$OUTPUT_PATH")"
[[ ! -d "$OUTPUT_PATH" ]] || fail "output path is a directory: $OUTPUT_PATH"

MERGE_BASE=""
if [[ "${#CHANGED_INCLUDES[@]}" -gt 0 ]]; then
  if ! git -C "$REPO_ROOT" rev-parse --verify --quiet "$BASE_REF^{commit}" >/dev/null; then
    fail "base ref does not resolve to a commit: $BASE_REF"
  fi
  if ! MERGE_BASE="$(git -C "$REPO_ROOT" merge-base HEAD "$BASE_REF" 2>/dev/null)"; then
    fail "could not resolve a merge base between HEAD and base ref: $BASE_REF"
  fi
  [[ -n "$MERGE_BASE" ]] || fail "could not resolve a merge base between HEAD and base ref: $BASE_REF"
fi

NORMALIZED_INCLUDES=()
NORMALIZED_CHANGED_INCLUDES=()
ALL_ROOTS=()

normalize_include() {
  local option="$1"
  local value="$2"
  local lexical_path
  local resolved_path
  local relative_path

  [[ "$value" != /* ]] || fail "$option path must be repository-relative: $value"
  lexical_path="$(realpath -ms -- "$REPO_ROOT/$value")"
  case "$lexical_path" in
    "$REPO_ROOT"|"$REPO_ROOT"/*) ;;
    *) fail "$option path resolves outside the repository: $value" ;;
  esac
  [[ -e "$lexical_path" || -L "$lexical_path" ]] || fail "$option path does not exist: $value"
  resolved_path="$(realpath -e -- "$lexical_path")"
  case "$resolved_path" in
    "$REPO_ROOT"|"$REPO_ROOT"/*) ;;
    *) fail "$option path resolves outside the repository: $value" ;;
  esac
  relative_path="$(realpath -ms --relative-to="$REPO_ROOT" "$lexical_path")"
  printf '%s\n' "$relative_path"
}

for include_path in "${INCLUDES[@]}"; do
  normalized="$(normalize_include "--include" "$include_path")"
  NORMALIZED_INCLUDES+=("$normalized")
  ALL_ROOTS+=("$normalized")
done
for include_path in "${CHANGED_INCLUDES[@]}"; do
  normalized="$(normalize_include "--include-changed" "$include_path")"
  NORMALIZED_CHANGED_INCLUDES+=("$normalized")
  ALL_ROOTS+=("$normalized")
done

TEMP_ROOT="$(mktemp -d)"
STAGING_DIR="$TEMP_ROOT/staging"
CANDIDATE_FILE="$TEMP_ROOT/candidates.bin"
SELECTION_FILE="$TEMP_ROOT/selection.txt"
TEMP_OUTPUT=""

cleanup() {
  local status=$?
  if [[ -n "$TEMP_OUTPUT" && -e "$TEMP_OUTPUT" ]]; then
    rm -f -- "$TEMP_OUTPUT"
  fi
  if [[ -d "$TEMP_ROOT" ]]; then
    rm -rf -- "$TEMP_ROOT"
  fi
  exit "$status"
}
trap cleanup EXIT

: > "$CANDIDATE_FILE"

append_candidates() {
  if ! git -C "$REPO_ROOT" "$@" >> "$CANDIDATE_FILE"; then
    fail "Git file selection failed."
  fi
}

for include_path in "${NORMALIZED_INCLUDES[@]}"; do
  append_candidates ls-files -z --cached --others --exclude-standard -- "$include_path"
done

for include_path in "${NORMALIZED_CHANGED_INCLUDES[@]}"; do
  append_candidates diff --name-only -z --diff-filter=ACMRTUXB "$MERGE_BASE" HEAD -- "$include_path"
  append_candidates diff --cached --name-only -z --diff-filter=ACMRTUXB -- "$include_path"
  append_candidates diff --name-only -z --diff-filter=ACMRTUXB -- "$include_path"
  append_candidates ls-files -z --others --exclude-standard -- "$include_path"
done

declare -A SELECTED_SET=()

is_under_requested_root() {
  local path="$1"
  local root
  for root in "${ALL_ROOTS[@]}"; do
    if [[ "$root" == "." || "$path" == "$root" || "$path" == "$root/"* ]]; then
      return 0
    fi
  done
  return 1
}

while IFS= read -r -d '' candidate; do
  candidate="${candidate#./}"
  [[ -n "$candidate" ]] || continue
  is_under_requested_root "$candidate" || continue

  candidate_path="$REPO_ROOT/$candidate"
  [[ -f "$candidate_path" || -L "$candidate_path" ]] || continue

  if [[ -L "$candidate_path" ]]; then
    if ! resolved_candidate="$(realpath -e -- "$candidate_path" 2>/dev/null)"; then
      fail "selected symbolic link cannot be resolved: $candidate"
    fi
    case "$resolved_candidate" in
      "$REPO_ROOT"|"$REPO_ROOT"/*) ;;
      *) fail "selected symbolic link resolves outside the repository: $candidate" ;;
    esac
    [[ -f "$resolved_candidate" ]] || fail "selected symbolic link does not resolve to a file: $candidate"
  else
    resolved_candidate="$(realpath -e -- "$candidate_path")"
  fi

  [[ "$resolved_candidate" != "$OUTPUT_PATH" && "$candidate_path" != "$OUTPUT_PATH" ]] || continue
  SELECTED_SET["$candidate"]=1
done < "$CANDIDATE_FILE"

if [[ "${#SELECTED_SET[@]}" -eq 0 ]]; then
  fail "computed file selection is empty."
fi

printf '%s\n' "${!SELECTED_SET[@]}" | LC_ALL=C sort > "$SELECTION_FILE"
mapfile -t SELECTED < "$SELECTION_FILE"

if [[ "$DRY_RUN" == true ]]; then
  printf 'Dry run: repository snapshot selection\n'
  printf 'Destination: %s\n' "$OUTPUT_PATH"
  if [[ -n "$MERGE_BASE" ]]; then
    printf 'Merge base: %s\n' "$MERGE_BASE"
  fi
  printf 'Selected files: %s\n' "${#SELECTED[@]}"
  printf 'FILE %s\n' "${SELECTED[@]}"
  exit 0
fi

command -v zip >/dev/null 2>&1 || fail "zip is required for archive creation but was not found on PATH."
if command -v zipinfo >/dev/null 2>&1; then
  INSPECTOR=(zipinfo -1)
elif command -v unzip >/dev/null 2>&1; then
  INSPECTOR=(unzip -Z1)
else
  fail "zipinfo or unzip is required for archive inspection but neither was found on PATH."
fi

mkdir -p "$STAGING_DIR"
for selected_path in "${SELECTED[@]}"; do
  mkdir -p "$STAGING_DIR/$(dirname -- "$selected_path")"
  if ! cp -L -- "$REPO_ROOT/$selected_path" "$STAGING_DIR/$selected_path"; then
    fail "failed to stage selected file: $selected_path"
  fi
done

TEMP_OUTPUT="$(mktemp --suffix=.zip "$OUTPUT_PARENT/.$(basename -- "$OUTPUT_PATH").tmp.XXXXXX")"
rm -f -- "$TEMP_OUTPUT"

if ! (cd "$STAGING_DIR" && zip -q "$TEMP_OUTPUT" -@ < "$SELECTION_FILE"); then
  fail "archive creation failed."
fi

ARCHIVE_ENTRIES="$TEMP_ROOT/archive-entries.txt"
if ! "${INSPECTOR[@]}" "$TEMP_OUTPUT" | sed 's#\\#/#g' | LC_ALL=C sort > "$ARCHIVE_ENTRIES"; then
  fail "archive entry inspection failed."
fi
if ! cmp -s "$SELECTION_FILE" "$ARCHIVE_ENTRIES"; then
  fail "archive entry verification failed."
fi

if ! mv -f -- "$TEMP_OUTPUT" "$OUTPUT_PATH"; then
  fail "failed to replace destination archive: $OUTPUT_PATH"
fi
TEMP_OUTPUT=""

printf 'Created repository snapshot: %s\n' "$OUTPUT_PATH"
if [[ -n "$MERGE_BASE" ]]; then
  printf 'Merge base: %s\n' "$MERGE_BASE"
fi
printf 'Selected files: %s\n' "${#SELECTED[@]}"
