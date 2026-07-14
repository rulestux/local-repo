# Sourced do dispatcher local-repo - Não executar diretamente

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
# MECANISMO DE IDEMPOTÊNCIA DO BOOTSTRAP
#
# Garante que as rotinas de carregamento e as funções do bootstrap
# não sejam redefinidas caso o script seja invocado repetidas vezes
# dentro do mesmo subshell ou por carregamentos cruzados.
#--------------------------------------------------------------------
[[ -n "${_BOOTSTRAP_SH_INCLUDED_}" ]] && return
_BOOTSTRAP_SH_INCLUDED_=1

# Variável de escopo global que armazena a raiz absoluta do projeto.
# Será inicializada dinamicamente pela função fundamental de descoberta.
PROJECT_ROOT=""

_bootstrap_find_root() {
    #----------------------------------------------------------------
    # AUTODESCOBERTA E INDEPENDÊNCIA DE DISPATCHER
    #
    # Resolve o caminho absoluto da raiz do projeto a partir do local
    # físico deste arquivo bootstrap.sh. Como este arquivo reside em
    # 'lib/core/', subir dois níveis nos dá a raiz exata, permitindo
    # que qualquer outro ponto de entrada (testes, TUI, CLI) inicialize
    # o framework de forma idêntica.
    #----------------------------------------------------------------
    local source_dir
    source_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PROJECT_ROOT="$(cd "${source_dir}/../../" && pwd)"
}

_bootstrap_source_module() {
    #----------------------------------------------------------------
    # SISTEMA DE CARREGAMENTO SEGURO E CENTRALIZADO (DRY)
    #
    # Modificado sutilmente para aceitar uma subpasta opcional através
    # do parâmetro $1. Caso omitido, assume por padrão "core". Isso
    # unifica a carga de 'core/log.sh' e 'backend/backend.sh' sob a
    # mesma engine protetora de checagem de integridade de arquivos.
    #----------------------------------------------------------------
    local category="$1"
    local module_name="$2"
    local target_file="${PROJECT_ROOT}/lib/${category}/${module_name}.sh"

    if [[ -f "${target_file}" ]]; then
        source "${target_file}"
    else
        echo ":: [FATAL] Critical architecture component missing: lib/${category}/${module_name}.sh" >&2
        exit 1
    fi
}

bootstrap_run() {
    #----------------------------------------------------------------
    # ORQUESTRAÇÃO DO CICLO DE VIDA (ORCHESTRATOR)
    #
    # Executa a sequência exata de inicialização do ecossistema.
    # A ordem importa: constantes preenchem fallbacks, logs dão voz
    # ao sistema, utilitários estendem capacidades e o ambiente valida
    # o host antes de qualquer tomada de decisão destrutiva.
    #----------------------------------------------------------------

    # 1. Descobre a raiz do projeto e estabelece os caminhos base
    _bootstrap_find_root

    # 2. Carrega sequencialmente os módulos através do gerenciador modular
    # Passamos explicitamente a categoria "core" para manter a clareza didática.
    _bootstrap_source_module "core" "constants"
    _bootstrap_source_module "core" "util"
    _bootstrap_source_module "core" "log"
    _bootstrap_source_module "core" "errors"
    _bootstrap_source_module "core" "lock"
    _bootstrap_source_module "core" "validation"
    _bootstrap_source_module "core" "config"
    _bootstrap_source_module "core" "environment"

    # Carrega o gerenciador de abstração de backends usando a mesma infraestrutura protegida
    _bootstrap_source_module "backend" "backend"

    # 3. Inicializa o subsistema de logs o mais cedo possível (Verificação de TTY para cores)
    log_initialize

    # 4. Inicializa os estados mutáveis globais baseados nas constantes
    constants_initialize_globals

    log_debug "Core architecture modules successfully loaded by Bootstrap."

    # 5. Ativa imediatamente a interceptação e o gerenciamento de erros globais
    errors_register_traps

    # 6. Carrega o arquivo de configuração e atualiza as variáveis globais se necessário
    config_load

    # 7. Executa a varredura e validação de sanidade do ambiente operacional host
    # (Validar o ambiente sempre deve vir antes de qualquer subsistema
    # que dependa de binários externos específicos.)
    environment_check_core

    # 8. Garante a proteção de exclusão mútua contra execuções paralelas
    lock_acquire

    log_debug "All core engine modules from Phase 2 successfully initialized and bounded."
    # 9. Inicializa a detecção e carga do gerenciador nativo
    backend_load

    # 10. Valida se o diretório base operacional está disponível e com escrita ativa
    if ! validation_directory_writable "${REPO_BASE_DIR}"; then
        log_fatal "Storage base workspace convergence failed. Check system permissions."
        exit "${EXIT_FAILURE}"
    fi

    # 11. Barreira de entrada: Validação elementar de argumentos passados via CLI
    if [[ $# -lt 1 ]]; then
        echo "Usage: ${PROGRAM_NAME} <command> [args]" >&2
        echo "Try '${PROGRAM_NAME} --help' for more information." >&2
        # Usa o código de saída específico para uso incorreto da CLI
        # (2), em vez do genérico EXIT_FAILURE (1), mantendo a
        # convenção de sysexits já declarada em constants.sh.
        exit "${EXIT_INVALID_USAGE}"
    fi

    local command="$1"
    shift

    # Helper privado de carregamento seguro para a categoria 'commands'.
    # Precisa estar definida ANTES do 'case' que a utiliza logo abaixo —
    # em Bash, uma função aninhada só passa a existir no momento em que
    # a linha que a declara é efetivamente executada, não antes.
    _bootstrap_source_command() {
        local cmd_name="$1"
        local target_cmd_file="${PROJECT_ROOT}/lib/commands/${cmd_name}.sh"
        if [[ -f "${target_cmd_file}" ]]; then
            source "${target_cmd_file}"
        else
            log_fatal "Command implementation file missing: lib/commands/${cmd_name}.sh"
            exit "${EXIT_FAILURE}"
        fi
    }

    log_info "Executing system dispatcher for command: '${command}'"

    #------------------------------------------------------------
    # ROTEADOR POLIMÓRFICO DE COMANDOS
    #
    # Cada comando de negócio (lib/commands/*.sh) só usa 'return'
    # internamente — nunca 'exit'. É este 'case', dentro do
    # orquestrador central, o único ponto autorizado a converter
    # esse código de retorno em um 'exit' de processo de verdade.
    #------------------------------------------------------------
    case "${command}" in
        init)
            _bootstrap_source_command "init"
            init_run "$@" || exit "$?"
            ;;
        import)
            _bootstrap_source_command "import"
            import_run "$@" || exit "$?"
            ;;
        export)
            _bootstrap_source_command "export"
            export_run "$@" || exit "$?"
            ;;
        diff)
            _bootstrap_source_command "diff"
            diff_run "$@" || exit "$?"
            ;;
        sync)
            _bootstrap_source_command "sync"
            sync_run "$@" || exit "$?"
            ;;
        download)
            _bootstrap_source_command "download"
            download_run "$@" || exit "$?"
            ;;
        install)
            _bootstrap_source_command "install"
            install_run "$@" || exit "$?"
            ;;
        stats|verify)
            log_warn "Command '${command}' is recognized but its pipeline stub is sleeping."
            ;;
        *)
            log_error "Unknown command: '${command}'"
            echo "Try '${PROGRAM_NAME} --help' for available commands." >&2
            exit "${EXIT_INVALID_USAGE}"
            ;;
    esac

    log_info "Application life cycle finished successfully."
    exit "${EXIT_SUCCESS}"
}
