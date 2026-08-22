# Sourced do bootstrap.sh - Não executar diretamente

#################################################################
# local-repo - Manages and converges local packet pools for     #
#              offline environments.                            #
#                                                               #
# Site:         https://github.com/rulestux                     #
# Author:       Jean Felipe                                     #
# Maintenance:  Jean Felipe                                     #
# License:      MIT                                             #
#                                                               #
#################################################################

[[ -n "${_UPGRADE_SH_INCLUDED_}" ]] && return
_UPGRADE_SH_INCLUDED_=1

upgrade_run() {
    #----------------------------------------------------------------
    # ATUALIZAÇÃO DE PACOTES JÁ INSTALADOS NO HOST (SEMÂNTICA APT/DNF)
    #
    # Diferente de 'converge' (que só atua sobre a pool/ local),
    # 'upgrade' é o único comando do projeto, junto de 'install', que
    # efetivamente modifica o sistema hospedeiro. Fluxo: garante cache
    # e pool atualizados (update + converge), depois varre a
    # interseção entre 'pool/' e pacotes já instalados no host,
    # listando e reinstalando os desatualizados.
    #
    # Padrão de confirmação: SEM nenhuma flag, o comportamento já é
    # equivalente a '-y'/'--yes' (prossegue automaticamente) — mantém
    # o projeto operável em cron/scripts sem exigir flag explícita.
    # '-n'/'--no' inverte isso: computa e lista as pendências, mas não
    # instala nada (modo de pré-visualização).
    #----------------------------------------------------------------
    local assume_yes=1

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -y|--yes|-Y|--Yes)
                assume_yes=1
                shift
                ;;
            -n|--no)
                assume_yes=0
                shift
                ;;
            *)
                log_error "Unknown argument for upgrade command: '$1'"
                return "${EXIT_INVALID_USAGE}"
                ;;
        esac
    done

    log_info "Initiating host package upgrade cycle..."

    _bootstrap_source_command "update"
    update_run || return "$?"

    _bootstrap_source_command "converge"
    converge_run || return "$?"

    if [[ ! -d "${REPO_BASE_DIR}/pool" ]]; then
        log_error "Repository workspace not initialized. Please run '${PROGRAM_NAME} init' first."
        return "${EXIT_FAILURE}"
    fi

    log_info "Scanning for installed packages with newer versions available in the local pool..."

    #------------------------------------------------------------
    # ARRAYS PARALELOS PARA REGISTRAR AS PENDÊNCIAS ENCONTRADAS
    #
    # Precisamos listar tudo ANTES de decidir se instala (o '-n' pode
    # cancelar a instalação depois de já termos a lista completa) —
    # por isso a varredura acumula em memória em vez de agir pacote a
    # pacote dentro do próprio loop, como converge.sh faz.
    #------------------------------------------------------------
    local -a pending_names=()
    local -a pending_from=()
    local -a pending_to=()

    while IFS= read -r -d '' pool_file; do
        local base_name identity pkg_name pool_version installed_version

        base_name="$(basename "${pool_file}")"

        identity=$(backend_parse_pool_identity "${base_name}") || continue
        pkg_name="${identity%%|*}"

        pool_version=$(backend_parse_pool_version "${base_name}") || continue

        # Só nos interessa quem já está instalado no host — pacotes
        # presentes na pool mas nunca instalados não fazem parte do
        # escopo do 'upgrade' (esse é o papel do 'install').
        backend_is_package_installed "${pkg_name}" || continue

        installed_version=$(backend_query_installed_version "${pkg_name}") || continue

        if backend_compare_versions "${installed_version}" "${pool_version}"; then
            pending_names+=("${pkg_name}")
            pending_from+=("${installed_version}")
            pending_to+=("${pool_version}")
        fi
    done < <(find "${REPO_BASE_DIR}/pool" -maxdepth 1 -type f -print0)

    if [[ ${#pending_names[@]} -eq 0 ]]; then
        log_info "All installed packages are already at their latest pool-available version."
        return "${EXIT_SUCCESS}"
    fi

    log_info "${#pending_names[@]} installed package(s) have newer versions available in the local pool:"
    local i
    for i in "${!pending_names[@]}"; do
        echo "  ${pending_names[${i}]}: ${pending_from[${i}]} -> ${pending_to[${i}]}"
    done

    if [[ ${assume_yes} -eq 0 ]]; then
        log_info "Dry-run mode ('-n'/'--no'): no packages were installed on host."
        return "${EXIT_SUCCESS}"
    fi

    local upgraded_count=0
    local pkg_name
    for pkg_name in "${pending_names[@]}"; do
        log_info "Reinstalling upgraded package on host: ${pkg_name}"
        if backend_install_from_local_pool "${pkg_name}" "${REPO_BASE_DIR}"; then
            upgraded_count=$((upgraded_count + 1))
        else
            log_error "Failed to upgrade package on host: ${pkg_name}"
        fi
    done

    if [[ ${upgraded_count} -lt ${#pending_names[@]} ]]; then
        log_error "Host upgrade cycle incomplete: only ${upgraded_count} of ${#pending_names[@]} package(s) were successfully upgraded."
        return "${EXIT_FAILURE}"
    fi

    log_info "Host upgrade cycle completed. All ${upgraded_count}/${#pending_names[@]} package(s) upgraded successfully."
    return "${EXIT_SUCCESS}"
}
