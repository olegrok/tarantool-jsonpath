# Tarantool jsonpath introspection tool

### Validation
```yaml
jsonpath = require('jsonpath')
tarantool> jsonpath.validate('["a"].b.c[4]') -- valid jsonpath
---
- true
...
tarantool> jsonpath.validate('["a"].b.c[4')  -- invalid jsonpath
---
- false
- 12 -- bad position
...
```

### Token extraction
```yaml
jsonpath = require('jsonpath')
tarantool> jsonpath.extract_tokens('["a"].b.c[4][*]')
---
- 1:
    type: 2
    value: a
  2:
    type: 2
    value: b
  3:
    type: 2
    value: c
  4:
    type: 1
    value: 4
  5:
    type: 3
  6:
    type: 4
...
tarantool> jsonpath.JSON_TOKEN_TYPE
---
- JSON_TOKEN_END: 4
  JSON_TOKEN_ANY: 3
  JSON_TOKEN_NUM: 1
  JSON_TOKEN_STR: 2
...
```
