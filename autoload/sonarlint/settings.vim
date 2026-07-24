vim9script
# Workspace settings: analyzers.

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
  return settings
enddef
