# Especificação de Arquitetura e Design: local-repo
Versão: 0.2
Data de aprovação inicial: 05-07-2026
Última revisão: 22-08-2026
Autor: Jean Felipe
Licença: MIT
Status: Aprovado (revisão incremental)

---

## 1. Visão Geral do Projeto & Requisitos Não Funcionais

O utilitário `local-repo` é um gerenciador declarativo de repositórios locais de pacotes com abordagem *offline-first*, multiplataforma e implementado em GNU Bash. Ele foi projetado para atuar como um motor de convergência localizado que separa o que o administrador deseja (o Estado Desejado) do que a infraestrutura de armazenamento de fato contém (o Estado Conhecido e o Estado Real Físico).

O objetivo deste projeto é fornecer uma solução leve, portátil, transparente e resiliente para gerenciar pacotes de software localizados e suas árvores de dependências recursivas completas, sem depender de um daemon residente, servidores de banco de dados ou conectividade ativa com a internet durante as fases de instalação nos clientes.

### Pilares Arquiteturais Core
* **Offline-first:** Todos os fluxos críticos de resolução, auditoria, fatiamento de metadados e provisionamento funcionam estritamente sem uma conexão ativa com a internet.
* **Paradigma Declarativo:** Os usuários manipulam um arquivo de manifesto em texto plano simples que define *quais* pacotes são necessários. A lógica central calcula o desvio (*drift*) e converge as camadas físicas subjacentes.
* **Portabilidade Atômica:** O sistema isola-se completamente de dependências do host local no que diz respeito ao rastreamento de caminhos absolutos. Todo o layout de armazenamento pode ser migrado para mídias externas (ex: armazenamento em massa USB) ou caminhos alternativos sem quebras estruturais.
* **Coleta de Lixo Baseada em Metadados (Garbage Collector):** Os *payloads* binários são expurgados, combinados e avaliados com base na extração real dos cabeçalhos dos binários (`dpkg-deb` / `rpm`), eliminando correspondências frágeis por expressões regulares baseadas em nomes de arquivos.
* **Controle Explícito de Concorrência:** Descritores de arquivos de alta integridade e travas de kernel determinísticas (`flock`) isolam os processos e eliminam condições de corrida (*race conditions*) multiusuário ou multiprocesso durante as transições de estado.
* **Ausência de Instalador Dedicado:** O `local-repo` é autocontido e não exige nenhum script de instalação/provisionamento no host — clonar o repositório e conceder permissão de execução ao dispatcher (`chmod +x ./local-repo`) já é suficiente para uso completo. Isso é uma decisão deliberada de simplicidade: evita manter um artefato adicional (`install.sh`) só para copiar arquivos que já funcionam a partir de onde estão.

### Fora de Escopo
* Espelhamento completo (*full-mirroring*) de repositórios oficiais das distribuições.
* Servidores embutidos de hospedagem HTTP/FTP/Daemon.
* Camadas de autenticação de usuário ou controle de acesso.
* Servidores de bancos de dados relacionais SQL/NoSQL.
* Scripts de instalação/desinstalação do próprio `local-repo` no host (ver "Ausência de Instalador Dedicado" acima).

---

## 2. Layout de Diretórios e Hierarquia do Sistema de Arquivos

O *framework* impõe uma divisão rigorosa entre o lançador de scripts voltado para o usuário (Dispatcher), as bibliotecas de infraestrutura central (`lib/core/`), as interfaces abstratas do gerenciador de pacotes (`lib/backend/`) e os subcomandos declarativos (`lib/commands/`).

### Árvore de Diretórios do Repositório de Origem

```text
local-repo/
├── local-repo                  # CLI Dispatcher & Ponto de Entrada do Script
├── local-repo-tui              # Wrapper da Interface TUI (Consome o binário dialog)
│
├── lib/                        # Motor Central do Framework & Subsistemas
│   │
│   ├── core/
│   │   ├── bootstrap.sh        # Carregador determinístico de componentes
│   │   ├── config.sh           # Validador de configuração do Host
│   │   ├── constants.sh        # Globais imutáveis do sistema
│   │   ├── environment.sh      # Auditor de dependências binárias de baixo nível do host
│   │   ├── errors.sh           # Manipuladores de capturas (traps) e wrappers de exceção
│   │   ├── hooks.sh            # Gatilhos extensíveis de etapas do ciclo de vida (stubs)
│   │   ├── lock.sh             # Manipuladores de aquisição de trava de concorrência
│   │   ├── log.sh              # Registro de log estruturado e impressor de saída
│   │   └── util.sh             # Primitivas puramente funcionais de cruzamento de subsistemas
│   │
│   ├── api/
│   │   └── backend-api.sh      # Especificação de interface concreta e docs de contrato
│   │
│   ├── backend/
│   │   ├── backend.sh          # Descoberta do gerenciador de pacotes e injeção dinâmica em runtime
│   │   ├── apt.sh              # Driver de pool concreto para Debian/Ubuntu (driver .deb)
│   │   └── dnf.sh              # Driver de pool concreto para Red Hat/Fedora (driver .rpm - v1.0)
│   │
│   └── commands/
│       ├── init.sh             # Assistente de provisionamento e lógica de bootstrap do host
│       ├── download.sh         # Injeção de estado puramente declarativa (Apenas Repo)
│       ├── import.sh           # Import (`--from-iso`, `--from-directory`, `--from-tar`)   
│       ├── install.sh          # Injeção de estado declarativa + Instalação no Host de UM pacote
│       ├── remove.sh           # Lógica de desinstalação apenas no host
│       ├── purge.sh            # Remoção física definitiva de pacotes da pool de armazenamento
│       ├── sync.sh             # Motor de divergência (Calcula List vs State)
│       ├── scan.sh             # Recuperação de desastres (Reconstrói o State a partir da Pool)
│       ├── verify.sh           # Auditor profundo de integridade estrutural e checksum (fsck)
│       ├── diff.sh             # Matriz passiva de detecção de desvio em três camadas
│       ├── update.sh           # Calculador diferencial de índices upstream (tolerante a falha de rede)
│       ├── converge.sh         # Convergência da pool local com as versões mais recentes upstream
│       ├── upgrade.sh          # Orquestrador update+converge + reinstalação seletiva no host
│       ├── prune.sh            # Expurgador interativo de órfãos
│       ├── search.sh           # Utilitário de busca no repositório local
│       ├── info.sh             # Descritor de metadados de pacotes
│       ├── stats.sh            # Painel de métricas operacionais
│       ├── export.sh           # Export (backup tar.gz: `--to-tar`)
│       └── clean.sh            # Limpeza de arquivos transitórios de runtime e estados de trava
│
├── tui/                        # Telas de Diálogo da Interface de Usuário de Terminal
│   ├── common.sh               # Funções e widgets reutilizáveis de layout do dialog
│   ├── menu.sh                 # Loop seletor visual principal da aplicação
│   └── ...                     # Arquivos de mapeamento de UI específicos de comandos
│
├── LICENSE                     # Descritor da Licença MIT
└── README.md                   # Visão geral administrativa e início rápido

```

> **Nota de Design — sem `install.sh`/`uninstall.sh` na raiz:** versões anteriores desta especificação prescreviam scripts dedicados de instalação/desinstalação do próprio `local-repo` no host. Essa previsão foi removida: o projeto não precisa de nenhuma etapa de instalação além de `git clone` + `chmod +x ./local-repo`. Não confundir com `lib/commands/install.sh` — este é um **comando do próprio `local-repo`** (`local-repo install <pacote>`), responsável por instalar *um pacote da pool local* no sistema hospedeiro; ele nunca teve relação com a instalação da ferramenta em si.

### Infraestrutura de Armazenamento em Runtime no Host

Para cumprir com o Filesystem Hierarchy Standard (FHS), as configurações do host residem dentro do espaço global e imutável de configuração do sistema, enquanto logs voláteis, metadados transacionais dinâmicos de arquivos multiusuário, travas e pacotes residem estritamente encapsulados dentro do espaço de armazenamento portátil do repositório definido em `${REPO_BASE_DIR}`.

```text
/etc/local-repo/local-repo.conf   # Arquivo de configuração estático global do host

[REPO_BASE_DIR]/                  # Caminho do espaço de trabalho dinâmico do repo (Fixo ou USB)
├── pool/                         # [ESTADO REAL] Árvore de diretórios física dos pacotes binários
│   ├── amd64/                    # Pool de armazenamento para arquitetura 64-bits (.deb ou .rpm)
│   └── i386/                     # Pool de armazenamento para arquitetura 32-bits (.deb ou .rpm)
│
├── run/
│   └── local-repo.lock           # Descritor de arquivo de mutex ativo em nível de processo (flock)
│
├── log/
│   └── local-repo.log            # Arquivo de log persistente e estruturado
│
└── state/
    ├── packages.list             # [ESTADO DESEJADO] Manifesto declarativo editável pelo usuário
    └── packages.state            # [ESTADO CONHECIDO] Base de dados delimitada por pipes gerada pela pipeline

```

---

## 3. Modelos de Dados e Camada de Separação de Estados

A integridade do `local-repo` depende de três estados de dados estruturais distintos:

```text
     [ESTADO DESEJADO]                        [ESTADO CONHECIDO]                  [ESTADO REAL]
[REPO_BASE_DIR]/state/packages.list  →  [REPO_BASE_DIR]/state/packages.state  →  [REPO_BASE_DIR]/pool/
 (Pacotes Mandatados pelo Admin)          (Inventário Rastreado pelo Sistema)    (Arquivos Físicos de Pacotes)

```

### A. Estado Desejado (`packages.list`)

Um arquivo de texto plano, editável pelo usuário ou administrador, que lista os requisitos alvos, ideal para controle de versão (Git).

Para garantir resiliência contra erros manuais de preenchimento ou inconsistências de layout, o interpretador do sistema adota as seguintes regras de normalização:
	* **Agnosticismo de Layout:** O sistema processa as definições nativamente tanto em formato de lista (vertical/colunar) quanto em linha (horizontal). Múltiplos espaços vazios, tabulações ou quebras de linha redundantes são tratados estritamente como delimitadores de separação de tokens.
	* **Fallback Automático de Arquitetura:** Os pacotes podem ser declarados no formato estrito `<nome_do_pacote>|<arquitetura>` ou de forma simplificada apenas como `<nome_do_pacote>`. Caso a arquitetura seja omitida, o motor do sistema resolve e injeta automaticamente a arquitetura nativa do host no qual o `local-repo` está sendo executado.

```text
curl|amd64
git|amd64
wine|amd64
wine|i386

```
	*  As seguintes entradas assumirão automaticamente a arquitetura nativa do sistema:

```text
tmux
htop
```

### B. Estado Conhecido (`packages.state`)

Uma base de dados automatizada, delimitada por pipes, que rastreia os pacotes registrados pelo motor interno. Este é um artefato derivado e pode ser destruído e regenerado com segurança sob demanda usando o comando `scan`.

```text
curl|8.16.0|amd64|manual|2026-07-04
git|2.51.0|amd64|manual|2026-07-04
libssl3|3.0.13|amd64|dependency|2026-07-04
wine|10.0|i386|manual|2026-07-04

```

### C. Estado Real (`pool/`)

Os pacotes binários reais armazenados dentro do diretório `pool/` e os ativos de índice (`Packages.gz` ou `repomd.xml`). Este representa a única fonte da verdade dos arquivos físicos.

---

## 4. Bootstrapping, Fluxo de Execução & Arquitetura do Dispatcher

### O Motor Dispatcher (`local-repo`)

O lançador executável raiz permanece incrivelmente compacto. Ele é responsável por invocar o `bootstrap.sh` uma única vez, verificar dependências, avaliar os limites do sistema, passar as flags recebidas para a camada de configuração dinâmica e executar os comandos dos módulos via análise de argumentos (*arg-parsing*).

```text
[Sequência de Execução]
main() → bootstrap.sh → environment.sh → parse_arguments() → config.sh → validation.sh → backend.sh → dispatch()

```

### O Bootstrapper (`lib/core/bootstrap.sh`)

O bootstrapper mapeia os componentes operacionais do framework avaliando os caminhos e importando as dependências em ordem estritamente topológica. Nenhum submódulo do core manipula operações diretas de `source`.

```text
[Ciclo de Vida de Importação do Bootstrap]
bootstrap() 
   ├── locate_project_root()
   ├── carregar constants.sh
   ├── carregar util.sh
   ├── carregar errors.sh
   ├── carregar log.sh
   ├── carregar config.sh
   ├── carregar validation.sh
   ├── carregar environment.sh
   ├── carregar lock.sh
   ├── carregar backend-api.sh
   ├── carregar backend.sh
   └── carregar commands/*.sh

```

---

## 5. Especificações dos Subsistemas

### Concorrência e Travas (`lib/core/lock.sh`)

Para proteger os arquivos internos contra corrupção transacional entre shells paralelas, todas as operações de escrita exigem uma trava explícita de descritor de arquivo usando abstrações de `flock` em nível de kernel sobre o caminho de trava mutável.

```bash
# Estratégia de implementação da trava central
exec 9>"${REPO_BASE_DIR}/run/local-repo.lock"
if ! flock -n 9; then
    echo "Error: Another instance of local-repo is performing a write operation." >&2
    exit 1
fi

```

*Nota de Design:* Como o diretório de trava reside dentro da estrutura de armazenamento físico (`${REPO_BASE_DIR}/run`), as travas persistem como arquivos reais após desligamentos inesperados. No entanto, o kernel do Linux gerencia naturalmente a limpeza de travas obsoletas ao derrubar os IDs de processo correspondentes. Remoções manuais de arquivos `local-repo.lock` são estritamente desnecessárias.

### Verificação de Ambiente de Baixo Nível (`lib/core/environment.sh`)

A rotina de inicialização baseia-se em uma ferramenta de verificação rígida do sistema, checando utilitários fundamentais (`awk`, `grep`, `sed`, `cut`, `fdupes`, `flock`, `dialog`) junto aos binários de backend (`dpkg`, `apt-cache`, `createrepo_c`, `rpm`) com base no perfil ativo do host.

### Matriz de Abstração de Erros (`lib/core/errors.sh`)

As falhas do sistema passam por wrappers uniformes de manipulação de encerramento:

* `fatal()`: Despacha um evento de nível de erro para os logs, imprime os dados de rastreamento (*trace data*) na saída de erro padrão, libera o registro de trava e executa as sequências de saída.
* `assert()`: Testa as suposições da matriz de condições e interrompe os ramos de execução instantaneamente caso as expressões falhem.

### Limite Abstrato do Backend (`lib/backend/backend.sh` & `lib/api/backend-api.sh`)

A aplicação implementa padrões de Interface Orientada a Objetos simulando stubs abstratos que se conectam a drivers específicos de distribuições com base nos resultados da descoberta automática.

```bash
# Exemplo de implementação dentro de lib/api/backend-api.sh
backend_package_download() {
    # Stub placeholder que impõe a necessidade de overrides programáticos
    fatal "API Error: backend_package_download has not been implemented by the loaded driver."
}

```

Drivers concretos (como `lib/backend/apt.sh` ou `lib/backend/dnf.sh`) devem sobrescrever cada padrão de execução central usando um ecossistema de nomes (*namespacing*) estrito e previsível:

```text
[Chamada do Motor Central] ──> backend_package_download() ──> Chama o driver carregado [apt.sh] ──> apt_package_download()

```

---

## 6. Especificações de Fluxo dos Comandos Funcionais

Os comandos devem seguir pipelines estruturais explícitas para manter a separação de conceitos.

```text
[Hierarquias de Chamada de Comandos]

1. download <pacote>
   └── chama download_command() ──> registra a intenção em packages.list ──> chama sync_command()

2. install <pacote>
   └── chama install_command() ──> chama download_command() ──> chama backend_install_from_local_repo()

3. converge
   └── chama converge_command() ──> compara cada pacote físico da pool/ com sua versão candidata upstream
       ──> rebaixa as versões desatualizadas via motor de download recursivo ──> remove os artefatos obsoletos
           substituídos (GC embutido, sem worker separado) ──> reconstrói os índices se algo mudou

4. upgrade
   └── chama upgrade_command() ──> chama update_command() ──> chama converge_command()
       ──> varre a interseção entre pool/ e pacotes já instalados no host ──> lista as pendências
           ──> aguarda confirmação (--yes por padrão, --no para pré-visualização)
               ──> chama backend_install_from_local_repo() para cada pendência confirmada

```

### Pipelines Detalhadas dos Comandos

#### `init`

* Gera os caminhos de infraestrutura sob `/etc/local-repo/` e `${REPO_BASE_DIR}`.
* Aceita opcionalmente um caminho de diretório como argumento posicional (`init <diretório>`); se informado, `${REPO_BASE_DIR}` passa a apontar para esse caminho (criando-o caso não exista) e a escolha é persistida em `/etc/local-repo/local-repo.conf`, tornando-se o padrão de todas as execuções seguintes — útil para apontar o repositório para um dispositivo removível (ex: pen drive). Sem argumento, assume-se o padrão `/var/local-repo`.
* Mapeia as métricas do dispositivo de bloco subjacente (UUID, rótulos de sistema de arquivos, vetores de conexão).
* Provisiona os ativos base realizando a montagem em loop (*loop-mount*) de mídias de armazenamento ou mapeando espelhos de sistemas localizados nativos.

#### `download <pacote>`

* Insere os tokens de configuração estrutural em `packages.list` (Estado Desejado).
* Dispara a sequência do comando `sync` para computar as diferenças.
* Intercepta as matrizes de download de forma segura usando espaços de isolamento transitórios (ex: `/tmp/local-repo-temp`), garantindo que as estruturas de cache locais (`/var/cache/apt/`) permaneçam limpas.
* Atualiza o `packages.state` e reconstrói os índices físicos (`Packages.gz`).

#### `install <pacote>`

* Executa a sequência local de `download` para garantir que a pool de armazenamento possua o ativo.
* Dispara as instalações no sistema host forçando os motores nativos a operarem a partir do espaço do diretório físico.

#### `sync`

* Analisa as diferenças entre `packages.list` e `packages.state`.
* Busca quaisquer arquivos ausentes utilizando operações de download incremental.

#### `import`

* Fornece um mecanismo alternativo de provisionamento inicial sem depender de conexões upstream ativas.
* Monta dinamicamente imagens em loop (mídias `.iso`) ou varre estruturas locais de diretórios e arquivos compactados (`tar.gz`).
* Extrai metadados binários em lote das fontes descobertas para registrar automaticamente as dependências no Estado Conhecido (`packages.state`), preservando a integridade física dos payloads na `pool/`.

#### `export`

* Executa o empacotamento atômico e arquivamento unificado do repositório local.
* Consolida toda a estrutura de estados (`packages.list`, `packages.state`), logs e a `pool/` binária em um único snapshot compactado nativamente via `tar.gz`.
* Atua como a primitiva oficial de backup offline do ecossistema, garantindo portabilidade entre hosts isolados.

#### `scan`

* Varre os caminhos do sistema de arquivos local sob `pool/`.
* Extrai informações estruturais diretamente dos cabeçalhos dos pacotes binários alvo.
* Sobrescreve e corrige o arquivo de estado `packages.state`.
* *Nota de Design:* O `scan` nunca modifica o `packages.list`. Se surgirem divergências, o usuário é alertado e solicitado a executar o `sync`.

#### `verify`

* Atua como uma ferramenta de verificação direcionada ao sistema de arquivos (`fsck`).
* Cruza a presença dos arquivos com os parâmetros dos metadados, avalia as assinaturas de rastreamento, checa os hashes de checksum criptográficos e relata corrupções de payload.

#### `diff`

* Executa comparações entre todos os três estados, renderizando matrizes de delta detalhadas por meio de indicadores intuitivos (`+` para dependências ausentes, `!` para órfãos locais não gerenciados).

#### `update`

* Atualiza o cache de índices de pacotes upstream contra os repositórios oficialmente configurados no host (equivalente a `apt-get update`/`dnf check-update`).
* Tolerante a indisponibilidade de rede: se o refresh do cache falhar (sem internet, repositório oficial fora do ar), o comando **não aborta** — prossegue com o último cache local já disponível, sinalizando isso com um aviso, e ainda assim executa o cálculo diferencial abaixo.
* Atua como o calculador diferencial do ecossistema: cruza cada pacote fisicamente presente na `pool/` com sua versão candidata upstream (fresca ou cacheada), imprimindo o subconjunto desatualizado.
* Nunca falha a cadeia de comandos que o envolve por indisponibilidade de rede — um upstream inacessível é tratado como "prossiga com o que há disponível", não como uma condição de erro.

#### `converge`

* Atua exclusivamente sobre a `pool/` local — nunca modifica o sistema hospedeiro. É o herdeiro direto do algoritmo originalmente desenhado para o comando `upgrade`, antes deste ser redefinido com a semântica tradicional de gerenciadores de pacote (ver `upgrade` abaixo).
* Para cada pacote fisicamente presente na `pool/`, compara sua versão com a candidata upstream e, havendo divergência, baixa novamente a versão mais recente através do motor de download recursivo do backend, substituindo o arquivo `.deb`/`.rpm` obsoleto na `pool/` (etapa de GC embutida — não existe um `gc.sh` separado; a coleta de lixo das versões substituídas vive embutida dentro de `converge.sh`).
* Reconstrói os índices de metadados do repositório somente se pelo menos um pacote tiver sido de fato convergido.

#### `upgrade`

* Orquestra `update` (garante que o cache/comparação estejam o mais atualizados possível) seguido de `converge` (garante que a `pool/` já contenha as versões mais recentes disponíveis) antes de avaliar qualquer coisa no host — mesma composição que `install` já faz com `download`.
* Varre a interseção entre a `pool/` e os pacotes já instalados no sistema hospedeiro, comparando a versão instalada com a versão disponível na pool. Pacotes presentes na pool mas nunca instalados no host ficam fora do escopo deste comando — esse é o papel do `install`.
* Lista de forma transparente cada pendência encontrada (nome do pacote, versão instalada, versão disponível na pool).
* Aceita confirmação via `-y`/`--yes`/`-Y`/`--Yes`, que também é o comportamento padrão mesmo sem nenhuma flag informada — mantém o comando operável em automação/cron sem exigir flag explícita — ou `-n`/`--no`, que computa e lista as pendências sem instalar nada no host (modo de pré-visualização).
* Reinstala no host, a partir exclusivamente da `pool/` local (nunca da rede diretamente), cada pacote confirmado.

---

## 7. Design Arquitetural da Interface de Usuário de Terminal (Anexo A)

O binário `local-repo-tui` serve como um wrapper interativo em torno das operações primárias da CLI. Ele mapeia as variáveis de execução para componentes interativos usando o motor nativo do sistema `dialog`.

### Arquitetura Visual e Fluxo de Estados

* **Operação Desacoplada:** O componente TUI não contém regras de negócio centrais ou de rastreamento de pacotes. Ele executa a ferramenta CLI de backend, captura os códigos de retorno e streams, e os traduz em janelas de diálogo estilizadas.
* **Contexto de Execução:** O caminho de execução da TUI depende de direitos de usuário administrativo (`sudo local-repo-tui`) para interagir com as configurações do host e com as estruturas de diretórios de armazenamento centrais.

### Mapeamento de Componentes da Interface Mestra

1. **Fase de Bootstrapping (tela `init`):** Avalia os perfis de configurações do host. Se ausentes, utiliza componentes padrão `--yesno` para lançar as sequências de configuração. Um componente `--inputbox`/`--fselect` permite ao administrador escolher um diretório customizado para `${REPO_BASE_DIR}` (equivalente ao argumento posicional `init <diretório>` da CLI), inclusive apontando para dispositivos removíveis. O mapeamento de dispositivos roda dentro de componentes `--menu` sob medida, e os loops de coleta de `.iso` brutos rodam através de widgets de diálogo de navegação alvo (`--fselect`).
2. **Grade de Controle da Aplicação (componente `--menu`):**

```text
  ┌─────────────────────── Local-Repo Manager ─────────────────────────┐
  │                                                                    │
  │  Select the action you want to perform on the repository:          │
  │                                                                    │
  │     1 Download Package to Repository (Add to Desired State Only)   │
  │     2 Install Package on Host System (Add to State & Provision)    │
  │     3 Remove Package from Host System (Keep Package in Repo)       │
  │     4 Purge Package Completely from Repository (Delete Files)      │
  │     5 Check for Updates on Upstream Mirrors (Update)               │
  │     6 Refresh Pool with Latest Upstream Versions (Converge)        │
  │     7 Upgrade Installed Host Packages (Upgrade)                    │
  │     8 Reconcile Repository with Package List (Sync)                │
  │     9 Clean Up Orphan Packages Outside List (Prune)                │
  │    10 Rebuild States from Physical Files (Scan)                    │
  │    11 Audit Physical Integrity and Checksums (Verify)              │
  │    12 Show Configuration and Disk Drifts (Diff)                    │
  │    13 View Statistics Dashboard (Stats)                            │
  │    14 Manage State Database Files (List/State)                     │
  │    15 Import Repository from External Source (ISO/Dir/Tar)         │
  │    16 Export Repository Snapshot to Backup (Tar)                   │
  │    17 Exit                                                         │
  │                                                                    │
  ├────────────────────────────────────────────────────────────────────┤
  │                     <  Select  >    <  Cancel  >                   │
  └────────────────────────────────────────────────────────────────────┘

```

*Nota de Design:* O item 8 foi rotulado "Reconcile" (e não "Converge") deliberadamente, para não colidir com o comando dedicado `converge` (item 6) — antes da introdução deste último, "converge" era usado de forma genérica para descrever o que o `sync` faz; agora que existe um comando homônimo com semântica própria (convergência da pool contra o upstream), o rótulo do `sync` precisou ser desambiguado.

3. **Rastreadores de Progresso Ativos:** Tarefas que escalam com base no tamanho dos volumes utilizam widgets visuais de rastreamento de progresso (`--gauge`) alimentados por pipelines de dados, ou saem para terminais interativos para preservar a legibilidade do stdout. A confirmação do `upgrade` (item 7) é mapeada para um componente `--yesno` nativo, espelhando o comportamento `-y`/`-n` da CLI.
4. **Telas de Relatório:** Tabelas de dados geradas via rotinas de auditoria (`verify`, `diff`, `stats`) são renderizadas dentro de componentes visualizadores de texto navegáveis (`--textbox`).

---

## 8. Política Padrão de Idioma e Localização

Para tornar o sistema altamente mantível para revisões internas de código e escalável para a comunidade open-source global, o desenvolvimento segue uma política de dois níveis de idioma:

### Lógica do Código do Script e Espaço de Runtime (Apenas Inglês)

* **Estrutura do Código-Fonte:** Definições de variáveis, funções procedimentais, rotinas de execução, blocos de lógica e arquiteturas de banco de dados são escritos em **Inglês**.
* **Saída Padrão da Interface:** Strings de erro, leituras informativas, entradas de log, avisos interativos e menus da TUI são entregues em **Inglês**.

### Documentação do Desenvolvedor e Espaço de Comentários do Código (Apenas Português)

* **Observações Internas:** Comentários no código que explicam blocos de lógica, decisões estruturais ou casos de borda (*edge cases*) utilizam o **Português**.
* **Espaço de Colaboração:** Atualizações iterativas de desenvolvimento, relatórios de gerenciamento de projeto e abertura de chamados/tickets utilizam o **Português**.

---

## 9. Fases de Implementação & Cronograma de Engenharia

```text
┌────────────────────────────────────────────────────────────────────────┐
│ FASE 1: BOOTSTRAP DO FRAMEWORK                                         │
│ Alvo: local-repo, bootstrap.sh, constants.sh, util.sh, log.sh, env.sh  │
│ Status: Concluído                                                      │
└───────────────────────────────────┬────────────────────────────────────┘
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│ FASE 2: INFRAESTRUTURA CENTRAL E TRAVAS (CORE)                         │
│ Alvo: lock.sh, errors.sh, config.sh, validation.sh                     │
│ Status: Concluído                                                      │
└───────────────────────────────────┬────────────────────────────────────┘
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│ FASE 3: INTERFACES ABSTRATAS DOS DRIVERS DE REPOSITÓRIO                │
│ Alvo: backend-api.sh, backend.sh, apt.sh                                │
│ Status: Concluído (backend APT); dnf.sh permanece planejado            │
└───────────────────────────────────┬────────────────────────────────────┘
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│ FASE 4: ESQUELETOS ESTRUTURAIS DA PIPELINE DE COMANDOS                 │
│ Alvo: import.sh, export.sh (esqueletos + assinaturas de contrato)      │
│ Status: Concluído                                                      │
└───────────────────────────────────┬────────────────────────────────────┘
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│ FASE 5: PROVISIONAMENTO E DETECÇÃO DE DESVIO                           │
│ Alvo: init.sh, diff.sh (implementação real e completa)                 │
│ Status: Concluído                                                      │
└───────────────────────────────────┬────────────────────────────────────┘
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│ FASE 6: CONVERGÊNCIA E PROVISIONAMENTO DO HOST                         │
│ Alvo: sync.sh, download.sh, install.sh                                 │
│ Status: Concluído                                                      │
└───────────────────────────────────┬────────────────────────────────────┘
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│ FASE 7: CICLO DE ATUALIZAÇÃO (UPSTREAM → POOL → HOST)                  │
│ Alvo: update.sh, converge.sh, upgrade.sh                                │
│ Status: Concluído                                                      │
└───────────────────────────────────┬────────────────────────────────────┘
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│ FASE 8: MANUTENÇÃO, AUDITORIA E CONSULTA                               │
│ Alvo: remove.sh, purge.sh, prune.sh, scan.sh, verify.sh, search.sh,    │
│        info.sh, stats.sh, clean.sh                                     │
│ Status: Planejado (interface pode mudar)                                │
└───────────────────────────────────┬────────────────────────────────────┘
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│ FASE 9: EXTENSÕES DE PLATAFORMA                                        │
│ Alvo: backend DNF (dnf.sh), interface em modo texto (local-repo-tui)   │
│ Status: Planejado                                                       │
└────────────────────────────────────────────────────────────────────────┘

```
