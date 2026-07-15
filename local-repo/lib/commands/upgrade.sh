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
    # RECONVERGÊNCIA DE VERSÃO DOS PACOTES JÁ RASTREADOS (ESPELHA 'install')
    #
    # Chama update_run() internamente, exatamente como install_run()
    # chama download_run() — o administrador só precisa invocar
    # 'upgrade', sem precisar saber que existe um passo de 'update' por
    # trás (mesma relação de composição já estabelecida no projeto).
    #----------------------------------------------------------------
    log_info "Initiating repository upgrade cycle for outdated packages..."

    _bootstrap_source_command "update"
    update_run || return "$?"

    if [[ ! -d "${REPO_BASE_DIR}/pool" ]]; then
        log_error "Repository workspace not initialized. Please run '${PROGRAM_NAME} init' first."
        return "${EXIT_FAILURE}"
    fi

    #------------------------------------------------------------
    # SNAPSHOT DA POOL ANTES DE QUALQUER MODIFICAÇÃO
    #
    # Materializa a lista de arquivos num array ANTES do loop começar
    # a baixar/remover arquivos da mesma pool/. Se isso fosse feito
    # via 'while read < <(find ...)' direto (como em outros comandos
    # deste projeto que só LEEM a pool), o 'find' poderia enxergar os
    # próprios arquivos novos sendo baixados no meio da própria
    # varredura, processando-os de novo na mesma execução — aqui, ao
    # contrário de diff/sync, o loop também ESCREVE na pool.
    #------------------------------------------------------------
    local -a pool_files=()
    while IFS= read -r -d '' pool_file; do
        pool_files+=("${pool_file}")
    done < <(find "${REPO_BASE_DIR}/pool" -maxdepth 1 -type f -print0)

    local upgraded_count=0

    for pool_file in "${pool_files[@]}"; do
        local base_name
        base_name="$(basename "${pool_file}")"

        local identity
        if ! identity=$(backend_parse_pool_identity "${base_name}"); then
            continue
        fi
        local pkg_name="${identity%%|*}"
        local pkg_arch="${identity##*|}"

        local local_version
        if ! local_version=$(backend_parse_pool_version "${base_name}"); then
            continue
        fi

        local upstream_version
        if ! upstream_version=$(backend_query_upstream_version "${pkg_name}"); then
            continue
        fi

        if ! backend_compare_versions "${local_version}" "${upstream_version}"; then
            continue
        fi

        log_info "Upgrading '${pkg_name}' (${local_version} -> ${upstream_version})..."

        if backend_download_package "${pkg_name}" "${REPO_BASE_DIR}/pool" "${pkg_arch}"; then
            # packages.state não rastreia versão — manter o .deb antigo
            # na pool só acumularia binários obsoletos sem propósito.
            rm -f "${pool_file}"
            upgraded_count=$((upgraded_count + 1))
        else
            log_error "Failed to download upgraded version for: ${pkg_name}"
        fi
    done

    if [[ ${upgraded_count} -gt 0 ]]; then
        log_info "Rebuilding repository index files after upgrade..."
        backend_generate_metadata "${REPO_BASE_DIR}"
    fi

    log_info "Upgrade cycle completed. ${upgraded_count} package(s) upgraded."
    return "${EXIT_SUCCESS}"
}
