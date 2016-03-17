## a list of reserved names from PyCall.jl
const reserved = Set{ASCIIString}()
for w in ("while", "if", "for", "try", "return", "break",
          "continue", "function", "macro", "quote", "let", "local",
          "global", "const", "abstract", "typealias", "type",
          "bitstype", "immutable", "ccall", "do", "module",
          "baremodule", "using", "import", "export", "importall",
          "false", "true")
    push!(reserved, w)
end

function rwrap(pkg::ASCIIString,s::Symbol)
    reval("library($pkg)")
    members = rcopy("ls('package:$pkg')")
    filter!(x -> !(x in reserved), members)
    m = Module(s)
    consts = [Expr(:const,
                    Expr(:(=),
                    symbol(x),
                    rcall(symbol("::"),symbol(pkg),symbol(x)))
                ) for x in members]
    id = Expr(:(=), :__package__, pkg)
    exports = [symbol(x) for x in members]
    s in exports && error("$pkg has a function with the same name as $(pkg), use `@rimport $pkg as ...` instead.")
    eval(m, Expr(:toplevel, consts..., Expr(:export, exports...), id, Expr(:(=), :__exports__, exports)))
    m
end

"Import a R Package as a Julia module. You can also use classic Python syntax to make an alias: `@rimport *module-name* as *shorthand*`"
macro rimport(x, args...)
    if length(args)==2 && args[1] == :as
        m = args[2]
    elseif length(args)==0
        m = x
    else
        throw(ArgumentError("invalid import syntax."))
    end
    pkg = string(x)
    sym = Expr(:quote, m)
    quote
        if !isdefined($sym)
            const $(esc(m)) = rwrap($pkg, $sym)
            nothing
        elseif typeof($(esc(m))) <: Module &&
                    :__package__ in names($(esc(m)), true) &&
                    $(esc(m)).__package__ == $pkg
            nothing
        else
            error("$($sym) already exists!")
            nothing
        end
    end
end

"""
Load all exported functions/objects of a R package to the current module.
"""
macro rlibrary(x)
    pkg = Expr(:quote, x)
    quote
        reval("library($($pkg))")
        members = rcopy("ls('package:$($pkg)')")
        filter!(x -> !(x in reserved), members)
        for m in members
            sym = symbol(m)
            eval(current_module(), Expr(
                    :(=),
                    sym,
                    Expr(:call, :rcall, QuoteNode(symbol("::")), QuoteNode($pkg), QuoteNode(sym))
                )
            )
        end
    end
end

macro rusing(x)
    pkg = Expr(:quote, x)
    quote
        error("`@rusing $($pkg)` is deprecated, please use the syntax `@rlibrary $($pkg)`.")
    end
end