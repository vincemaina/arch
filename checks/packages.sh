#!/usr/bin/env bash
set -euo pipefail

# Does what is installed on this machine match setup/packages/?
#
# The manifests are meant to be the intentional description of the system, and
# nothing enforced that. Two ways they rot, both quiet:
#
#   * something is installed by hand to try it out and is never declared. A
#     rebuilt machine does not have it, and nobody finds out until it is
#     missing - which is long after the person who installed it has forgotten.
#   * something is added to a manifest while it is already present as a
#     dependency of something else. sync.sh installs with `pacman -T`, which
#     reports it as satisfied, so pacman is never told the package is now
#     wanted in its own right. It stays marked as a dependency and remains one
#     orphan-removal away from disappearing - which is the precise thing
#     packages/README.md says listing it was supposed to prevent.
#
# So the model here is: **the manifests declare the set of packages that should
# be explicitly installed**, and drift is the difference between that set and
# `pacman -Qqe`, in both directions. The full dependency closure is not the
# subject - `pacman -Q` lists several hundred packages and only the top-level
# ones are a decision anybody made.
#
# This is a check rather than a tool: it ends in a verdict and exits non-zero
# when the two disagree, so it can gate a commit or another check.
#
# It does not care which manifest a package is in. base/desktop/dev is a
# statement about when a package is installed, not about whether it is wanted,
# and moving a line between two files is not drift.
#
# Runs on an installed Arch machine; it needs the local package database.
# Read-only - it never installs, removes or re-marks anything, it only says
# which command would.

# pacman's -Qi field labels are translated. Every parse below matches on
# "Provides", "Name" and "Required By", so pin the locale rather than assume
# the machine runs in English. Also makes `sort` ordering deterministic.
export LC_ALL=C

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST_DIR="$REPO_ROOT/setup/packages"

PASS=0
FAIL=0
SKIP=0

pass() { printf '  \033[32mPASS\033[0m  %s\n' "$*"; PASS=$((PASS + 1)); }
fail() { printf '  \033[31mFAIL\033[0m  %s\n' "$*"; FAIL=$((FAIL + 1)); }
skip() { printf '  \033[33mSKIP\033[0m  %s\n' "$*"; SKIP=$((SKIP + 1)); }
info() { printf '        %s\n' "$*"; }

section() { printf '\n==> %s\n' "$*"; }

if ! command -v pacman &>/dev/null; then
    echo "Required command not found: pacman" >&2
    echo "This check runs on an installed Arch system." >&2
    exit 1
fi

shopt -s nullglob
MANIFESTS=("$MANIFEST_DIR"/*.txt)
shopt -u nullglob

if [[ ${#MANIFESTS[@]} -eq 0 ]]; then
    echo "No manifests found in $MANIFEST_DIR" >&2
    exit 1
fi

# ----------------------------------------------------------------------
section "Manifest hygiene"

# The two manifest parsers do not agree, and the disagreement is invisible on
# the machine you are testing on. 02-base.sh reads base.txt with a bare
# `mapfile` and no filtering, so a comment or a blank line in it is handed to
# pacstrap as a package name and a fresh install dies. sync.sh globs
# packages/*.txt through a comment-stripping grep, so the same file keeps
# working here forever. Only a rebuild would ever find it. Check it instead.
BASE_MANIFEST="$MANIFEST_DIR/base.txt"

if [[ ! -f "$BASE_MANIFEST" ]]; then
    fail "$BASE_MANIFEST does not exist"
else
    # grep -c, not grep -q: -q exits at the first match and closes the pipe,
    # the writer takes SIGPIPE, and pipefail turns that into a failure of the
    # whole pipeline. See the scripting-traps skill. Here the output is
    # captured rather than counted, which reads its input to the end for the
    # same reason.
    offenders="$(grep -nE '^[[:space:]]*(#|$)' "$BASE_MANIFEST" || true)"
    if [[ -z "$offenders" ]]; then
        pass "base.txt is one package per line, no comments or blank lines"
    else
        fail "base.txt contains comments or blank lines, which 02-base.sh passes to pacstrap as package names"
        while IFS= read -r line; do
            info "line ${line%%:*}"
        done <<<"$offenders"
        info "sync.sh strips them, so this only breaks a fresh install"
    fi
fi

# Neither parser trims. A line with a stray trailing space, a tab, or two
# names on it survives the comment-stripping grep intact and is handed to
# pacman as a package name, where it surfaces two sections down as "declared
# but not installed" - which reads like a missing package rather than like a
# typo. Arch package names are [a-z0-9@._+-]; anything else on a package line
# is a mistake.
malformed="$(
    awk '!/^[[:space:]]*(#|$)/ && !/^[a-zA-Z0-9@._+-]+$/ {
             printf "%s:%d:%s\n", FILENAME, FNR, $0
         }' "${MANIFESTS[@]}" || true
)"
if [[ -z "$malformed" ]]; then
    pass "every package line is a bare package name"
else
    while IFS= read -r line; do
        fail "$(basename "${line%%:*}") line $(cut -d: -f2 <<<"$line") is not a bare package name: [$(cut -d: -f3- <<<"$line")]"
    done <<<"$malformed"
    info "leading or trailing whitespace is passed to pacman as part of the name"
fi

duplicates="$(grep -hEv '^[[:space:]]*(#|$)' "${MANIFESTS[@]}" | sort | uniq -d || true)"
if [[ -z "$duplicates" ]]; then
    pass "no package is listed in more than one place"
else
    while IFS= read -r dup; do
        where="$(grep -nFx -- "$dup" "${MANIFESTS[@]}" |
            sed -E "s|^${MANIFEST_DIR}/||; s|:[^:]*\$||" | tr '\n' ' ')"
        fail "$dup is listed more than once: $where"
    done <<<"$duplicates"
fi

# ----------------------------------------------------------------------
section "What the repository declares"

# The permissive parser, the one sync.sh uses: comments and blank lines are
# fine everywhere except base.txt, which the section above is about.
mapfile -t DECLARED < <(
    grep -hEv '^[[:space:]]*(#|$)' "${MANIFESTS[@]}" | sort -u
)

if [[ ${#DECLARED[@]} -eq 0 ]]; then
    echo "No packages declared in $MANIFEST_DIR" >&2
    exit 1
fi

mapfile -t EXPLICIT < <(pacman -Qqe | sort -u)
mapfile -t PRESENT < <(pacman -Qq | sort -u)
mapfile -t AS_DEPENDENCY < <(pacman -Qdq | sort -u)

info "${#DECLARED[@]} packages declared across ${#MANIFESTS[@]} manifests"
info "${#EXPLICIT[@]} packages explicitly installed, ${#PRESENT[@]} present in total"

# Membership is asked several hundred times below. Associative arrays rather
# than a grep per question: exact string matching, no pattern or quoting
# surface, and no pipeline to take a SIGPIPE.
declare -A IS_DECLARED=() IS_EXPLICIT=() IS_PRESENT=() IS_DEPENDENCY=()
for pkg in "${DECLARED[@]}"; do IS_DECLARED["$pkg"]=1; done
for pkg in "${EXPLICIT[@]}"; do IS_EXPLICIT["$pkg"]=1; done
for pkg in "${PRESENT[@]}"; do IS_PRESENT["$pkg"]=1; done
for pkg in ${AS_DEPENDENCY+"${AS_DEPENDENCY[@]}"}; do IS_DEPENDENCY["$pkg"]=1; done

# Built once, and only if something needs it: which installed package provides
# a name that is not itself installed.
declare -A PROVIDER_OF=()
PROVIDES_MAP_BUILT=false

build_provides_map() {
    if [[ "$PROVIDES_MAP_BUILT" == true ]]; then
        return 0
    fi
    PROVIDES_MAP_BUILT=true

    local line pkg="" name
    while IFS= read -r line; do
        if [[ "$line" =~ ^Name[[:space:]]+:[[:space:]]*(.*)$ ]]; then
            pkg="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^Provides[[:space:]]+:[[:space:]]*(.*)$ ]]; then
            for name in ${BASH_REMATCH[1]}; do
                [[ "$name" == "None" ]] && continue
                name="${name%%[<>=]*}"
                [[ -n "$name" ]] || continue
                # First writer wins, so the report is stable.
                [[ -v PROVIDER_OF["$name"] ]] || PROVIDER_OF["$name"]="$pkg"
            done
        fi
    done < <(pacman -Qi)
}

required_by() {
    pacman -Qi -- "$1" | awk -F': *' '/^Required By/ {print $2}'
}

# `pacman -Si` is how a declared-but-missing package is told apart from a typo,
# and it can only answer that if the sync database has been populated. On a
# machine that has never run `pacman -Sy`, every missing package would look
# like a typo. Ask once.
SYNC_DB_POPULATED=false
if [[ "$(pacman -Slq 2>/dev/null | grep -c . || true)" -gt 0 ]]; then
    SYNC_DB_POPULATED=true
fi

# ----------------------------------------------------------------------
section "Declared but not installed"

# pacman -T rather than a set difference, because it understands a package
# being satisfied under another name. It exits non-zero when something is
# unsatisfied, which is the normal case here and not an error.
mapfile -t UNSATISFIED < <(pacman -T -- "${DECLARED[@]}" 2>/dev/null | sort -u || true)

declare -A IS_UNSATISFIED=()
for pkg in ${UNSATISFIED+"${UNSATISFIED[@]}"}; do IS_UNSATISFIED["$pkg"]=1; done

if [[ ${#UNSATISFIED[@]} -eq 0 ]]; then
    pass "every declared package is satisfied"
else
    for pkg in "${UNSATISFIED[@]}"; do
        if [[ "$SYNC_DB_POPULATED" != true ]]; then
            fail "$pkg is declared but not installed"
        elif pacman -Si -- "$pkg" &>/dev/null; then
            fail "$pkg is declared but not installed"
        else
            fail "$pkg is declared, not installed, and no such package exists in the repositories"
            info "a typo in a manifest looks exactly like this"
        fi
    done
    if [[ "$SYNC_DB_POPULATED" != true ]]; then
        info "the sync database is empty, so a typo cannot be told from a missing package here"
    fi
    info "install them with ./sync.sh, or drop the line if it is no longer wanted"
fi

# ----------------------------------------------------------------------
section "Declared but installed as a dependency"

# Present, so nothing reports it as missing, but pacman believes it is only
# here to satisfy something else and will remove it with `-Rns` on that
# something else. A package is in a manifest precisely so that cannot happen.
DEP_MARKED=()
PROVIDED_BY_EXPLICIT=()
PROVIDED_BY_DEPENDENCY=()
PROVIDED_BY_UNKNOWN=()

for pkg in "${DECLARED[@]}"; do
    [[ -v IS_EXPLICIT["$pkg"] ]] && continue
    if [[ -v IS_DEPENDENCY["$pkg"] ]]; then
        DEP_MARKED+=("$pkg")
    elif [[ ! -v IS_PRESENT["$pkg"] ]]; then
        # Not installed under this name at all. Either genuinely absent, which
        # the previous section already reported, or satisfied by a package
        # providing the name.
        [[ -v IS_UNSATISFIED["$pkg"] ]] && continue
        build_provides_map
        provider="${PROVIDER_OF[$pkg]:-}"
        if [[ -z "$provider" ]]; then
            PROVIDED_BY_UNKNOWN+=("$pkg")
        elif [[ -v IS_EXPLICIT["$provider"] ]]; then
            PROVIDED_BY_EXPLICIT+=("$pkg=$provider")
        else
            PROVIDED_BY_DEPENDENCY+=("$pkg=$provider")
        fi
    fi
done

if [[ ${#DEP_MARKED[@]} -eq 0 && ${#PROVIDED_BY_DEPENDENCY[@]} -eq 0 ]]; then
    pass "every installed declared package is marked as explicitly installed"
fi

if [[ ${#DEP_MARKED[@]} -gt 0 ]]; then
    for pkg in "${DEP_MARKED[@]}"; do
        fail "$pkg is declared, but pacman has it as a dependency of: $(required_by "$pkg")"
    done
    info "removing what needs them would take them with it, which is what declaring them was meant to prevent"
    info "fix:  sudo pacman -D --asexplicit ${DEP_MARKED[*]}"
fi

# The same orphan risk, one step removed: the declared name is satisfied, but
# only by a package pacman also believes it can remove.
if [[ ${#PROVIDED_BY_DEPENDENCY[@]} -gt 0 ]]; then
    providers=()
    for entry in "${PROVIDED_BY_DEPENDENCY[@]}"; do
        pkg="${entry%%=*}"; provider="${entry#*=}"
        fail "$pkg is declared and provided by $provider, which pacman has as a dependency of: $(required_by "$provider")"
        providers+=("$provider")
    done
    info "the capability is declared, but the only thing supplying it can still be removed as an orphan"
    info "fix:  sudo pacman -D --asexplicit ${providers[*]}"
fi

for entry in ${PROVIDED_BY_EXPLICIT+"${PROVIDED_BY_EXPLICIT[@]}"}; do
    skip "${entry%%=*} is not installed under that name; ${entry#*=} provides it and is explicitly installed"
done

for pkg in ${PROVIDED_BY_UNKNOWN+"${PROVIDED_BY_UNKNOWN[@]}"}; do
    skip "$pkg is satisfied but nothing installed declares it in Provides; pacman resolved it another way"
done

# ----------------------------------------------------------------------
section "Installed but not declared"

UNDECLARED=()
for pkg in "${EXPLICIT[@]}"; do
    [[ -v IS_DECLARED["$pkg"] ]] || UNDECLARED+=("$pkg")
done

# An explicitly installed package may be standing in for a declared name it
# provides. Nothing here declares a virtual package today, but a manifest line
# like `ttf-font` would make this the difference between a clean run and a
# false report.
if [[ ${#UNDECLARED[@]} -gt 0 ]]; then
    KEPT=()
    for pkg in "${UNDECLARED[@]}"; do
        satisfies=""
        while IFS= read -r name; do
            [[ -z "$name" || "$name" == "None" ]] && continue
            if [[ -v IS_DECLARED["$name"] ]]; then
                satisfies="$name"
                break
            fi
        done < <(
            pacman -Qi -- "$pkg" |
                awk -F': *' '/^Provides/ {print $2}' |
                tr ' ' '\n' |
                sed -E 's/[<>=].*$//'
        )
        if [[ -n "$satisfies" ]]; then
            pass "$pkg provides $satisfies, which is declared"
        else
            KEPT+=("$pkg")
        fi
    done
    UNDECLARED=(${KEPT+"${KEPT[@]}"})
fi

if [[ ${#UNDECLARED[@]} -eq 0 ]]; then
    pass "every explicitly installed package is declared"
else
    # Split by remedy. A package the manifests already depend on does not need
    # declaring - it needs pacman to stop calling it a top-level choice.
    # Anything else is a real decision that was never written down.
    declare -A IN_CLOSURE=()
    if command -v pactree &>/dev/null; then
        while IFS= read -r name; do
            [[ -n "$name" ]] && IN_CLOSURE["$name"]=1
        done < <(
            for pkg in "${DECLARED[@]}"; do
                pactree -lu "$pkg" 2>/dev/null || true
            done | sort -u
        )
    else
        skip "pactree not found, so undeclared packages cannot be split by remedy (pacman-contrib provides it)"
    fi

    REDUNDANT=()
    AD_HOC=()
    for pkg in "${UNDECLARED[@]}"; do
        if [[ -v IN_CLOSURE["$pkg"] ]]; then
            REDUNDANT+=("$pkg")
        else
            AD_HOC+=("$pkg")
        fi
    done

    for pkg in ${REDUNDANT+"${REDUNDANT[@]}"}; do
        fail "$pkg is marked as a top-level choice but is only needed by: $(required_by "$pkg")"
    done
    if [[ ${#REDUNDANT[@]} -gt 0 ]]; then
        info "fix:  sudo pacman -D --asdeps ${REDUNDANT[*]}"
    fi

    for pkg in ${AD_HOC+"${AD_HOC[@]}"}; do
        fail "$pkg is installed by hand and nothing in setup/packages/ declares or needs it"
    done
    if [[ ${#AD_HOC[@]} -gt 0 ]]; then
        info "a rebuilt machine would not have these"
        info "declare them in a manifest, or:  sudo pacman -Rns ${AD_HOC[*]}"
    fi
fi

# ----------------------------------------------------------------------
printf '\n========================================\n'
printf ' %d passed, %d failed, %d skipped\n' "$PASS" "$FAIL" "$SKIP"
printf '========================================\n'

if [[ $FAIL -eq 0 ]]; then
    printf '\nThe manifests describe this machine.\n'
else
    printf '\nThe manifests and this machine disagree in %d place(s).\n' "$FAIL"
    printf 'Every line above says which command settles it. None were run.\n'
fi

[[ $FAIL -eq 0 ]]
