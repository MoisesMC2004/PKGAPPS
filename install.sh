#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# PKGAPPS - Automated System Installer, Migrator & Uninstaller (Omarchy TUI)
# ==============================================================================

SCRIPT_SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || pwd)"

main() {

GITHUB_USER="MoisesMC2004"
REPO_RAW_URL="https://raw.githubusercontent.com/${GITHUB_USER}/pkgapps/main/pkgapps"
GLOBAL_CONF="/etc/pkgapps.conf"

# TrueColor & ANSI Palette
C_RESET="\033[0m"
C_BOLD="\033[1m"
C_DIM="\033[38;2;108;112;134m"
C_TEXT="\033[38;2;205;214;244m"
C_SUBTEXT="\033[38;2;166;173;200m"
C_BORDER="\033[38;2;116;199;236m"
C_CYAN="\033[38;2;0;240;255m"
C_PURPLE="\033[38;2;168;85;247m"
C_GREEN="\033[38;2;166;227;161m"
C_YELLOW="\033[38;2;249;226;175m"
C_RED="\033[38;2;243;139;168m"

# Active Button Highlight (Cyan/Green pill with dark bold text like Omarchy)
BTN_ACTIVE="\033[48;2;137;220;235m\033[38;2;17;17;27m\033[1m"
BTN_WARN_ACTIVE="\033[48;2;243;139;168m\033[38;2;17;17;27m\033[1m"
BTN_INACTIVE="\033[38;2;205;214;244m"

# Gradient rows (Cyan -> Purple)
G1="\033[38;2;0;242;254m"
G2="\033[38;2;45;205;253m"
G3="\033[38;2;90;165;251m"
G4="\033[38;2;130;125;249m"
G5="\033[38;2;168;85;247m"
G6="\033[38;2;192;58;242m"

cleanup_cursor() {
    tput cnorm 2>/dev/null || true
}
trap cleanup_cursor EXIT INT TERM

# Verify Pacman-based system
if ! command -v pacman &>/dev/null; then
    echo -e "${C_RED}Error: 'pacman' was not found on this system.${C_RESET}" >&2
    echo "pkgapps is designed exclusively for Arch Linux, Omarchy, and CachyOS." >&2
    exit 1
fi

# Detect Operating System (including Omarchy)
detect_os_name() {
    if [ -d "$HOME/.local/share/omarchy" ] || command -v omarchy-update &>/dev/null || grep -qi "omarchy" /etc/os-release 2>/dev/null; then
        echo "Omarchy"
        return
    fi
    if [ -f /etc/os-release ]; then
        # shellcheck source=/dev/null
        source /etc/os-release
        echo "${PRETTY_NAME:-${NAME:-Arch Linux}}"
    else
        echo "Arch Linux"
    fi
}

OS_NAME="$(detect_os_name)"

# Default Configuration Values
DEFAULT_REPO_NAME="myapps"
DEFAULT_REPO_DIR="/var/cache/myapps"
DEFAULT_BIN_PATH="/usr/local/bin/pkgapps"
DEFAULT_APP_DIR="/opt"

REPO_NAME="$DEFAULT_REPO_NAME"
REPO_DIR="$DEFAULT_REPO_DIR"
BIN_PATH="$DEFAULT_BIN_PATH"
APP_BASE_DIR="$DEFAULT_APP_DIR"
REQUIRED_PKGS=("curl" "tar" "base-devel" "chafa" "file" "librsvg" "imagemagick" "xz" "zstd" "bzip2" "squashfs-tools")

# Load existing configuration if installed
IS_INSTALLED=0
if [ -f "$GLOBAL_CONF" ]; then
    # shellcheck source=/dev/null
    source "$GLOBAL_CONF"
    IS_INSTALLED=1
elif [ -x "$DEFAULT_BIN_PATH" ]; then
    IS_INSTALLED=1
elif [ -x "$HOME/.local/bin/pkgapps" ]; then
    IS_INSTALLED=1
    OLD_BIN_PATH="$HOME/.local/bin/pkgapps"
elif [ -d "$DEFAULT_REPO_DIR" ] && [ -f "${DEFAULT_REPO_DIR}/${DEFAULT_REPO_NAME}.db.tar.gz" ]; then
    IS_INSTALLED=1
elif grep -q "\[${DEFAULT_REPO_NAME}\]" /etc/pacman.conf 2>/dev/null; then
    IS_INSTALLED=1
fi

OLD_REPO_NAME="$REPO_NAME"
OLD_REPO_DIR="$REPO_DIR"
OLD_BIN_PATH="${OLD_BIN_PATH:-$BIN_PATH}"
OLD_APP_BASE_DIR="$APP_BASE_DIR"

# ==============================================================================
# TUI Rendering Engine (Omarchy Style)
# ==============================================================================
render_header() {
    local subtitle="${1:-Lets setup pkgapps on your ${OS_NAME}...}"
    clear 2>/dev/null || true
    echo ""
    echo -e "  ${G1}██████╗ ██╗  ██╗ ██████╗  █████╗ ██████╗ ██████╗ ███████╗${C_RESET}"
    echo -e "  ${G2}██╔══██╗██║ ██╔╝██╔════╝ ██╔══██╗██╔══██╗██╔══██╗██╔════╝${C_RESET}"
    echo -e "  ${G3}██████╔╝█████╔╝ ██║  ███╗███████║██████╔╝██████╔╝███████╗${C_RESET}"
    echo -e "  ${G4}██╔═══╝ ██╔═██╗ ██║   ██║██╔══██║██╔═══╝ ██╔═══╝ ╚════██║${C_RESET}"
    echo -e "  ${G5}██║     ██║  ██╗╚██████╔╝██║  ██║██║     ██║     ███████║${C_RESET}"
    echo -e "  ${G6}╚═╝     ╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═╝╚═╝     ╚═╝     ╚══════╝${C_RESET}"
    echo -e "  ${C_PURPLE}:: PRECOMPILED ARCHIVE (.TAR.*) & APPIMAGE SYSTEM MANAGER ::${C_RESET}"
    echo ""
    echo -e "  ${C_TEXT}${subtitle}${C_RESET}"
    echo ""
}

# Renders an Omarchy-style ASCII table: takes pairs of "Field" "Value"
render_table() {
    local -a fields=()
    local -a values=()
    local max_f=14
    local max_v=36

    while [ $# -ge 2 ]; do
        local f="$1"
        local v="$2"
        shift 2
        f="${f//$'\r'/}"
        v="${v//$'\r'/}"
        f="${f//$'\n'/ }"
        v="${v//$'\n'/ }"
        fields+=("$f")
        values+=("$v")
        [ "${#f}" -gt "$max_f" ] && max_f="${#f}"
        [ "${#v}" -gt "$max_v" ] && max_v="${#v}"
    done

    max_f=$((max_f + 2))
    max_v=$((max_v + 2))

    local h_f="" h_v=""
    printf -v h_f "%*s" $((max_f + 1)) ""
    printf -v h_v "%*s" $((max_v + 1)) ""
    h_f="${h_f// /-}"
    h_v="${h_v// /-}"

    local sep="  ${C_BORDER}+${h_f}+${h_v}+${C_RESET}"

    echo -e "$sep"
    printf "  ${C_BORDER}|${C_RESET} ${C_SUBTEXT}%-*s${C_RESET}${C_BORDER}|${C_RESET} ${C_SUBTEXT}%-*s${C_RESET}${C_BORDER}|${C_RESET}\n" "$max_f" "Field" "$max_v" "Value"
    echo -e "$sep"

    local idx
    local total_fields="${#fields[@]}"
    for ((idx=0; idx!=total_fields; idx++)); do
        printf "  ${C_BORDER}|${C_RESET} ${C_TEXT}%-*s${C_RESET}${C_BORDER}|${C_RESET} ${C_CYAN}%-*s${C_RESET}${C_BORDER}|${C_RESET}\n" "$max_f" "${fields[$idx]}" "$max_v" "${values[$idx]}"
    done

    echo -e "$sep"
    echo ""
}

# Interactive Horizontal Button Selector
SELECTED_INDEX=0
DIRECT_FIELD_CHOICE=""
prompt_buttons() {
    local question="$1"
    local hint="$2"
    shift 2
    local -a btns=("$@")
    local count="${#btns[@]}"
    local cur=0
    local key=""
    DIRECT_FIELD_CHOICE=""

    tput civis 2>/dev/null || true
    echo -e "  ${C_BORDER}${question}${C_RESET}"
    echo ""
    tput sc 2>/dev/null || true

    while true; do
        tput rc 2>/dev/null || printf "\r"
        tput ed 2>/dev/null || true

        local line="  "
        local i
        for ((i=0; i!=count; i++)); do
            if [ "$i" -eq "$cur" ]; then
                if [[ "${btns[$i]}" =~ (Delete|Uninstall|Overwrite|Reinstall|No|Abort|Cancel) && "$i" -gt 0 ]]; then
                    line+="${BTN_WARN_ACTIVE}   ${btns[$i]}   ${C_RESET}   "
                else
                    line+="${BTN_ACTIVE}   ${btns[$i]}   ${C_RESET}   "
                fi
            else
                line+="${BTN_INACTIVE}   ${btns[$i]}   ${C_RESET}   "
            fi
        done
        echo -e "$line"
        echo ""
        echo -e "  ${C_DIM}↔ toggle • enter submit • ${hint}${C_RESET}"

        IFS= read -rsn1 key < /dev/tty || true

        if [[ -z "$key" ]]; then
            SELECTED_INDEX="$cur"
            break
        elif [[ "$key" == $'\x1b' ]]; then
            local seq=""
            read -rsn2 -t 0.05 seq < /dev/tty || true
            case "$seq" in
                "[C"|"[B") cur=$(( (cur + 1) % count )) ;;
                "[D"|"[A") cur=$(( (cur - 1 + count) % count )) ;;
            esac
        else
            case "${key,,}" in
                l) cur=$(( (cur + 1) % count )) ;;
                h) cur=$(( (cur - 1 + count) % count )) ;;
                k)
                    if [[ "${btns[0],,}" == k* ]]; then
                        SELECTED_INDEX=0
                        break
                    fi
                    ;;
                w)
                    if [ "$count" -ge 2 ] && [[ "${btns[1],,}" == w* ]]; then
                        SELECTED_INDEX=1
                        break
                    fi
                    ;;
                y)
                    if [[ "${btns[0],,}" == y* ]]; then
                        SELECTED_INDEX=0
                        break
                    fi
                    ;;
                s)
                    if [[ "${btns[0],,}" == s* ]]; then
                        SELECTED_INDEX=0
                        break
                    fi
                    ;;
                n)
                    if [ "$count" -ge 2 ] && [[ "${btns[1],,}" == n* ]]; then
                        SELECTED_INDEX=1
                        break
                    fi
                    ;;
                b)
                    if [ "$count" -ge 3 ] && [[ "${btns[2],,}" == b* ]]; then
                        SELECTED_INDEX=2
                        break
                    fi
                    ;;
                c)
                    if [ "$count" -ge 3 ] && [[ "${btns[2],,}" == c* ]]; then
                        SELECTED_INDEX=2
                        break
                    elif [[ "${btns[0],,}" == c* ]]; then
                        SELECTED_INDEX=0
                        break
                    fi
                    ;;
                r)
                    if [ "$count" -ge 2 ] && [[ "${btns[1],,}" == r* ]]; then
                        SELECTED_INDEX=1
                        break
                    fi
                    ;;
                e)
                    if [ "$count" -ge 3 ] && [[ "${btns[2],,}" == e* ]]; then
                        SELECTED_INDEX=2
                        break
                    elif [ "$count" -ge 2 ] && [[ "${btns[1],,}" == e* ]]; then
                        SELECTED_INDEX=1
                        break
                    fi
                    ;;
                d|u)
                    if [ "$count" -ge 4 ]; then
                        SELECTED_INDEX=3
                        break
                    fi
                    ;;
                1|2|3|4)
                    if [ "$count" -ge 2 ] && [[ "${btns[1]}" == *"1-4"* ]]; then
                        SELECTED_INDEX=1
                        DIRECT_FIELD_CHOICE="$key"
                        break
                    else
                        local num_idx=$((key - 1))
                        if [ "$num_idx" -lt "$count" ]; then
                            SELECTED_INDEX="$num_idx"
                            break
                        fi
                    fi
                    ;;
            esac
        fi
    done

    tput cnorm 2>/dev/null || true
    echo ""
}

detect_shells_summary() {
    local s=()
    [ -f "$HOME/.bashrc" ] && s+=("bash")
    [ -f "$HOME/.zshrc" ] && s+=("zsh")
    { [ -d "$HOME/.config/fish" ] || command -v fish &>/dev/null; } && s+=("fish")
    { [ -d "$HOME/.local/share/omarchy" ] || command -v omarchy-update &>/dev/null; } && s+=("omarchy-updater")
    echo "${s[*]}"
}

count_tracked_apps() {
    local sf="$HOME/.config/${REPO_NAME}/sources.conf"
    if [ -s "$sf" ]; then
        local count
        count=$(grep -cEv '^\s*(#|$)' "$sf" 2>/dev/null) || count=0
        echo "${count:-0}"
    else
        echo 0
    fi
}

show_config_summary_table() {
    local mode_label="$1"
    local shells_str
    shells_str="$(detect_shells_summary)"
    local tracked_count
    tracked_count="$(count_tracked_apps)"
    local app_word="apps"
    [ "$tracked_count" -eq 1 ] && app_word="app"

    render_table \
        "Target OS" "${OS_NAME}" \
        "Setup Mode" "${mode_label}" \
        "Pacman Repository" "[${REPO_NAME}] (${REPO_DIR})" \
        "Binary Location" "${BIN_PATH}" \
        "Apps Install Path" "${APP_BASE_DIR}/[app-name]" \
        "Tracked Sources" "~/.config/${REPO_NAME}/sources.conf (${tracked_count} ${app_word})" \
        "Pacman Dependencies" "${REQUIRED_PKGS[*]}" \
        "Shell & Hooks" "${shells_str}"
}

# ==============================================================================
# Interactive Customizer (Used for Custom Install & Edit/Migrate)
# ==============================================================================
customize_settings_interactive() {
    local title="$1"
    while true; do
        render_header "$title"
        show_config_summary_table "Custom Configuration"

        echo -e "  ${C_SUBTEXT}Select a parameter to customize:${C_RESET}"
        echo -e "    ${C_CYAN}[1]${C_RESET} Repository Name      ${C_DIM}(Current: ${REPO_NAME})${C_RESET}"
        echo -e "    ${C_CYAN}[2]${C_RESET} Repository Cache Dir ${C_DIM}(Current: ${REPO_DIR})${C_RESET}"
        echo -e "    ${C_CYAN}[3]${C_RESET} Binary Install Path  ${C_DIM}(Current: ${BIN_PATH})${C_RESET}"
        echo -e "    ${C_CYAN}[4]${C_RESET} Apps Base Directory  ${C_DIM}(Current: ${APP_BASE_DIR})${C_RESET}"
        echo ""
        prompt_buttons "Are you ready to apply these settings?" "1-4 edit field • s Save & Apply • b Back" "Save & Apply" "Edit a Field (1-4)" "Back / Cancel"

        if [ "$SELECTED_INDEX" -eq 0 ]; then
            return 0
        elif [ "$SELECTED_INDEX" -eq 2 ]; then
            return 1
        else
            local fnum="$DIRECT_FIELD_CHOICE"
            if [ -z "$fnum" ]; then
                echo -e "  ${C_CYAN}::${C_RESET} Enter field number to edit [1-4]: "
                read -rp "  > " fnum < /dev/tty || true
            fi
            case "$fnum" in
                1)
                    read -rp "  Enter new Pacman repository name [${REPO_NAME}]: " in_repo < /dev/tty || true
                    if [ -n "$in_repo" ]; then
                        REPO_NAME=$(echo "$in_repo" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9_-]+/-/g; s/^-+|-+$//g')
                        [ -z "$REPO_NAME" ] && REPO_NAME="myapps"
                        if [ "$REPO_DIR" = "/var/cache/${OLD_REPO_NAME}" ] || [ "$REPO_DIR" = "$DEFAULT_REPO_DIR" ]; then
                            REPO_DIR="/var/cache/${REPO_NAME}"
                        fi
                    fi
                    ;;
                2)
                    read -e -rp "  Enter new repository directory [${REPO_DIR}]: " in_dir < /dev/tty || true
                    [ -n "$in_dir" ] && REPO_DIR="${in_dir%/}"
                    ;;
                3)
                    read -e -rp "  Enter new binary path [${BIN_PATH}]: " in_bin < /dev/tty || true
                    [ -n "$in_bin" ] && BIN_PATH="$in_bin"
                    ;;
                4)
                    read -e -rp "  Enter new apps installation base dir [${APP_BASE_DIR}]: " in_app < /dev/tty || true
                    [ -n "$in_app" ] && APP_BASE_DIR="${in_app%/}"
                    ;;
            esac
        fi
    done
}

# ==============================================================================
# Core Actions: Install, Migrate, Clean & Uninstall
# ==============================================================================
ensure_sudo_tty() {
    sudo -v < /dev/tty
}

write_global_conf() {
    ensure_sudo_tty
    printf '%s\n' \
        "REPO_NAME=\"${REPO_NAME}\"" \
        "REPO_DIR=\"${REPO_DIR}\"" \
        "BIN_PATH=\"${BIN_PATH}\"" \
        "APP_BASE_DIR=\"${APP_BASE_DIR}\"" \
        | sudo tee "$GLOBAL_CONF" >/dev/null
}

install_dependencies() {
    local missing=()
    local pkg
    for pkg in "${REQUIRED_PKGS[@]}"; do
        if ! pacman -Qi "$pkg" &>/dev/null && ! pacman -Qg "$pkg" &>/dev/null; then
            missing+=("$pkg")
        fi
    done
    if [ "${#missing[@]}" -gt 0 ]; then
        echo -e "  ${C_CYAN}::${C_RESET} Installing missing dependencies: ${C_YELLOW}${missing[*]}${C_RESET}..."
        sudo pacman -S --needed --noconfirm "${missing[@]}" < /dev/tty
    fi
}

install_pkgapps_binary() {
    echo -e "  ${C_CYAN}::${C_RESET} Installing pkgapps binary to ${C_CYAN}${BIN_PATH}${C_RESET}..."
    sudo mkdir -p "$(dirname "$BIN_PATH")" < /dev/tty

    if [ -f "${SCRIPT_SOURCE_DIR}/pkgapps" ]; then
        sudo install -Dm755 "${SCRIPT_SOURCE_DIR}/pkgapps" "$BIN_PATH" < /dev/tty
    elif [ -f "./pkgapps" ]; then
        sudo install -Dm755 "./pkgapps" "$BIN_PATH" < /dev/tty
    else
        sudo curl -fsSL "$REPO_RAW_URL" -o "$BIN_PATH" < /dev/tty
        sudo chmod +x "$BIN_PATH" < /dev/tty
    fi

    # Remove stale duplicate binaries in other PATH locations so /usr/local/bin/pkgapps is the only one and has absolute priority
    local other_bin
    for other_bin in "/usr/bin/pkgapps" "/usr/local/bin/pkgapps" "$HOME/.local/bin/pkgapps"; do
        if [ "$other_bin" != "$BIN_PATH" ] && [ -f "$other_bin" ]; then
            sudo rm -f "$other_bin" < /dev/tty 2>/dev/null || rm -f "$other_bin" 2>/dev/null || true
        fi
    done
    rm -f "$HOME/.local/bin/pkgapps" 2>/dev/null || true
    sudo rm -f "/usr/bin/pkgapps" < /dev/tty 2>/dev/null || true
    hash -r 2>/dev/null || true
}

configure_shells_and_omarchy() {
    echo -e "  ${C_CYAN}::${C_RESET} Configuring Bash, Zsh, Fish completions & Omarchy updater hooks..."

    # 1. Bash & Zsh sudo pacman -Syu hook
    inject_posix_hook() {
        local rc="$1"
        [ -f "$rc" ] || return 0
        sed -i '/# >>> pkgapps auto-updater >>>/,/# <<< pkgapps auto-updater <<</d' "$rc" 2>/dev/null || true
        sed -i '/# --- pkgapps auto-updater start ---/,/# --- pkgapps auto-updater end ---/d' "$rc" 2>/dev/null || true
        printf '%s\n' \
            "" \
            "# --- pkgapps auto-updater start ---" \
            "sudo() {" \
            "    if [[ \"\$1\" == \"pacman\" && \"\$*\" == *-S*y*u* ]]; then" \
            "        if [ -x \"${BIN_PATH}\" ]; then" \
            "            \"${BIN_PATH}\" --update" \
            "        elif command -v pkgapps &>/dev/null; then" \
            "            pkgapps --update" \
            "        fi" \
            "    fi" \
            "    command sudo \"\$@\"" \
            "}" \
            "# --- pkgapps auto-updater end ---" \
            >> "$rc"
    }

    [ -f "$HOME/.bashrc" ] && inject_posix_hook "$HOME/.bashrc"
    [ -f "$HOME/.zshrc" ] && inject_posix_hook "$HOME/.zshrc"

    # 2. Zsh Autocompletion
    if [ -d "/usr/share/zsh/site-functions" ] || command -v zsh &>/dev/null; then
        sudo mkdir -p /usr/share/zsh/site-functions < /dev/tty
        printf '%s\n' \
            '#compdef pkgapps' \
            '' \
            '_pkgapps_completion() {' \
            '    local state' \
            '    _arguments \' \
            '        '\''(-h --help)'\''{-h,--help}'\''[Show detailed help and usage examples]'\'' \' \
            '        '\''(-i --init)'\''{-i,--init}'\''[Initialize local repository and pacman hook]'\'' \' \
            '        '\''(-u --update)'\''{-u,--update}'\''[Check and package updates now]'\'' \' \
            '        '\''(-l --list)'\''{-l,--list}'\''[List tracked applications in repository]'\'' \' \
            '        '\''(-r --remove)'\''{-r,--remove}'\''[Uninstall application and remove from repo]:app:->apps'\'' \' \
            '        '\''*:Download page, archive (.tar.*), or .AppImage URL:_urls'\''' \
            '' \
            '    if [[ "$state" == "apps" ]]; then' \
            '        local repo_conf="/etc/pkgapps.conf"' \
            '        local REPO_NAME="myapps"' \
            '        [ -f "$repo_conf" ] && source "$repo_conf"' \
            '        local sources_file="$HOME/.config/${REPO_NAME}/sources.conf"' \
            '        if [[ -f "$sources_file" ]]; then' \
            '            local -a app_list' \
            '            app_list=(${(f)"$(cut -d'\''|'\'' -f1 "$sources_file")"})' \
            '            _describe '\''tracked apps'\'' app_list' \
            '        fi' \
            '    fi' \
            '}' \
            '_pkgapps_completion' \
            | sudo tee "/usr/share/zsh/site-functions/_pkgapps" >/dev/null
    fi

    # 3. Fish Shell Integration (Autocompletion + sudo pacman -Syu hook)
    if command -v fish &>/dev/null || [ -d "$HOME/.config/fish" ]; then
        mkdir -p "$HOME/.config/fish/conf.d" "$HOME/.config/fish/completions"

        printf '%s\n' \
            "# --- pkgapps auto-updater (Fish) start ---" \
            "function sudo --wraps=sudo --description 'pkgapps auto-updater hook for pacman -Syu'" \
            "    if test (count \$argv) -ge 2; and test \"\$argv[1]\" = \"pacman\"" \
            "        if string match -qr -- '-[a-zA-Z]*S[a-zA-Z]*y[a-zA-Z]*u|-[a-zA-Z]*y[a-zA-Z]*S[a-zA-Z]*u' \"\$argv\"" \
            "            if test -x \"${BIN_PATH}\"" \
            "                \"${BIN_PATH}\" --update" \
            "            else if command -sq pkgapps" \
            "                pkgapps --update" \
            "            end" \
            "        end" \
            "    end" \
            "    command sudo \$argv" \
            "end" \
            "# --- pkgapps auto-updater (Fish) end ---" \
            > "$HOME/.config/fish/conf.d/pkgapps.fish"

        printf '%s\n' \
            'function __fish_pkgapps_tracked_apps' \
            '    set -l repo_name "myapps"' \
            '    if test -f /etc/pkgapps.conf' \
            '        set -l parsed (grep '\''^REPO_NAME='\'' /etc/pkgapps.conf | cut -d'\''"'\'' -f2)' \
            '        if test -n "$parsed"' \
            '            set repo_name "$parsed"' \
            '        end' \
            '    end' \
            '    set -l sources_file "$HOME/.config/$repo_name/sources.conf"' \
            '    if test -f "$sources_file"' \
            '        cut -d'\''|'\'' -f1 "$sources_file"' \
            '    end' \
            'end' \
            '' \
            'complete -c pkgapps -s h -l help -d "Show detailed help screen"' \
            'complete -c pkgapps -s i -l init -d "Initialize local repository and Pacman hook"' \
            'complete -c pkgapps -s l -l list -d "List tracked applications in repository"' \
            'complete -c pkgapps -s u -l update -d "Check tracked URLs for newer versions"' \
            'complete -c pkgapps -s r -l remove -x -a "(__fish_pkgapps_tracked_apps)" -d "Uninstall tracked application"' \
            > "$HOME/.config/fish/completions/pkgapps.fish"
    fi

    # 4. Bash Completion
    if [ -d "/usr/share/bash-completion/completions" ]; then
        printf '%s\n' \
            '_pkgapps_bash() {' \
            '    local cur prev opts' \
            '    COMPREPLY=()' \
            '    cur="${COMP_WORDS[COMP_CWORD]}"' \
            '    prev="${COMP_WORDS[COMP_CWORD-1]}"' \
            '    opts="-h --help -i --init -l --list -u --update -r --remove"' \
            '' \
            '    if [[ "$prev" == "-r" || "$prev" == "--remove" ]]; then' \
            '        local REPO_NAME="myapps"' \
            '        [ -f /etc/pkgapps.conf ] && source /etc/pkgapps.conf' \
            '        local sf="$HOME/.config/${REPO_NAME}/sources.conf"' \
            '        if [ -f "$sf" ]; then' \
            '            local apps' \
            '            apps=$(cut -d'\''|'\'' -f1 "$sf" | tr '\''\n'\'' '\'' '\'')' \
            '            COMPREPLY=( $(compgen -W "$apps" -- "$cur") )' \
            '        fi' \
            '        return 0' \
            '    fi' \
            '    COMPREPLY=( $(compgen -W "$opts" -- "$cur") )' \
            '}' \
            'complete -F _pkgapps_bash pkgapps' \
            | sudo tee "/usr/share/bash-completion/completions/pkgapps" >/dev/null
    fi

    # 5. Omarchy Updater Integration (Hooks into omarchy-update if present)
    if [ -d "$HOME/.local/share/omarchy" ] || command -v omarchy-update &>/dev/null; then
        mkdir -p "$HOME/.config/omarchy/hooks" "$HOME/.local/bin"
        printf '%s\n' \
            "#!/usr/bin/env bash" \
            "[ -x \"${BIN_PATH}\" ] && \"${BIN_PATH}\" --update || true" \
            > "$HOME/.config/omarchy/hooks/pre-update"
        chmod +x "$HOME/.config/omarchy/hooks/pre-update"

        if [ -x "$HOME/.local/share/omarchy/bin/omarchy-update" ]; then
            if ! grep -q "pkgapps --update" "$HOME/.local/share/omarchy/bin/omarchy-update" 2>/dev/null; then
                sed -i "2i # pkgapps auto-updater integration\n[ -x \"${BIN_PATH}\" ] && \"${BIN_PATH}\" --update || true" "$HOME/.local/share/omarchy/bin/omarchy-update" 2>/dev/null || true
            fi
        fi
    fi
}

purge_app_user_data() {
    local app_slug="$1"
    local app_pretty="${2:-}"
    [ -z "$app_slug" ] && return 0

    case "${app_slug,,}" in
        ""|"."|".."|"root"|"home"|"config"|"cache"|"local"|"share"|"state"|"bin"|"lib"|"etc")
            return 0
            ;;
    esac

    local -a candidate_dirs=(
        "${XDG_CONFIG_HOME:-$HOME/.config}/${app_slug}"
        "${XDG_CACHE_HOME:-$HOME/.cache}/${app_slug}"
        "${XDG_DATA_HOME:-$HOME/.local/share}/${app_slug}"
        "${XDG_STATE_HOME:-$HOME/.local/state}/${app_slug}"
    )

    if [ -n "$app_pretty" ] && [ "${app_pretty}" != "${app_slug}" ]; then
        local stripped_pretty="${app_pretty// /}"
        candidate_dirs+=(
            "${XDG_CONFIG_HOME:-$HOME/.config}/${stripped_pretty}"
            "${XDG_CACHE_HOME:-$HOME/.cache}/${stripped_pretty}"
            "${XDG_DATA_HOME:-$HOME/.local/share}/${stripped_pretty}"
            "${XDG_STATE_HOME:-$HOME/.local/state}/${stripped_pretty}"
        )
    fi

    local dir
    for dir in "${candidate_dirs[@]}"; do
        if [[ "$dir" =~ ^${HOME}/(\.config|\.cache|\.local/share|\.local/state)/.+ ]] && [ -d "$dir" ]; then
            echo -e "  ${C_YELLOW}::${C_RESET} Purging user data: ${C_DIM}${dir}${C_RESET}"
            rm -rf "$dir"
        fi
    done
}

prompt_factory_reset_choice() {
    local context_title="$1"
    render_header "$context_title"
    echo -e "  ${C_SUBTEXT}How would you like to handle application user data in your user profile?${C_RESET}"
    echo -e "    ${C_CYAN}[1] Keep User Data & Sessions${C_RESET}     ${C_DIM}(Removes packages/binaries; keeps ~/.config, caches & sessions)${C_RESET}"
    echo -e "    ${C_RED}[2] Wipe All Data — Factory Reset${C_RESET} ${C_DIM}(Permanently erases all configs, active sessions, and caches)${C_RESET}"
    echo ""
    prompt_buttons \
        "Choose an uninstallation data mode:" \
        "k Keep Data • w Wipe All (Factory Reset) • c Cancel" \
        "Keep User Data & Sessions" "Wipe All Data — Factory Reset" "Cancel / Abort"

    case "$SELECTED_INDEX" in
        0)
            return 0
            ;;
        1)
            render_header "WARNING: Factory Reset Confirmation"
            echo -e "  ${C_RED}${C_BOLD}WARNING: ALL APPLICATION USER DATA WILL BE PERMANENTLY ERASED!${C_RESET}"
            echo -e "  ${C_TEXT}This will erase all login sessions, settings, caches, and states across:${C_RESET}"
            echo -e "  ${C_RED}• ~/.config/[app]${C_RESET}"
            echo -e "  ${C_RED}• ~/.cache/[app]${C_RESET}"
            echo -e "  ${C_RED}• ~/.local/share/[app]${C_RESET}"
            echo -e "  ${C_RED}• ~/.local/state/[app]${C_RESET}"
            echo -e "  ${C_DIM}The system will be left as if the application(s) had NEVER been installed.${C_RESET}"
            echo ""
            prompt_buttons \
                "Are you absolutely sure you want to permanently wipe all user data?" \
                "w Yes, erase all • n No, go back" \
                "Yes, Erase Everything" "No, Go Back"
            if [ "$SELECTED_INDEX" -eq 0 ]; then
                return 1
            fi
            return 2
            ;;
        2)
            return 2
            ;;
    esac
}

remove_all_installed_apps_and_repo() {
    local target_repo="$1"
    local target_dir="$2"
    local target_app_base="$3"
    local purge_data="${4:-0}"
    local sf="$HOME/.config/${target_repo}/sources.conf"

    ensure_sudo_tty

    # Read all tracked apps into an in-memory array first to avoid loop corruption by pacman hooks
    local -a app_entries=()
    if [ -f "$sf" ]; then
        while IFS='|' read -r app_slug _url _orig app_pretty _rest || [ -n "$app_slug" ]; do
            [[ -z "$app_slug" || "$app_slug" =~ ^[[:space:]]*# ]] && continue
            app_entries+=("${app_slug}|${app_pretty:-$app_slug}")
        done < "$sf"
    fi

    local entry
    for entry in "${app_entries[@]}"; do
        local app_slug="${entry%%|*}"
        local app_pretty="${entry#*|}"
        if pacman -Qi "${app_slug}-bin" &>/dev/null; then
            echo -e "  ${C_YELLOW}::${C_RESET} Removing installed package ${C_BOLD}${app_slug}-bin${C_RESET}..."
            sudo pacman -Rns --noconfirm "${app_slug}-bin" < /dev/tty 2>/dev/null || true
        fi
        sudo rm -rf "${target_app_base}/${app_slug}" < /dev/null 2>/dev/null || true

        if [ "$purge_data" -eq 1 ]; then
            purge_app_user_data "$app_slug" "$app_pretty"
        fi
    done

    # Remove repo block from /etc/pacman.conf
    if grep -q "\[${target_repo}\]" /etc/pacman.conf 2>/dev/null; then
        sudo sed -i "/^\[${target_repo}\]/,+2d" /etc/pacman.conf < /dev/tty 2>/dev/null || true
    fi

    sudo rm -f "/etc/pacman.d/hooks/${target_repo}-cleanup.hook" < /dev/tty 2>/dev/null || true
    sudo rm -rf "$target_dir" < /dev/tty 2>/dev/null || true
    rm -rf "$HOME/.config/${target_repo}" 2>/dev/null || true
}

perform_full_uninstall() {
    local purge_data="${1:-0}"
    render_header "Uninstalling pkgapps from your ${OS_NAME}..."
    remove_all_installed_apps_and_repo "$OLD_REPO_NAME" "$OLD_REPO_DIR" "$OLD_APP_BASE_DIR" "$purge_data"

    echo -e "  ${C_CYAN}::${C_RESET} Cleaning shell hooks, completions, and binaries..."
    if [ -f "$HOME/.bashrc" ]; then
        sed -i '/# >>> pkgapps auto-updater >>>/,/# <<< pkgapps auto-updater <<</d' "$HOME/.bashrc" 2>/dev/null || true
        sed -i '/# --- pkgapps auto-updater start ---/,/# --- pkgapps auto-updater end ---/d' "$HOME/.bashrc" 2>/dev/null || true
    fi
    if [ -f "$HOME/.zshrc" ]; then
        sed -i '/# >>> pkgapps auto-updater >>>/,/# <<< pkgapps auto-updater <<</d' "$HOME/.zshrc" 2>/dev/null || true
        sed -i '/# --- pkgapps auto-updater start ---/,/# --- pkgapps auto-updater end ---/d' "$HOME/.zshrc" 2>/dev/null || true
    fi
    rm -f "$HOME/.config/fish/conf.d/pkgapps.fish" "$HOME/.config/fish/completions/pkgapps.fish" 2>/dev/null || true
    rm -f "$HOME/.config/omarchy/hooks/pre-update" 2>/dev/null || true
    if [ -f "$HOME/.local/share/omarchy/bin/omarchy-update" ]; then
        sed -i '/pkgapps/d' "$HOME/.local/share/omarchy/bin/omarchy-update" 2>/dev/null || true
    fi

    sudo rm -f "/usr/share/zsh/site-functions/_pkgapps" "/usr/share/bash-completion/completions/pkgapps" < /dev/tty 2>/dev/null || true
    sudo rm -f "$OLD_BIN_PATH" "$DEFAULT_BIN_PATH" "/usr/bin/pkgapps" "$HOME/.local/bin/pkgapps" "$GLOBAL_CONF" < /dev/tty 2>/dev/null || true
    rm -f "$HOME/.local/bin/pkgapps" 2>/dev/null || true
    sudo pacman -Sy < /dev/tty >/dev/null 2>&1 || true

    echo ""
    echo -e "  ${C_GREEN}✓ pkgapps, all tracked applications, repositories, and shell hooks have been completely removed.${C_RESET}"
    echo ""
}

perform_fresh_install() {
    render_header "Installing pkgapps on your ${OS_NAME}..."
    write_global_conf
    install_dependencies
    install_pkgapps_binary
    configure_shells_and_omarchy

    echo -e "  ${C_CYAN}::${C_RESET} Initializing local Pacman repository [${REPO_NAME}]..."
    "$BIN_PATH" --init < /dev/tty

    echo ""
    echo -e "  ${C_GREEN}✓ pkgapps setup completed successfully!${C_RESET}"
    echo -e "  ${C_DIM}Restart your terminal or reload your shell to activate autocompletions.${C_RESET}"
    echo ""
}

perform_migration() {
    render_header "Migrating pkgapps installation & packages..."
    ensure_sudo_tty

    # 1. Move repository directory & database if changed
    if [ "$OLD_REPO_DIR" != "$REPO_DIR" ] || [ "$OLD_REPO_NAME" != "$REPO_NAME" ]; then
        echo -e "  ${C_CYAN}::${C_RESET} Migrating repository [${OLD_REPO_NAME}] (${OLD_REPO_DIR}) -> [${REPO_NAME}] (${REPO_DIR})..."
        sudo mkdir -p "$REPO_DIR" < /dev/tty
        sudo chown -R "$USER:$USER" "$REPO_DIR" < /dev/tty
        chmod 755 "$REPO_DIR"

        if [ -d "$OLD_REPO_DIR" ]; then
            cp -a "$OLD_REPO_DIR"/*.pkg.tar.zst* "$REPO_DIR/" 2>/dev/null || true
        fi

        # Rebuild DB under new repo name
        tar -czf "${REPO_DIR}/${REPO_NAME}.db.tar.gz" -T /dev/null
        ln -sf "${REPO_NAME}.db.tar.gz" "${REPO_DIR}/${REPO_NAME}.db"
        shopt -s nullglob
        local pkgs=("$REPO_DIR"/*.pkg.tar.zst)
        if [ "${#pkgs[@]}" -gt 0 ]; then
            repo-add -R "${REPO_DIR}/${REPO_NAME}.db.tar.gz" "${pkgs[@]}" >/dev/null
        fi
        shopt -u nullglob

        if grep -q "\[${OLD_REPO_NAME}\]" /etc/pacman.conf 2>/dev/null; then
            sudo sed -i "/^\[${OLD_REPO_NAME}\]/,+2d" /etc/pacman.conf < /dev/tty 2>/dev/null || true
        fi
        sudo rm -f "/etc/pacman.d/hooks/${OLD_REPO_NAME}-cleanup.hook" < /dev/tty 2>/dev/null || true
        [ "$OLD_REPO_DIR" != "$REPO_DIR" ] && sudo rm -rf "$OLD_REPO_DIR" < /dev/tty 2>/dev/null || true
    fi

    # 2. Move user sources.conf if repo name changed
    if [ "$OLD_REPO_NAME" != "$REPO_NAME" ]; then
        mkdir -p "$HOME/.config/${REPO_NAME}"
        if [ -f "$HOME/.config/${OLD_REPO_NAME}/sources.conf" ]; then
            mv "$HOME/.config/${OLD_REPO_NAME}/sources.conf" "$HOME/.config/${REPO_NAME}/sources.conf"
        else
            touch "$HOME/.config/${REPO_NAME}/sources.conf"
        fi
        rm -rf "$HOME/.config/${OLD_REPO_NAME}" 2>/dev/null || true
    fi

    # 3. Move installed apps base directory & sync Pacman local DB if changed
    if [ "$OLD_APP_BASE_DIR" != "$APP_BASE_DIR" ]; then
        echo -e "  ${C_CYAN}::${C_RESET} Migrating installed applications from ${OLD_APP_BASE_DIR} to ${APP_BASE_DIR}..."
        sudo mkdir -p "$APP_BASE_DIR" < /dev/tty
        local sf="$HOME/.config/${REPO_NAME}/sources.conf"
        local old_rel="${OLD_APP_BASE_DIR#/}"
        local new_rel="${APP_BASE_DIR#/}"

        if [ -f "$sf" ]; then
            while IFS='|' read -r app_slug _rest || [ -n "$app_slug" ]; do
                [[ -z "$app_slug" || "$app_slug" =~ ^[[:space:]]*# ]] && continue
                if [ -d "${OLD_APP_BASE_DIR}/${app_slug}" ]; then
                    sudo rm -rf "${APP_BASE_DIR}/${app_slug}" < /dev/null 2>/dev/null || true
                    sudo mv "${OLD_APP_BASE_DIR}/${app_slug}" "${APP_BASE_DIR}/${app_slug}" < /dev/null
                    # Update symlink in /usr/bin and .desktop file
                    if [ -L "/usr/bin/${app_slug}" ]; then
                        local old_target
                        old_target=$(readlink "/usr/bin/${app_slug}")
                        local new_target="${old_target/#$OLD_APP_BASE_DIR/$APP_BASE_DIR}"
                        sudo ln -sf "$new_target" "/usr/bin/${app_slug}" < /dev/null
                    fi
                    if [ -f "/usr/share/applications/${app_slug}.desktop" ]; then
                        sudo sed -i "s|${OLD_APP_BASE_DIR}/${app_slug}|${APP_BASE_DIR}/${app_slug}|g" "/usr/share/applications/${app_slug}.desktop" < /dev/null
                    fi
                    # Sync Pacman local database files list so pacman -Ql and pacman -Rns track the new path
                    shopt -s nullglob
                    local db_files=("/var/lib/pacman/local/${app_slug}-bin-"*/files)
                    if [ "${#db_files[@]}" -gt 0 ]; then
                        sudo sed -i "s|^${old_rel}/${app_slug}|${new_rel}/${app_slug}|g" "${db_files[@]}" < /dev/null 2>/dev/null || true
                    fi
                    shopt -u nullglob
                fi
            done < "$sf"
        fi
    fi

    # 4. Move binary if changed
    if [ "$OLD_BIN_PATH" != "$BIN_PATH" ] && [ -f "$OLD_BIN_PATH" ]; then
        sudo rm -f "$OLD_BIN_PATH" < /dev/tty
    fi

    write_global_conf
    install_dependencies
    install_pkgapps_binary
    configure_shells_and_omarchy
    "$BIN_PATH" --init < /dev/tty

    echo ""
    echo -e "  ${C_GREEN}✓ Migration completed! All settings, packages, and Pacman DB paths have been updated.${C_RESET}"
    echo ""
}

# ==============================================================================
# Main Entry Flow
# ==============================================================================
if [ "$IS_INSTALLED" -eq 0 ]; then
    # --------------------------------------------------------------------------
    # STATE A: Fresh Installation
    # --------------------------------------------------------------------------
    while true; do
        render_header "Lets setup pkgapps on your ${OS_NAME}..."
        show_config_summary_table "New Installation (Default Settings)"

        prompt_buttons \
            "Would you like to install pkgapps on your ${OS_NAME}?" \
            "y Yes • n No • c Custom Installation" \
            "Yes" "No" "Custom Installation"

        case "$SELECTED_INDEX" in
            0)
                perform_fresh_install
                exit 0
                ;;
            1)
                echo -e "  ${C_YELLOW}==> Installation cancelled by user.${C_RESET}"
                exit 0
                ;;
            2)
                if customize_settings_interactive "Customize pkgapps installation parameters..."; then
                    perform_fresh_install
                    exit 0
                fi
                ;;
        esac
    done
else
    # --------------------------------------------------------------------------
    # STATE B: Existing Installation Detected
    # --------------------------------------------------------------------------
    while true; do
        render_header "An existing pkgapps installation was detected on your ${OS_NAME}."
        show_config_summary_table "Installed & Active"

        prompt_buttons \
            "What would you like to do?" \
            "u Update / Refresh • r Clean Reinstall • e Edit pkgapps • d Delete • c Cancel" \
            "Update / Refresh" "Reinstall (Clean)" "Edit pkgapps" "Delete" "Cancel / Abort"

        case "$SELECTED_INDEX" in
            0)
                # Update / Refresh binary and shell hooks (preserves existing apps & repo)
                perform_fresh_install
                exit 0
                ;;
            1)
                # Confirmation for Clean Overwrite / Reinstall
                render_header "Confirm Clean Reinstallation on ${OS_NAME}"
                show_config_summary_table "Overwrite / Reset to Defaults"
                prompt_buttons \
                    "Are you sure you want to overwrite? All settings will reset to defaults." \
                    "y Yes, overwrite • n No, go back" \
                    "Yes" "No"

                if [ "$SELECTED_INDEX" -eq 0 ]; then
                    prompt_factory_reset_choice "Data Retention Mode for Clean Reinstall"
                    local reset_choice=$?
                    [ "$reset_choice" -eq 2 ] && continue

                    remove_all_installed_apps_and_repo "$OLD_REPO_NAME" "$OLD_REPO_DIR" "$OLD_APP_BASE_DIR" "$reset_choice"
                    REPO_NAME="$DEFAULT_REPO_NAME"
                    REPO_DIR="$DEFAULT_REPO_DIR"
                    BIN_PATH="$DEFAULT_BIN_PATH"
                    APP_BASE_DIR="$DEFAULT_APP_DIR"
                    perform_fresh_install
                    exit 0
                fi
                ;;
            2)
                # Edit & Migrate existing installation
                if customize_settings_interactive "Edit pkgapps paths & migrate installed applications..."; then
                    render_header "Confirm Migration of pkgapps Environment"
                    show_config_summary_table "Migrate Existing Installation"
                    prompt_buttons \
                        "Apply new paths and automatically move all existing packages, configs, and apps?" \
                        "y Yes, migrate now • n No, go back" \
                        "Yes" "No"

                    if [ "$SELECTED_INDEX" -eq 0 ]; then
                        perform_migration
                        exit 0
                    fi
                fi
                ;;
            3)
                # Confirmation for Complete Deletion
                render_header "Confirm Complete Uninstallation from ${OS_NAME}"
                show_config_summary_table "Complete Removal (Uninstall & Purge)"
                prompt_buttons \
                    "Are you sure you want to completely delete pkgapps, tracked applications, and shell hooks?" \
                    "y Yes, delete • n No, go back" \
                    "Yes" "No"

                if [ "$SELECTED_INDEX" -eq 0 ]; then
                    prompt_factory_reset_choice "Data Retention Mode for Uninstallation"
                    local del_reset_choice=$?
                    [ "$del_reset_choice" -eq 2 ] && continue

                    perform_full_uninstall "$del_reset_choice"
                    exit 0
                fi
                ;;
            4)
                echo -e "  ${C_DIM}==> No changes made. Exiting.${C_RESET}"
                exit 0
                ;;
        esac
    done
fi

}

main "$@" < /dev/tty