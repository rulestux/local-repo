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

#--------------------------------------------------------------------
# PROTEÇÃO CONTRA DUPLO CARREGAMENTO
#--------------------------------------------------------------------
[[ -n "${_VALIDATION_SH_INCLUDED_}" ]] && return
_VALIDATION_SH_INCLUDED_=1

validation_directory_writable() {
    #----------------------------------------------------------------
    # VALIDAÇÃO DE ESCRITA DE DIRETÓRIOS COM AUTO-CORREÇÃO
    #
    # Verifica se um caminho de diretório existe e possui flag de escrita
    # ativa para o processo do script. Caso o diretório não exista, tenta
    # criá-lo de forma incremental em modo 'mkdir -p'. Se falhar por falta
    # de privilégios (ex: falta de root), aborta imediatamente com erro.
    #----------------------------------------------------------------
    local target_dir="$1"

    if [[ ! -d "${target_dir}" ]]; then
        log_debug "Directory '${target_dir}' does not exist. Creating filesystem branch..."
        if ! mkdir -p "${target_dir}" &> /dev/null; then
            log_error "Critical validation failure: Unable to create target directory structure: ${target_dir}"
            return "${EXIT_FAILURE}"
        fi
    fi

    # Executa teste lógico de permissão de escrita (-w) nativo do Bash
    if [[ ! -w "${target_dir}" ]]; then
        log_error "Permissions validation failure: Directory '${target_dir}' is read-only for this process."
        return "${EXIT_FAILURE}"
    fi

    return "${EXIT_SUCCESS}"
}

validation_file_state_format() {
    #----------------------------------------------------------------
    # CHECK DE FORMATO DECLARATIVO (STATE VALIDATOR)
    #
    # Método auxiliar focado em auditar se os arquivos textuais da pasta
    # state/ não possuem quebras de linha DOS (\r\n) ou caracteres corrompidos
    # que sabotem o processamento iterativo de arrays subsequentes.
    #----------------------------------------------------------------
    local target_file="$1"

    if [[ -f "${target_file}" ]]; then
        if grep -q $'\r' "${target_file}" &> /dev/null; then
            log_warn "File '${target_file}' contains DOS carriage returns (\r). This may cause structural parsing failures."
            return "${EXIT_FAILURE}"
        fi
    fi
    return "${EXIT_SUCCESS}"
}

validation_manifest_sanitize() {
    #----------------------------------------------------------------
    # SANITIZAÇÃO DECLARATIVA DE MANIFESTO (ANTI-HUMAN ERROR)
    #
    # Converte packages.list (que aceita layout horizontal, vertical,
    # comentários e arquitetura opcional) num formato canônico único:
    # uma entrada 'nome|arquitetura' por linha, ordenada e sem
    # duplicatas. A ordenação estrita é requisito obrigatório de quem
    # consome esse arquivo depois via 'comm' (ex: diff.sh) — comm só
    # produz resultado correto com entradas já ordenadas.
    #----------------------------------------------------------------
    local input_manifest="$1"
    local output_clean_state="$2"

    log_debug "Sanitizing declarative manifest '${input_manifest}' against drifts and human anomalies..."

    if [[ ! -f "${input_manifest}" ]]; then
        log_error "Manifest file not found for sanitization: ${input_manifest}"
        return "${EXIT_FAILURE}"
    fi

    local host_arch
    host_arch=$(util_host_architecture)

    #------------------------------------------------------------
    # PIPELINE DE NORMALIZAÇÃO (em uma única passada):
    #   1. grep remove linhas de comentário ('#...') e linhas vazias
    #   2. tr -s colapsa qualquer sequência de espaços/tabs em quebras
    #      de linha, transformando o layout horizontal
    #      ('tmux htop vim') em um token por linha
    #   3. awk aplica a herança de arquitetura: token sem '|' recebe
    #      '|${host_arch}' automaticamente; token que já tem '|'
    #      (ex: 'curl|i386') é mantido como está
    #   4. sort -u ordena estritamente e remove duplicatas
    #------------------------------------------------------------
    grep -vE '^[[:space:]]*(#|$)' "${input_manifest}" \
        | tr -s '[:space:]' '\n' \
        | grep -v '^$' \
        | awk -v arch="${host_arch}" '{ print ($0 ~ /\|/) ? $0 : $0 "|" arch }' \
        | sort -u > "${output_clean_state}"

    log_debug "Manifest sanitized. $(wc -l < "${output_clean_state}") unique package identities resolved."
    return "${EXIT_SUCCESS}"
}
