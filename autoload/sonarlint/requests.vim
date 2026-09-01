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

def IsGitIgnored(fname: string): bool
  if !executable('git')
    return false
  endif
  var dir = fname->fnamemodify(':h')
  system($'git -C {shellescape(dir)} check-ignore -q -- {shellescape(fname)}')
  return v:shell_error == 0
enddef

# Asked before files are re-analysed, e.g. after a settings change.
def OnFilterOutExcludedFiles(lspserver: dict<any>, request: dict<any>)
  var uris = utils.List(utils.Dict(request->get('params'))->get('fileUris'))
  var kept = uris->copy()->filter((_, uri) => !IsGitIgnored(util.LspUriToFile(uri)))
  lspserver.sendResponse(request, {fileUris: kept}, {})
enddef

def OnGetTokenForServer(lspserver: dict<any>, request: dict<any>)
  var serverUrl = utils.FirstParam(request)
  var tokens = utils.Dict(get(g:, 'sonarqube_tokens', {}))
  var token = type(serverUrl) == v:t_string && tokens->has_key(serverUrl) ? tokens[serverUrl]
    : !empty($SONAR_TOKEN) ? $SONAR_TOKEN : null
  lspserver.sendResponse(request, token, {})
enddef

export def Handlers(): dict<func>
  return {
    'sonarlint/isOpenInEditor': OnIsOpenInEditor,
    'sonarlint/listFilesInFolder': OnListFilesInFolder,
    'sonarlint/filterOutExcludedFiles': OnFilterOutExcludedFiles,
    'sonarlint/getTokenForServer': OnGetTokenForServer,
    'sonarlint/canShowMissingRequirementsNotification': Respond('ERROR_ONLY'),
    'sonarlint/hasJoinedIdeLabs': Respond(false),
    'sonarlint/askSslCertificateConfirmation': Respond(false),
    'sonarlint/getJavaConfig': Respond(null),
  }
enddef
