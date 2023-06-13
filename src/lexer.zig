const std = @import("std");

pub const Token = union(enum) {
    // special
    illegal: u8,
    eof,

    // identifiers and literals
    identifier: []const u8,
    integer: i64,

    // operators
    assign, // =
    plus, // +
    minus, // -
    bang, // !
    asterisk, // *
    slash, // /
    less_than, // <
    greater_than, // >
    equal, // ==
    not_equal, // !=

    // delimiters
    comma, // ,
    semicolon, // ;
    left_parenthesis, // (
    right_parenthesis, // )
    left_brace, // {
    right_brace, // }

    // keywords
    let_, // let
    function_, // fn
    if_, // if
    else_, // else
    true_, // true
    false_, // false
    return_, // return

    fn keyword(ident: []const u8) ?Token {
        const map = std.ComptimeStringMap(Token, .{
            .{ "let", .let_ },
            .{ "fn", .function_ },
            .{ "if", .if_ },
            .{ "else", .else_ },
            .{ "true", .true_ },
            .{ "false", .false_ },
            .{ "return", .return_ },
        });

        return map.get(ident);
    }
};

pub const Lexer = struct {
    const Self = @This();
    const NUL: u8 = 0; // ASCII NUL

    position: u64 = 0,
    read_position: u64 = 0,
    char: u8 = NUL,
    input: []const u8 = undefined,

    pub fn init(input: []const u8) Self {
        var lexer = Self{ .input = input };
        lexer.readCharacter();

        return lexer;
    }

    pub fn nextToken(self: *Self) Token {
        self.skipWhitespace();
        const token: Token = switch (self.char) {
            '=' => equal: {
                if (self.peekCharacter() == '=') {
                    self.readCharacter();
                    break :equal .equal;
                }
                break :equal .assign;
            },
            '+' => .plus,
            '-' => .minus,
            '!' => not_equal: {
                if (self.peekCharacter() == '=') {
                    self.readCharacter();
                    break :not_equal .not_equal;
                }
                break :not_equal .bang;
            },
            '*' => .asterisk,
            '/' => .slash,
            '<' => .less_than,
            '>' => .greater_than,
            ',' => .comma,
            ';' => .semicolon,
            '(' => .left_parenthesis,
            ')' => .right_parenthesis,
            '{' => .left_brace,
            '}' => .right_brace,
            NUL => .eof,
            else => |char| {
                if (isLetter(char)) {
                    const id = self.readIdentifier();
                    if (Token.keyword(id)) |tok| {
                        return tok;
                    }
                    return Token{ .identifier = id };
                }

                if (isDigit(char)) {
                    const int = self.readInteger() catch {
                        return Token{ .illegal = char };
                    };
                    return Token{ .integer = int };
                }

                return Token{ .illegal = char };
            },
        };
        self.readCharacter();

        return token;
    }

    fn peekCharacter(self: *Self) u8 {
        if (self.read_position >= self.input.len) {
            return NUL;
        }

        return self.input[self.read_position];
    }

    fn readCharacter(self: *Self) void {
        if (self.read_position >= self.input.len) {
            self.char = NUL;
        } else {
            self.char = self.input[self.read_position];
        }
        self.position = self.read_position;
        self.read_position += 1;
    }

    pub fn readIdentifier(self: *Self) []const u8 {
        var start_idx = self.position;
        while (isLetter(self.char)) {
            readCharacter(self);
        }
        var end_idx = self.position;

        return self.input[start_idx..end_idx];
    }

    fn readInteger(self: *Self) !i64 {
        const position = self.position;
        while (isDigit(self.char)) {
            self.readCharacter();
        }
        const buffer = self.input[position..self.position];
        const int = try std.fmt.parseInt(i64, buffer, 10);

        return int;
    }

    pub fn isLetter(ch: u8) bool {
        return ('a' <= ch and ch <= 'z') or ('A' <= ch and ch <= 'Z') or (ch == '_');
    }

    pub fn isDigit(ch: u8) bool {
        return ('0' <= ch and ch <= '9');
    }

    fn skipWhitespace(self: *Self) void {
        while (std.ascii.isWhitespace(self.char)) {
            self.readCharacter();
        }
    }
};

test "lexer test 1: some operators and delimiters" {
    const input = "=+(){},;";

    // zig fmt: off
    const expected_tokens = [_]Token{
        .assign,
        .plus,
        .left_parenthesis,
        .right_parenthesis,
        .left_brace,
        .right_brace,
        .comma,
        .semicolon,
        .eof };
    // zig fmt: on

    var lexer = Lexer.init(input);

    for (expected_tokens) |expected_token| {
        var token = lexer.nextToken();

        try std.testing.expectEqualDeep(expected_token, token);
    }
}

test "lexer test 2: simple program" {
    const input =
        \\ let five = 5;
        \\ let ten = 10;
        \\
        \\ let add = fn(x, y) {
        \\   x + y;
        \\ };
        \\
        \\ let result = add(five, ten);
    ;

    // zig fmt: off
    const expected_tokens = [_]Token{
        .let_, Token{ .identifier = "five" }, .assign, Token{ .integer = 5 }, .semicolon, // let five = 5;
        .let_, Token{ .identifier = "ten" }, .assign, Token{ .integer = 10 }, .semicolon, // let ten = 10;
        .let_, Token{ .identifier = "add" }, .assign, .function_, .left_parenthesis, Token{ .identifier = "x" }, .comma, Token{ .identifier = "y" }, .right_parenthesis, .left_brace, // let add = fn(x, y) {
        Token{ .identifier = "x" }, .plus, Token{ .identifier = "y" }, .semicolon, // x + y;
        .right_brace, .semicolon, // };
        .let_, Token{ .identifier = "result" }, .assign, Token{ .identifier = "add" }, .left_parenthesis, Token{ .identifier = "five" }, .comma, Token{ .identifier = "ten" }, .right_parenthesis, .semicolon, // let result = add(five, ten);
        .eof
    };
    // zig fmt: on

    var lexer = Lexer.init(input);

    for (expected_tokens) |expected_token| {
        var token = lexer.nextToken();

        try std.testing.expectEqualDeep(expected_token, token);
    }
}

test "lexer test 3: miscellaneous" {
    const input =
        \\!-/*5;
        \\5 < 10 > 5;
    ;

    // zig fmt: off
    const expected_tokens = [_]Token{
        .bang, .minus, .slash, .asterisk, Token{ .integer = 5 }, .semicolon, // !-/*5;
        Token {.integer = 5}, .less_than, Token{ .integer = 10 }, .greater_than, Token{ .integer = 5 }, .semicolon, // 5 < 10 > 5;
        .eof
    };
    // zig fmt: on

    var lexer = Lexer.init(input);

    for (expected_tokens) |expected_token| {
        var token = lexer.nextToken();

        try std.testing.expectEqualDeep(expected_token, token);
    }
}

test "lexer test 4: conditionals" {
    const input =
        \\ if (5 < 10) {
        \\  return true;
        \\ } else {
        \\  return false;
        \\ }
    ;

    // zig fmt: off
    const expected_tokens = [_]Token{
        .if_, .left_parenthesis, Token{ .integer = 5 }, .less_than, Token{ .integer = 10 }, .right_parenthesis, .left_brace, // if (5 < 10) {
        .return_, .true_, .semicolon, // return true;
        .right_brace, .else_, .left_brace, // } else {
        .return_, .false_, .semicolon, // return false;
        .right_brace, // }
        .eof
    };
    // zig fmt: on

    var lexer = Lexer.init(input);

    for (expected_tokens) |expected_token| {
        var token = lexer.nextToken();

        try std.testing.expectEqualDeep(expected_token, token);
    }
}

test "lexer test 5: one letter operators" {
    const input = "=+-!*/<>";

    // zig fmt: off
    const expected_tokens = [_]Token{
        .assign,
        .plus,
        .minus,
        .bang,
        .asterisk,
        .slash,
        .less_than,
        .greater_than,
        .eof,
    };
    // zig fmt: on

    var lexer = Lexer.init(input);

    for (expected_tokens) |expected_token| {
        var token = lexer.nextToken();

        try std.testing.expectEqualDeep(expected_token, token);
    }
}

test "lexer test 6: two letter operators" {
    const input = "==!= == !=";

    // zig fmt: off
    const expected_tokens = [_]Token{
        .equal,
        .not_equal,
        .equal,
        .not_equal,
        .eof,
    };
    // zig fmt: on

    var lexer = Lexer.init(input);

    for (expected_tokens) |expected_token| {
        var token = lexer.nextToken();

        try std.testing.expectEqualDeep(expected_token, token);
    }
}

test "lexer test 7: delimiters" {
    const input = ",;(){}";

    // zig fmt: off
    const expected_tokens = [_]Token{
        .comma,
        .semicolon,
        .left_parenthesis,
        .right_parenthesis,
        .left_brace,
        .right_brace,
        .eof,
    };
    // zig fmt: on

    var lexer = Lexer.init(input);

    for (expected_tokens) |expected_token| {
        var token = lexer.nextToken();

        try std.testing.expectEqualDeep(expected_token, token);
    }
}

test "lexer test 8: keywords" {
    const input = "let fn if else true false return";

    // zig fmt: off
    const expected_tokens = [_]Token{
        .let_,
        .function_,
        .if_,
        .else_,
        .true_,
        .false_,
        .return_,
        .eof,
    };
    // zig fmt: on

    var lexer = Lexer.init(input);

    for (expected_tokens) |expected_token| {
        var token = lexer.nextToken();

        try std.testing.expectEqualDeep(expected_token, token);
    }
}
