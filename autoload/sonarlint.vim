vim9script
# SonarQube for IDE (sonarlint-ls) client for yegappan/lsp.

import autoload 'sonarlint/settings.vim'

export def AnalyzerJars(dirs: list<string>): list<string>
  return settings.AnalyzerJars(dirs)
enddef
