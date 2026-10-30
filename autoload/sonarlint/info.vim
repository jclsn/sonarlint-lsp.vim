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

def CompileCommandsSection(lspserver: dict<any>, bnr: number): list<string>
  var lines = ['Compilation database']
  var inUse = lspserver->empty() ? '' : utils.Str(server.Settings(lspserver), 'pathToCompileCommands')
  var found = settings.CompileCommandsPath(bnr->bufname()->fnamemodify(':p:h'))
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

# Break {text} at whitespace so that no line is wider than {width}, indenting
# the continuation lines by {indent} columns.
def Wrap(text: string, width: number, indent: number): list<string>
  var lines: list<string> = []
  var prefix = '  '
  var rest = text
  while prefix->strcharlen() + rest->strcharlen() > width
    var room = max([width - prefix->strcharlen(), 1])
    var cut = rest->strcharpart(0, room + 1)->match('.*\zs\s')
    if cut <= 0
      cut = rest->strcharpart(0, room)->len()
    endif
    lines->add(prefix .. rest->strpart(0, cut))
    rest = rest->strpart(cut)->substitute('^\s\+', '', '')
    prefix = repeat(' ', indent)
  endwhile
  return lines + [prefix .. rest]
enddef

# sonarlint-ls logs everything as "Log" and puts the level into the message.
def LogSection(lspserver: dict<any>, width: number): list<string>
  var lines = ['Recent errors and warnings']
  var messages = lspserver->empty() ? [] : lspserver.messages
    ->copy()
    ->filter((_, m) => m =~ '\[\%(Error\|Warn\) - ')
    ->map((_, m) => m->substitute('^\(\S\+ \S\+\): \[\a\+\]: \[\(\a\+\) - [^]]*\] \%(\[[^]]*\] \)\=', '\1 \2: ', ''))
    ->map((_, m) => m->substitute('\s\+$', '', ''))
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
  for m in unique[-MAX_LOG_LINES :]
    # Continuation lines start below the text after the timestamp and level.
    lines->extend(Wrap(m, width, 2 + m->matchstr('^\S\+ \S\+ \a\+: ')->strcharlen()))
  endfor
  return lines
enddef

def Report(lspserver: dict<any>, bnr: number, width: number): list<string>
  var title = 'SonarQube for IDE (sonarlint-ls)'
  var lines = [title, repeat('=', title->strcharlen()), '']
  for section in [ServerSection(lspserver), AnalyzerSection(lspserver),
      CompileCommandsSection(lspserver, bnr), RulesSection(), BufferSection(bnr),
      LogSection(lspserver, width)]
    lines->extend(section + [''])
  endfor
  return lines[: -2]
enddef

export def Show()
  var lspserver = server.Get()
  var bnr = bufnr()
  var old = bufnr(BUFNAME)
  # Refresh a visible report in place, keeping its split and size.
  var winid = old > 0 ? bufwinid(old) : -1
  if winid < 0
    if old > 0
      execute $'bwipeout {old}'
    endif
    botright vertical new
    setlocal buftype=nofile bufhidden=wipe noswapfile nobuflisted nowrap nomodifiable
    execute $'silent file {BUFNAME}'
    nnoremap <buffer> <silent> q <Cmd>close<CR>
    syntax match SonarLintInfoTitle /^\S.*$/
    syntax match SonarLintInfoBad /✗.*$/
    syntax match SonarLintInfoGood /✓/
    highlight default link SonarLintInfoTitle Title
    highlight default link SonarLintInfoBad ErrorMsg
    highlight default link SonarLintInfoGood DiffAdd
    old = bufnr()
    winid = win_getid()
  endif
  var info = getwininfo(winid)[0]
  var lines = Report(lspserver, bnr, info.width - info.textoff)
  setbufvar(old, '&modifiable', true)
  setbufline(old, 1, lines)
  if getbufinfo(old)[0].linecount > lines->len()
    deletebufline(old, lines->len() + 1, '$')
  endif
  setbufvar(old, '&modifiable', false)
  win_execute(winid, 'normal! gg')
enddef
