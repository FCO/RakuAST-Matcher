use v6.e.PREVIEW;
unit class RakuAST::Matcher::ASTMatch does Positional does Associative;

has @.positional handles <AT-POS EXISTS-POS>;
has %.named      handles <keys AT-KEY EXISTS-KEY>;
has RakuAST::Node $.node;
method of { ::?CLASS }

method elems {
    ($!node ?? 1 !! 0) + @!positional.elems + %!named.elems
}

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
