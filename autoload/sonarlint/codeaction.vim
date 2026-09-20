vim9script
# Code actions and the client-side commands they run.

import autoload 'sonarlint/utils.vim'
import autoload 'sonarlint/settings.vim'

export def CmdDeactivateRule(cmd: dict<any>)
  var ruleKey = utils.List(cmd->get('arguments'))->get(0, '')
  if type(ruleKey) == v:t_string && !ruleKey->empty()
    settings.SetRuleLevel(ruleKey, 'off')
  endif
enddef
