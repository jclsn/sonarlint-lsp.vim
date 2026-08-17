vim9script
# Notifications sent by sonarlint-ls to the client.

def Ignore(lspserver: dict<any>, reply: dict<any>)
enddef

export def Handlers(): dict<func>
  var handlers: dict<func> = {}
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
