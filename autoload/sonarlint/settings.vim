vim9script
# Workspace settings: analyzers, compilation database and rule overrides.

import autoload 'lsp/util.vim'
import autoload 'sonarlint/compiledb.vim'
import autoload 'sonarlint/utils.vim'
import autoload 'sonarlint/server.vim'

const COMPILE_COMMANDS_DIRS = ['', 'build', 'build/Release', 'build/Debug']

# How often a path is sent again when the server keeps asking for it.
const COMPILE_COMMANDS_RETRIES = 3

var compileCommandsSent: dict<number> = {}

def FindCompileCommandsUpwards(startDir: string): string
  var dir = startDir->fnamemodify(':p:h')
  while true
    for sub in COMPILE_COMMANDS_DIRS
      var json = $'{dir}/{sub}/compile_commands.json'->substitute('/\+', '/', 'g')
      if json->filereadable()
        return json
      endif
    endfor
    var parent = dir->fnamemodify(':h')
    if parent == dir
      return ''
    endif
    dir = parent
  endwhile
  return ''
enddef

export def CompileCommandsPath(startDir: string = getcwd()): string
  var path = get(g:, 'sonarlint_compile_commands', '')
  if !path->empty()
    return path->fnamemodify(':p')
  endif
  var dir = compiledb.FindDir()
  if !dir->empty()
    return $'{dir}/compile_commands.json'
  endif
  return FindCompileCommandsUpwards(startDir)
enddef

export def AnalyzerJars(dirs: list<string>): list<string>
  var jars: dict<string> = {}
  for dir in dirs
    for jar in globpath(dir, '*.jar', true, true)
      jars->extend({[jar->fnamemodify(':t')]: jar}, 'keep')
    endfor
  endfor
  return jars->values()->sort()
enddef

export def RulesFile(): string
  var vimdir = empty($MYVIMDIR) ? expand('~/.vim/') : $MYVIMDIR
  return get(g:, 'sonarlint_rules_file', $'{vimdir}sonarlint-rules.json')
enddef

# Rule overrides as understood by sonarlint-ls: {"cpp:S1234": {"level": "off"}}
export def LoadRules(): dict<any>
  var file = RulesFile()
  if !file->filereadable()
    return {}
  endif
  try
    return utils.Dict(file->readfile()->join("\n")->json_decode())
  catch
    util.ErrMsg($'SonarQube: cannot read {file}: {v:exception}')
    return {}
  endtry
enddef

# One rule per line keeps the file easy to diff.
def SaveRules(rules: dict<any>)
  var keys = rules->keys()->sort()
  var lines = keys->mapnew((i, key) => $'  {json_encode(key)}: {json_encode(rules[key])}'
    .. (i < keys->len() - 1 ? ',' : ''))
  writefile(['{'] + lines + ['}'], RulesFile())
enddef

export def SetRuleLevel(ruleKey: string, level: string)
  var rules = LoadRules()
  rules[ruleKey] = {level: level}
  SaveRules(rules)

  var lspserver = server.Get()
  if !lspserver->empty()
    var settings = server.Settings(lspserver)
    settings.rules = rules
    lspserver.sendWorkspaceConfig()
  endif
  util.InfoMsg($'SonarQube: rule {ruleKey} turned {level}')
enddef

# The "sonarlint" section of the workspace configuration.
export def WorkspaceSettings(): dict<any>
  var settings: dict<any> = {
    rules: LoadRules(),
    disableTelemetry: true,
    focusOnNewCode: false,
    automaticAnalysis: true,
  }
  var compileCommands = CompileCommandsPath()
  if !compileCommands->empty()
    settings.pathToCompileCommands = compileCommands
  endif
  var connectedMode = get(g:, 'sonarqube_connected_mode', {})
  if !connectedMode->empty()
    settings.connectedMode = connectedMode
  endif
  return settings
enddef

export def OnNeedCompilationDatabase(lspserver: dict<any>, reply: dict<any>)
  server.Remember(lspserver)
  var found = CompileCommandsPath(expand('%:p:h'))
  if found->empty()
    utils.WarnOnce('compiledb', 'no compile_commands.json found, C/C++ files are not analysed'
      .. ' (cmake -DCMAKE_EXPORT_COMPILE_COMMANDS=ON or set g:sonarlint_compile_commands)')
    return
  endif
  # Also asked before the settings were pulled, so resend a known path.
  var sent = compileCommandsSent->get(found, 0)
  if sent >= COMPILE_COMMANDS_RETRIES
    utils.WarnOnce($'compiledb:{found}', $'sonarlint-ls does not accept {found}')
    return
  endif
  compileCommandsSent[found] = sent + 1
  var settings = server.Settings(lspserver)
  settings.pathToCompileCommands = found
  lspserver.sendWorkspaceConfig()
enddef
