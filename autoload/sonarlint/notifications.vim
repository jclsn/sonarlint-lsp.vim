vim9script
# Notifications sent by sonarlint-ls to the client.

import autoload 'lsp/util.vim'
import autoload 'sonarlint/utils.vim'

def Ignore(lspserver: dict<any>, reply: dict<any>)
enddef

def OnFirstSecret(lspserver: dict<any>, reply: dict<any>)
  utils.WarnOnce('secret', 'a secret was found in an open file, see the diagnostics')
enddef

def OnBrowseTo(lspserver: dict<any>, reply: dict<any>)
  var url = utils.FirstParam(reply)
  if type(url) == v:t_string && !url->empty()
    util.InfoMsg($'SonarQube: {url}')
  endif
enddef

export def Handlers(): dict<func>
  var handlers: dict<func> = {
    'sonarlint/showNotificationForFirstSecretsIssue': OnFirstSecret,
    'sonarlint/browseTo': OnBrowseTo,
  }
  # Status and VS Code UI notifications that have no counterpart in Vim.
  for method in [
      'didChangePluginStatuses', 'doNotShowMissingRequirementsMessageAgain',
      'embeddedServerStarted', 'endProgressNotification',
      'maybeShowWiderLanguageSupportNotification', 'openConnectionSettings',
      'openJavaHomeSettings', 'openPathToNodeSettings', 'publishDependencyRisks',
      'removeBindingsForDeletedConnections', 'reportConnectionCheckResult',
      'setReferenceBranchNameForFolder', 'settingsApplied', 'showFixSuggestion',
      'showHotspot', 'showIssue', 'showIssueOrHotspot', 'showSonarLintOutput',
      'showSoonUnsupportedVersionMessage', 'startProgressNotification',
      'submitNewCodeDefinition', 'suggestBinding', 'suggestConnection',
    ]
    handlers[$'sonarlint/{method}'] = Ignore
  endfor
  return handlers
enddef
