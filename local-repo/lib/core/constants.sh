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
[[ -n "${_CONSTANTS_SH_INCLUDED_}" ]] && return
_CONSTANTS_SH_INCLUDED_=1

#--------------------------------------------------------------------
# CONSTANTES ESTRITAS DA APLICAÇÃO (IMUTÁVEIS)
#
# Valores fixos de auditoria, assinaturas e comportamentos de sistema
# que nunca mudam durante o runtime, independente da configuração do host.
#--------------------------------------------------------------------
readonly PROGRAM_NAME="local-repo"
readonly PROGRAM_VERSION="0.2"
readonly PROGRAM_AUTHOR="Jean Felipe"

# Códigos de saída universais baseados nos padrões POSIX/SysExits
readonly EXIT_SUCCESS=0
readonly EXIT_FAILURE=1
readonly EXIT_INVALID_USAGE=2
readonly EXIT_ENV_MISSING=3
readonly EXIT_LOCK_FAILED=4

# Níveis de severidade de log, usados por log.sh para decidir o que
# deve (ou não) ser impresso com base na configuração LOG_LEVEL do host.
# Ordem crescente de severidade: DEBUG é o mais verboso, FATAL o mais crítico.
readonly LOG_LEVEL_DEBUG=0
readonly LOG_LEVEL_INFO=1
readonly LOG_LEVEL_WARN=2
readonly LOG_LEVEL_ERROR=3
readonly LOG_LEVEL_FATAL=4

# Backends homologados pelo core do sistema
readonly BACKEND_APT="apt"
readonly BACKEND_DNF="dnf"

# Caminhos padrão do sistema (Usados como Fallback de segurança)
readonly DEFAULT_CONFIG_DIR="/etc/local-repo"
readonly DEFAULT_CONFIG_FILE="${DEFAULT_CONFIG_DIR}/local-repo.conf"
readonly DEFAULT_REPO_BASE_DIR="/var/local-repo"

#--------------------------------------------------------------------
# VARIÁVEIS GLOBAIS DE ESTADO E CONFIGURAÇÃO (MUTÁVEIS)
#
# Escopo de memória global do framework. Elas nascem preenchidas com
# os valores de fallback (DEFAULT_*), mas o módulo config.sh poderá
# redefini-las dinamicamente se o administrador customizar o arquivo .conf.
#--------------------------------------------------------------------
CONFIG_FILE=""
REPO_BASE_DIR=""
POOL_DIR=""
LOG_FILE=""
LOCK_FILE=""
STATE_DIR=""
FILE_DESIRED_STATE=""
# CONTRATO DE FORMATO: qualquer código que escreva em FILE_KNOWN_STATE
# (packages.state) — hoje só 'init' o cria vazio, futuramente 'sync' —
# DEVE manter o arquivo estritamente ordenado (sort -u) e no formato
# canônico 'nome|arquitetura', idêntico ao produzido por
# validation_manifest_sanitize(). Comandos consultivos como diff.sh
# usam 'comm' para comparar esse arquivo contra outras listas, e
# 'comm' produz resultado incorreto (silenciosamente, sem erro) se
# qualquer um dos lados não estiver ordenado ou em formato compatível.
FILE_KNOWN_STATE=""
CURRENT_BACKEND=""
LOG_LEVEL=""

constants_initialize_globals() {
    #----------------------------------------------------------------
    # INICIALIZAÇÃO DE VARIÁVEIS COMPARTILHADAS
    #
    # Função responsável por realizar o bind inicial das variáveis
    # mutáveis globais a partir de seus valores padrões de fallback.
    #----------------------------------------------------------------
    CONFIG_FILE="${DEFAULT_CONFIG_FILE}"
    REPO_BASE_DIR="${DEFAULT_REPO_BASE_DIR}"

    # Caminhos derivados que dependem do diretório base do repositório
    POOL_DIR="${REPO_BASE_DIR}/pool"
    LOG_FILE="${REPO_BASE_DIR}/log/local-repo.log"
    LOCK_FILE="${REPO_BASE_DIR}/run/local-repo.lock"
    STATE_DIR="${REPO_BASE_DIR}/state"

    FILE_DESIRED_STATE="${STATE_DIR}/packages.list"
    FILE_KNOWN_STATE="${STATE_DIR}/packages.state"

	#------------------------------------------------------------
    # BACKEND NÃO É PRÉ-DEFINIDO AQUI
    #
    # Deixar CURRENT_BACKEND vazio no boot é o que permite que
    # backend_detect() (em backend.sh) rode sua heurística real de
    # autodetecção via 'command -v apt-get/dnf'. Se atribuíssemos um
    # valor padrão aqui, backend_detect() sempre encontraria a
    # variável já preenchida e nunca chegaria a checar o host de
    # fato — o que tornava a autodetecção código morto.
    # O único lugar que deve definir um valor definitivo é
    # config_load() (config explícita do admin) ou backend_load()
    # (resultado da própria detecção).
    #------------------------------------------------------------
    CURRENT_BACKEND=""

    # Nível de log padrão, sobrescrevível via LOG_LEVEL no .conf
    LOG_LEVEL="INFO"
}
