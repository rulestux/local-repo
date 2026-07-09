# Sourced do bootstrap.sh - Não executar diretamente

#--------------------------------------------------------------------
# SUBSISTEMA DE LOGGING E SAÍDA EM RUNTIME
#--------------------------------------------------------------------
[[ -n "${_LOG_SH_INCLUDED_}" ]] && return
_LOG_SH_INCLUDED_=1

# Códigos ANSI para estilização visual das saídas em terminal interativo
LOG_COLOR_RESET=""
LOG_COLOR_DEBUG=""
LOG_COLOR_INFO=""
LOG_COLOR_WARN=""
LOG_COLOR_ERROR=""
LOG_COLOR_FATAL=""

log_initialize() {
    #----------------------------------------------------------------
    # DETECÇÃO DINÂMICA DE TERMINAL INTERATIVO (TTY)
    #
    # Analisa se a saída padrão (stdout / descritor 1) está conectada
    # a um terminal interativo. Se o comando estiver sendo jogado para
    # um arquivo ($ local-repo stats > log.txt) ou um pipe, as cores
    # são omitidas automaticamente, gerando um log limpo de caracteres
    # de escape ANSI.
    #----------------------------------------------------------------
    if [[ -t 1 ]]; then
        LOG_COLOR_RESET="\033[0m"
        LOG_COLOR_DEBUG="\033[36m"    # Ciano
        LOG_COLOR_INFO="\033[32m"     # Verde
        LOG_COLOR_WARN="\033[33m"     # Amarelo
        LOG_COLOR_ERROR="\033[31m"    # Vermelho
        LOG_COLOR_FATAL="\033[41;37m" # Fundo Vermelho, Fonte Branca
    fi
}

_log_level_to_int() {
    #----------------------------------------------------------------
    # TRADUTOR DE SEVERIDADE (STRING → INT)
    #
    # Converte o nome textual do nível de log em seu valor numérico
    # correspondente (definido em constants.sh), permitindo comparação
    # aritmética simples entre "o que está sendo logado" e "o que o
    # admin configurou para ser exibido" (LOG_LEVEL).
    #----------------------------------------------------------------
    case "$1" in
        DEBUG) echo "${LOG_LEVEL_DEBUG}" ;;
        INFO)  echo "${LOG_LEVEL_INFO}"  ;;
        WARN)  echo "${LOG_LEVEL_WARN}"  ;;
        ERROR) echo "${LOG_LEVEL_ERROR}" ;;
        FATAL) echo "${LOG_LEVEL_FATAL}" ;;
        *)     echo "${LOG_LEVEL_INFO}"  ;;
    esac
}

_log_should_emit() {
    #----------------------------------------------------------------
    # FILTRO DE VERBOSIDADE
    #
    # Retorna sucesso (0) apenas se a severidade da mensagem for maior
    # ou igual ao limiar configurado em LOG_LEVEL. ERROR e FATAL não
    # passam por este filtro em suas funções públicas — falhas graves
    # devem sempre ser visíveis, independente da verbosidade escolhida.
    #----------------------------------------------------------------
    local message_level_int
    local threshold_int
    message_level_int=$(_log_level_to_int "$1")
    threshold_int=$(_log_level_to_int "${LOG_LEVEL:-INFO}")
    [[ "${message_level_int}" -ge "${threshold_int}" ]]
}

_log_internal() {
    #----------------------------------------------------------------
    # MOTOR DE FORMATAÇÃO PROTEGIDO E SEGURO (STREAM-SAFE)
    #
    # Modificado para mitigar vulnerabilidades e quebras de string onde
    # caracteres especiais (como '%') contidos na mensagem do usuário
    # bagunçavam o interpretador printf. O uso de '%s' e '%b' isola
    # os metacaracteres e injeta as variáveis com segurança cirúrgica.
    #----------------------------------------------------------------
    local level="$1"
    local color="$2"
    local message="$3"
    local target_stream="/dev/stdout"

    # Erros operacionais e falhas impeditivas são direcionados para a stderr
    if [[ "${level}" == "ERROR" ]] || [[ "${level}" == "FATAL" ]]; then
        target_stream="/dev/stderr"
    fi

    local timestamp
    timestamp=$(util_timestamp)

    # Injeção segura utilizando mapeamento rígido de formatos
    printf "%b[%s] [%s] %s%b\n" "${color}" "${timestamp}" "${level}" "${message}" "${LOG_COLOR_RESET}" > "${target_stream}"
}

log_debug() {
    _log_should_emit "DEBUG" || return 0
    _log_internal "DEBUG" "${LOG_COLOR_DEBUG}" "$1"
}

log_info() {
    _log_should_emit "INFO" || return 0
    _log_internal "INFO" "${LOG_COLOR_INFO}" "$1"
}

log_warn() {
    _log_should_emit "WARN" || return 0
    _log_internal "WARN" "${LOG_COLOR_WARN}" "$1"
}

log_error() {
    # Erros e falhas fatais sempre são emitidos, sem passar pelo filtro
    # de LOG_LEVEL — silenciar uma falha real seria mais perigoso do
    # que poluir o output.
    _log_internal "ERROR" "${LOG_COLOR_ERROR}" "$1"
}

log_fatal() {
    _log_internal "FATAL" "${LOG_COLOR_FATAL}" "$1"
}
