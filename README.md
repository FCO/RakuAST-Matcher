# RakuAST::Matcher

Library for matching/searching for nodes on RakuAST.

## Synopsis

```raku
use RakuAST::Matcher;

say ast-matcher("ANY-FUNCTION-WITH-ARGS(42)").search: "say 1 + 2 + 3 + 4; say(42)";
# ｢say(42)｣
#  ANY-FUNCTION-WITH-ARGS => ｢say(42)｣

say ast-matcher("say 42").search: "say 1 + 2 + 3 + 4; say 42; print 42";
# ｢say(42)｣

say ast-matcher("1 + ANYTHING").search: "say 1 + 2 + 3 + 4";
# ｢1 + 2｣
#  ANYTHING => ｢2｣

say ast-matcher("1 - ANYTHING").search: "say 1 + 2 + 3 + 4";
# (ASTMatch)

say ast-matcher("1").search: "say 1 + 2 + 3 + 4";
# ｢1｣
```
