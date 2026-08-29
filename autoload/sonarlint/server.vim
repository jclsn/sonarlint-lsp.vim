vim9script
# The sonarlint-ls server object.

export def Settings(lspserver: dict<any>): dict<any>
  if type(lspserver.workspaceConfig->get('sonarlint')) != v:t_dict
    lspserver.workspaceConfig.sonarlint = {}
  endif
  return lspserver.workspaceConfig.sonarlint
enddef
