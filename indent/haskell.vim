if exists('b:did_indent')
	finish
endif

let s:save_cpo = &cpo
set cpo&vim

if !exists('b:undo_indent')
	let b:undo_indent = ''
else
	let b:undo_indent .= '|'
endif

let b:undo_indent .= 'setlocal
	\ indentexpr<
	\ autoindent<
	\ indentkeys<
	\'

setlocal indentexpr=HaskellIndent()
setlocal autoindent
setlocal indentkeys=o,O,!^F,0<Bar>,0,0),0],0},<Bar><Bar>,0=instance\ ,0=class\ ,0=type\ ,0=newtype\ ,0=data\ ,0=then\ ,0=else\ ,0=infix\ ,0=infixr\ ,0=infixl\ ,0=deriving\ ,0=where\ ,0=in\ ,*<Return>

let s:keep_indent = -1

function! HaskellIndent() abort
	let cur_lnum = v:lnum
	let cur_line = getline(cur_lnum)
	let pre_lnum = s:prev_noncomment(v:lnum)
	if pre_lnum == 0
		let pre_lnum = 1
	endif
	let pre_line = getline(pre_lnum)


	"for indentkeys o,O,!^F
	if s:is_empty(cur_line)
		if s:is_followed(pre_line, '\v<where>')
			let base_indent = matchend(pre_line, '\v<where>\s*')
		elseif s:is_followed(pre_line, '\v<let>') && !s:is_in_do(pre_lnum)
			let base_indent = matchend(pre_line, '\v<let>\s*')
		elseif s:is_followed(pre_line, '\v<do>')
			let base_indent = matchend(pre_line, '\v<do>\s*')
		else
			let base_indent = indent(pre_lnum)
		endif

		if s:is_end_with(pre_line, '\v<%(do|of|let|in|deriving|if|then|else)>')
	  \ || s:is_end_with_equal(pre_line)
	  \ || s:is_end_with_arrow(pre_line)
	  \ || s:is_end_with_open(pre_line)
	  \ || s:is_end_with(pre_line, '::')
			return s:inc_indent(base_indent)

		elseif s:is_end_with(pre_line, '\v<where>')
			if !s:is_module(pre_line, pre_lnum)
				return s:inc_indent(base_indent)
			else
				return 0
			endif

"([ [a, b, c]
" , [d, e, f]
" ])
		elseif s:is_open(pre_line)
			let paren = s:last_open_not_closed(pre_line, '(')
			let bracket = s:last_open_not_closed(pre_line, '[')
			let brace = s:last_open_not_closed(pre_line, '{')
			let x = max([paren, bracket, brace])
			if x != s:keep_indent
				return x
			endif
			"cansel if else chain to handle nested parent
		endif

		if s:is_close(pre_line)
			return s:indent_as_match_open(pre_line, pre_lnum)
		else
			return base_indent
		endif


	"for indentkeys 0char, =word, 0=word, *<Return>
	else
		if s:is_start_with(cur_line, '\v<%(data|type|instance|class|newtype)>')
			return 0

		elseif s:is_start_with(cur_line, '\v<%(infix[rl]?)>')
			return 0

		elseif s:is_start_with(cur_line, '\v<deriving>')
			return shiftwidth()

		elseif s:is_start_with(cur_line, '\v<in>')
			return = s:indent_as_match_pair(cur_lnum, '\v<let>', '\v<in>')

		elseif s:is_start_with(cur_line, '\v<then>')
			return = s:indent_as_match_pair(cur_lnum, '\v<if>', '\v<then>')

		elseif s:is_start_with(cur_line, '\v<else>')
			return = s:indent_as_match_pair(cur_lnum, '\v<if>', '\v<else>')

		elseif s:is_arrow_in_case(cur_line)
			let x = s:prev_case(cur_lnum)
			"to return which is better when prev_case is not exist,
			"0 or keep_indent?
			if x == 0
				return 0
			endif
			return s:inc_indent(indent(x)))

		elseif s:is_start_with(cur_line, ',')
		  \ || s:is_start_with_close(cur_line)
		  	let same = s:prev_same_indent(cur_lnum, indent(cur_lnum))
		  	if s:is_start_with(getline(same), ',')
		  		return s:keep_indent
			endif
			let less = s:prev_less_indent(cur_lnum, indent(cur_lnum))
			"to return which is better when prev_such is not exist,
			"0 or keep_indent?
			if less == 0
				return 0
			endif
			if s:is_start_with(getline(less), ',')
				return indent(less)
			else
				return s:keep_indent
			endif

		"elseif s:is_start_with(cur_line, '\v<where>')
		"	return s:inc_indent(indent(s:prev_function(cur_lnum)))
		"guard or function less_or_same_indent

		"PLAN: align prev_condition
		elseif s:is_start_with(cur_line, '||')
			return base_indent

		elseif s:is_start_with(cur_line, '|')
"data Example = One
"             | Two
			let x = s:is_in_data_then_lnum(pre_lnum)
			if x > 0
				return matchend(getline(x), '\v^\s*<data>.*\=') - 1
""example x
""    | x > 0 = dummy *** this is conserned this line ***
""    | x == 0 = dummy
			else
				let same = s:prev_same_indent(cur_lnum, indent(cur_lnum))
				if s:is_start_with(getline(same), '|')
					return s:keep_indent
				endif
				let less = s:prev_less_indent(cur_lnum, indent(cur_lnum))
				"to return which is better when prev_such is not exist,
				"0 or keep_indent?
				if less == 0
					return 0
				endif
				if s:is_start_with(getline(less), '|')
					return indent(less)
				else
"				"unimplemented
					return s:keep_indent
				endif
			endif
		else
			return s:keep_indent
		endif
	endif
endfunction

function! s:is_in_do(lnum)
	let x = s:prev_less_indent(a:lnum, indent(a:lnum))
	if x == 0
		return v:false
	else
		return getline(x) =~# '\v<do>'
	endif
endfunction

function! s:is_end_with_equal(line)
	return s:is_end_with(a:line, '\v[[:blank:][:alnum:]_'')]\=')
endfunction

function! s:is_end_with_arrow(line)
	return s:is_end_with(a:line, '\v[-=>]+\>')
endfunction

function! s:is_end_with_open(line)
	return s:is_end_with(a:line, '\v[\([\{]+')
endfunction

function! s:is_module(line, lnum)
"module Example (
	"One,
	"Two ) where

"module Example
"(
	"One,
	"Two,
") where
	if s:is_start_with(a:line, '\v<module>')
		return v:true
	
	else
		if s:is_end_with(a:line, ')\s*\v<where>')
			let lnum_close_module = a:lnum
		else
			let lnum_close_module = s:prev_match(a:lnum, ')')
		endif
		let lnum_open_module = s:prev_match_pair(lnum_close_module, '(', ')')
		if lnum_open_module <= 0
			return v:false

		elseif lnum_open_module == 1
			return s:is_start_with(getline(lnum_open_module), '\v<module>')
		else
			return
			\ s:is_start_with(getline(lnum_open_module), '\v<module>') ||
			\ s:is_start_with(getline(prevnonblank(lnum_open_module - 1)), '\v<module>')
		endif
	endif
endfunction

function! s:is_close(line)
	return a:line =~# '\v[\)\]\}]'
endfunction

function! s:indent_as_match_open(line, lnum)
	let idx_last_close = s:last_match(a:line, '\v[\)\]\}]')
	let close = a:line[idx_last_close]
	let open = s:get_open_from_close(close)
	return s:indent_as_match_pair(a:lnum, open, close)
endfunction

function! s:is_open(line)
	return a:line =~# '\v[\(\[\{]'
endfunction

function! s:last_open_not_closed(line, open)
	let i = match(a:line, a:open)
	"[ and ] have special meaning in ()
	if a:open == '['
		let open = '\['
		let close = '\]'
	else
		let open = a:open
		let close = s:get_close_from_open(a:open)
	endif

	let list = []
	while i != -1
		if a:line[i] == a:open
			call add(list, i)
		else
			call remove(list, -1)
		endif
		let i = match(a:line, '\(' . open . '\|' . close . '\)', i + 1)
	endwhile
	return empty(list) ? s:keep_indent : list[-1]
endfunction

function! s:get_open_from_close(close)
	if a:close == ')'
		return '('
	elseif a:close == ']'
		return '['
	elseif a:close == '}'
		return '{'
	else
		return ''
	endif
endfunction

function! s:get_close_from_open(open)
	if a:open == '('
		return ')'
	elseif a:open == '['
		return ']'
	elseif a:open == '{'
		return '}'
	else
		return ''
	endif
endfunction

function! s:is_arrow_in_case(line)
	return a:line =~# '->' && s:is_start_with(a:line, '|')
endfunction

function! s:prev_case(lnum)
	let indent = indent(a:lnum)
	let i = s:prev_less_indent(a:lnum, indent)
	while i > 0
		if s:is_case(getline(i))
			return i
		endif
		let i = s:prev_less_indent(i, indent)
	endwhile
	return 0
endfunction

function! s:is_case(line)
	return a:line =~# '\v<case>'
endfunction

function! s:is_start_with_close(line)
	return s:is_start_with(a:line, '\v[\)\]\}]')
endfunction

function! s:prev_function(lnum)
	let i = a:lnum
	while i > 0
		let line = getline(i)
		if 
endfunction

"return value
"    line number if it is in data
"    0 if it is not in data
function! s:is_in_data_then_lnum(lnum)
	let i = a:lnum
	while i > 0
		let line = getline(i)
		if !s:is_start_with(line, '|')
			return s:is_start_with(line, '\v<data>') ? i : 0
		endif
		let i = s:prev_noncomment(i)
	endwhile
	return 0
endfunction

"function! s:is_in_where_then_lnum(lnum)
"	let i = a:lnum
"	while i > 0
"		let line = getline(i)
"		if
"		endif
"		let i = prevnonblank(i - 1)
"	endwhile
"	return 0
"endfunction

"function! s:is_in_let_then_lnum(lnum)
"endfunction

function! s:is_start_with_keywords(line)
	return a:line =~# '\v^\s*<%(data|type|newtype|class|instance|deriving|do|case|of|let|in|where|if|then|else|infix[rl]?|import|module)>'
endfunction


function! s:is_start_with(line, pattern)
	return a:line =~# '^\s*' . a:pattern
endfunction

function! s:is_end_with(line, pattern)
	return a:line =~# a:pattern . '\v\s*(--.*)?$'
endfunction

function! s:is_followed(line, pattern)
	return a:line =~# a:pattern && !s:is_end_with(a:line, a:pattern)
endfunction

function! s:prev_noncomment(lnum)
	let i = prevnonblank(a:lnum - 1)
	while i > 0
		if !s:is_comment(getline(i))
			return i
		endif
		let i = prevnonblank(i - 1)
	endwhile
	return 0
endfunction

function! s:is_comment(line)
	return a:line =~# '^\s*--'
endfunction

function! s:is_empty(line)
	return a:line =~# '\v^\s*$'
endfunction

function! s:inc_indent(indent)
	return a:indent + shiftwidth()
endfunction

function! s:dec_indent(indent)
	let x = a:indent - shiftwidth()
	return x > 0 ? x : 0
endfunction

function! s:prev_match(lnum, pattern)
	let i = s:prev_noncomment(a:lnum)
	while i > 0
		if getline(i) =~# a:pattern
			return i
		endif
		let i = s:prev_noncomment(i)
	endwhile
	return 0
endfunction

function! s:indent_as_match(lnum, pattern)
	let x = s:prev_match(a:lnum, a:pattern)
	if x == 0
		return s:keep_indent
	else
		return indent(x)
	endif
endfunction

function! s:prev_match_pair(lnum, open, close)
	let count_open = 0
	let count_close = 0
	let i = a:lnum
	while i > 0
		let line = getline(i)
		let count_open += s:count_match(line, a:open)
		let count_close += s:count_match(line, a:close)
		if count_open >= count_close
			return i
		endif
		let i = s:prev_noncomment(i)
	endwhile
	return 0
endfunction

function! s:indent_as_match_pair(lnum, open, close)
	let x = s:prev_match_pair(a:lnum, a:open, a:close)
	if x == 0 || x == a:lnum
		return s:keep_indent
	else
		return indent(x)
	endif
endfunction

function! s:align_as_match_pair(lnum, open, close)
	let x = s:prev_match_pair(a:lnum, a:open, a:close)
	if x == 0
		return s:keep_indent
	else
		return s:last_matchend(getline(x), a:open)
	endif
endfunction

function! s:count_match(line, pattern)
	"because incrementing count happens even not match
	let counter = -1
	let i = 0
	while i != -1
		let i = matchend(a:line, a:pattern, i)
		let counter += 1
	endwhile
	return counter
endfunction

function! s:last_match(line, pattern)
	let i = match(a:line, a:pattern)
	while i != -1
		let ret = i
		let i = match(a:line, a:pattern, i + 1)
	endwhile
	return ret
endfunction

function! s:last_matchend(line, pattern)
	let i = matchend(a:line, a:pattern)
	while i != -1
		let ret = i
		let i = matchend(a:line, a:pattern, i)
	endwhile
	return ret
endfunction

function! s:prev_less_indent(lnum, indent)
	if a:indent <= 0
		return 0
	endif

	let i = s:prev_noncomment(a:lnum)

	while i > 0
		if indent(i) < a:indent
			return i
		endif
		let i = s:prev_noncomment(i)
	endwhile
	return 0
endfunction

function! s:prev_same_indent(lnum, indent)
	let i = s:prev_noncomment(a:lnum)

	while i > 0
		let x = indent(i)
		if x == a:indent
			return i
		elseif x < a:indent
			return 0
		endif
		let i = s:prev_noncomment(i)
	endwhile
	return 0
endfunction

function! s:prev_same_or_less_indent(lnum, indent)
	let i = s:prev_noncomment(a:lnum)

	while i > 0
		if indent(i) <= a:indent
			return i
		endif
		let i = s:prev_noncomment(i)
	endwhile
	return 0
endfunction

let b:did_indent = 1

let &cpo = s:save_cpo
unlet s:save_cpo
