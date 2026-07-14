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

[[ -n "${_INSTALL_SH_INCLUDED_}" ]] && return
_INSTALL_SH_INCLUDED_=1

install_run() {
    #----------------------------------------------------------------
    # COMANDO DE ATIVAÇÃO DE INSTALAÇÃO NO HOST (INSTALL)
    #
    # Dispara a cadeia declarativa de downloads para a pool local
    # e, ato contínuo, chama as diretrizes do driver de backend
    # ativo para instalar localmente no sistema operacional host.
    #----------------------------------------------------------------
    if [[ $# -lt 1 ]]; then
        log_error "No package name provided for local installation."
        echo "Usage: ${PROGRAM_NAME} install <package_name> ..." >&2
        return "${EXIT_INVALID_USAGE}"
    fi

    # Garante que as rotinas de download sejam sourcing-compatíveis
    _bootstrap_source_command "download"

    # Preserva a lista de pacotes solicitados para instalação host posterior
    local install_list=("$@")

    log_info "Stage 1: Enforcing declarative convergence onto the local pool..."

    # Repassa a totalidade dos argumentos de forma segura para a pipeline de download
    if ! download_run "${install_list[@]}"; then
        log_fatal "Aborting host installation. Local pool convergence phase failed."
        return "${EXIT_FAILURE}"
    fi

    log_info "Stage 2: Transitioning payload to the active host system..."

    # Laço iterativo de instalação para cada um dos alvos no host
    for target_package in "${install_list[@]}"; do
        # Isola a arquitetura opcional e captura apenas o nome base
        local name_base="${target_package%%|*}"

        log_info "Triggering local offline installation for payload: ${name_base}"

        # Invoca a API de backend para efetivar a instalação usando exclusivamente a pool offline
        if ! backend_install_from_local_pool "${name_base}" "${REPO_BASE_DIR}"; then
            log_error "Installation failed on host system for: ${name_base}"
            return "${EXIT_FAILURE}"
        fi
    done

    log_info "Host package installation process completed successfully."
    return "${EXIT_SUCCESS}"
}
