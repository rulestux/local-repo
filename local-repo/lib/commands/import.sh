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

[[ -n "${_IMPORT_SH_INCLUDED_}" ]] && return
_IMPORT_SH_INCLUDED_=1

#--------------------------------------------------------------------
# CONTRATO DE FONTES SUPORTADAS PELO COMANDO IMPORT
#
# Conforme ARCHITECTURE.md (documento congelado): o import aceita três
# origens de dados possíveis, MUTUAMENTE EXCLUSIVAS entre si:
#
#   --from-iso <path.iso>       Monta uma imagem ISO via loop device
#   --from-directory <path>     Varre uma estrutura de diretório já existente
#   --from-tar <path.tar.gz>    Restaura um snapshot gerado pelo comando 'export'
#
# NOTA DE DESIGN: uma flag "--from-usb" dedicada é desnecessária. Um
# dispositivo USB montado no sistema operacional já é, por definição,
# um diretório comum — basta o usuário montá-lo (ex: via gerenciador
# de arquivos ou 'mount' manual) e usar '--from-directory' apontando
# para o ponto de montagem. Isso evita depender de 'blkid' só para
# resolver rótulo/UUID de dispositivo, sem perder funcionalidade real:
# a varredura de pacotes é idêntica entre "diretório comum" e
# "diretório que por acaso é um pendrive montado".
#--------------------------------------------------------------------
readonly _IMPORT_FLAG_ISO="--from-iso"
readonly _IMPORT_FLAG_DIRECTORY="--from-directory"
readonly _IMPORT_FLAG_TAR="--from-tar"

_import_print_usage() {
    #----------------------------------------------------------------
    # MENSAGEM DE USO CENTRALIZADA
    #----------------------------------------------------------------
    echo "Usage: ${PROGRAM_NAME} import <source-flag> <value>" >&2
    echo "" >&2
    echo "Source flags (mutually exclusive, choose exactly one):" >&2
    echo "  ${_IMPORT_FLAG_ISO} <path.iso>        Import from a mountable ISO image" >&2
    echo "  ${_IMPORT_FLAG_DIRECTORY} <path>      Import from an existing directory (also use this for a mounted USB device)" >&2
    echo "  ${_IMPORT_FLAG_TAR} <path.tar.gz>     Restore a snapshot exported by 'local-repo export'" >&2
}

_import_parse_args() {
    #----------------------------------------------------------------
    # PARSER DE ARGUMENTOS DO COMANDO IMPORT
    #
    # Usa nameref (Bash 4.3+, seguro pois environment_check_core exige
    # Bash 5.0+) para devolver tipo e valor da flag escolhida sem
    # variáveis globais soltas. Garante exclusividade mútua entre
    # flags de origem.
    #----------------------------------------------------------------
    local -n out_source_type="$1"
    local -n out_source_value="$2"
    shift 2

    out_source_type=""
    out_source_value=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            "${_IMPORT_FLAG_ISO}"|"${_IMPORT_FLAG_DIRECTORY}"|"${_IMPORT_FLAG_TAR}")
                if [[ -n "${out_source_type}" ]]; then
                    log_error "Conflicting source flags: '${out_source_type}' and '$1' are mutually exclusive."
                    return "${EXIT_INVALID_USAGE}"
                fi
                if [[ -z "${2:-}" ]]; then
                    log_error "Missing value argument for flag '$1'."
                    return "${EXIT_INVALID_USAGE}"
                fi
                out_source_type="$1"
                out_source_value="$2"
                shift 2
                ;;
            *)
                log_error "Unknown argument for import command: '$1'"
                return "${EXIT_INVALID_USAGE}"
                ;;
        esac
    done

    if [[ -z "${out_source_type}" ]]; then
        log_error "No source flag provided. Exactly one of ${_IMPORT_FLAG_ISO}/${_IMPORT_FLAG_DIRECTORY}/${_IMPORT_FLAG_TAR} is required."
        return "${EXIT_INVALID_USAGE}"
    fi

    return "${EXIT_SUCCESS}"
}

_import_from_iso() {
    #----------------------------------------------------------------
    # ORIGEM: IMAGEM ISO (LOOP MOUNT)
    #
    # Todo erro usa 'return' em vez de 'exit': quem decide encerrar
	# o processo é o dispatcher em bootstrap.sh, não este handler.
	# Isso mantém a função testável isoladamente.
    #----------------------------------------------------------------
    local iso_path="$1"

    log_info "Preparing ISO-based import from: ${iso_path}"

    if [[ ! -f "${iso_path}" ]]; then
        log_error "ISO source file not found: ${iso_path}"
        return "${EXIT_INVALID_USAGE}"
    fi

    if [[ ! -r "${iso_path}" ]]; then
        log_error "ISO source file is not readable by this process: ${iso_path}"
        return "${EXIT_FAILURE}"
    fi

    # TODO(próxima subfase): loop-mount real via 'mount -o loop,ro' num
    # diretório temporário sob "${REPO_BASE_DIR}/run/mnt-import", varrer
    # o conteúdo montado, copiar pacotes válidos para POOL_DIR e
    # desmontar com segurança — inclusive em caso de erro no meio do
    # processo (via trap local dedicado a este handler).
    log_warn "ISO import pipeline completed as stub. No files were physically copied yet."
    return "${EXIT_SUCCESS}"
}

_import_from_directory() {
    #----------------------------------------------------------------
    # ORIGEM: DIRETÓRIO LOCAL (também cobre dispositivos USB montados
    # manualmente — ver nota de design no topo do arquivo)
    #----------------------------------------------------------------
    local source_dir="$1"

    log_info "Preparing directory-based import from: ${source_dir}"

    if [[ ! -d "${source_dir}" ]]; then
        log_error "Source directory does not exist: ${source_dir}"
        return "${EXIT_INVALID_USAGE}"
    fi

    if [[ ! -r "${source_dir}" ]]; then
        log_error "Source directory is not readable by this process: ${source_dir}"
        return "${EXIT_FAILURE}"
    fi

    # TODO(próxima subfase): varrer recursivamente 'source_dir' em busca
    # de pacotes compatíveis com o backend ativo (.deb para APT, .rpm
    # para DNF), copiá-los para POOL_DIR e reconstruir packages.state.
    log_warn "Directory import pipeline completed as stub. No files were physically copied yet."
    return "${EXIT_SUCCESS}"
}

_import_from_tar() {
    #----------------------------------------------------------------
    # ORIGEM: SNAPSHOT TAR.GZ GERADO PELO COMANDO 'EXPORT'
    #
    # Usa a compressão gzip nativa do próprio 'tar' (-z), sem depender
    # de nenhum binário externo além do 'tar' já exigido pelo core.
    #----------------------------------------------------------------
    local archive_path="$1"

    log_info "Preparing snapshot restoration from: ${archive_path}"

    if [[ ! -f "${archive_path}" ]]; then
        log_error "Snapshot archive not found: ${archive_path}"
        return "${EXIT_INVALID_USAGE}"
    fi

    if [[ ! -r "${archive_path}" ]]; then
        log_error "Snapshot archive is not readable by this process: ${archive_path}"
        return "${EXIT_FAILURE}"
    fi

    # TODO(próxima subfase): validar a integridade do arquivo
    # ('tar -tzf "${archive_path}"'), extrair pool/, state/ e log/
    # preservando permissões via 'tar -xzf', e reconciliar o
    # packages.state restaurado com o conteúdo atual de REPO_BASE_DIR.
    log_warn "Tar snapshot import pipeline completed as stub. No files were physically extracted yet."
    return "${EXIT_SUCCESS}"
}

import_run() {
    #----------------------------------------------------------------
    # DISPATCHER INTERNO DO COMANDO IMPORT
    #
    # Todo o corpo abaixo só usa 'return' — nenhum 'exit' direto. Isso
    # é intencional: o dispatcher central em bootstrap.sh é o único
    # ponto autorizado a encerrar o processo, checando o código de
    # retorno logo após chamar 'import_run "$@"'.
    #----------------------------------------------------------------
    if [[ $# -eq 0 ]]; then
        log_error "Missing source flag for import operation."
        _import_print_usage
        return "${EXIT_INVALID_USAGE}"
    fi

    local source_type
    local source_value

    if ! _import_parse_args source_type source_value "$@"; then
        _import_print_usage
        return "${EXIT_INVALID_USAGE}"
    fi

    log_info "Import operation requested. Source type: '${source_type}' | Value: '${source_value}'"

    case "${source_type}" in
        "${_IMPORT_FLAG_ISO}")
            _import_from_iso "${source_value}" || return "$?"
            ;;
        "${_IMPORT_FLAG_DIRECTORY}")
            _import_from_directory "${source_value}" || return "$?"
            ;;
        "${_IMPORT_FLAG_TAR}")
            _import_from_tar "${source_value}" || return "$?"
            ;;
    esac

    log_info "Import command finished."
    return "${EXIT_SUCCESS}"
}
