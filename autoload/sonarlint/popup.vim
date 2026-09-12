vim9script
# Rule description popup.

import autoload 'lsp/options.vim' as opt
import autoload 'sonarlint/utils.vim'
import autoload 'sonarlint/server.vim'
import autoload 'sonarlint/markdown.vim'

# Sonar language keys whose Vim syntax has a different name.
const LANGUAGE_TO_FILETYPE = {
  azureresourcemanager: 'json',
  cloudformation: 'yaml',
  docker: 'dockerfile',
  ipython: 'python',
  js: 'javascript',
  kubernetes: 'yaml',
  py: 'python',
  secrets: '',
  text: '',
  ts: 'typescript',
  web: 'html',
}

const POPUP_SCROLL_KEYS = [
  "\<C-E>", "\<C-Y>", "\<C-D>", "\<C-U>", "\<C-F>", "\<C-B>",
  "\<PageDown>", "\<PageUp>",
]

var rulePopup: number = 0

def LanguageFiletype(languageKey: string): string
  if languageKey->empty()
    return &filetype
  endif
  return LANGUAGE_TO_FILETYPE->get(languageKey, languageKey)
enddef

def SeverityDetails(details: dict<any>): list<string>
  var parts: list<string> = []
  var impacts = utils.Dict(details->get('impacts'))
  for quality in impacts->keys()->sort()
    parts->add($'{quality}: {impacts[quality]}')
  endfor
  for key in ['cleanCodeAttribute', 'type', 'severity']
    if !utils.Str(details, key)->empty()
      parts->add(details[key])
    endif
  endfor
  return parts
enddef

# Contextual tabs have one description per framework; show the default one.
def TabHtml(tab: dict<any>): string
  var nonContextual = utils.Dict(tab->get('ruleDescriptionTabNonContextual'))
  if !utils.Str(nonContextual, 'htmlContent')->empty()
    return nonContextual.htmlContent
  endif
  var contexts = utils.List(tab->get('ruleDescriptionTabContextual'))
  if contexts->empty()
    return ''
  endif
  var defaultKey = utils.Str(tab, 'defaultContextKey')
  var chosen = utils.Dict(contexts[0])
  for context in contexts
    if utils.Str(utils.Dict(context), 'contextKey') == defaultKey
      chosen = context
    endif
  endfor
  var html = utils.Str(chosen, 'htmlContent')
  if contexts->len() > 1 && !utils.Str(chosen, 'displayName')->empty()
    html = $'<p><em>{chosen.displayName}</em></p>{html}'
  endif
  return html
enddef

def RuleToMarkdown(rule: dict<any>): list<string>
  var lang = LanguageFiletype(utils.Str(rule, 'languageKey'))
  var key = utils.Str(rule, 'key')
  var name = utils.Str(rule, 'name')
  var lines = [$'# {markdown.Escape(name->empty() ? key : name)}', '']
  var meta = (key->empty() ? [] : [$'`{key}`'])
    + SeverityDetails(utils.Dict(rule->get('severityDetails')))
  lines->extend([meta->join(' · '), ''])

  var html = utils.Str(rule, 'htmlDescription')
  if !html->empty()
    lines->extend(markdown.FromHtml(html, lang) + [''])
  endif
  for tab in utils.List(rule->get('htmlDescriptionTabs'))
    var tabMd = markdown.FromHtml(TabHtml(utils.Dict(tab)), lang)
    if !tabMd->empty()
      lines->extend([$'## {markdown.Escape(utils.Str(utils.Dict(tab), "title"))}', ''] + tabMd + [''])
    endif
  endfor

  var params = utils.List(rule->get('parameters'))
  if !params->empty()
    lines->extend(['## Parameters', ''])
    for p in params->mapnew((_, v) => utils.Dict(v))
      var defaultValue = utils.Str(p, 'defaultValue')->empty() ? '' : $' (default `{p.defaultValue}`)'
      lines->add($'- `{utils.Str(p, "name")}`{defaultValue}: {markdown.Escape(utils.Str(p, "description"))}')
    endfor
  endif
  return markdown.Tidy(lines->join("\n"))
enddef

def RulePopupClose()
  if rulePopup != 0 && popup_list()->index(rulePopup) != -1
    rulePopup->popup_close()
  endif
  rulePopup = 0
enddef

def RulePopupClosed(winid: number, result: any)
  if rulePopup == winid
    rulePopup = 0
  endif
enddef

def RulePopupFilter(winid: number, key: string): bool
  if POPUP_SCROLL_KEYS->index(key) != -1
    win_execute(winid, $'normal! {key}')
    return true
  elseif key == "\<Esc>"
    winid->popup_close()
    return true
  endif
  return false
enddef

def ShowMarkdownPopup(lines: list<string>)
  RulePopupClose()
  var popupAttrs = opt.PopupConfigure('Hover', {
    moved: 'any',
    close: 'click',
    fixed: true,
    mapping: false,
    maxwidth: 80,
    maxheight: max([5, &lines * 2 / 3]),
    scrollbar: true,
    filter: RulePopupFilter,
    callback: RulePopupClosed,
    padding: [0, 1, 0, 1],
  })
  var popupBuf = bufadd(null_string)
  rulePopup = popupBuf->popup_atcursor(popupAttrs)
  rulePopup->popup_settext(lines)
  win_execute(rulePopup, 'setlocal bufhidden=wipe buftype=popup')
  win_execute(rulePopup, 'setlocal filetype=lspgfm')
enddef

export def OnShowRuleDescription(lspserver: dict<any>, reply: dict<any>)
  server.Remember(lspserver)
  var rule = utils.Dict(reply->get('params'))
  if !rule->empty()
    ShowMarkdownPopup(RuleToMarkdown(rule))
  endif
enddef
