# Example parser for a very basic language of expressions, calls and function
# definitions.

function parse_toplevel(st)
    mark = position(st)
    while true
        bump_trivia(st, skip_newlines=true)
        if peek(st) == K"EndMarker"
            break
        end
        parse_statement(st)
    end
    emit(st, mark, K"toplevel")
end

function parse_statement(st)
    mark = position(st)
    if peek(st) == K"function"
        parse_function_def(st)
    else
        parse_assignment(st)
    end
end

function parse_function_def(st)
    mark = position(st)
    @assert peek(st) == K"function"
    bump(st, TRIVIA_FLAG)
    parse_call(st)
    parse_block(st, K"end")
    @assert peek(st) == K"end"
    bump(st, TRIVIA_FLAG)
    emit(st, mark, K"function")
end

function parse_block(st, closing_kind)
    mark = position(st)
    while true
        bump_trivia(st, skip_newlines=true)
        if peek(st) == closing_kind
            break
        elseif peek(st) == K"EndMarker"
            emit_diagnostic(st, error="Unexpecte end of input")
            break
        end
        parse_assignment(st)
    end
    emit(st, mark, K"block")
end

function parse_assignment(st)
    mark = position(st)
    parse_expression(st)
    if peek(st) == K"="
        bump(st, TRIVIA_FLAG)
        parse_expression(st)
        emit(st, mark, K"=")
    end
end

function parse_expression(st)
    mark = position(st)
    parse_term(st)
    while peek(st) in (K"+", K"-")
        bump(st)
        parse_term(st)
        emit(st, mark, K"call", INFIX_FLAG)
    end
end

function parse_term(st)
    mark = position(st)
    parse_call(st)
    while peek(st) in (K"*", K"/")
        bump(st)
        parse_call(st)
        emit(st, mark, K"call", INFIX_FLAG)
    end
end

function parse_call(st)
    mark = position(st)
    parse_atom(st)
    flags = EMPTY_FLAGS
    if peek(st) == K"("
        bump(st, TRIVIA_FLAG)
        need_comma = false
        while true
            k = peek(st)
            if need_comma && k == K","
                bump(st, TRIVIA_FLAG)
                k = peek(st)
                need_comma = false
            end
            if k == K")"
                bump(st, TRIVIA_FLAG)
                break
            elseif k == K"EndMarker"
                emit_diagnostic(st, error="Unexpected end of input")
                flags = ERROR_FLAG
                break
            elseif need_comma
                emit_diagnostic(st, error="Expected a `,`")
                flags = ERROR_FLAG
            end
            parse_expression(st)
            need_comma = true
        end
        emit(st, mark, K"call", flags)
    end
end

function parse_atom(st)
    bump_trivia(st, skip_newlines=true)
    mark = position(st)
    k = peek(st)
    if k == K"Identifier" || isliteral(k)
        bump(st)
    elseif k in (K"-", K"+")
        bump(st)
        parse_atom(st)
        emit(st, mark, K"call")
    elseif k == K"("
        bump(st, TRIVIA_FLAG)
        parse_expression(st)
        if peek(st) == K")"
            bump(st, TRIVIA_FLAG)
            # emit(st, mark, K"(")
        else
            emit(st, mark, K"(",
                 error="Expected `)` following expression")
        end
    else
        bump(st)
        emit(st, mark, K"Error",
             error="Expected literal, identifier or opening parenthesis")
    end
end

function parse_and_show(production::Function, code)
    st = ParseStream(code)
    production(st)
    t = JuliaSyntax.to_raw_tree(st, wrap_toplevel_as_kind=K"Error")
    show(stdout, MIME"text/plain"(), t, code, show_trivia=true)
    if !isempty(st.diagnostics)
        println()
        for d in st.diagnostics
            JuliaSyntax.show_diagnostic(stdout, d, code)
        end
    end
    t
end

println()
println("Example diagnostics:")
parse_and_show(parse_expression, "(x + a*y) * (b")

println()
println("Example good parse:")
parse_and_show(parse_toplevel,
               """
               function f(x, y)
                   z = (x + y) * 2
                   z * z
               end

               f(1,2)
               """)

nothing