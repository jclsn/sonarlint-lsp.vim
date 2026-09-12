vim9script
# Diagnostics, security hotspots and taint vulnerabilities.

import autoload 'lsp/diag.vim'
import autoload 'sonarlint/utils.vim'

const SONAR_SOURCE = 'sonarqube'
# LSP severity by data.impactSeverity (INFO, LOW, MEDIUM, HIGH, BLOCKER)
const IMPACT_TO_LSP_SEVERITY = [4, 3, 2, 1, 1]
const LSP_SEVERITY_HINT = 4

# The Sonar diagnostic on the cursor line, preferring the one under the cursor.
export def CursorIssue(lspserver: dict<any>): dict<any>
  var diags = diag.GetDiagsByLine(bufnr(), line('.'), lspserver)
    ->copy()
    ->filter((_, d) => d->get('source', '') == SONAR_SOURCE)
  if diags->empty()
    return {}
  endif
  var col = charcol('.') - 1
  for d in diags
    if d.range.start.character <= col && col <= d.range.end.character
      return d
    endif
  endfor
  return diags[0]
enddef

export def ProcessDiags(diags: list<dict<any>>): list<dict<any>>
  for d in diags
    var code = d->get('code', '')
    if type(code) == v:t_string && !code->empty() && d.message !~# $'\V[{code}]\$'
      d.message ..= $' [{code}]'
    endif

    # Hotspots, taints and hints outside new code keep their severity.
    if d->get('source', '') != SONAR_SOURCE
        || d->get('severity', 0) == LSP_SEVERITY_HINT
      continue
    endif
    var impact = utils.Dict(d->get('data'))->get('impactSeverity', -1)
    if type(impact) == v:t_number
        && impact >= 0 && impact < IMPACT_TO_LSP_SEVERITY->len()
      d.severity = IMPACT_TO_LSP_SEVERITY[impact]
    endif
  endfor
  return diags
enddef

# A separate kind, so they don't replace the regular issues.
def PublishExtraDiags(lspserver: dict<any>, reply: dict<any>, kind: string)
  var params = utils.Dict(reply->get('params'))
  if utils.Str(params, 'uri')->empty()
    return
  endif
  diag.DiagNotification(lspserver, params.uri, utils.List(params->get('diagnostics')), kind)
enddef

export def OnPublishSecurityHotspots(lspserver: dict<any>, reply: dict<any>)
  PublishExtraDiags(lspserver, reply, 'sonarlint-hotspots')
enddef

export def OnPublishTaintVulnerabilities(lspserver: dict<any>, reply: dict<any>)
  PublishExtraDiags(lspserver, reply, 'sonarlint-taints')
enddef
