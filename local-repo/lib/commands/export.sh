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

[[ -n "${_EXPORT_SH_INCLUDED_}" ]] && return
_EXPORT_SH_INCLUDED_=1

#--------------------------------------------------------------------
# CONTRATO DO COMANDO EXPORT
#
# Conforme ARCHITECTURE.md: consolida packages.list, packages.state,
# logs e a pool/ binária num único snapshot compactado, gerado via
# '--to-tar <path>'. O formato de compressão é gzip nativo do 'tar'
# (mesma decisão tomada em import.sh, para não exigir binário externo
# além do que o core já valida em environment_check_core).
#--------------------------------------------------------------------
readonly _EXPORT_FLAG_TO_TAR="--to-tar"

_export_print_usage() {
    echo "Usage: ${PROGRAM_NAME} export ${_EXPORT_FLAG_TO_TAR} <output_path.tar.gz>" >&2
}

_export_to_tar() {
    #----------------------------------------------------------------
    # CONSOLIDAÇÃO FÍSICA EM SNAPSHOT TAR.GZ
    #----------------------------------------------------------------
    local output_path="$1"
    local output_dir
    output_dir="$(dirname "${output_path}")"

    log_info "Packaging local repository environment to: ${output_path}"

    if [[ ! -d "${REPO_BASE_DIR}" ]]; then
        log_error "Repository base directory does not exist yet: ${REPO_BASE_DIR}. Run '${PROGRAM_NAME} init' first."
        return "${EXIT_FAILURE}"
    fi

    if [[ ! -d "${output_dir}" ]] || [[ ! -w "${output_dir}" ]]; then
        log_error "Destination directory is missing or not writable: ${output_dir}"
        return "${EXIT_INVALID_USAGE}"
    fi

    # '-C' muda o diretório de trabalho do tar ANTES de empacotar, então os
    # caminhos dentro do tarball ficam relativos (pool/..., state/...,
    # log/...) em vez de absolutos — essencial para que o import funcione
    # independente de onde o REPO_BASE_DIR de destino estiver localizado.
    if ! tar -czf "${output_path}" -C "${REPO_BASE_DIR}" pool state log 2>/dev/null; then
        log_error "Failed to create snapshot archive at: ${output_path}"
        rm -f "${output_path}"
        return "${EXIT_FAILURE}"
    fi

    # Checagem de integridade pós-escrita antes de reportar sucesso.
    if ! tar -tzf "${output_path}" &> /dev/null; then
        log_error "Snapshot archive integrity check failed after creation: ${output_path}"
        rm -f "${output_path}"
        return "${EXIT_FAILURE}"
    fi

    log_info "Snapshot successfully written and verified: ${output_path}"
    return "${EXIT_SUCCESS}"
}

export_run() {
    #----------------------------------------------------------------
    # DISPATCHER INTERNO DO COMANDO EXPORT
    #
    # Segue o mesmo padrão de import_run(): só 'return', nunca 'exit'.
    #----------------------------------------------------------------
    if [[ $# -lt 2 ]] || [[ "$1" != "${_EXPORT_FLAG_TO_TAR}" ]]; then
        log_error "Missing or invalid destination flag for export operation."
        _export_print_usage
        return "${EXIT_INVALID_USAGE}"
    fi

    local output_path="$2"

    _export_to_tar "${output_path}" || return "$?"

    log_info "Export command finished."
    return "${EXIT_SUCCESS}"
}
