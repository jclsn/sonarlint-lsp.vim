vim9script
# SonarQube for IDE (sonarlint-ls) client for yegappan/lsp.

import autoload 'lsp/buffer.vim' as buf
import autoload 'lsp/util.vim'
import autoload 'sonarlint/utils.vim'
import autoload 'sonarlint/server.vim'
import autoload 'sonarlint/settings.vim'
import autoload 'sonarlint/diagnostics.vim'
import autoload 'sonarlint/codeaction.vim'
import autoload 'sonarlint/info.vim'
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

export def LoadRules(): dict<any>
  return settings.LoadRules()
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

export def ShowRule(ruleKey: string = '')
  var lspserver = server.Get()
  if lspserver->empty()
    util.ErrMsg($'{server.NAME} is not running for this buffer')
    return
  endif
  var uri = util.LspBufnrToUri(bufnr())
  if !ruleKey->empty()
    lspserver.executeCommand({command: 'SonarLint.OpenRuleDesc', arguments: [ruleKey, uri]})
    return
  endif
  var issue = diagnostics.CursorIssue(lspserver)
  var entryKey = utils.Str(utils.Dict(issue->get('data')), 'entryKey')
  if entryKey->empty()
    util.WarnMsg('SonarQube: no issue on the current line')
    return
  endif
  lspserver.executeCommand({
    command: 'SonarLint.ShowIssueDetailsCodeAction',
    arguments: [entryKey, uri],
  })
enddef

export def RuleLevel(level: string, ruleKey: string = '')
  var key = ruleKey
  var lspserver = server.Get()
  if key->empty() && !lspserver->empty()
    var code = diagnostics.CursorIssue(lspserver)->get('code', '')
    key = type(code) == v:t_string ? code : ''
  endif
  if key->empty()
    util.WarnMsg('SonarQube: no issue on the current line')
    return
  endif
  settings.SetRuleLevel(key, level)
enddef

export def CompleteRules(arglead: string, cmdline: string, cursorpos: number): list<string>
  return settings.LoadRules()->keys()->sort()->filter((_, k) => k->stridx(arglead) == 0)
enddef

export def Info()
  info.Show()
enddef

# Called on the LspSetup event.
export def Setup()
  g:LspRegisterCmdHandler('SonarLint.DeactivateRule', codeaction.CmdDeactivateRule)
  g:LspRegisterCmdHandler('SonarLint.ShowAllLocations', codeaction.CmdShowAllLocations)

  command! SonarLintInfo sonarlint#Info()
  command! -nargs=? SonarLintRule sonarlint#ShowRule(<q-args>)
  command! -nargs=? -complete=customlist,sonarlint#CompleteRules SonarLintRuleDisable
        \ sonarlint#RuleLevel('off', <q-args>)
  command! -nargs=? -complete=customlist,sonarlint#CompleteRules SonarLintRuleEnable
        \ sonarlint#RuleLevel('on', <q-args>)
enddef

# Called on the LspAttached event.
export def Attach()
  var lspserver = buf.CurbufGetServerByName(server.NAME)
  if !lspserver->empty()
    codeaction.WrapRequests(lspserver)
  endif
enddef
