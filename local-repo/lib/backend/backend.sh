# Sourced do bootstrap.sh - Não executar diretamente

#--------------------------------------------------------------------
# PROTEÇÃO CONTRA DUPLO CARREGAMENTO
#--------------------------------------------------------------------
[[ -n "${_BACKEND_SH_INCLUDED_}" ]] && return
_BACKEND_SH_INCLUDED_=1

backend_detect() {
    #----------------------------------------------------------------
    # DETECÇÃO OPERACIONAL AUTOMATIZADA
    #
    # Identifica o ecossistema nativo do host analisando a existência
    # de binários chave de gerenciamento. Dá preferência para o que
    # foi configurado no arquivo .conf (CURRENT_BACKEND), mas assume
    # o fallback automático se o config estiver em branco.
    #----------------------------------------------------------------
    log_debug "Detecting host operating system package management family..."

    if [[ -n "${CURRENT_BACKEND}" ]]; then
        log_debug "Using package manager explicitly requested by config: ${CURRENT_BACKEND}"
        echo "${CURRENT_BACKEND}"
        return "${EXIT_SUCCESS}"
    fi

    # Varredura dinâmica heurística baseada em binários nativos
    if command -v apt-get &> /dev/null; then
        echo "${BACKEND_APT}"
    elif command -v dnf &> /dev/null; then
        echo "${BACKEND_DNF}"
    else
        echo "unknown"
    fi
}

backend_load() {
    #----------------------------------------------------------------
    # INJEÇÃO DINÂMICA DE BACKEND (POLIMORFISMO EM RUNTIME)
    #
    # Descobre qual gerenciador deve ser adotado, valida se o arquivo
    # script daquele backend existe na pasta lib/backend/ e o importa.
    # Em seguida, força o backend a validar suas próprias dependências.
    #----------------------------------------------------------------
    local detected
    detected=$(backend_detect)

    if [[ "${detected}" == "unknown" ]]; then
        log_fatal "Unsupported Linux distribution. No compatible backend found (APT/DNF)."
        exit "${EXIT_ENV_MISSING}"
    fi

    # Atualiza a variável de estado global com o veredito final
    CURRENT_BACKEND="${detected}"

    local backend_script="${PROJECT_ROOT}/lib/backend/${CURRENT_BACKEND}.sh"

    if [[ -f "${backend_script}" ]]; then
        log_debug "Loading dynamic backend engine driver: ${backend_script}"
        source "${backend_script}"
    else
        log_fatal "Driver script missing for the detected backend: lib/backend/${CURRENT_BACKEND}.sh"
        exit "${EXIT_FAILURE}"
    fi

    # Acoplamento concluído. Agora invoca a validação interna do driver injetado
    log_debug "Invoking package manager dependency check via contract..."
    backend_check_dependencies
}
