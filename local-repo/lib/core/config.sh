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
[[ -n "${_CONFIG_SH_INCLUDED_}" ]] && return
_CONFIG_SH_INCLUDED_=1

config_load() {
    #----------------------------------------------------------------
    # PARSER SEGURO DE ARQUIVOS DE CONFIGURAÇÃO (.CONF)
    #
    # Em vez de dar 'source' no arquivo do usuário (permitindo que ele
    # execute códigos maliciosos como root), este método faz um parse
    # textual estrito via Regex. Ele isola chaves e valores e aceita
    # apenas variáveis pré-homologadas na whitelist de configuração.
    #----------------------------------------------------------------
    local custom_config_file="${1:-$CONFIG_FILE}"

    if [[ ! -f "${custom_config_file}" ]]; then
        log_warn "Configuration file not found at: ${custom_config_file}. Using structural fallbacks."
        return "${EXIT_SUCCESS}"
    fi

    log_info "Loading and parsing configuration file: ${custom_config_file}"

    local line_number=0
    while IFS= read -r line || [[ -n "${line}" ]]; do
        ((line_number++))

        # Ignora linhas em branco ou comentários que comecem com '#'
        [[ "${line}" =~ ^[[:space:]]*$ ]] && continue
        [[ "${line}" =~ ^[[:space:]]*# ]] && continue

        # Valida a sintaxe estrita da atribuição: KEY="VALUE" ou KEY=VALUE
        if [[ "${line}" =~ ^[[:space:]]*([A-Za-z0-9_]+)[[:space:]]*=[[:space:]]*[\"\']?([^\"\']*)[\"\']?.*$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"

            # Aplica a Whitelist de segurança: Modifica apenas o escopo autorizado do core
            case "${key}" in
                REPO_BASE_DIR)
                    REPO_BASE_DIR="${value}"
                    # Remapeia dinamicamente os caminhos subordinados dependentes
                    POOL_DIR="${REPO_BASE_DIR}/pool"
                    LOG_FILE="${REPO_BASE_DIR}/log/local-repo.log"
                    LOCK_FILE="${REPO_BASE_DIR}/run/local-repo.lock"
                    STATE_DIR="${REPO_BASE_DIR}/state"
                    FILE_DESIRED_STATE="${STATE_DIR}/packages.list"
                    FILE_KNOWN_STATE="${STATE_DIR}/packages.state"
                    ;;
                CURRENT_BACKEND|BACKEND)
                    #------------------------------------------------
                    # ALIAS DE COMPATIBILIDADE COM A DOCUMENTAÇÃO
                    #
                    # O README documenta a chave como "BACKEND"
                    # (nome mais amigável para o admin), enquanto o
                    # core internamente usa "CURRENT_BACKEND" (mais
                    # explícito no código). Aceitamos as duas grafias
                    # aqui para não quebrar quem seguiu o README, mas
                    # ambas convergem para a mesma variável de estado.
                    #------------------------------------------------
                    if [[ "${value}" == "${BACKEND_APT}" ]] || [[ "${value}" == "${BACKEND_DNF}" ]]; then
                        CURRENT_BACKEND="${value}"
                    else
                        log_error "Config error [line ${line_number}]: Unsupported backend architecture '${value}'."
                    fi
                    ;;
                LOG_LEVEL)
                    case "${value}" in
                        DEBUG|INFO|WARN|ERROR|FATAL)
                            LOG_LEVEL="${value}"
                            ;;
                        *)
                            log_error "Config error [line ${line_number}]: Invalid LOG_LEVEL value '${value}'. Expected DEBUG|INFO|WARN|ERROR|FATAL."
                            ;;
                    esac
                    ;;
                *)
                    log_warn "Config warning [line ${line_number}]: Variable '${key}' is invalid or unauthorized."
                    ;;
            esac
        else
            log_warn "Config syntax error [line ${line_number}]: Invalid declaration format."
        fi
    done < "${custom_config_file}"
}
