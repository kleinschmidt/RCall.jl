# R formula to julia Formula

# a special wrapper for rcopy specialized for formulas
function rcopy_formula(s::Ptr{S}) where S<:Sxp
    r = rcopy(s)
    if isa(r, Number) && isinteger(r)
        Int(r)
    else
        r
    end
end

function rcopy(::Type{Expr}, l::Ptr{LangSxp})
    op = rcopy(Symbol, l[1])
    if op == :(:)
        op = :&
    end
    args = cdr(l)
    if op == Symbol("(")
        f = rcopy(Expr, l[2])
    else
        f = Expr(:call, op,
            [ isNull(t) ? rcopy_formula(s) : Expr(:(=), rcopy_formula(t), rcopy_formula(s))
                for (t, s) in enumerate(args)]...)
    end
    # unwind these opeators
    if op in (:+, :*, :&) && isa(f.args[2], Expr) && f.args[2].args[1] == op
        f = Expr(:call, op, f.args[2].args[2:end]..., f.args[3])
    end
    f
end

function rcopy(::Type{Formula}, l::Ptr{LangSxp})
    Formula(rcopy(l[2]), rcopy(l[3]))
end


# julia Formula to R formula

# formula
function sexp_formula(e::Expr)
    e.head == :call || error("invalid formula object")
    op = e.args[1]
    if op == :&
        op = :(:)
    end
    if length(e.args) > 3 && op in (:+, :*, :(:))
        rlang_p(op, sexp_formula(Expr(e.head, e.args[1:end-1]...)), sexp_formula(e.args[end]))
    else
        rlang_p(op, map(sexp_formula, e.args[2:end])...)
    end
end
sexp_formula(e::Symbol) = sexp(SymSxp, e)
sexp_formula(n::Integer) = sexp(RealSxp, Float64(n))
sexp_formula(n::Number) = sexp(n)


# R formula objects
function sexp(::Type{LangSxp}, f::Formula)
    s = protect(rlang_p(:~, sexp_formula(f.lhs), sexp_formula(f.rhs)))
    try
        setattrib!(s, Const.ClassSymbol, sexp("formula"))
        setattrib!(s, ".Environment", Const.GlobalEnv)
    finally
        unprotect(1)
    end
    s
end
