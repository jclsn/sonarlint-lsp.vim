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

# Without git, only the top level is listed.
def ListFiles(root: string): list<string>
  if executable('git')
    var files = systemlist($'git -C {shellescape(root)} -c core.quotePath=false'
      .. ' ls-files --cached --others --exclude-standard')
    if v:shell_error == 0
      return files->map((_, f) => $'{root}/{f}')
    endif
  endif
  return globpath(root, '*', true, true) + globpath(root, '.sonarlint/*', true, true)
enddef

def OnListFilesInFolder(lspserver: dict<any>, request: dict<any>)
  var root = util.LspUriToFile(utils.Str(utils.Dict(request->get('params')), 'folderUri'))
  var files = ListFiles(root->substitute('/$', '', ''))
    ->filter((_, f) => f->filereadable())
    ->mapnew((_, f) => ({fileName: f->fnamemodify(':t'), filePath: f, content: null}))
  lspserver.sendResponse(request, {foundFiles: files}, {})
enddef

export def Handlers(): dict<func>
  return {
    'sonarlint/isOpenInEditor': OnIsOpenInEditor,
    'sonarlint/listFilesInFolder': OnListFilesInFolder,
    'sonarlint/canShowMissingRequirementsNotification': Respond('ERROR_ONLY'),
    'sonarlint/hasJoinedIdeLabs': Respond(false),
    'sonarlint/askSslCertificateConfirmation': Respond(false),
    'sonarlint/getJavaConfig': Respond(null),
  }
enddef
