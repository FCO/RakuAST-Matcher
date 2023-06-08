use v6.e.PREVIEW;

unit class RakuAST::Matcher;

has RakuAST::Node $.ast;

class Match does Positional does Associative {
    has @.positional; # handles <AT-POS EXISTS-POS>;
    has %.named     ; # handles <keys AT-KEY EXISTS-KEY>;
    has RakuAST::Node $.node;
    method of { Match }

    multi method gist(::?CLASS:D:) {
        with $!node {
            qq:to<END>.chomp;
            ｢{
              .DEPARSE
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
        } else {
            @!positional.map(*.gist).join("\n")
        }
    }
}

method ACCEPTS($ast) {
    match $!ast, $ast
}

multi method search(Str $ast --> Match) {
    self.search($ast.AST)
}
multi method search(RakuAST::Node $ast --> Match) {
    my @positional = $ast.map({ match $!ast, $_ }).grep({ .defined });
    @positional
    ?? Match.new(:@positional)
    !! Match
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
    my @*positional;
    my %*named;
    Match.new: node => $ast, :@*positional, :%*named
}
sub ANY-FUNCTION(
    RakuAST::Call::Name $needle,
    RakuAST::Call::Name $ast,
) is export {
    my @*positional;
    my %*named;
    Match.new: node => $ast, :@*positional, :%*named
}
sub ANY-FUNCTION-WITH-ARGS(
    RakuAST::Call::Name $needle,
    RakuAST::Call::Name $ast,
) is export {
    my @*positional;
    my %*named;
    match($needle.args, $ast.args)
    && Match.new: node => $ast, :@*positional, :%*named
}
sub ANY-FUNCTION-NAMED(
    RakuAST::Call::Name $needle,
    RakuAST::Call::Name $ast where *.name.canonicalize eq $needle.args.args.head.literal-value,
) is export {
    my @*positional;
    my %*named;
    Match.new: node => $ast, :@*positional, :%*named
}

for [ &ANYTHING, &ANY-FUNCTION, &ANY-FUNCTION-WITH-ARGS, &ANY-FUNCTION-NAMED ] -> $matcher {
    $matcher does MatcherFunction;
}

sub match($needle, $ast) is export {
    DEBUG $?LINE, ": ", $needle.^name, " ~~ ", $ast.^name;
    my @*positional;
    my %*named;
    my Bool() $res = so _match $needle, $ast;

    $res
    ?? Match.new(node => $ast, :@*positional, :%*named)
    !! Match
}

proto _match($needle, $ast --> Match) {*}

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
