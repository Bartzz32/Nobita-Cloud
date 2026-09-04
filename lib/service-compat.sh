#!/usr/bin/env bash

# Source this file from scripts that need service management on hosts without systemd.
# The wrapper intentionally keeps the existing systemctl-shaped API used by installers.

service_compat_command() {
    command -v service >/dev/null 2>&1
}

service_compat_name() {
    printf '%s\n' "${1%.service}"
}

service_compat_run() {
    service_compat_command || {
        printf '%s\n' "service command is required on this host" >&2
        return 127
    }

    service "$(service_compat_name "$1")" "$2"
}

systemctl() {
    [ "$#" -gt 0 ] || return 1

    command -v /bin/systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ] && {
        /bin/systemctl "$@"
        return $?
    }

    local action="" quiet=0 now=0
    local -a services=()
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --quiet) quiet=1 ;;
            --now) now=1 ;;
            --no-pager|--full) ;;
            -p) shift ;;
            start|stop|restart|reload|status|enable|disable|is-active|is-enabled|show|daemon-reload)
                action="$1"
                ;;
            *) services+=("$1") ;;
        esac
        shift
    done

    case "$action" in
        daemon-reload)
            return 0
            ;;
        show)
            return 0
            ;;
        enable|disable)
            # SysV init scripts are enabled by the host's init system. There is
            # no portable equivalent of systemd enable/disable here.
            if [ "$action" = "enable" ] && [ "$now" -eq 1 ]; then
                local service_name result=0
                for service_name in "${services[@]}"; do
                    service_compat_run "$service_name" start || result=$?
                done
                return "$result"
            fi
            return 0
            ;;
        is-active|is-enabled)
            [ "${#services[@]}" -gt 0 ] || return 1
            service_compat_run "${services[0]}" status >/dev/null 2>&1
            return $?
            ;;
        start|stop|restart|reload|status)
            [ "${#services[@]}" -gt 0 ] || return 1
            local service_name result=0
            for service_name in "${services[@]}"; do
                service_compat_run "$service_name" "$action" || result=$?
            done
            return "$result"
            ;;
        *)
            printf '%s\n' "Unsupported service operation: ${action:-none}" >&2
            return 1
            ;;
    esac
}
