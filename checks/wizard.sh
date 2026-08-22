#!/usr/bin/env bash
set -euo pipefail

# Does the install wizard write an install.conf the rest of the build can read?
#
# setup/install/00-wizard.sh is the only thing other than a human editor that
# writes setup/install.conf, and that file has two consumers with two different
# parsers, neither of which would report a problem where it could be fixed:
#
#   * 03-system.sh and 05-dotfiles.sh `source` it. A value that breaks shell
#     quoting fails three stages later, inside a chroot, on a machine with no
#     editor and no network.
#   * setup/dotfiles/dot_gitconfig.tmpl parses it with ^[A-Z_]+="[^"]*" through
#     chezmoi's include. A value that breaks that regex fails the render of
#     every dotfile, or - worse - produces an empty git identity, which git
#     accepts and turns into unattributable commits.
#
# A wrong answer is the same shape of problem: a timezone or keymap that does
# not exist does not fail the install, it produces a machine that comes up an
# hour later with the wrong keyboard. So the wizard validates against the live
# system, and this checks that it really does.
#
# The install path itself cannot be run - install.sh erases a disk - so the two
# things under test are the wizard, driven with piped answers, and a copy of
# install.sh truncated before its first destructive line. Every write goes to a
# throwaway directory; the real setup/install.conf is only ever read.
#
# Needs bash and coreutils. Where a data file the wizard validates against is
# genuinely absent (another distribution, a container without kbd), the
# assertions that depend on it are skipped and say so.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WIZARD="$REPO_ROOT/setup/install/00-wizard.sh"
CONF="$REPO_ROOT/setup/install.conf"
INSTALLER="$REPO_ROOT/install.sh"

ZONEINFO=/usr/share/zoneinfo
LOCALE_GEN=/etc/locale.gen
KEYMAP_DIR=/usr/share/kbd/keymaps

PASS=0
FAIL=0
SKIP=0

pass() { printf '  \033[32mPASS\033[0m  %s\n' "$*"; PASS=$((PASS + 1)); }
fail() { printf '  \033[31mFAIL\033[0m  %s\n' "$*"; FAIL=$((FAIL + 1)); }
skip() { printf '  \033[33mSKIP\033[0m  %s\n' "$*"; SKIP=$((SKIP + 1)); }
info() { printf '        %s\n' "$*"; }

section() { printf '\n==> %s\n' "$*"; }

expect() { # label got want
    if [[ "$2" == "$3" ]]; then
        pass "$1"
    else
        fail "$1"
        info "want: $3"
        info "got:  $2"
    fi
}

if [[ ! -x "$WIZARD" ]]; then
    echo "Not found or not executable: $WIZARD" >&2
    exit 1
fi

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

# The wizard is given a copy, always. Nothing here may write $CONF.
CONF_BEFORE="$(cat "$CONF")"
fresh() { cp "$CONF" "$T/conf"; }

# Read a value back the way 03-system.sh does: by sourcing.
sourced() {
    ( set -euo pipefail; . "$1"; printf '%s' "${!2-<UNSET>}" ) 2>/dev/null \
        || printf '%s' '<SOURCE-FAILED>'
}

RC=0
OUT=""
run_wizard() { # answers, then the wizard's own arguments
    local answers="$1"; shift
    RC=0
    OUT="$(printf '%s' "$answers" | bash "$WIZARD" "$@" 2>&1)" || RC=$?
}

saw() { # substring -> how many lines of the last run contained it
    printf '%s\n' "$OUT" | grep -cF -- "$1" || true
}

saw_line() { # whole line -> how many lines of the last run were exactly it.
    # The suggestion list is indented, and "      fr" is a substring of
    # "      fr_CH": a substring match here counted ten keymaps as one.
    printf '%s\n' "$OUT" | grep -cxF -- "$1" || true
}

untouched() { # label, file that should still equal the committed install.conf
    if [[ "$(cat "$2")" == "$CONF_BEFORE" ]]; then
        pass "$1"
    else
        fail "$1"
    fi
}

# ----------------------------------------------------------------------
section "Prerequisites"

if bash -n "$WIZARD" 2>/dev/null; then
    pass "setup/install/00-wizard.sh parses"
else
    fail "setup/install/00-wizard.sh does not parse"
fi

if bash -n "$INSTALLER" 2>/dev/null; then
    pass "install.sh parses"
else
    fail "install.sh does not parse"
fi

# Answers are chosen from what this machine actually has, so the check is not
# tied to a French keyboard being installed.
HAVE_TZ=no
TZ_ANSWER=""
if [[ -d "$ZONEINFO" ]]; then
    HAVE_TZ=yes
    for candidate in Europe/Paris America/New_York UTC; do
        [[ -f "$ZONEINFO/$candidate" ]] && { TZ_ANSWER="$candidate"; break; }
    done
fi
if [[ -n "$TZ_ANSWER" ]]; then
    pass "a timezone to answer with: $TZ_ANSWER"
else
    HAVE_TZ=no
    TZ_ANSWER="Europe/Paris"
    skip "no $ZONEINFO on this machine; the zone assertions cannot run"
fi

HAVE_LOCALE=no
LOCALE_ANSWER=""
if [[ -f "$LOCALE_GEN" ]]; then
    HAVE_LOCALE=yes
    LOCALE_ANSWER="$(awk '{ sub(/^#/, "") }
        $2 == "UTF-8" && $1 ~ /\.UTF-8$/ { print $1 }' "$LOCALE_GEN" |
        grep -x 'fr_FR.UTF-8' || true)"
    if [[ -z "$LOCALE_ANSWER" ]]; then
        LOCALE_ANSWER="$(awk '{ sub(/^#/, "") }
            $2 == "UTF-8" && $1 ~ /\.UTF-8$/ { print $1 }' "$LOCALE_GEN" |
            head -1 || true)"
    fi
fi
if [[ -n "$LOCALE_ANSWER" ]]; then
    pass "a locale to answer with: $LOCALE_ANSWER"
else
    HAVE_LOCALE=no
    LOCALE_ANSWER="fr_FR.UTF-8"
    skip "no usable $LOCALE_GEN; the locale-membership assertions cannot run"
fi

HAVE_KEYMAP=no
KEYMAP_ANSWER=""
if [[ -d "$KEYMAP_DIR" ]]; then
    HAVE_KEYMAP=yes
    KEYMAP_ANSWER="$(find "$KEYMAP_DIR" -type f -name 'fr.map.gz' 2>/dev/null |
        head -1 || true)"
    if [[ -n "$KEYMAP_ANSWER" ]]; then
        KEYMAP_ANSWER=fr
    else
        KEYMAP_ANSWER="$(find "$KEYMAP_DIR" -type f -name '*.map.gz' 2>/dev/null |
            sed 's|.*/||; s|\.map\.gz$||' | sort -u | head -1 || true)"
    fi
fi
if [[ -n "$KEYMAP_ANSWER" ]]; then
    pass "a keymap to answer with: $KEYMAP_ANSWER"
else
    HAVE_KEYMAP=no
    KEYMAP_ANSWER="fr"
    skip "no $KEYMAP_DIR on this machine; the keymap assertions cannot run"
fi

# The full set of good answers, used by several sections below.
GOOD=$'newuser\nlaptop\n'"$TZ_ANSWER"$'\n'"$LOCALE_ANSWER"$'\n'"$KEYMAP_ANSWER"$'\nAda Lovelace\nada@example.com\ny\n'

# ----------------------------------------------------------------------
section "Pressing Enter through the wizard changes nothing"

fresh
run_wizard $'\n\n\n\n\n\n\n\n' "$T/conf"
expect "exit status is 0" "$RC" "0"
untouched "the file is byte-identical to the one it started from" "$T/conf"

# ----------------------------------------------------------------------
section "A full set of answers reaches every consumer"

fresh
run_wizard "$GOOD" "$T/conf"
expect "exit status is 0" "$RC" "0"

expect "USERNAME sources back"  "$(sourced "$T/conf" USERNAME)"  "newuser"
expect "HOSTNAME sources back"  "$(sourced "$T/conf" HOSTNAME)"  "laptop"
expect "TIMEZONE sources back"  "$(sourced "$T/conf" TIMEZONE)"  "$TZ_ANSWER"
expect "LOCALE sources back"    "$(sourced "$T/conf" LOCALE)"    "$LOCALE_ANSWER"
expect "KEYMAP sources back"    "$(sourced "$T/conf" KEYMAP)"    "$KEYMAP_ANSWER"
expect "GIT_NAME sources back"  "$(sourced "$T/conf" GIT_NAME)"  "Ada Lovelace"
expect "GIT_EMAIL sources back" "$(sourced "$T/conf" GIT_EMAIL)" "ada@example.com"

expect "every comment survived" \
    "$(grep -c '^#' "$T/conf" || true)" "$(grep -c '^#' "$CONF" || true)"
expect "the line count is unchanged" \
    "$(wc -l < "$T/conf")" "$(wc -l < "$CONF")"

# The second parser. dot_gitconfig.tmpl matches ^[A-Z_]+="[^"]*", so a value
# has to be on one line, in double quotes, exactly once.
expect "dot_gitconfig.tmpl's regex finds GIT_NAME exactly once" \
    "$(grep -cE '^GIT_NAME="Ada Lovelace"$' "$T/conf" || true)" "1"
expect "dot_gitconfig.tmpl's regex finds GIT_EMAIL exactly once" \
    "$(grep -cE '^GIT_EMAIL="ada@example\.com"$' "$T/conf" || true)" "1"

# What 03-system.sh will actually do with the answers.
if [[ "$HAVE_TZ" == yes ]]; then
    if [[ -f "$ZONEINFO/$(sourced "$T/conf" TIMEZONE)" ]]; then
        pass "the timezone written is a real zoneinfo file"
    else
        fail "the timezone written has no zoneinfo file"
    fi
else
    skip "the timezone written cannot be resolved without $ZONEINFO"
fi

if [[ "$HAVE_LOCALE" == yes ]]; then
    # 03-system.sh un-comments "<locale> UTF-8" and then writes LANG=<locale>.
    written_locale="$(sourced "$T/conf" LOCALE)"
    if [[ "$(grep -c "^#\?${written_locale} UTF-8" "$LOCALE_GEN" || true)" -eq 1 ]]; then
        pass "the locale written is a line 03-system.sh's sed can un-comment"
    else
        fail "the locale written has no '<locale> UTF-8' line in $LOCALE_GEN"
    fi
else
    skip "the locale written cannot be resolved without $LOCALE_GEN"
fi

if [[ "$HAVE_KEYMAP" == yes ]]; then
    found="$(find "$KEYMAP_DIR" -type f -name "$(sourced "$T/conf" KEYMAP).map.gz" 2>/dev/null | head -1 || true)"
    if [[ -n "$found" ]]; then
        pass "the keymap written is a real kbd keymap"
    else
        fail "the keymap written is not under $KEYMAP_DIR"
    fi
else
    skip "the keymap written cannot be resolved without $KEYMAP_DIR"
fi

# ----------------------------------------------------------------------
section "A wrong answer is refused and asked again, never written"

fresh
run_wizard $'Root User\n0bad\ngood\nbad-\nlaptop\n'"$TZ_ANSWER"$'\n'"$LOCALE_ANSWER"$'\n'"$KEYMAP_ANSWER"$'\nAda\nnot-an-email\nada@example.com\ny\n' "$T/conf"
expect "exit status is 0" "$RC" "0"
expect "a username with a space and a capital was refused" \
    "$(sourced "$T/conf" USERNAME)" "good"
expect "a hostname ending in a hyphen was refused" \
    "$(sourced "$T/conf" HOSTNAME)" "laptop"
expect "an address with no @ was refused" \
    "$(sourced "$T/conf" GIT_EMAIL)" "ada@example.com"

fresh
run_wizard $'newuser\nlaptop\nMars/Olympus\n'"$TZ_ANSWER"$'\nen_GB\n'"$LOCALE_ANSWER"$'\nno/such\n'"$KEYMAP_ANSWER"$'\nAda\nada@example.com\ny\n' "$T/conf"
expect "exit status is 0" "$RC" "0"
expect "a locale with no charset suffix was refused" \
    "$(sourced "$T/conf" LOCALE)" "$LOCALE_ANSWER"
expect "a keymap name with a slash was refused" \
    "$(sourced "$T/conf" KEYMAP)" "$KEYMAP_ANSWER"

if [[ "$HAVE_TZ" == yes ]]; then
    expect "an invented timezone was refused, by name" "$(saw 'no such zone')" "1"
    expect "and the good one was taken instead" \
        "$(sourced "$T/conf" TIMEZONE)" "$TZ_ANSWER"
else
    skip "an invented timezone cannot be detected without $ZONEINFO"
    skip "and so the recovery cannot be checked either"
fi

if [[ "$HAVE_LOCALE" == yes ]]; then
    fresh
    run_wizard $'newuser\nlaptop\n'"$TZ_ANSWER"$'\nen_XX.UTF-8\n'"$LOCALE_ANSWER"$'\n'"$KEYMAP_ANSWER"$'\nAda\nada@example.com\ny\n' "$T/conf"
    expect "a locale absent from locale.gen was refused, with the reason" \
        "$(saw 'locale-gen would generate nothing')" "1"
    expect "and the good one was taken instead" \
        "$(sourced "$T/conf" LOCALE)" "$LOCALE_ANSWER"
else
    skip "a locale absent from locale.gen cannot be detected without $LOCALE_GEN"
    skip "and so the recovery cannot be checked either"
fi

if [[ "$HAVE_KEYMAP" == yes ]]; then
    fresh
    run_wizard $'newuser\nlaptop\n'"$TZ_ANSWER"$'\n'"$LOCALE_ANSWER"$'\nnosuchkeymap\n'"$KEYMAP_ANSWER"$'\nAda\nada@example.com\ny\n' "$T/conf"
    expect "a keymap that does not exist was refused, by name" \
        "$(saw 'no keymap called')" "1"
    expect "and the good one was taken instead" \
        "$(sourced "$T/conf" KEYMAP)" "$KEYMAP_ANSWER"
else
    skip "a missing keymap cannot be detected without $KEYMAP_DIR"
    skip "and so the recovery cannot be checked either"
fi

# ----------------------------------------------------------------------
section "A value that would break either parser cannot be entered"

fresh
run_wizard $'ev"il\nnewuser\nlaptop\n'"$TZ_ANSWER"$'\n'"$LOCALE_ANSWER"$'\n'"$KEYMAP_ANSWER"$'\nAda $(rm -rf /)\nAda `id`\nAda\\Lovelace\nAda\nada@example.com\ny\n' "$T/conf"
expect "exit status is 0" "$RC" "0"
expect "a double quote was refused"  "$(saw 'must not contain a double quote')" "1"
expect "a dollar sign was refused"   "$(saw 'must not contain a dollar sign')" "1"
expect "a backtick was refused"      "$(saw 'must not contain a backtick')" "1"
expect "a backslash was refused"     "$(saw 'must not contain a backslash')" "1"
expect "the clean username was kept" "$(sourced "$T/conf" USERNAME)" "newuser"
expect "the clean git name was kept" "$(sourced "$T/conf" GIT_NAME)" "Ada"

# ----------------------------------------------------------------------
section "Listing and searching the valid answers"

if [[ "$HAVE_TZ" == yes && "$HAVE_LOCALE" == yes && "$HAVE_KEYMAP" == yes ]]; then
    fresh
    run_wizard $'?\nnewuser\nlaptop\n?'"${TZ_ANSWER#*/}"$'\n'"$TZ_ANSWER"$'\n?'"${LOCALE_ANSWER%%.*}"$'\n'"$LOCALE_ANSWER"$'\n?'"$KEYMAP_ANSWER"$'\n'"$KEYMAP_ANSWER"$'\nAda\nada@example.com\ny\n' "$T/conf"
    expect "exit status is 0" "$RC" "0"
    expect "searching the timezones offered $TZ_ANSWER" \
        "$(saw_line "      $TZ_ANSWER")" "1"
    expect "searching the locales offered $LOCALE_ANSWER" \
        "$(saw_line "      $LOCALE_ANSWER")" "1"
    expect "searching the keymaps offered $KEYMAP_ANSWER" \
        "$(saw_line "      $KEYMAP_ANSWER")" "1"
    expect "? on a field with no list says so" \
        "$(saw 'no list of valid values for USERNAME')" "1"
    expect "the searched-for timezone was accepted" \
        "$(sourced "$T/conf" TIMEZONE)" "$TZ_ANSWER"
else
    skip "searching cannot be checked without zoneinfo, locale.gen and kbd all present"
fi

# ----------------------------------------------------------------------
section "The confirmation at the end"

fresh
run_wizard $'newuser\nlaptop\n'"$TZ_ANSWER"$'\n'"$LOCALE_ANSWER"$'\n'"$KEYMAP_ANSWER"$'\nAda\nada@example.com\nn\n' "$T/conf"
expect "answering n fails, rather than writing" "$RC" "1"
untouched "and the file is untouched" "$T/conf"

fresh
run_wizard $'newuser\nlaptop\n'"$TZ_ANSWER"$'\n'"$LOCALE_ANSWER"$'\n'"$KEYMAP_ANSWER"$'\nAda\nada@example.com\nr\n\n\n\n\n\n\nzoe@example.com\ny\n' "$T/conf"
expect "answering r starts over and then succeeds" "$RC" "0"
expect "the earlier answers became the new defaults" \
    "$(sourced "$T/conf" USERNAME)" "newuser"
expect "and the one that was changed is the changed one" \
    "$(sourced "$T/conf" GIT_EMAIL)" "zoe@example.com"

fresh
run_wizard $'newuser\n' "$T/conf"
expect "running out of input fails" "$RC" "1"
expect "and says how to install without answering" \
    "$(saw 'install.sh --no-wizard')" "1"
untouched "and writes nothing at all" "$T/conf"

# ----------------------------------------------------------------------
section "Writing"

fresh
run_wizard "$GOOD" --output "$T/elsewhere" "$T/conf"
expect "--output succeeds" "$RC" "0"
untouched "and leaves the file it read for its defaults alone" "$T/conf"
expect "and writes the answers where it was told" \
    "$(sourced "$T/elsewhere" HOSTNAME)" "laptop"

grep -v '^KEYMAP=' "$CONF" > "$T/conf"
run_wizard "$GOOD" "$T/conf"
expect "a key the file did not carry is appended" "$RC" "0"
expect "and it sources back" "$(sourced "$T/conf" KEYMAP)" "$KEYMAP_ANSWER"
expect "and it said it was appending" "$(saw 'appending it')" "1"

# ----------------------------------------------------------------------
section "The verify-before-replace guard actually fires"

# A check that has never failed has not been tested. render() is sabotaged to
# emit a line that does not close its quote - the exact class of mistake the
# guard exists for - and the run must fail with the target left alone. If the
# sabotage stops matching because the wizard was rewritten, that is reported
# rather than passing silently.
sed 's|printf .%s="%s"\\n. "$key" "${VALUE\[$key\]}" >> "$dest"|printf "%s=\\"%s\\n" "$key" "${VALUE[$key]}" >> "$dest"|' \
    "$WIZARD" > "$T/sabotaged.sh"

if diff -q "$WIZARD" "$T/sabotaged.sh" >/dev/null; then
    fail "the sabotage no longer matches the wizard, so the guard is untested"
    info "update the sed in this section to break render() again"
else
    pass "render() was sabotaged to write an unterminated quote"

    fresh
    RC=0
    OUT="$(printf '%s' "$GOOD" | bash "$T/sabotaged.sh" "$T/conf" 2>&1)" || RC=$?
    expect "the sabotaged wizard fails" "$RC" "1"
    if [[ "$(saw 'not source-able')" -gt 0 || "$(saw 'does not source back')" -gt 0 ]]; then
        pass "and it is the guard that failed it, not something else"
    else
        fail "it failed for some other reason than the guard"
        info "$OUT"
    fi
    untouched "and the target file was left exactly as it was" "$T/conf"
fi

# ----------------------------------------------------------------------
section "install.sh asks, or does not, as instructed"

# install.sh erases a disk and must never be run. What is exercised here is a
# copy that stops two lines before the first stage call, with only the root
# check neutralised - so every line under test is byte-identical to the real
# one. The copy is then read back and refused if anything destructive survived
# the truncation, because this is the one place in the repository where a
# mistake would be expensive.
cut_at="$(grep -n 'Preparing disk' "$INSTALLER" | head -1 | cut -d: -f1 || true)"

if [[ -z "$cut_at" ]]; then
    skip "install.sh no longer has the '[1/5] Preparing disk' line to cut at"
else
    head -n $((cut_at - 2)) "$INSTALLER" |
        sed 's/^if \[\[ $EUID -ne 0 \]\]; then$/if false; then/' \
        > "$T/install.sh"
    echo 'echo "REACHED-DISK-STAGE"' >> "$T/install.sh"
    chmod +x "$T/install.sh"

    # Comments are stripped first: install.sh explains in prose that the
    # wizard runs before 01-disk.sh, and matching that sentence made the guard
    # refuse a copy that was perfectly safe.
    dangerous="$(sed 's/#.*//' "$T/install.sh" |
        grep -cE '01-disk|02-base|arch-chroot|pacstrap|parted|mkfs|umount|poweroff' || true)"
    if [[ "$dangerous" -eq 0 ]]; then
        pass "the truncated copy contains nothing destructive"
    else
        fail "the truncated copy still contains a destructive line - not running it"
    fi

    expect "the root check was neutralised" \
        "$(grep -c '^if false; then$' "$T/install.sh" || true)" "1"

    if [[ "$dangerous" -eq 0 ]] && bash -n "$T/install.sh" 2>/dev/null; then
        pass "the truncated copy parses"

        # It must act on its own setup/ copy, never the repository's.
        cp -a "$REPO_ROOT/setup" "$T/setup"
        reset_setup() { cp "$CONF" "$T/setup/install.conf"; }

        try_installer() { # answers (may be empty), then install.sh's arguments
            local answers="$1"; shift
            RC=0
            if [[ -z "$answers" ]]; then
                OUT="$("$T/install.sh" "$@" </dev/null 2>&1)" || RC=$?
            else
                OUT="$(printf '%s' "$answers" | "$T/install.sh" "$@" 2>&1)" || RC=$?
            fi
        }

        reset_setup
        try_installer ""
        expect "no disk argument is refused" "$RC" "1"
        expect "and it prints its usage" "$(saw 'Usage: install.sh')" "1"

        reset_setup
        try_installer "" --wizzard /dev/vda
        expect "an unknown option is refused" "$RC" "1"
        expect "and it names the option" "$(saw 'Unknown option: --wizzard')" "1"

        reset_setup
        try_installer "" /dev/vda /dev/vdb
        expect "two disks are refused" "$RC" "1"
        expect "and it says why" "$(saw 'Only one disk')" "1"

        reset_setup
        try_installer "" --no-wizard /dev/vda
        expect "--no-wizard reaches the disk stage" "$RC" "0"
        expect "having asked nothing" "$(saw 'Wizard skipped (--no-wizard)')" "1"
        untouched "leaving install.conf exactly as committed" "$T/setup/install.conf"
        expect "and it prints the identity it will build with" \
            "$(saw 'USERNAME = ')" "1"

        reset_setup
        try_installer "" /dev/vda --no-wizard
        expect "the flag works after the disk as well as before" "$RC" "0"

        # This is the whole non-interactive path: an existing scripted build
        # passes no new flag, and must keep working exactly as it did.
        reset_setup
        try_installer "" /dev/vda
        expect "no flag and no terminal skips the wizard" "$RC" "0"
        expect "and says that is why" "$(saw 'stdin is not a terminal')" "1"
        untouched "leaving install.conf exactly as committed" "$T/setup/install.conf"

        reset_setup
        try_installer $'zoe\nnest\n'"$TZ_ANSWER"$'\n'"$LOCALE_ANSWER"$'\n'"$KEYMAP_ANSWER"$'\nZoe Q\nzoe@example.com\ny\n' --wizard /dev/vda
        expect "--wizard asks even with no terminal" "$RC" "0"
        expect "and the answers land in install.conf before the disk stage" \
            "$(sourced "$T/setup/install.conf" USERNAME)" "zoe"
        expect "and the identity banner shows them" "$(saw 'HOSTNAME = nest')" "1"
        expect "and it did reach the disk stage" "$(saw 'REACHED-DISK-STAGE')" "1"

        reset_setup
        try_installer $'zoe\nnest\n'"$TZ_ANSWER"$'\n'"$LOCALE_ANSWER"$'\n'"$KEYMAP_ANSWER"$'\nZoe Q\nzoe@example.com\nn\n' --wizard /dev/vda
        expect "aborting the wizard fails the install" "$RC" "1"
        expect "before the disk stage is reached" "$(saw 'REACHED-DISK-STAGE')" "0"
        untouched "and install.conf is untouched" "$T/setup/install.conf"
    else
        skip "the truncated copy is not safe or does not parse; not running it"
    fi
fi

# ----------------------------------------------------------------------
section "This check wrote nothing it should not have"

untouched "the repository's setup/install.conf is unchanged" "$CONF"

printf '\n========================================\n'
printf ' %d passed, %d failed, %d skipped\n' "$PASS" "$FAIL" "$SKIP"
printf '========================================\n'

[[ $FAIL -eq 0 ]]
