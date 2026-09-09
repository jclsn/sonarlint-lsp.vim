vim9script
# Notifications sent by sonarlint-ls to the client.

import autoload 'lsp/util.vim'
import autoload 'sonarlint/utils.vim'
import autoload 'sonarlint/settings.vim'
import autoload 'sonarlint/diagnostics.vim'
import autoload 'sonarlint/popup.vim'

def Ignore(lspserver: dict<any>, reply: dict<any>)
enddef

def OnFirstSecret(lspserver: dict<any>, reply: dict<any>)
  utils.WarnOnce('secret', 'a secret was found in an open file, see the diagnostics')
enddef

def OnInvalidToken(lspserver: dict<any>, reply: dict<any>)
  utils.WarnOnce('token', 'the SonarQube token was rejected, check g:sonarqube_tokens or $SONAR_TOKEN')
enddef

def OnBrowseTo(lspserver: dict<any>, reply: dict<any>)
  var url = utils.FirstParam(reply)
  if type(url) == v:t_string && !url->empty()
    util.InfoMsg($'SonarQube: {url}')
  endif
enddef

export def Handlers(): dict<func>
  var handlers: dict<func> = {
    'sonarlint/showRuleDescription': popup.OnShowRuleDescription,
    'sonarlint/publishSecurityHotspots': diagnostics.OnPublishSecurityHotspots,
    'sonarlint/publishTaintVulnerabilities': diagnostics.OnPublishTaintVulnerabilities,
    'sonarlint/needCompilationDatabase': settings.OnNeedCompilationDatabase,
    'sonarlint/showNotificationForFirstSecretsIssue': OnFirstSecret,
    'sonarlint/notifyInvalidToken': OnInvalidToken,
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
