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
