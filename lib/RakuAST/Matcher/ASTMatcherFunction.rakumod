use experimental :rakuast;
unit role RakuAST::Matcher::ASTMatcherFunction;

method is-matcher-function { True }

multi trait_mod:<is>(
    Sub $func,
    :$matcher-function
) is export {
    trait_mod:<is>($func, :export);
    $func does RakuAST::Matcher::ASTMatcherFunction
}

