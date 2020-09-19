#!/usr/bin/env tarantool

local jsonpath = require('jsonpath')
local tap = require('tap')
local test = tap.test('jsonpath')
test:plan(2)

local function test_basic(test)
    test:plan(18)

    local path = "[1].field1.field2['field3'][5]"
    test:ok(jsonpath.validate(path))
    local tokens = jsonpath.extract_tokens(path)
    test:is_deeply(tokens, {
        {type = jsonpath.JSON_TOKEN_TYPE.JSON_TOKEN_NUM, value = 1},
        {type = jsonpath.JSON_TOKEN_TYPE.JSON_TOKEN_STR, value = 'field1'},
        {type = jsonpath.JSON_TOKEN_TYPE.JSON_TOKEN_STR, value = 'field2'},
        {type = jsonpath.JSON_TOKEN_TYPE.JSON_TOKEN_STR, value = 'field3'},
        {type = jsonpath.JSON_TOKEN_TYPE.JSON_TOKEN_NUM, value = 5},
        {type = jsonpath.JSON_TOKEN_TYPE.JSON_TOKEN_END},
    })

    path = "[3].field[2].field"
    test:ok(jsonpath.validate(path))
    tokens = jsonpath.extract_tokens(path)
    test:is_deeply(tokens, {
        {type = jsonpath.JSON_TOKEN_TYPE.JSON_TOKEN_NUM, value = 3},
        {type = jsonpath.JSON_TOKEN_TYPE.JSON_TOKEN_STR, value = 'field'},
        {type = jsonpath.JSON_TOKEN_TYPE.JSON_TOKEN_NUM, value = 2},
        {type = jsonpath.JSON_TOKEN_TYPE.JSON_TOKEN_STR, value = 'field'},
        {type = jsonpath.JSON_TOKEN_TYPE.JSON_TOKEN_END},
    })

    path = "[\"f1\"][\"f2'3'\"]"
    test:ok(jsonpath.validate(path))
    tokens = jsonpath.extract_tokens(path)
    test:is_deeply(tokens, {
        {type = jsonpath.JSON_TOKEN_TYPE.JSON_TOKEN_STR, value = 'f1'},
        {type = jsonpath.JSON_TOKEN_TYPE.JSON_TOKEN_STR, value = "f2'3'"},
        {type = jsonpath.JSON_TOKEN_TYPE.JSON_TOKEN_END},
    })

    path = ".field1"
    test:ok(jsonpath.validate(path))
    tokens = jsonpath.extract_tokens(path)
    test:is_deeply(tokens, {
        {type = jsonpath.JSON_TOKEN_TYPE.JSON_TOKEN_STR, value = 'field1'},
        {type = jsonpath.JSON_TOKEN_TYPE.JSON_TOKEN_END},
    })

    path = "[1234]"
    test:ok(jsonpath.validate(path))
    tokens = jsonpath.extract_tokens(path)
    test:is_deeply(tokens, {
        {type = jsonpath.JSON_TOKEN_TYPE.JSON_TOKEN_NUM, value = 1234},
        {type = jsonpath.JSON_TOKEN_TYPE.JSON_TOKEN_END},
    })

    path = ""
    test:ok(jsonpath.validate(path))
    tokens = jsonpath.extract_tokens(path)
    test:is_deeply(tokens, {
        {type = jsonpath.JSON_TOKEN_TYPE.JSON_TOKEN_END},
    })

    path = "field1.field2"
    test:ok(jsonpath.validate(path))
    tokens = jsonpath.extract_tokens(path)
    test:is_deeply(tokens, {
        {type = jsonpath.JSON_TOKEN_TYPE.JSON_TOKEN_STR, value = 'field1'},
        {type = jsonpath.JSON_TOKEN_TYPE.JSON_TOKEN_STR, value = 'field2'},
        {type = jsonpath.JSON_TOKEN_TYPE.JSON_TOKEN_END},
    })

    path = "[2][6]['привет中国world']['中国a']"
    test:ok(jsonpath.validate(path))
    tokens = jsonpath.extract_tokens(path)
    test:is_deeply(tokens, {
        {type = jsonpath.JSON_TOKEN_TYPE.JSON_TOKEN_NUM, value = 2},
        {type = jsonpath.JSON_TOKEN_TYPE.JSON_TOKEN_NUM, value = 6},
        {type = jsonpath.JSON_TOKEN_TYPE.JSON_TOKEN_STR, value = 'привет中国world'},
        {type = jsonpath.JSON_TOKEN_TYPE.JSON_TOKEN_STR, value = '中国a'},
        {type = jsonpath.JSON_TOKEN_TYPE.JSON_TOKEN_END},
    })

    path = "[2][6][*][2][6]"
    test:ok(jsonpath.validate(path))
    tokens = jsonpath.extract_tokens(path)
    test:is_deeply(tokens, {
        {type = jsonpath.JSON_TOKEN_TYPE.JSON_TOKEN_NUM, value = 2},
        {type = jsonpath.JSON_TOKEN_TYPE.JSON_TOKEN_NUM, value = 6},
        {type = jsonpath.JSON_TOKEN_TYPE.JSON_TOKEN_ANY},
        {type = jsonpath.JSON_TOKEN_TYPE.JSON_TOKEN_NUM, value = 2},
        {type = jsonpath.JSON_TOKEN_TYPE.JSON_TOKEN_NUM, value = 6},
        {type = jsonpath.JSON_TOKEN_TYPE.JSON_TOKEN_END},
    })
end

local function test_errors(test)
    local test_cases = {
        -- Double [[
        {"[[", 2},
        -- Not string inside []
        {"[field]", 2},
        -- String outside of []
        {"'field1'.field2", 1},
        -- Empty brackets
        {"[]", 2},
        -- Empty string
        {"''", 1},
        -- Spaces between identifiers
        {" field1", 1},
        -- Start from digit
        {"1field", 1},
        {".1field", 2},
        -- Unfinished identifiers
        {"['field", 8},
        {"['field'", 9},
        {"[123", 5},
        {"['']", 3},
        {"[\"a\"].b.c[4", 12},
        -- Not trivial error: can not write '[]' after '.'
        {".[123]", 2},
        -- Misc
        {"[.]", 2},
        -- Invalid UNICODE */
        {"['aaa\xc2\xc2']", 6},
        {".\xc2\xc2", 2},
    }
    test:plan(#test_cases)
    for _, test_case in ipairs(test_cases) do
        local _, err = jsonpath.validate(test_case[1])
        test:is(test_case[2], err, ('%s (%d)'):format(test_case[1], test_case[2]))
    end
end

test:test('test_basic', test_basic)
test:test('test_errors', test_errors)

os.exit(test:check() and 0 or 1)
