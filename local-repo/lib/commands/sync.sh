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

[[ -n "${_SYNC_SH_INCLUDED_}" ]] && return
_SYNC_SH_INCLUDED_=1

sync_run() {
    #----------------------------------------------------------------
    # MOTOR DE CONVERGÊNCIA E SINCRONISMO DE ESTADOS (SYNC)
    #
    # Resolve as divergências entre o Estado Desejado e o Estado
    # Conhecido, realizando o download incremental de novos pacotes
    # e dependências recursivas, atualizando o database de forma ordenada.
    #----------------------------------------------------------------
    log_info "Initiating repository state synchronization..."

    if [[ ! -f "${FILE_DESIRED_STATE}" ]] || [[ ! -f "${FILE_KNOWN_STATE}" ]]; then
        log_error "Repository workspace not initialized. Please run '${PROGRAM_NAME} init' first."
        return "${EXIT_FAILURE}"
    fi

    local clean_manifest
    clean_manifest=$(util_make_temp "manifest")

    # Sanitiza o manifesto contra desvios ou espaçamentos humanos
    if ! validation_manifest_sanitize "${FILE_DESIRED_STATE}" "${clean_manifest}"; then
        log_error "Failed to sanitize declarative manifest. Aborting sync."
        rm -f "${clean_manifest}"
        return "${EXIT_FAILURE}"
    fi

    # Calcula as intenções que precisam ser baixadas (Desejado - Conhecido)
    local drift_intent
    drift_intent=$(comm -23 "${clean_manifest}" "${FILE_KNOWN_STATE}")
    if [[ $? -ne 0 ]]; then
        log_error "Failed to calculate drift intent via 'comm'."
        rm -f "${clean_manifest}"
        return "${EXIT_FAILURE}"
    fi

    if [[ -z "${drift_intent}" ]]; then
        log_info "All desired packages are already fully synchronized in the known state."
        rm -f "${clean_manifest}"
        return "${EXIT_SUCCESS}"
    fi

    # Acumulador de entradas bem-sucedidas nesta execução — evita reescrever
    # e reordenar o arquivo de estado a cada pacote individual do loop.
    local success_sync=0
    local newly_synced=""

    while IFS= read -r entry; do
        [[ -z "${entry}" ]] && continue

        # Separa o nome lógico do pacote e sua arquitetura correspondente
        local name="${entry%%|*}"
        local arch="${entry##*|}"

        log_info "Processing incremental download: ${name} (${arch})"

        # Invoca o motor de downloads do backend de forma segura
        # O driver APT ou DNF cuidará do download recursivo das dependências
        if backend_download_package "${name}" "${REPO_BASE_DIR}/pool" "${arch}"; then
            # Apenas acumula em memória — nada de I/O em disco por iteração
            newly_synced+="${entry}"$'\n'
            success_sync=$((success_sync + 1))
        else
            log_error "Failed to download package sequence for: ${entry}"
        fi
    done <<< "${drift_intent}"

    #----------------------------------------------------------------
    # GRAVAÇÃO E ORDENAÇÃO ÚNICA DO ESTADO CONHECIDO
    #
    # Só toca em FILE_KNOWN_STATE uma vez, depois que todo o loop de
    # downloads terminou — em vez de reescrever e reordenar o arquivo
    # inteiro a cada pacote individual (custo O(n) repetido n vezes).
    # Isso também reduz a janela de I/O em disco a uma única operação
    # atômica por execução de sync, em vez de várias pequenas.
    #----------------------------------------------------------------
    if [[ ${success_sync} -gt 0 ]]; then
        printf '%s' "${newly_synced}" >> "${FILE_KNOWN_STATE}"
        sort -u -o "${FILE_KNOWN_STATE}" "${FILE_KNOWN_STATE}"

        log_info "Rebuilding repository index files from downloaded metadata..."
        backend_generate_metadata "${REPO_BASE_DIR}"
    fi

    rm -f "${clean_manifest}"

    local total_pending
    total_pending=$(wc -l <<< "${drift_intent}")

    # Se a lista de pendências não for vazia e o número de sucessos for menor que o total pendente
    if [[ ${total_pending} -gt 0 ]] && [[ ${success_sync} -lt ${total_pending} ]]; then
        log_error "State synchronization incomplete: only ${success_sync} of ${total_pending} pending packages were synchronized."
        return "${EXIT_FAILURE}"
    fi

    log_info "State synchronization process completed. All ${success_sync}/${total_pending} packages synchronized successfully."
    return "${EXIT_SUCCESS}"
}
