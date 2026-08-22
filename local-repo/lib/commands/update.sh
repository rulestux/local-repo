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

[[ -n "${_UPDATE_SH_INCLUDED_}" ]] && return
_UPDATE_SH_INCLUDED_=1

_update_list_outdated_packages() {
    #----------------------------------------------------------------
    # CALCULADOR DIFERENCIAL PURO (SEM REFRESH DE CACHE, SEM LOGS DE ROTINA)
    #
    # Assume que o cache upstream já foi atualizado por quem chamou
    # (via backend_refresh_upstream_cache). Varre a pool/, compara cada
    # pacote contra sua versão candidata e sugere o 'upgrade' se houver
    # algo desatualizado. Extraída de update_run() para que sync.sh
    # possa reaproveitar exatamente esta parte sem repetir as mensagens
    # de rotina "Refreshing upstream cache...", que só fazem sentido
    # quando 'update' é invocado diretamente pelo administrador.
    #----------------------------------------------------------------
    if [[ ! -d "${REPO_BASE_DIR}/pool" ]]; then
        return "${EXIT_SUCCESS}"
    fi

    local outdated_count=0
    while IFS= read -r -d '' pool_file; do
        local base_name identity pkg_name local_version upstream_version
        base_name="$(basename "${pool_file}")"
        identity=$(backend_parse_pool_identity "${base_name}") || continue
        pkg_name="${identity%%|*}"
        local_version=$(backend_parse_pool_version "${base_name}") || continue
        upstream_version=$(backend_query_upstream_version "${pkg_name}") || continue

        if backend_compare_versions "${local_version}" "${upstream_version}"; then
            echo "${pkg_name}"
            outdated_count=$((outdated_count + 1))
        fi
    done < <(find "${REPO_BASE_DIR}/pool" -maxdepth 1 -type f -print0)

    if [[ ${outdated_count} -gt 0 ]]; then
        log_info "${outdated_count} package(s) have newer versions available upstream. Run '${PROGRAM_NAME} upgrade' to update them."
    fi

    return "${EXIT_SUCCESS}"
}

update_run() {
    #----------------------------------------------------------------
    # ATUALIZAÇÃO DO CACHE UPSTREAM + CALCULADORA DIFERENCIAL (UPDATE)
    #
    # 1. Tenta atualizar o cache contra os repositórios oficiais.
    # 2. Se não houver resposta (sem internet, repositório fora do
    #    ar), NÃO trata como erro — apenas segue adiante com o último
    #    cache local já disponível, registrando isso via log_warn.
    # 3. Sempre executa o cálculo diferencial (_update_list_outdated_
    #    packages), mesmo quando o passo 1 falhou — comparar a pool
    #    contra um cache desatualizado ainda é uma operação válida,
    #    só deixa de ser garantidamente fresca.
    #----------------------------------------------------------------
    log_info "Refreshing upstream repository package index cache..."

    if backend_refresh_upstream_cache; then
        log_info "Upstream repository cache successfully refreshed."
    else
        log_warn "Upstream repository unreachable. Proceeding with the last known local cache."
    fi

    _update_list_outdated_packages
    return "${EXIT_SUCCESS}"
}
