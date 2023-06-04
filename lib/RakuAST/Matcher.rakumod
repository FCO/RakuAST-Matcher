use v6.e.PREVIEW;

unit class RakuAST::Matcher;

has RakuAST::Node $.ast;

class Match does Positional does Associative {
    has @.positional; # handles <AT-POS EXISTS-POS>;
    has %.named     ; # handles <keys AT-KEY EXISTS-KEY>;
    has RakuAST::Node $.node;
    method of { Match }

    multi method gist(::?CLASS:D:) {
        qq:to<END>.chomp;
        ｢{
          .DEPARSE with $!node
        }｣{
            do if @!positional {
                "\n" ~ @!positional.kv.map(-> $i, $_ { "$i => { .gist }" }).join("\n").indent: 1
            }
        }{
            do if %!named {
                "\n" ~ %!named.kv.map(-> $i, $_ {"$i => { .gist }"}).join("\n").indent: 1
            }
        }
        END
    }
}

method ACCEPTS($ast) {
    match $!ast, $ast
}

multi method search(Str $ast) {
    self.search($ast.AST)
}
multi method search(RakuAST::Node $ast) {
    Match.new: :node($ast), :positional($ast.map({ match $!ast, $_ }).grep({ .defined }))
}

proto ast-matcher(|c) is export {*}

multi ast-matcher(Str $needle) {
    my $ast = $needle.AST.statements[0].expression;
    ast-matcher($ast)
}

multi ast-matcher(RakuAST::Node $needle) {
    RakuAST::Matcher.new(ast => $needle)
}

role MatcherFunction {
    method is-matcher-function { True }
}

# sub trait_mod:<is>(&func, Bool :$matcher-function) {
#     # trait_mod:<is>(&func, :export);
#     &func does MatcherFunction
# }

sub ANYTHING(
    RakuAST::Call::Name $needle,
    RakuAST::Node       $ast,
) is export {
    %*named<ANYTHING> = Match.new(node => $ast)
}
sub ANY-FUNCTION(
    RakuAST::Call::Name $needle,
    RakuAST::Call::Name $ast,
) is export {
    %*named<ANY-FUNCTION> = Match.new(node => $ast)
}
sub ANY-FUNCTION-WITH-ARGS(
    RakuAST::Call::Name $needle,
    RakuAST::Call::Name $ast,
) is export {
    match($needle.args, $ast.args)
    && (%*named<ANY-FUNCTION-WITH-ARGS> = Match.new(node => $ast, :@*positional, :%*named))
}
sub ANY-FUNCTION-NAMED(
    RakuAST::Call::Name $needle,
    RakuAST::Call::Name $ast where *.name.canonicalize eq $needle.args.args.head.literal-value,
) is export {
    %*named<ANY-FUNCTION-NAMED> = Match.new(node => $ast)
}

for [ &ANYTHING, &ANY-FUNCTION, &ANY-FUNCTION-WITH-ARGS, &ANY-FUNCTION-NAMED ] -> $matcher {
    $matcher does MatcherFunction;
}

proto match($needle, $ast) is export {
    DEBUG $?LINE, ": ", $needle.^name, " ~~ ", $ast.^name;
    my @*positional;
    my %*named;
    my Bool() $res = so {*};

    $res
    ?? Match.new(node => $ast, :@*positional, :%*named)
    !! Match
}

multi match(Str $needle, RakuAST::Node $haystack) {
    my $ast  = $needle.AST.statements[0].expression;
    match $ast, $haystack
}

multi match(
    RakuAST::Call::Name $needle where { ::("&{ .name.canonicalize }").is-matcher-function },
    RakuAST::Node       $ast where { True },
) {
    DEBUG $?LINE, ": ", $needle.^name, " ~~ ", $ast.^name;
    my &func = ::("&{ $needle.name.canonicalize }");
    return False unless \($needle, $ast) ~~ &func.signature;
    func $needle, $ast
}

multi match(RakuAST::Name $needle, RakuAST::Name $ast) {
    DEBUG $?LINE, ": ", $needle.^name, " ~~ ", $ast.^name;
    $needle.canonicalize eq $ast.canonicalize
}

multi match(RakuAST::ApplyInfix $needle, RakuAST::ApplyInfix $ast) {
    DEBUG $?LINE, ": ", $needle.^name, " ~~ ", $ast.^name;
       match($needle.left , $ast.left )
     & match($needle.right, $ast.right)
     & match($needle.infix, $ast.infix)
}

multi match(RakuAST::ApplyPostfix $needle, RakuAST::ApplyPostfix $ast) {
    DEBUG $?LINE, ": ", $needle.^name, " ~~ ", $ast.^name;
       match($needle.operand, $ast.operand)
     & match($needle.postfix, $ast.postfix)
}

multi match(
    RakuAST::Call::Name $needle,
    RakuAST::Call::Name $ast where {
        my $f = ::("&{ .name.canonicalize }");
        $f.Bool && $f.?is-matcher-function
    }
) {
    DEBUG $?LINE, ": ", $needle.^name, " ~~ ", $ast.^name;
       match($needle.name, $ast.name)
     & match($needle.args, $ast.args)
}

multi match(RakuAST::Infix $needle, RakuAST::Infix $ast) {
    DEBUG $?LINE, ": ", $needle.^name, " ~~ ", $ast.^name;
    $needle.operator eq $ast.operator
}

multi match(RakuAST::VarDeclaration::Simple $needle, RakuAST::VarDeclaration::Simple $ast) {
    DEBUG $?LINE, ": ", $needle.^name, " ~~ ", $ast.^name;
       ($needle.?name // "") eq ($ast.?name // "")
     & match($needle.?initializer, $ast.?initializer)
}

multi match(RakuAST::Initializer $needle, RakuAST::Initializer $ast) {
    DEBUG $?LINE, ": ", $needle.^name, " ~~ ", $ast.^name;
    match($needle.?expression, $ast.?expression)
}

multi match(RakuAST::Initializer::Assign $needle, RakuAST::Initializer::Assign $ast) {
    DEBUG $?LINE, ": ", $needle.^name, " ~~ ", $ast.^name;
       match($needle.expression, $ast.expression)
}

multi match(RakuAST::ArgList $needle, RakuAST::ArgList $ast) {
    DEBUG $?LINE, ": ", $needle.^name, " ~~ ", $ast.^name;
    ($needle.args Z $ast.args).map({ match(|$_) }).all
}

multi match(RakuAST::IntLiteral $needle, RakuAST::IntLiteral $ast) {
    DEBUG $?LINE, ": ", $needle.^name, " ~~ ", $ast.^name;
    $needle.value == $ast.value
}

multi match(::T RakuAST::Node $needle, T $ast) {
    DEBUG $?LINE, ": ", $needle.^name, " ~~ ", $ast.^name;
    note "{ T.^name } matcher not implemented yet: ", $ast;
    False
}

multi match($needle, $ast) {
    DEBUG $?LINE, ": ", $needle.^name, " ~~ ", $ast.^name;
    False
}

sub DEBUG(*@data) {
    note |@data if $*DEBUG
}
