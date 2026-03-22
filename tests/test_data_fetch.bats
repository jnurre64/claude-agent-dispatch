#!/usr/bin/env bats
# Tests for scripts/lib/data-fetch.sh

load 'helpers/test_helper'

_source_data_fetch() {
    source "${LIB_DIR}/common.sh"
    source "${LIB_DIR}/data-fetch.sh"
}

# ═══════════════════════════════════════════════════════════════
# extract_debug_data tests
# ═══════════════════════════════════════════════════════════════

@test "extract_debug_data: sets empty globals when no data found" {
    _source_data_fetch
    local data_dir="${TEST_TEMP_DIR}/data"

    extract_debug_data '[]' "$data_dir"

    assert_equal "$EXTRACTED_DATA_COMMENT_FILE" ""
    assert_equal "$EXTRACTED_GIST_FILES" ""
}

@test "extract_debug_data: creates data directory" {
    _source_data_fetch
    local data_dir="${TEST_TEMP_DIR}/newdir"

    extract_debug_data '[]' "$data_dir"

    assert [ -d "$data_dir" ]
}

@test "extract_debug_data: finds submit-logs comment by Environment marker" {
    _source_data_fetch
    local data_dir="${TEST_TEMP_DIR}/data"
    local comments_json='[{"author":{"login":"jnurre64"},"body":"### Environment\nOS: Linux\nSome debug data"}]'

    extract_debug_data "$comments_json" "$data_dir"

    assert [ -n "$EXTRACTED_DATA_COMMENT_FILE" ]
    assert [ -f "$EXTRACTED_DATA_COMMENT_FILE" ]
    run grep "Environment" "$EXTRACTED_DATA_COMMENT_FILE"
    assert_success
}

@test "extract_debug_data: skips bot comments" {
    _source_data_fetch
    local data_dir="${TEST_TEMP_DIR}/data"
    local comments_json='[{"author":{"login":"test-bot"},"body":"### Environment\nBot data"}]'

    extract_debug_data "$comments_json" "$data_dir"

    assert_equal "$EXTRACTED_DATA_COMMENT_FILE" ""
}

@test "extract_debug_data: finds gist links in comments" {
    create_mock "gh" "gist content here"
    _source_data_fetch
    local data_dir="${TEST_TEMP_DIR}/data"
    local comments_json='[{"author":{"login":"jnurre64"},"body":"See https://gist.github.com/jnurre64/abc123def456"}]'

    extract_debug_data "$comments_json" "$data_dir"

    # Should have attempted gist download
    local calls
    calls=$(get_mock_calls "gh")
    [[ "$calls" == *"gist"* ]]
}

@test "extract_debug_data: checks extra_text for attachments" {
    create_mock "gh" "gist body"
    _source_data_fetch
    local data_dir="${TEST_TEMP_DIR}/data"

    extract_debug_data '[]' "$data_dir" "See https://gist.github.com/user/deadbeef123456"

    assert [ -n "$EXTRACTED_DATA_COMMENT_FILE" ]
}

# ═══════════════════════════════════════════════════════════════
# _download_linked_files tests
# ═══════════════════════════════════════════════════════════════

@test "_download_linked_files: extracts and downloads gist URLs" {
    create_mock "gh" "downloaded content"
    _source_data_fetch
    local data_dir="${TEST_TEMP_DIR}/data"
    mkdir -p "$data_dir"

    EXTRACTED_GIST_FILES=""
    EXTRACTED_DATA_ERRORS="${data_dir}/errors.txt"

    _download_linked_files "See https://gist.github.com/user/abc123 for details" "$data_dir"

    assert [ -n "$EXTRACTED_GIST_FILES" ]
    assert [ -f "${data_dir}/gist-abc123.txt" ]
}

@test "_download_linked_files: handles multiple gist URLs" {
    create_mock "gh" "content"
    _source_data_fetch
    local data_dir="${TEST_TEMP_DIR}/data"
    mkdir -p "$data_dir"

    EXTRACTED_GIST_FILES=""
    EXTRACTED_DATA_ERRORS="${data_dir}/errors.txt"

    _download_linked_files "Gist 1: https://gist.github.com/user/aaa111 and Gist 2: https://gist.github.com/user/bbb222" "$data_dir"

    assert [ -f "${data_dir}/gist-aaa111.txt" ]
    assert [ -f "${data_dir}/gist-bbb222.txt" ]
}

@test "_download_linked_files: records errors for failed downloads" {
    create_mock "gh" "" 1
    _source_data_fetch
    local data_dir="${TEST_TEMP_DIR}/data"
    mkdir -p "$data_dir"

    EXTRACTED_GIST_FILES=""
    EXTRACTED_DATA_ERRORS="${data_dir}/errors.txt"

    _download_linked_files "Fail: https://gist.github.com/user/failgist" "$data_dir"

    assert [ -f "$EXTRACTED_DATA_ERRORS" ]
    run grep "FAILED" "$EXTRACTED_DATA_ERRORS"
    assert_success
}

# ═══════════════════════════════════════════════════════════════
# Source verification tests
# ═══════════════════════════════════════════════════════════════

@test "data-fetch.sh: handles attachment URLs" {
    grep -q "user-attachments" "${LIB_DIR}/data-fetch.sh"
}

@test "data-fetch.sh: validates downloaded files aren't error pages" {
    grep -q "Not Found\|DOCTYPE" "${LIB_DIR}/data-fetch.sh"
}
