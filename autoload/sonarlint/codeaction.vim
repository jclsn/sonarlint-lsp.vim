vim9script
# Code actions and the client-side commands they run.

import autoload 'lsp/util.vim'
import autoload 'sonarlint/utils.vim'
import autoload 'sonarlint/settings.vim'

export def CmdDeactivateRule(cmd: dict<any>)
  var ruleKey = utils.List(cmd->get('arguments'))->get(0, '')
  if type(ruleKey) == v:t_string && !ruleKey->empty()
    settings.SetRuleLevel(ruleKey, 'off')
  endif
enddef

def RangeItem(fname: string, range: dict<any>, text: string): dict<any>
  return {
    filename: fname,
    lnum: utils.Num(range, 'startLine', 1),
    col: utils.Num(range, 'startLineOffset', 0) + 1,
    end_lnum: utils.Num(range, 'endLine', 0),
    end_col: utils.Num(range, 'endLineOffset', -1) + 1,
    text: text,
  }
enddef

export def CmdShowAllLocations(cmd: dict<any>)
  var issue = utils.Dict(utils.List(cmd->get('arguments'))->get(0))
  if issue->empty()
    return
  endif
  var fname = util.LspUriToFile(utils.Str(issue, 'fileUri'))
  var ruleKey = utils.Str(issue, 'ruleKey')
  var items = [RangeItem(fname, utils.Dict(issue->get('textRange')),
    $'{utils.Str(issue, "message")} [{ruleKey}]')]

  var flows = utils.List(issue->get('flows'))
  for [i, flow] in flows->items()
    # Sonar lists the locations of a flow from the sink back to the source.
    var locations = utils.List(utils.Dict(flow)->get('locations'))->copy()->reverse()
    for [j, location] in locations->items()
      var loc = utils.Dict(location)
      var uri = utils.Str(loc, 'uri')
      var file = !uri->empty() ? util.LspUriToFile(uri)
        : !utils.Str(loc, 'filePath')->empty() ? loc.filePath : fname
      var label = flows->len() > 1 ? $'flow {i + 1} step {j + 1}' : $'step {j + 1}'
      items->add(RangeItem(file, utils.Dict(loc->get('textRange')),
        $'{label}: {utils.Str(loc, "message")}'))
    endfor
  endfor

  setloclist(0, [], ' ', {title: $'SonarQube: {ruleKey}', items: items})
  :lopen
enddef

# The edits of a quickfix are relative to the original text, so merge them.
def MergeDocumentEdits(edit: dict<any>)
  var changes = utils.List(edit->get('documentChanges'))
  if changes->len() < 2
    return
  endif
  var merged: list<dict<any>> = []
  var byUri: dict<dict<any>> = {}
  for change in changes
    var docEdit = utils.Dict(change)
    var uri = utils.Str(utils.Dict(docEdit->get('textDocument')), 'uri')
    if docEdit->has_key('kind') || uri->empty()
      # File operations must keep their order relative to the text edits.
      merged->add(docEdit)
      byUri = {}
    elseif byUri->has_key(uri)
      byUri[uri].edits->extend(utils.List(docEdit->get('edits')))
    else
      var first = docEdit->copy()
      first.edits = utils.List(docEdit->get('edits'))->copy()
      byUri[uri] = first
      merged->add(first)
    endif
  endfor
  edit.documentChanges = merged
enddef

def FixCodeActions(actions: any)
  for item in utils.List(actions)
    var action = utils.Dict(item)
    var edit = utils.Dict(action->get('edit'))
    if !edit->empty()
      MergeDocumentEdits(edit)
    endif
  endfor
enddef

# yegappan/lsp has no hook for code action replies.
export def WrapRequests(lspserver: dict<any>)
  if lspserver->get('sonarlintWrapped', false)
    return
  endif
  lspserver.sonarlintWrapped = true

  var Rpc = lspserver.rpc
  lspserver.rpc = (method: string, params: any, ...rest: list<any>): dict<any> => {
    var reply = call(Rpc, [method, params] + rest)
    if method == 'textDocument/codeAction'
      FixCodeActions(utils.Dict(reply)->get('result'))
    endif
    return reply
  }

  var RpcAsync = lspserver.rpc_a
  lspserver.rpc_a = (method: string, params: any, Cbfunc: func): number => {
    if method != 'textDocument/codeAction'
      return RpcAsync(method, params, Cbfunc)
    endif
    return RpcAsync(method, params, (srv: dict<any>, result: any, err: dict<any>) => {
      FixCodeActions(result)
      Cbfunc(srv, result, err)
    })
  }
enddef
