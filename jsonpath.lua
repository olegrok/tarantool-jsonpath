local utf8 = require('utf8')

local JSON_TOKEN_TYPE = {
	JSON_TOKEN_NUM = 1,
	JSON_TOKEN_STR = 2,
	JSON_TOKEN_ANY = 3,
    -- Lexer reached end of path.
	JSON_TOKEN_END = 4,
}

local ZERO_BYTE = string.byte('0')
local UNDERSCORE_BYTE = string.byte('_')
local OPEN_BRACKET_BYTE = string.byte('[')
local CLOSE_BRACKET_BYTE = string.byte(']')
local SINGLE_QUOTE_BYTE = string.byte('\'')
local DOUBLE_QUOTE_BYTE = string.byte('"')
local STAR_BYTE = string.byte('*')
local DOT_BYTE = string.byte('.')

local function json_lexer_new(src, base)
    return {
        src = src,
        src_len = #src,
        offset = 1,
        symbol_count = 0,
        index_base = base,
    }
end

-- json token
-- {
--      type = ...,
--      value = ...,
-- }

local function json_lexer_is_eof(lexer)
    return lexer.offset == lexer.src_len + 1
end

local function json_read_symbol(lexer)
    if json_lexer_is_eof(lexer) then
        return nil, lexer.symbol_count + 1
    end

    local offset, codepoint = utf8.next(lexer.src, lexer.offset)
    if codepoint == nil then
        return nil, lexer.symbol_count + 1
    end

    lexer.offset = offset
    lexer.symbol_count = lexer.symbol_count + 1

    return codepoint
end

local function json_current_char(lexer)
    local _, codepoint = utf8.next(lexer.src, lexer.offset)
    return codepoint
end

local function json_skip_char(lexer)
    lexer.offset = lexer.offset + 1
    lexer.symbol_count = lexer.symbol_count + 1
end

local function json_parse_string(lexer, token, quote_type)
    json_skip_char(lexer)
    local str_offset = lexer.offset
    local char, err
    while true do
        char, err = json_read_symbol(lexer)
        if err ~= nil then
            return nil, err
        end

        if char == quote_type then
            local len = lexer.offset - str_offset - 1
            if len == 0 then
                return nil, lexer.symbol_count
            end
            token.type = JSON_TOKEN_TYPE.JSON_TOKEN_STR
            token.value = utf8.sub(lexer.src, str_offset, str_offset + len - 1)
            return nil
        end
    end
end

local function json_parse_integer(lexer, token)
    local offset, codepoint = utf8.next(lexer.src, lexer.offset)

    if not utf8.isdigit(codepoint) then
        return nil, lexer.symbol_count + 1
    end

    local value = 0
    local len = 0
    repeat
        value = value * 10 + codepoint - ZERO_BYTE
        len = len + 1

        offset, codepoint = utf8.next(lexer.src, offset)
    until not (offset + len < lexer.src_len and utf8.isdigit(codepoint))

    if value < lexer.index_base then
        return nil, lexer.symbol_count + 1
    end

    lexer.offset = lexer.offset + len
	lexer.symbol_count = lexer.symbol_count + len
	token.type = JSON_TOKEN_TYPE.JSON_TOKEN_NUM
	token.value = value - lexer.index_base
    return nil
end

local function json_revert_symbol(lexer, offset)
    lexer.offset = offset
    lexer.symbol_count = lexer.symbol_count - 1
end

local function json_is_valid_identifier_symbol(char)
	return utf8.isalpha(char) or char == UNDERSCORE_BYTE or utf8.isdigit(char);
end

local function json_parse_identifier(lexer, token)
    local str_offset = lexer.offset;
    local char, err = json_read_symbol(lexer)
    if err ~= nil then
        return nil, err
    end

    -- First symbol can not be digit
    if (not utf8.isalpha(char)) and char ~= UNDERSCORE_BYTE then
        return nil, lexer.symbol_count
    end

    local last_offset = lexer.offset;
    while true do
        char, err = json_read_symbol(lexer)
        if err ~= nil then
            break
        end

        if not json_is_valid_identifier_symbol(char) then
            json_revert_symbol(lexer, last_offset)
            break
        end
        last_offset = lexer.offset
    end

    token.type = JSON_TOKEN_TYPE.JSON_TOKEN_STR
    token.value = utf8.sub(lexer.src, str_offset, lexer.offset - 1)
end

local function json_lexer_next_token(lexer, token)
    if json_lexer_is_eof(lexer) then
        token.type = JSON_TOKEN_TYPE.JSON_TOKEN_END
        token.value = nil
        return
    end

    local char, err = json_read_symbol(lexer)
    if err ~= nil then
        return nil, err
    end

    local last_offset = lexer.offset;
    if char == OPEN_BRACKET_BYTE then
        if json_lexer_is_eof(lexer) then
            return nil, lexer.symbol_count
        end

        local _, err
        char = json_current_char(lexer)
        if char == SINGLE_QUOTE_BYTE or char == DOUBLE_QUOTE_BYTE then
			_, err = json_parse_string(lexer, token, char);
		elseif char == STAR_BYTE then
			json_skip_char(lexer)
			token.type = JSON_TOKEN_TYPE.JSON_TOKEN_ANY
			token.value = nil
		else
			_, err = json_parse_integer(lexer, token)
		end

        if err ~= nil then
            return nil, err
        end

        --
		-- Expression, started from [ must be finished
		-- with ] regardless of its type.
		--
        if json_lexer_is_eof(lexer) or json_current_char(lexer) ~= CLOSE_BRACKET_BYTE then
            return nil, lexer.symbol_count + 1
        end

        json_skip_char(lexer);
        return nil
    elseif char == DOT_BYTE then
        if json_lexer_is_eof(lexer) then
            return nil, lexer.symbol_count + 1
        end
		return json_parse_identifier(lexer, token);
    else
        if last_offset ~= 0 then
            return nil, lexer.symbol_count;
        end
		json_revert_symbol(lexer, last_offset);
		return json_parse_identifier(lexer, token);
    end
end

local function validate(path, base)
    local lexer = json_lexer_new(path, base or 0)
    local token = {}

    while true do
        local _, err = json_lexer_next_token(lexer, token)
        if err ~= nil then
            return false, err
        end

        if token.type == JSON_TOKEN_TYPE.JSON_TOKEN_END then
            return true
        end
    end
end

local function extract_tokens(path, base)
    local lexer = json_lexer_new(path, base or 0)
    local token = {}

    local result = {}
    local i = 1
    while true do
        local _, err = json_lexer_next_token(lexer, token)
        if err ~= nil then
            return nil, err
        end

        result[i] = {type = token.type, value = token.value}

        if token.type == JSON_TOKEN_TYPE.JSON_TOKEN_END then
            return result
        end
        i = i + 1
    end
end

return {
    JSON_TOKEN_TYPE = JSON_TOKEN_TYPE,
    validate = validate,
    extract_tokens = extract_tokens,
}
