vim9script
# HTML rule descriptions to GitHub flavored markdown.

def DecodeEntities(text: string): string
  return text
    ->substitute('&#\(\d\+\);', '\=nr2char(str2nr(submatch(1)))', 'g')
    ->substitute('&#[xX]\(\x\+\);', '\=nr2char(str2nr(submatch(1), 16))', 'g')
    ->substitute('&nbsp;', ' ', 'g')
    ->substitute('&lt;', '<', 'g')
    ->substitute('&gt;', '>', 'g')
    ->substitute('&quot;', '"', 'g')
    ->substitute('&apos;', "'", 'g')
    ->substitute('&amp;', '\&', 'g')
enddef

export def Escape(text: string): string
  return text->substitute('[\\`*_[\]<>|~]', '\\&', 'g')
enddef

def ListIndent(lists: list<dict<any>>): string
  return repeat('  ', lists->len())
enddef

# Collapse HTML whitespace and append the text to the markdown output.
def AppendText(out: string, html: string, inCode: bool): string
  var text = DecodeEntities(html->substitute('\_s\+', ' ', 'g'))
  if out->empty() || out =~ '[ \n]$'
    text = text->substitute('^ \+', '', '')
  endif
  return out .. (inCode ? text : Escape(text))
enddef

# Drop blank lines at the borders of code blocks and collapse blank runs.
export def Tidy(md: string): list<string>
  var lines: list<string> = []
  var inFence = false
  for line in md->split("\n", true)
    if line =~ '^```'
      if inFence
        while !lines->empty() && lines[-1] =~ '^\s*$'
          lines->remove(-1)
        endwhile
      endif
      inFence = !inFence
      lines->add(line)
    elseif inFence
      if line !~ '^\s*$' || lines[-1] !~ '^```'
        lines->add(line)
      endif
    else
      var trimmed = line->substitute('\s\+$', '', '')
      if !trimmed->empty() || (!lines->empty() && lines[-1] != '')
        lines->add(trimmed)
      endif
    endif
  endfor
  while !lines->empty() && lines[-1] == ''
    lines->remove(-1)
  endwhile
  return lines
enddef

# <pre> blocks become fenced code blocks in language "lang".
export def FromHtml(html: string, lang: string): list<string>
  var out = ''
  var pos = 0
  var inPre = false
  var inCode = false
  var lists: list<dict<any>> = []
  var links: list<string> = []

  while true
    var [tag, tagStart, tagEnd] = html->matchstrpos('<[^>]*>', pos)
    var text = html->strpart(pos, (tagStart < 0 ? html->len() : tagStart) - pos)
    out = inPre ? out .. DecodeEntities(text) : AppendText(out, text, inCode)
    if tagStart < 0
      break
    endif
    pos = tagEnd

    var name = tag->matchstr('^</\=\zs[[:alnum:]]\+')->tolower()
    var closing = tag =~ '^</'
    if inPre
      if name == 'pre' && closing
        out = out->substitute('\n*$', "\n", '') .. "```\n\n"
        inPre = false
      endif
      continue
    endif

    if name == 'pre' && !closing
      out ..= $"\n\n```{lang}\n"
      inPre = true
    elseif name == 'code'
      out ..= '`'
      inCode = !closing
    elseif name == 'strong' || name == 'b'
      out ..= '**'
    elseif name == 'em' || name == 'i'
      out ..= '*'
    elseif name == 'a'
      if !closing
        links->add(tag->matchstr('\chref\s*=\s*["'']\zs[^"'']*'))
      elseif !links->empty()
        var href = links->remove(-1)
        if href =~ '^https\=:' && out !~ '\V' .. escape(href, '\') .. '\$'
          out ..= $' ({href})'
        endif
      endif
    elseif name == 'br'
      out ..= "\n" .. ListIndent(lists)
    elseif name =~ '^\%(p\|div\|blockquote\|dl\|dt\|dd\|table\|tr\)$'
      out ..= lists->empty() ? "\n\n" : "\n" .. ListIndent(lists)
    elseif name =~ '^h[1-6]$'
      out ..= closing ? "\n\n" : "\n\n" .. repeat('#', min([6, str2nr(name[1]) + 1])) .. ' '
    elseif name == 'ul' || name == 'ol'
      if closing
        if !lists->empty()
          lists->remove(-1)
        endif
        out ..= lists->empty() ? "\n\n" : "\n"
      else
        lists->add({ordered: name == 'ol', count: 0})
        out ..= "\n"
      endif
    elseif name == 'li' && !closing
      var marker = '- '
      if !lists->empty() && lists[-1].ordered
        lists[-1].count += 1
        marker = $'{lists[-1].count}. '
      endif
      out = out->substitute('[ \n]*$', '', '')
        .. "\n" .. repeat('  ', max([0, lists->len() - 1])) .. marker
    elseif name =~ '^t[dh]$' && !closing
      out ..= ' '
    elseif name == 'hr'
      out ..= "\n\n---\n\n"
    endif
  endwhile

  return Tidy(out)
enddef
