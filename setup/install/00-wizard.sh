#!/usr/bin/env bash
#
# The install wizard: asks for this machine's identity and writes it into
# setup/install.conf, so building a machine no longer starts with editing a
# file by hand.
#
# WHERE IT RUNS. On the booted Arch live ISO, as root, against the repository
# checkout - the same context as 01-disk.sh and 02-base.sh, and *before* both,
# because nothing here touches the disk and asking these questions after the
# disk is erased would be too late to change an answer.
#
# WHAT IT MAY USE. Only what the ISO already carries: bash, coreutils, awk,
# find, and the data files shipped by tzdata (/usr/share/zoneinfo), glibc
# (/etc/locale.gen) and kbd (/usr/share/kbd/keymaps). Deliberately no TUI:
# neither dialog nor whiptail is on the Arch install medium, and a wizard that
# has to install a package before it can ask its first question is worse than
# the text editor it replaces.
#
# WHAT IT WRITES. setup/install.conf, in place, replacing only the KEY="value"
# lines and leaving every comment exactly where it was. That file has two
# consumers with two different parsers and both have to keep working:
#
#   - 03-system.sh and 05-dotfiles.sh `source` it, so a value has to survive
#     shell evaluation;
#   - setup/dotfiles/dot_gitconfig.tmpl parses it with the regex
#     ^[A-Z_]+="[^"]*" and chezmoi's `include "../install.conf"`, so a value
#     must not contain a double quote and the quoting style must not drift.
#
# So every answer is refused if it contains " \ ` $ or a control character,
# and the finished file is sourced back in a clean subshell and compared to
# the answers before it is allowed to replace the original. An install.conf
# that does not source would fail three stages later, inside a chroot, on a
# machine with no way to edit it - which is exactly the invisible-failure mode
# this repository keeps hitting.
#
# WHAT IT DOES NOT ASK. Passwords. 03-system.sh asks for those interactively
# at the point they are set, and nothing here ever stores one.
#
# Every answer is also validated against the live system rather than against a
# regex alone: the timezone must be a real zoneinfo file, the locale must be a
# UTF-8 line that exists in /etc/locale.gen (because 03-system.sh un-comments
# exactly that line and then writes LANG verbatim), the keymap must be a real
# kbd keymap. A subtly wrong answer here does not fail the install; it
# produces a machine that boots with the wrong keyboard an hour later.

set -euo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_CONF="$(cd "$SELF_DIR/.." && pwd)/install.conf"

ZONEINFO="${ZONEINFO_DIR:-/usr/share/zoneinfo}"
LOCALE_GEN="${LOCALE_GEN_FILE:-/etc/locale.gen}"
KEYMAP_DIR="${KEYMAP_DIR:-/usr/share/kbd/keymaps}"

# The keys the wizard owns, in the order it asks for them. Any other KEY="..."
# line in install.conf is left untouched.
KEYS=(USERNAME HOSTNAME TIMEZONE LOCALE KEYMAP GIT_NAME GIT_EMAIL)

declare -A VALUE=()
declare -A DEFAULT=()

usage() {
    cat <<'USAGE'
Usage: 00-wizard.sh [--output FILE] [CONF]

Asks for this machine's identity and writes it to CONF, which defaults to
setup/install.conf next to this script. Existing values in CONF are offered as
the defaults, so pressing Enter through the whole wizard changes nothing.

  --output FILE   write the result to FILE instead of CONF (CONF is still read
                  for its defaults and its comments). Used for testing.
  -h, --help      this message.

At any prompt, "?" lists the valid answers and "?text" searches them.
USAGE
}

die() {
    printf 'wizard: %s\n' "$*" >&2
    exit 1
}

say() { printf '%s\n' "$*" >&2; }
bad() { printf '  ! %s\n' "$*" >&2; }

# ---------------------------------------------------------------- candidates

candidates_TIMEZONE() {
    # zone1970.tab is the curated list; UTC is a real zone that is not in it.
    {
        echo UTC
        [[ -f "$ZONEINFO/zone1970.tab" ]] &&
            awk '!/^#/ && NF >= 3 { print $3 }' "$ZONEINFO/zone1970.tab"
    } | sort -u
}

candidates_LOCALE() {
    # Only locales whose *name* carries the UTF-8 suffix. 03-system.sh
    # un-comments "<name> UTF-8" and then writes LANG=<name> verbatim, so a
    # bare name like "aa_ER" would generate aa_ER.utf8 and set LANG to
    # something glibc cannot resolve.
    [[ -f "$LOCALE_GEN" ]] || return 0
    awk '{ sub(/^#/, "") } $2 == "UTF-8" && $1 ~ /\.UTF-8/ { print $1 }' \
        "$LOCALE_GEN" | sort -u
}

candidates_KEYMAP() {
    [[ -d "$KEYMAP_DIR" ]] || return 0
    # find exits non-zero if a directory vanishes; the list is advisory.
    find "$KEYMAP_DIR" -type f -name '*.map.gz' 2>/dev/null |
        sed 's|.*/||; s|\.map\.gz$||' | sort -u || true
}

# Print up to 12 candidates matching $2 (empty = the head of the list).
show_candidates() {
    local key="$1" needle="${2:-}" list matches total
    list="$(candidates_"$key" 2>/dev/null || true)"

    if [[ -z "$list" ]]; then
        bad "no list of valid $key values is available on this system."
        return 0
    fi

    if [[ -n "$needle" ]]; then
        matches="$(printf '%s\n' "$list" | grep -i -- "$needle" || true)"
    else
        matches="$list"
    fi

    if [[ -z "$matches" ]]; then
        bad "nothing matching '$needle'."
        return 0
    fi

    total="$(printf '%s\n' "$matches" | grep -c . || true)"
    # head exits early and SIGPIPEs printf; pipefail would make that fatal.
    printf '%s\n' "$matches" | head -12 | sed 's/^/      /' >&2 || true
    [[ "$total" -gt 12 ]] && say "      ... and $((total - 12)) more"
    return 0
}

in_candidates() {
    local key="$1" value="$2" list
    list="$(candidates_"$key" 2>/dev/null || true)"
    [[ -z "$list" ]] && return 0   # no list available: cannot judge, allow
    # grep -c, never grep -q: -q closes the pipe, printf takes SIGPIPE and
    # pipefail then reports the pipeline as failed. See the scripting-traps skill.
    [[ "$(printf '%s\n' "$list" | grep -cxF -- "$value" || true)" -gt 0 ]]
}

# --------------------------------------------------------------- validation

# Refuse anything that would not survive both parsers of install.conf.
shell_safe() {
    local v="$1"
    case "$v" in
        *'"'*) bad 'must not contain a double quote: dot_gitconfig.tmpl parses KEY="value".' ; return 1 ;;
        *'\'*) bad 'must not contain a backslash: the stage scripts source this file.' ; return 1 ;;
        *'`'*) bad 'must not contain a backtick: the stage scripts source this file.' ; return 1 ;;
        *'$'*) bad 'must not contain a dollar sign: the stage scripts source this file.' ; return 1 ;;
    esac
    if [[ "$v" == *[[:cntrl:]]* ]]; then
        bad 'must not contain control characters.'
        return 1
    fi
    return 0
}

validate_USERNAME() {
    local v="$1"
    if [[ ${#v} -gt 32 ]]; then
        bad 'at most 32 characters (useradd refuses longer).'
        return 1
    fi
    if ! [[ "$v" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
        bad 'lower-case letters, digits, - and _ only, and must not start with a digit.'
        return 1
    fi
    if [[ "$v" == root ]]; then
        bad 'root already exists; this is the everyday login account.'
        return 1
    fi
    return 0
}

validate_HOSTNAME() {
    local v="$1"
    if [[ ${#v} -gt 63 ]]; then
        bad 'at most 63 characters.'
        return 1
    fi
    if ! [[ "$v" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?$ ]]; then
        bad 'letters, digits and hyphens only, and must not start or end with a hyphen.'
        return 1
    fi
    return 0
}

validate_TIMEZONE() {
    local v="$1"
    if ! [[ "$v" =~ ^[A-Za-z0-9][A-Za-z0-9_+-]*(/[A-Za-z0-9_+-]+)*$ ]]; then
        bad 'looks like Region/City, for example Europe/London.'
        return 1
    fi
    if [[ -d "$ZONEINFO" ]] && [[ ! -f "$ZONEINFO/$v" ]]; then
        bad "no such zone: $ZONEINFO/$v does not exist."
        show_candidates TIMEZONE "$v"
        return 1
    fi
    return 0
}

validate_LOCALE() {
    local v="$1"
    if ! [[ "$v" =~ ^[a-zA-Z0-9_-]+\.UTF-8(@[a-zA-Z0-9]+)?$ ]]; then
        bad 'must be a UTF-8 locale name, for example en_GB.UTF-8.'
        return 1
    fi
    if ! in_candidates LOCALE "$v"; then
        bad "$LOCALE_GEN has no '$v UTF-8' line, so locale-gen would generate nothing."
        show_candidates LOCALE "${v%%.*}"
        return 1
    fi
    return 0
}

validate_KEYMAP() {
    local v="$1"
    if ! [[ "$v" =~ ^[A-Za-z0-9_.+-]+$ ]]; then
        bad 'a kbd keymap name, for example uk or us.'
        return 1
    fi
    if ! in_candidates KEYMAP "$v"; then
        bad "no keymap called '$v' under $KEYMAP_DIR."
        show_candidates KEYMAP "$v"
        return 1
    fi
    return 0
}

validate_GIT_NAME() {
    # Anything printable. An empty one is already refused by ask(), and an
    # empty user.name is the failure dot_gitconfig.tmpl exists to prevent.
    return 0
}

validate_GIT_EMAIL() {
    local v="$1"
    if ! [[ "$v" =~ ^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$ ]]; then
        bad 'looks like name@example.com.'
        return 1
    fi
    return 0
}

# ------------------------------------------------------------------- asking

describe() {
    case "$1" in
        USERNAME) echo 'The everyday login account. Created by 03-system.sh, in the wheel group.' ;;
        HOSTNAME) echo "The machine's name, in /etc/hostname." ;;
        TIMEZONE) echo 'A zoneinfo name. "?" lists them, "?Lond" searches.' ;;
        LOCALE)   echo 'The system locale, un-commented in /etc/locale.gen and used as LANG.' ;;
        KEYMAP)   echo 'The console keymap, for /etc/vconsole.conf. Sway sets its own separately.' ;;
        GIT_NAME) echo "git's user.name, read by dot_gitconfig.tmpl (not by the stage scripts)." ;;
        GIT_EMAIL) echo "git's user.email, read by dot_gitconfig.tmpl." ;;
    esac
}

ask() {
    local key="$1" default="${DEFAULT[$key]:-}" answer
    while true; do
        say ""
        say "$(describe "$key")"
        if [[ -n "$default" ]]; then
            printf '  %s [%s]: ' "$key" "$default" >&2
        else
            printf '  %s: ' "$key" >&2
        fi

        if ! IFS= read -r answer; then
            say ""
            die "ran out of input while asking for $key. For a non-interactive install, fill in ${CONF} and run install.sh --no-wizard."
        fi
        # A terminal echoes what was typed; a pipe does not, and the prompt has
        # no trailing newline - so a piped run would run the answer, the next
        # message and the next prompt all into one line. Echo it back instead,
        # which is what makes a scripted transcript readable.
        [[ -t 0 ]] || printf '%s\n' "$answer" >&2

        # trim surrounding whitespace
        answer="${answer#"${answer%%[![:space:]]*}"}"
        answer="${answer%"${answer##*[![:space:]]}"}"

        if [[ "$answer" == '?'* ]]; then
            if declare -F "candidates_$key" >/dev/null; then
                show_candidates "$key" "${answer#\?}"
            else
                bad "no list of valid values for $key."
            fi
            continue
        fi

        [[ -z "$answer" ]] && answer="$default"

        if [[ -z "$answer" ]]; then
            bad "$key cannot be empty."
            continue
        fi

        shell_safe "$answer" || continue
        "validate_$key" "$answer" || continue

        VALUE[$key]="$answer"
        return 0
    done
}

# ------------------------------------------------------------------ reading

# Read the current KEY="value" lines. Parsed rather than sourced, because this
# is the same shape dot_gitconfig.tmpl matches on, and because a defaults file
# should never be able to run code.
load_defaults() {
    local file="$1" line key
    [[ -f "$file" ]] || die "no such file: $file"
    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" =~ ^([A-Z_]+)=\"(.*)\"[[:space:]]*$ ]]; then
            key="${BASH_REMATCH[1]}"
            DEFAULT[$key]="${BASH_REMATCH[2]}"
        fi
    done < "$file"
}

# ------------------------------------------------------------------ writing

# Rewrite only the lines the wizard owns; every comment survives.
render() {
    local src="$1" dest="$2" line key
    declare -A written=()

    : > "$dest"
    while IFS= read -r line || [[ -n "$line" ]]; do
        key=""
        if [[ "$line" =~ ^([A-Z_]+)=\" ]]; then
            key="${BASH_REMATCH[1]}"
        fi
        if [[ -n "$key" && -n "${VALUE[$key]+x}" ]]; then
            printf '%s="%s"\n' "$key" "${VALUE[$key]}" >> "$dest"
            written[$key]=1
        else
            printf '%s\n' "$line" >> "$dest"
        fi
    done < "$src"

    # A key the file did not already carry is appended rather than dropped.
    for key in "${KEYS[@]}"; do
        if [[ -z "${written[$key]:-}" ]]; then
            say "  note: $key was not in $src; appending it."
            printf '%s="%s"\n' "$key" "${VALUE[$key]}" >> "$dest"
        fi
    done
}

# Source the rendered file in a clean subshell and compare what comes back to
# what was answered. This is the check that a wizard writing a broken
# install.conf cannot pass: it proves the file the stage scripts will source
# yields exactly these values.
verify() {
    local file="$1" got expected key
    got="$(env -i bash --noprofile --norc -c '
        set -euo pipefail
        # shellcheck disable=SC1090
        . "$1"
        shift
        for k in "$@"; do
            printf "%s=%s\n" "$k" "${!k-<UNSET>}"
        done
    ' _ "$file" "${KEYS[@]}" 2>&1)" || {
        say "$got"
        die "the file just written is not source-able. Nothing was changed."
    }

    expected=""
    for key in "${KEYS[@]}"; do
        expected+="$key=${VALUE[$key]}"$'\n'
    done

    if [[ "$got"$'\n' != "$expected" ]]; then
        say "expected:"; say "$expected"
        say "sourced back:"; say "$got"
        die "the file just written does not source back to the answers. Nothing was changed."
    fi

    # The second consumer: dot_gitconfig.tmpl's regex.
    for key in "${KEYS[@]}"; do
        if [[ "$(grep -cxF -- "${key}=\"${VALUE[$key]}\"" "$file" || true)" -ne 1 ]]; then
            die "$key is not written as ${key}=\"...\" exactly once; dot_gitconfig.tmpl would not parse it. Nothing was changed."
        fi
    done
}

# --------------------------------------------------------------------- main

CONF=""
OUTPUT=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help) usage; exit 0 ;;
        --output) [[ $# -ge 2 ]] || die "--output needs a path"; OUTPUT="$2"; shift 2 ;;
        --output=*) OUTPUT="${1#--output=}"; shift ;;
        -*) usage >&2; die "unknown option: $1" ;;
        *) [[ -z "$CONF" ]] || die "only one config file may be given"; CONF="$1"; shift ;;
    esac
done

[[ -n "$CONF" ]] || CONF="$DEFAULT_CONF"
[[ -n "$OUTPUT" ]] || OUTPUT="$CONF"

load_defaults "$CONF"

say "========================================"
say " Machine identity"
say "========================================"
say ""
say "Answer or press Enter to keep the value already in"
say "$CONF."
say ""
say "Passwords are NOT asked for here and are never written to a file;"
say "03-system.sh asks for them while it creates the accounts."

while true; do
    for key in "${KEYS[@]}"; do
        ask "$key"
    done

    say ""
    say "----------------------------------------"
    for key in "${KEYS[@]}"; do
        printf '  %-10s %s\n' "$key" "${VALUE[$key]}" >&2
    done
    say "----------------------------------------"
    printf '  Write this to %s? [Y/n/r] (r = start over): ' "$OUTPUT" >&2

    if ! IFS= read -r reply; then
        say ""
        die "ran out of input at the confirmation. Nothing was changed."
    fi
    [[ -t 0 ]] || printf '%s\n' "$reply" >&2

    case "${reply,,}" in
        ''|y|yes) break ;;
        r|redo|again)
            # Re-asking starts from the answers just given, not the file.
            for key in "${KEYS[@]}"; do DEFAULT[$key]="${VALUE[$key]}"; done
            continue
            ;;
        n|no|q|quit) die "aborted at the user's request. Nothing was changed." ;;
        *) bad "answer y, n or r." ;;
    esac
done

TMP="$(mktemp "${OUTPUT}.wizard.XXXXXX")"
trap 'rm -f "$TMP"' EXIT

render "$CONF" "$TMP"
verify "$TMP"

if [[ -f "$OUTPUT" ]]; then
    chmod --reference="$OUTPUT" "$TMP"
else
    chmod 644 "$TMP"
fi

mv "$TMP" "$OUTPUT"
trap - EXIT

say ""
say "Wrote $OUTPUT."
