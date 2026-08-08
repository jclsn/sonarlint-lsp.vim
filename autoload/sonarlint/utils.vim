vim9script
# Helpers shared by the sonarlint modules.

# JSON values from the server may be null, so check the type before use.
export def Dict(value: any): dict<any>
  return type(value) == v:t_dict ? value : {}
enddef

export def Str(d: dict<any>, key: string): string
  var value = d->get(key, '')
  return type(value) == v:t_string ? value : ''
enddef

# Parameters of single-argument requests arrive either bare or in a list.
export def FirstParam(msg: dict<any>): any
  var params = msg->get('params', '')
  if type(params) == v:t_list
    return params->empty() ? '' : params[0]
  endif
  return params
enddef
