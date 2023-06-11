use v6.e.PREVIEW;
use experimental :rakuast;
use RakuAST::Matcher::ASTMatch;
use RakuAST::Matcher::ASTMatcherFunction;

unit class RakuAST::Matcher;

has RakuAST::Node $.ast;

method ACCEPTS($ast) {
    match $!ast, $ast
}

multi method search(Str $ast --> ASTMatch) {
    self.search($ast.AST)
}
multi method search(RakuAST::Node $ast --> ASTMatch) {
    my @positional = $ast.map({ match $!ast, $_ }).grep({ .defined });
    @positional
    ?? ASTMatch.new(:@positional)
    !! ASTMatch
}

proto ast-matcher(|c) is export {*}

multi ast-matcher(Str $needle) {
    my $ast = $needle.AST.statements[0].expression;
    ast-matcher($ast)
}

multi ast-matcher(RakuAST::Node $needle) {
    RakuAST::Matcher.new(ast => $needle)
}

sub ANYTHING(
    RakuAST::Call::Name $needle,
    RakuAST::Node       $ast,
) is matcher-function {
    my @*positional;
    my %*named;
    ASTMatch.new: node => $ast, :@*positional, :%*named
}
sub ANY-FUNCTION(
    RakuAST::Call::Name $needle,
    RakuAST::Call::Name $ast,
) is matcher-function {
    my @*positional;
    my %*named;
    ASTMatch.new: node => $ast, :@*positional, :%*named
}
sub ANY-FUNCTION-WITH-ARGS(
    RakuAST::Call::Name $needle,
    RakuAST::Call::Name $ast,
) is matcher-function {
    my @*positional;
    my %*named;
    match($needle.args, $ast.args)
    && ASTMatch.new: node => $ast, :@*positional, :%*named
}
sub ANY-FUNCTION-NAMED(
    RakuAST::Call::Name $needle,
    RakuAST::Call::Name $ast where *.name.canonicalize eq $needle.args.args.head.literal-value,
) is export {
    my @*positional;
    my %*named;
    ASTMatch.new: node => $ast, :@*positional, :%*named
}

sub match($needle, $ast) is export {
    DEBUG $?LINE, ": ", $needle.^name, " ~~ ", $ast.^name;
    my @*positional;
    my %*named;
    my Bool() $res = so _match $needle, $ast;

    $res
    ?? ASTMatch.new(node => $ast, :@*positional, :%*named)
    !! ASTMatch
}

proto _match($needle, $ast --> ASTMatch) {*}

multi _match(Str $needle, RakuAST::Node $haystack) {
    my $ast  = $needle.AST.statements[0].expression;
    match $ast, $haystack
}

multi _match(
    RakuAST::Call::Name $needle where { ::("&{ .name.canonicalize }").?is-matcher-function },
    RakuAST::Node       $ast where { True },
) {
    DEBUG $?LINE, ": ", $needle.^name, " ~~ ", $ast.^name;
    my &func = ::("&{ $needle.name.canonicalize }");
    return False unless \($needle, $ast) ~~ &func.signature;
    my $ret = func $needle, $ast;
    %*named.push: $needle.name.canonicalize => $_ with $ret;
    $ret
}

multi _match(RakuAST::Name $needle, RakuAST::Name $ast) {
    DEBUG $?LINE, ": ", $needle.^name, " ~~ ", $ast.^name;
    $needle.canonicalize eq $ast.canonicalize
}

multi _match(::T RakuAST::Literal $needle, T $ast) {
    DEBUG $?LINE, ": ", $needle.^name, " ~~ ", $ast.^name;
    $needle.value ~~ $ast.value
}

multi _match(::T RakuAST::Node $needle where {.^can: "operator"}, T $ast) {
    DEBUG $?LINE, ": ", $needle.^name, " ~~ ", $ast.^name;
    $needle.operator ~~ $ast.operator
}

multi _match(::T RakuAST::Node $needle, T $ast) {
    DEBUG $?LINE, ": ", $needle.^name, " ~~ ", $ast.^name;
    my @needle = gather { $needle.visit-children: *.take };
    my @ast    = gather { $ast.visit-children: *.take };

    #@needle ~~ @ast
    [&&] (@needle Z @ast).map({ _match(|$_) })
}

multi _match($needle, $ast) {
    DEBUG $?LINE, ": ", $needle.^name, " ~~ ", $ast.^name;
    False
}

sub DEBUG(*@data) {
    note |@data if $*DEBUG
}
