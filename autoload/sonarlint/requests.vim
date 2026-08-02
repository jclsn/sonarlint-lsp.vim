vim9script
# Requests sent by sonarlint-ls to the client.

import autoload 'lsp/util.vim'
import autoload 'sonarlint/utils.vim'

def Respond(value: any): func
  return (lspserver: dict<any>, request: dict<any>) => {
    lspserver.sendResponse(request, value, {})
  }
enddef

def OnIsOpenInEditor(lspserver: dict<any>, request: dict<any>)
  var uri = utils.FirstParam(request)
  var fname = type(uri) == v:t_string ? util.LspUriToFile(uri) : ''
  var isOpen = !fname->empty() && fname->bufexists() && fname->bufnr()->bufloaded()
  lspserver.sendResponse(request, isOpen, {})
enddef

export def Handlers(): dict<func>
  return {
    'sonarlint/isOpenInEditor': OnIsOpenInEditor,
    'sonarlint/canShowMissingRequirementsNotification': Respond('ERROR_ONLY'),
    'sonarlint/hasJoinedIdeLabs': Respond(false),
    'sonarlint/askSslCertificateConfirmation': Respond(false),
    'sonarlint/getJavaConfig': Respond(null),
  }
enddef
