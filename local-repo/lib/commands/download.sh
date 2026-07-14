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

[[ -n "${_DOWNLOAD_SH_INCLUDED_}" ]] && return
_DOWNLOAD_SH_INCLUDED_=1

download_run() {
    #----------------------------------------------------------------
    # COMANDO DE INJEÇÃO DECLARATIVA DE PACIENTES (DOWNLOAD)
    #
    # Adiciona um ou mais pacotes de forma padronizada em packages.list
    # e executa uma passagem silenciosa de sync para convergir.
    #----------------------------------------------------------------
    if [[ $# -lt 1 ]]; then
        log_error "No package name provided for download action."
        echo "Usage: ${PROGRAM_NAME} download <package_name>[|architecture] ..." >&2
        return "${EXIT_INVALID_USAGE}"
    fi

    if [[ ! -f "${FILE_DESIRED_STATE}" ]]; then
        log_error "Workspace not found. Initialize it first using '${PROGRAM_NAME} init'."
        return "${EXIT_FAILURE}"
    fi

    local host_arch
    host_arch=$(util_host_architecture)
    local updated=0

    # Processa cada argumento passado na CLI de forma dinâmica
    for input_pkg in "$@"; do
        # Normaliza a entrada para o formato canônico
        local canonical_entry
        if [[ "${input_pkg}" =~ \| ]]; then
            canonical_entry="${input_pkg}"
        else
            canonical_entry="${input_pkg}|${host_arch}"
        fi

        # Evita duplicidades simples injetando apenas se não existir no manifesto físico
        if ! grep -qxF "${canonical_entry}" "${FILE_DESIRED_STATE}"; then
            log_info "Injecting '${canonical_entry}' into desired state..."
            echo "${canonical_entry}" >> "${FILE_DESIRED_STATE}"
            updated=$((updated + 1))
        else
            log_info "Package '${canonical_entry}' already registered in the desired list."
        fi
    done

    # Se novos pacotes foram injetados na listagem, aciona o sincronismo automático
    if [[ ${updated} -gt 0 ]]; then
        log_info "New intents registered. Triggering declarative sync pipeline..."
        # O sourcing de sync garante a presença de sync_run no escopo
        _bootstrap_source_command "sync"
        sync_run || return "$?"
    else
        log_info "Desired state is already fully satisfied. No download required."
    fi

    return "${EXIT_SUCCESS}"
}
