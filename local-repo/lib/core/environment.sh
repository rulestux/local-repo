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
# VALIDADOR DE SANIDADE OPERACIONAL DO AMBIENTE (SANDBOX GUARD)
#--------------------------------------------------------------------
[[ -n "${_ENVIRONMENT_SH_INCLUDED_}" ]] && return
_ENVIRONMENT_SH_INCLUDED_=1

environment_check_core() {
    #----------------------------------------------------------------
    # DESACOPLAMENTO DE INERAESTRUTURA X COMPONENTES DE DISTRO
    #
    # Este método valida estritamente os utilitários transversais e o
    # interpretador Bash. Ferramentas como 'dpkg' ou 'createrepo' foram
    # extraídas desta camada, pois pertencem à responsabilidade única
    # dos respectivos backends, mantendo a arquitetura limpa.
    #----------------------------------------------------------------
    log_debug "Initiating core infrastructure sanity checks..."

    # 1. Validação estrita da versão do Bash (Requer Bash 5.0+)
    if [[ -z "${BASH_VERSINFO[0]}" ]] || [[ "${BASH_VERSINFO[0]}" -lt 5 ]]; then
        log_fatal "Incompatible Bash version. This framework requires Bash 5.0 or superior."
        exit "${EXIT_ENV_MISSING}"
    fi

    # 2. Utilitários universais mínimos exigidos pelo núcleo da aplicação
    #    'fdupes' entra aqui (e não no backend) porque é usado pelo core
    #    em operações de deduplicação/auditoria da pool (verify, scan),
    #    e essas operações são as mesmas independentemente do backend
    #    (APT ou DNF) que estiver carregado.
    local core_commands=("awk" "grep" "sed" "cut" "sort" "find" "flock" "mount" "tar" "fdupes" "comm")
    local missing_commands=()

    for cmd in "${core_commands[@]}"; do
        if ! command -v "${cmd}" &> /dev/null; then
            missing_commands+=("${cmd}")
        fi
    done

    # Se houver ferramentas ausentes, interrompe a inicialização do ecossistema imediatamente
    if [[ ${#missing_commands[@]} -gt 0 ]]; then
        log_fatal "The following core system binaries are missing: ${missing_commands[*]}"
        log_fatal "Please install them before running ${PROGRAM_NAME}."
        exit "${EXIT_ENV_MISSING}"
    fi

    log_debug "Core environment validation successful. Infrastructure is safe."
}

environment_check_tui() {
    #----------------------------------------------------------------
    # VALIDAÇÃO DE SANIDADE EXCLUSIVA DA INTERFACE TUI
    #
    # Separada de environment_check_core() porque o 'dialog' só é
    # necessário para quem executa o wrapper local-repo-tui. Se essa
    # checagem estivesse dentro do bootstrap principal da CLI, um
    # administrador rodando apenas 'local-repo <comando>' num servidor
    # headless seria bloqueado por uma dependência que ele nunca usa —
    # contrariando o princípio de leveza/offline-first do projeto.
    # Esta função deve ser chamada pelo próprio dispatcher da TUI,
    # depois do bootstrap_run() da CLI já ter validado o núcleo.
    #----------------------------------------------------------------
    log_debug "Initiating TUI-specific sanity checks..."

    if ! command -v dialog &> /dev/null; then
        log_fatal "The 'dialog' package is required to run local-repo-tui, but it was not found."
        exit "${EXIT_ENV_MISSING}"
    fi

    log_debug "TUI environment validation successful."
}
