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

[[ -n "${_INIT_SH_INCLUDED_}" ]] && return
_INIT_SH_INCLUDED_=1

init_run() {
    #----------------------------------------------------------------
    # IMPLEMENTAÇÃO DO COMANDO DE INICIALIZAÇÃO DE WORKSPACE (INIT)
    #
    # Cria toda a topologia de diretórios isolados requisitados pela
    # especificação arquitetural (pool, log, run, state) e escreve
    # os arquivos de estado iniciais limpos se eles não existirem.
    #----------------------------------------------------------------
    log_info "Initializing a new declarative package repository workspace..."
    log_debug "Target repository base path: ${REPO_BASE_DIR}"

    # Lista contendo todas as subpastas obrigatórias do ecossistema
    local required_dirs=(
        "${REPO_BASE_DIR}/pool"
        "${REPO_BASE_DIR}/log"
        "${REPO_BASE_DIR}/run"
        "${REPO_BASE_DIR}/state"
    )

    # Criação iterativa e checagem de privilégios de escrita
    for dir in "${required_dirs[@]}"; do
        if ! validation_directory_writable "${dir}"; then
            log_error "Initialization aborted: Cannot converge structure for directory: ${dir}"
            return "${EXIT_FAILURE}"
        fi
    done

    # Resolução dinâmica e idempotente da arquitetura nativa do Host,
    # centralizada em util_host_architecture() para não divergir da
    # mesma lógica usada por validation_manifest_sanitize().
    local host_arch
    host_arch=$(util_host_architecture)

    #----------------------------------------------------------------
    # ESCRITA DO MANIFESTO INICIAL (PACKAGES.LIST)
    #
    # Se o arquivo não existir, gera um esqueleto didático documentado
    # demonstrando o novo padrão flexível com delimitadores de espaços,
    # quebras de linhas e herança automática de arquitetura via pipe.
    #----------------------------------------------------------------
    if [[ ! -f "${FILE_DESIRED_STATE}" ]]; then
        log_debug "Generating template for Desired State: ${FILE_DESIRED_STATE}"
        cat << EOF > "${FILE_DESIRED_STATE}"
# ===================================================================
# local-repo Desired State Package Manifest (packages.list)
# ===================================================================
# Define here the packages you want to be synchronized and available
# in your offline pool repository.
#
# Syntax Options:
#   1. Vertical layout (Columns): One package per line
#   2. Horizontal layout (Spaces): Multiple packages on the same line
#   3. Explicit Architecture: package_name|architecture
#
# Note: If architecture is omitted, the system defaults to the host
#       native architecture (${host_arch}).
# ===================================================================

# Core diagnostics utilities (Horizontal layout example)
tmux htop vim

# Custom architecture constraint (Explicit pipe example)
# curl|i386
# nginx|armhf
EOF
        log_info "Created standard declarative manifest file template at: ${FILE_DESIRED_STATE}"
    else
        log_warn "Manifest file 'packages.list' already exists. Preserving original layout."
    fi

    #----------------------------------------------------------------
    # CRIAÇÃO DO BANCO DE ESTADO CONHECIDO (PACKAGES.STATE)
    #
    # Inicializa um banco de dados em formato de texto plano limpo
    # indicando que nenhum pacote foi convergido fisicamente ainda.
    #----------------------------------------------------------------
    if [[ ! -f "${FILE_KNOWN_STATE}" ]]; then
        log_debug "Initializing empty Known State tracker: ${FILE_KNOWN_STATE}"
        touch "${FILE_KNOWN_STATE}" || {
            log_error "Failed to write database file: ${FILE_KNOWN_STATE}"
            return "${EXIT_FAILURE}"
        }
        log_info "Created empty known state database tracker at: ${FILE_KNOWN_STATE}"
    else
        log_debug "Database file 'packages.state' already present. Skipping creation."
    fi

    # Invoca o driver do backend dinâmico para gerar os arquivos de índices do repositório
    log_info "Requesting repository index metadata generation from dynamic backend driver..."
    backend_generate_metadata "${REPO_BASE_DIR}"

    log_info "Workspace successfully initialized and bound at '${REPO_BASE_DIR}'."
    return "${EXIT_SUCCESS}"
}
