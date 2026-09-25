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
