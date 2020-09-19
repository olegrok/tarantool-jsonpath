#!/usr/bin/env tarantool

local clock = require('clock')
local jsonpath = require('jsonpath')

local start = clock.monotonic()
for _ = 1,1e6 do
    jsonpath.validate('["a.b"].c[3].d[*][5]')
end
print('Validate total: ', clock.monotonic() - start)

start = clock.monotonic()
for _ = 1,1e6 do
    jsonpath.extract_tokens('["a.b"].c[3].d[*][5]')
end
print('Validate total: ', clock.monotonic() - start)
