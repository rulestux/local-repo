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

[[ -n "${_DIFF_SH_INCLUDED_}" ]] && return
_DIFF_SH_INCLUDED_=1

diff_run() {
    #----------------------------------------------------------------
    # IMPLEMENTAÇÃO DO COMANDO DE ANÁLISE DE DESVIOS (DIFF)
    #
    # Compara de forma não destrutiva os três estados do ecossistema:
    # Estado Desejado (Manifesto), Estado Conhecido (Database) e
    # Estado Real (Arquivos físicos na Pool).
    #----------------------------------------------------------------
    log_info "Initiating non-destructive repository drift analysis..."

    if [[ ! -f "${FILE_DESIRED_STATE}" ]] || [[ ! -f "${FILE_KNOWN_STATE}" ]]; then
        log_error "Repository workspace not initialized. Please run '${PROGRAM_NAME} init' first."
        return "${EXIT_FAILURE}"
    fi

    local clean_manifest
    local physical_pool
    clean_manifest=$(util_make_temp "manifest")
    physical_pool=$(util_make_temp "pool")

    #----------------------------------------------------------------
    # 1. COMPARAÇÃO: MANIFESTO (DESEJADO) × DATABASE (CONHECIDO)
    #----------------------------------------------------------------
    log_debug "Sanitizing declarative manifest for delta computation..."

    if ! validation_manifest_sanitize "${FILE_DESIRED_STATE}" "${clean_manifest}"; then
        log_error "Failed to sanitize manifest. Aborting drift analysis."
        rm -f "${clean_manifest}" "${physical_pool}"
        return "${EXIT_FAILURE}"
    fi

    log_info "Calculating missing intent deviations (+)..."

    local drift_intent
    drift_intent=$(comm -23 "${clean_manifest}" "${FILE_KNOWN_STATE}")
    if [[ $? -ne 0 ]]; then
        log_error "Command 'comm' failed while comparing manifest against known state."
        rm -f "${clean_manifest}" "${physical_pool}"
        return "${EXIT_FAILURE}"
    fi

    if [[ -n "${drift_intent}" ]]; then
        echo "=== Missing Packages (Desired but not synced) ==="
        while IFS= read -r line; do
            echo "+ ${line}"
        done <<< "${drift_intent}"
        echo ""
    else
        log_info "No missing intent software drift detected."
    fi

    #----------------------------------------------------------------
    # 2. COMPARAÇÃO: DISCO (REAL) × DATABASE (CONHECIDO)
    #
    # Traduz cada arquivo físico da pool/ para a identidade lógica
    # 'nome|arquitetura' via o contrato de backend (backend_parse_
    # pool_identity), garantindo que esta comparação opere no mesmo
    # espaço de formato usado por packages.list/packages.state — em
    # vez de comparar nomes de arquivo brutos contra identidades
    # lógicas, o que reportaria falsos órfãos assim que 'sync' passar
    # a popular packages.state de verdade.
    #----------------------------------------------------------------
    log_info "Scanning physical pool directory storage for orphaned packages (!)..."

    : > "${physical_pool}"
    while IFS= read -r -d '' pool_file; do
        local identity
        if identity=$(backend_parse_pool_identity "$(basename "${pool_file}")"); then
            echo "${identity}" >> "${physical_pool}"
        else
            log_warn "Skipping unrecognized file in pool during drift scan: $(basename "${pool_file}")"
        fi
    done < <(find "${REPO_BASE_DIR}/pool" -maxdepth 1 -type f -not -name ".*" -print0)

    sort -u -o "${physical_pool}" "${physical_pool}"

    local drift_orphans
    drift_orphans=$(comm -23 "${physical_pool}" "${FILE_KNOWN_STATE}")
    if [[ $? -ne 0 ]]; then
        log_error "Command 'comm' failed while comparing pool storage against known state."
        rm -f "${clean_manifest}" "${physical_pool}"
        return "${EXIT_FAILURE}"
    fi

    if [[ -n "${drift_orphans}" ]]; then
        echo "=== Orphaned Local Files (Present in pool but untracked) ==="
        while IFS= read -r entry; do
            echo "! ${entry}"
        done <<< "${drift_orphans}"
        echo ""
    else
        log_info "No storage pool physical drift detected."
    fi

    rm -f "${clean_manifest}" "${physical_pool}"

    log_info "Drift analysis pipeline completed successfully."
    return "${EXIT_SUCCESS}"
}
