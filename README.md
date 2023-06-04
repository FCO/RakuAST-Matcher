# RakuAST::Matcher

Library for matching/searching for nodes on RakuAST.

## Synopsis

```raku
use RakuAST::Matcher -e '

say ast-matcher("ANY-FUNCTION-WITH-ARGS(42)").search: "say 1 + 2 + 3 + 4; say(42)"
```

It will print:

```
｢say(1 + 2 + 3 + 4);
say(42)
｣
 0 => ｢say(42)｣
  ANY-FUNCTION-WITH-ARGS => ｢say(42)｣
```
