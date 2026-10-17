vim9script
# :SonarLintInfo report.

import autoload 'lsp/diag.vim'
import autoload 'sonarlint/server.vim'
import autoload 'sonarlint/settings.vim'
import autoload 'sonarlint/utils.vim'

const BUFNAME = 'sonarlint://info'
const ONDEMAND_DIR = expand('~/.sonarlint/storage/ondemand-plugins')
const SEVERITY_NAMES = ['error', 'warning', 'information', 'hint']
const MAX_LOG_LINES = 10

def Field(name: string, value: string): string
  return printf('  %-9s %s', $'{name}:', value)
enddef

def ServerSection(lspserver: dict<any>): list<string>
  var lines = ['Server']
  if lspserver->empty()
    return lines + ['  ✗ sonarlint-ls is not attached to this buffer']
  endif
  var state = !lspserver.running ? '✗ not running' : lspserver.ready ? 'running' : 'starting'
  var info = utils.Dict(lspserver.caps->get('~additionalInitResult_serverInfo'))
  lines->add(Field('status', state))
  if !info->empty()
    lines->add(Field('version', $'{utils.Str(info, "name")} {utils.Str(info, "version")}'))
  endif
  var exe = lspserver.path->exepath()
  lines->add(Field('command', exe->empty() ? $'✗ {lspserver.path} not found in $PATH' : exe))
  var java = executable('java') ? systemlist('java -version 2>&1')->get(0, '') : ''
  lines->add(Field('java', java->empty() ? '✗ not found in $PATH' : java))
  return lines
enddef

def AnalyzerSection(lspserver: dict<any>): list<string>
  var lines = ['Analyzers']
  var args = lspserver->empty() ? [] : lspserver.args
  var start = args->index('-analyzers')
  var jars = start < 0 ? [] : args[start + 1 :]
  if jars->empty()
    lines->add('  ✗ no -analyzers passed to the server')
  endif
  var missing = false
  for jar in jars
    if jar->filereadable()
      lines->add($'  ✓ {jar}')
    else
      lines->add($'  ✗ {jar} (missing)')
      missing = true
    endif
  endfor
  if missing
    lines->add('    A missing jar makes sonarlint-ls fail to load all analyzers.')
  endif

  lines->add('')
  lines->add($'Downloaded analyzers ({ONDEMAND_DIR->fnamemodify(":~")})')
  var plugins = globpath(ONDEMAND_DIR, '*/*', true, true)->filter((_, d) => d->isdirectory())
  if plugins->empty()
    lines->add('  none yet, C/C++ and C# analyzers are downloaded on first use')
  endif
  var width = plugins->mapnew((_, d) => d->fnamemodify(':h:t')->strcharlen())->max()
  for dir in plugins
    lines->add(printf('  %-*s  %s', width, dir->fnamemodify(':h:t'), dir->fnamemodify(':t')))
  endfor
  return lines
enddef

def CompileCommandsSection(lspserver: dict<any>): list<string>
  var lines = ['Compilation database']
  var inUse = lspserver->empty() ? '' : utils.Str(server.Settings(lspserver), 'pathToCompileCommands')
  var found = settings.CompileCommandsPath(expand('%:p:h'))
  if inUse->empty()
    lines->add(Field('in use', '✗ none'))
  else
    lines->add(Field('in use', inUse->filereadable() ? inUse : $'✗ {inUse} (missing)'))
  endif
  if found != inUse
    lines->add(Field('found', found->empty() ? 'none' : found))
  endif
  return lines
enddef

def RulesSection(): list<string>
  var lines = [$'Rules ({settings.RulesFile()->fnamemodify(":~")})']
  var byLevel: dict<list<string>> = {}
  var rules = settings.LoadRules()
  for key in rules->keys()->sort()
    var level = utils.Str(utils.Dict(rules[key]), 'level')
    byLevel[level] = byLevel->get(level, []) + [key]
  endfor
  if byLevel->empty()
    lines->add('  no overrides')
  endif
  for level in byLevel->keys()->sort()
    lines->add(Field(level, byLevel[level]->join(', ')))
  endfor
  return lines
enddef

def BufferSection(bnr: number): list<string>
  var counts = {issues: [0, 0, 0, 0], hotspots: [0, 0, 0, 0]}
  for d in diag.GetDiagsForBuf(bnr)
    var source = d->get('source', '')
    var kind = source == 'sonarqube' ? 'issues' : source =~ 'hotspot$' ? 'hotspots' : ''
    var severity = d->get('severity', 1)
    if !kind->empty() && severity >= 1 && severity <= 4
      counts[kind][severity - 1] += 1
    endif
  endfor
  var lines = [$'Current buffer ({bnr->bufname()->fnamemodify(":~:.")})']
  for kind in ['issues', 'hotspots']
    var total = counts[kind]->reduce((acc, n) => acc + n, 0)
    var parts = range(4)->filter((_, i) => counts[kind][i] > 0)
      ->map((_, i) => $'{counts[kind][i]} {SEVERITY_NAMES[i]}')
    lines->add(Field(kind, total == 0 ? '0' : $'{total} ({parts->join(", ")})'))
  endfor
  return lines
enddef

# sonarlint-ls logs everything as "Log" and puts the level into the message.
def LogSection(lspserver: dict<any>): list<string>
  var lines = ['Recent errors and warnings']
  var messages = lspserver->empty() ? [] : lspserver.messages
    ->copy()
    ->filter((_, m) => m =~ '\[\%(Error\|Warn\) - ')
    ->map((_, m) => m->substitute('^\(\S\+ \S\+\): \[\a\+\]: \[\(\a\+\) - [^]]*\] \%(\[[^]]*\] \)\=', '\1 \2: ', ''))
  # The same error repeats on every analysis; keep the latest of each.
  var seen: dict<bool> = {}
  var unique: list<string> = []
  for m in messages->reverse()
    var text = m->substitute('^\S\+ \S\+ ', '', '')
    if !seen->has_key(text)
      seen[text] = true
      unique->insert(m)
    endif
  endfor
  if unique->empty()
    lines->add('  none')
  endif
  return lines + unique[-MAX_LOG_LINES :]->map((_, m) => $'  {m}')
enddef

def Report(lspserver: dict<any>, bnr: number): list<string>
  var title = 'SonarQube for IDE (sonarlint-ls)'
  var lines = [title, repeat('=', title->strcharlen()), '']
  for section in [ServerSection(lspserver), AnalyzerSection(lspserver),
      CompileCommandsSection(lspserver), RulesSection(), BufferSection(bnr),
      LogSection(lspserver)]
    lines->extend(section + [''])
  endfor
  return lines[: -2]
enddef

export def Show()
  var lines = Report(server.Get(), bufnr())
  var old = bufnr(BUFNAME)
  if old > 0
    execute $'bwipeout {old}'
  endif
  execute $'botright :{min([lines->len(), &lines / 2])}new'
  setlocal buftype=nofile bufhidden=wipe noswapfile nobuflisted nowrap
  execute $'silent file {BUFNAME}'
  setline(1, lines)
  setlocal nomodifiable
  nnoremap <buffer> <silent> q <Cmd>close<CR>
  syntax match SonarLintInfoTitle /^\S.*$/
  syntax match SonarLintInfoBad /✗.*$/
  syntax match SonarLintInfoGood /✓/
  highlight default link SonarLintInfoTitle Title
  highlight default link SonarLintInfoBad ErrorMsg
  highlight default link SonarLintInfoGood DiffAdd
enddef
