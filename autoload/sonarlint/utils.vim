vim9script
# Helpers shared by the sonarlint modules.

# Parameters of single-argument requests arrive either bare or in a list.
export def FirstParam(msg: dict<any>): any
  var params = msg->get('params', '')
  if type(params) == v:t_list
    return params->empty() ? '' : params[0]
  endif
  return params
enddef
