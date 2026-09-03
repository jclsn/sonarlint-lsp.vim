vim9script
# SonarQube for IDE (sonarlint-ls) client for yegappan/lsp.

import autoload 'sonarlint/settings.vim'
import autoload 'sonarlint/diagnostics.vim'
import autoload 'sonarlint/requests.vim'
import autoload 'sonarlint/notifications.vim'

export def AnalyzerJars(dirs: list<string>): list<string>
  return settings.AnalyzerJars(dirs)
enddef

export def CompileCommandsPath(startDir: string = getcwd()): string
  return settings.CompileCommandsPath(startDir)
enddef

export def WorkspaceSettings(): dict<any>
  return settings.WorkspaceSettings()
enddef

export def ProcessDiags(diags: list<dict<any>>): list<dict<any>>
  return diagnostics.ProcessDiags(diags)
enddef

export def NotificationHandlers(): dict<func>
  return notifications.Handlers()
enddef

export def RequestHandlers(): dict<func>
  return requests.Handlers()
enddef
