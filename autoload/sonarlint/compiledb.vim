vim9script
# Locate the compilation database

const CANDIDATES = ['.', 'build/Release', 'build/Debug']

# Return the absolute directory that contains the first existing
# compile_commands.json, or an empty string if none is found.
export def FindDir(candidates: list<string> = CANDIDATES): string
  for dir in candidates
    var json = $'{dir}/compile_commands.json'
    if json->filereadable()
      return json->fnamemodify(':p:h')
    endif
  endfor
  return ''
enddef
