vim9script
# The sonarlint-ls server object.

import autoload 'lsp/buffer.vim' as buf

export const NAME = 'sonarlint-ls'
var lastServer: dict<any> = {}

export def Remember(lspserver: dict<any>)
  lastServer = lspserver
enddef

# Command handlers do not get the server object.
export def Get(): dict<any>
  var lspserver = buf.CurbufGetServerByName(NAME)
  return lspserver->empty() ? lastServer : lspserver
enddef

export def Settings(lspserver: dict<any>): dict<any>
  if type(lspserver.workspaceConfig->get('sonarlint')) != v:t_dict
    lspserver.workspaceConfig.sonarlint = {}
  endif
  return lspserver.workspaceConfig.sonarlint
enddef
