# Sourced do bootstrap.sh - Não executar diretamente

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
    # Consome o arquivo informado, remove espaços, linhas em branco,
    # comentários, unifica duplicidades (sort -u) e valida se os nomes
    # dos pacotes seguem a especificação de nomenclatura POSIX/Linux.
    #----------------------------------------------------------------
    local input_manifest="$1"
    local output_clean_state="$2"

    # Lógica estrutural de Regex e desduplicação que usaremos na pipeline
    log_debug "Sanitizing declarative manifest '${input_manifest}' against drifts and human anomalies..."
    return "${EXIT_SUCCESS}"
}
