vim9script
# Workspace settings: analyzers and compilation database.

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

# The "sonarlint" section of the workspace configuration.
export def WorkspaceSettings(): dict<any>
  var settings: dict<any> = {
    disableTelemetry: true,
    focusOnNewCode: false,
    automaticAnalysis: true,
  }
  var compileCommands = CompileCommandsPath()
  if !compileCommands->empty()
    settings.pathToCompileCommands = compileCommands
  endif
  return settings
enddef

export def OnNeedCompilationDatabase(lspserver: dict<any>, reply: dict<any>)
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
