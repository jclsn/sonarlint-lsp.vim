# sonarlint-lsp.vim

This plugin extends [yegappan/lsp](https://github.com/yegappan/lsp) to work with 
[sonarlint-ls](https://www.sonarsource.com/products/sonarlint/).

sonarlint-ls only uses plain LSP for document synchronization, diagnostics and code
actions. Everything else goes through `sonarlint/*` messages written for the
VS Code extension.

This plugin translates them into what yegappan/lsp understands.

## Features

- Maps the Sonar impact (Blocker/High, Medium, Low, Info) to LSP Error, Warning,
- Information and Hint, so the sign column shows meaningful signs.
- Security vulnerabilities are shown as diagnostics
- Rule descriptions open in a popup styled like the LSP hover popup
- Quickfixes are offered through `:LspCodeAction`
- Client-side command support

## Requirements

- Vim 9.1 or later with `+vim9script`
- [yegappan/lsp](https://github.com/yegappan/lsp)
- sonarlint-ls, the [SonarLint language server](https://github.com/SonarSource/sonarlint-language-server),
  with its analyzer jars.
- Java 17 or later to run sonarlint-ls

## Installation

With [vim-plug](https://github.com/junegunn/vim-plug):

```vim
Plug 'yegappan/lsp'
Plug 'jclsn/sonarlint-lsp.vim'
```

## Configuration

The plugin does not register the server itself. Add it to yegappan/lsp in your
vimrc, after the plugins are loaded. A minimal configuration:

```vim
vim9script

const analyzerDirs = [
  expand('~/.local/share/sonarlint-ls/analyzers'),
  '/usr/share/java/sonarlint-ls/analyzers',
]

var sonarlint = {
  name: 'sonarlint-ls',
  path: 'sonarlint-ls',
  filetype: [
    'c',
    'cpp',
    'go',
    'html',
    'dockerfile',
    'terraform',
    'yaml',
    'java',
    'javascript',
    'javascriptreact',
    'typescript',
    'typescriptreact',
    'cs',
    'php',
    'python',
    'text',
    'xml',
  ],
  args: ['-stdio', '-analyzers'] + sonarlint#AnalyzerJars(analyzerDirs),
  syncInit: false,
  processDiagHandler: function('sonarlint#ProcessDiags'),
  customNotificationHandlers: sonarlint#NotificationHandlers(),
  customRequestHandlers: sonarlint#RequestHandlers(),
  workspaceConfig: {sonarlint: sonarlint#WorkspaceSettings()},
  initializationOptions: {
    productKey: 'vim',
    productName: 'SonarLint Vim',
    rules: sonarlint#LoadRules(),
    additionalAttributes: {vscode: {isTelemetryEnabled: false}},
    connections: get(g:, 'sonarqube_connected_mode', {})->get('connections', {}),
  },
}

autocmd User LspSetup g:LspAddServer([sonarlint])
```

## Compilation database

C and C++ files are only analysed with a `compile_commands.json`. It is looked
up in this order:

1. `g:sonarlint_compile_commands`, if set
2. `sonarlint#compiledb#FindDir()`: `.`, `build/Release` and `build/Debug`, relative to
   the working directory when Vim starts
3. the directory of the current file, its `build`, `build/Release` and
   `build/Debug` directories, and the same in every parent directory

## Commands

| Command | Description |
| --- | --- |
| `:SonarLintRule [key]` | Show the rule of the issue under the cursor, or the given rule |
| `:SonarLintRuleDisable [key]` | Turn a rule off |
| `:SonarLintRuleEnable [key]` | Turn a rule on |

Rule changes are saved to `$MYVIMDIR/sonarlint-rules.json` and sent to the
server right away. The code action "Deactivate rule" does the same.

## Options

| Variable | Default | Description |
| --- | --- | --- |
| `g:sonarlint_compile_commands` | unset | Path of the `compile_commands.json` to use |
| `g:sonarlint_rules_file` | `$MYVIMDIR/sonarlint-rules.json` | Where rule overrides are stored |
| `g:sonarqube_connected_mode` | unset | Connected mode settings, see below |
| `g:sonarqube_tokens` | unset | Tokens by server URL, falls back to `$SONAR_TOKEN` |

### Connected mode

To bind a project to SonarQube Server or SonarQube Cloud, set this before
the server configuration is created:

```vim
g:sonarqube_connected_mode = {
  connections: {
    sonarqube: [{
      connectionId: 'work',
      serverUrl: 'https://sonar.example.com'
    }]
  },
  project: {
    connectionId: 'work',
    projectKey: 'my-project'
  },
}
```

Also pass `connections` in `initializationOptions`. The token is read from
`g:sonarqube_tokens['https://sonar.example.com']` or `$SONAR_TOKEN`.
