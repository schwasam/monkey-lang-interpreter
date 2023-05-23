const std = @import("std");

pub const Token = union(enum) {
    // special
    illegal: u8,
    eof: void,

    // identifiers and literals
    ident: []const u8,
    int: i64,

    // operators
    assign: void,
    plus: void,
    minus: void,
    bang: void,
    asterisk: void,
    slash: void,
    less_than: void,
    greater_than: void,
    equal: void,
    not_equal: void,

    // delimiters
    comma: void,
    semicolon: void,
    lparen: void,
    rparen: void,
    lbrace: void,
    rbrace: void,

    // keywords
    function: void,
    let: void,
    true: void,
    false: void,
    if_: void,
    else_: void,
    return_: void,
};

pub const Lexer = struct {
    const Self = @This();

    // zig fmt: off
    const Keywords = std.ComptimeStringMap(Token, .{
        .{ "fn", .function },
        .{ "let", .let },
        .{ "true", .true },
        .{ "false", .false },
        .{ "if", .if_ },
        .{ "else", .else_ },
        .{ "return", .return_ },
    });
    // zig fmt: on

    input: []const u8 = undefined, // input / program code
    position: usize = 0, // current position in input (points to current char)
    read_position: usize = 0, // current reading position in input (after current char)
    ch: u8 = undefined, // current char under examination

    pub fn init(input: []const u8) Self {
        var self = Self{ .input = input };
        readCharacter(&self);

        return self;
    }

    pub fn nextToken(self: *Self) Token {
        var skipRead = false;

        skipWhitespace(self);

        var token: Token = undefined;
        token = switch (self.ch) {
            '=' => {
                if (peekCharacter(self) == '=') {
                    readCharacter(self);
                    return .equal;
                } else {
                    return .assign;
                }
            },
            '+' => .plus,
            '-' => .minus,
            '!' => {
                if (peekCharacter(self) == '=') {
                    readCharacter(self);
                    return .not_equal;
                } else {
                    return .bang;
                }
            },
            '*' => .asterisk,
            '/' => .slash,
            '<' => .less_than,
            '>' => .greater_than,
            ',' => .comma,
            ';' => .semicolon,
            '(' => .lparen,
            ')' => .rparen,
            '{' => .lbrace,
            '}' => .rbrace,
            0 => .eof,
            else => |c| {
                if (isLetter(c)) {
                    var id = readIdentifier(self);
                    var tk = lookupIdentifier(id);
                    skipRead = true;
                    return tk;
                }

                if (isDigit(c)) {
                    var num = readNumber(self);
                    var tk = Token{ .int = num };
                    skipRead = true;
                    return tk;
                }

                return Token{ .illegal = c };
            },
        };

        if (!skipRead) {
            readCharacter(self);
        }

        return token;
    }

    pub fn skipWhitespace(self: *Self) void {
        while (isWhitespace(self.ch)) {
            readCharacter(self);
        }
    }

    pub fn readCharacter(self: *Self) void {
        if (self.read_position >= self.input.len) {
            self.ch = 0;
        } else {
            self.ch = self.input[self.read_position];
        }
        self.position = self.read_position;
        self.read_position += 1;
    }

    pub fn peekCharacter(self: *Self) u8 {
        if (self.read_position >= self.input.len) {
            return 0;
        } else {
            return self.input[self.read_position];
        }
    }

    pub fn readIdentifier(self: *Self) []const u8 {
        var start_idx = self.position;
        while (isLetter(self.ch)) {
            readCharacter(self);
        }
        var end_idx = self.position;

        return self.input[start_idx..end_idx];
    }

    pub fn lookupIdentifier(identifier: []const u8) Token {
        var keyword = Keywords.get(identifier);
        if (keyword == null) {
            return Token{ .ident = identifier };
        }

        return keyword.?;
    }

    pub fn readNumber(self: *Self) i64 {
        var start_idx = self.position;
        while (isDigit(self.ch)) {
            readCharacter(self);
        }
        var end_idx = self.position;
        var number = std.fmt.parseInt(i64, self.input[start_idx..end_idx], 10) catch -1;

        return number;
    }

    pub fn isWhitespace(ch: u8) bool {
        return (ch == ' ') or (ch == '\t') or (ch == '\n') or (ch == '\r');
    }

    pub fn isLetter(ch: u8) bool {
        return ('a' <= ch and ch <= 'z') or ('A' <= ch and ch <= 'Z') or (ch == '_');
    }

    pub fn isDigit(ch: u8) bool {
        return ('0' <= ch and ch <= '9');
    }
};

test "lexer test 1" {
    const input = "=+(){},;";
    const expected_tokens = [_]Token{ .assign, .plus, .lparen, .rparen, .lbrace, .rbrace, .comma, .semicolon, .eof };

    var lexer = Lexer.init(input);

    for (expected_tokens) |expected_token| {
        var token = lexer.nextToken();

        try std.testing.expectEqualDeep(expected_token, token);
    }
}

test "lexer test 2" {
    const input = "====)));";
    const expected_tokens = [_]Token{ .assign, .assign, .assign, .assign, .rparen, .rparen, .rparen, .semicolon, .eof };

    var lexer = Lexer.init(input);

    for (expected_tokens) |expected_token| {
        var token = lexer.nextToken();

        try std.testing.expectEqualDeep(expected_token, token);
    }
}

test "lexer test 3" {
    const input =
        \\let five = 5;
        \\let ten = 10;
        \\
        \\let add = fn(x, y) {
        \\  x + y;
        \\};
        \\
        \\let result = add(five, ten);
    ;

    // zig fmt: off
    const expected_tokens = [_]Token{ 
        .let, Token{ .ident = "five" }, .assign, Token{ .int = 5 }, .semicolon, // let five = 5;
        .let, Token{ .ident = "ten" }, .assign, Token{ .int = 10 }, .semicolon, // let ten = 10;
        .let, Token{ .ident= "add" }, .assign, .function, .lparen, Token{ .ident = "x" }, .comma, Token{ .ident = "y" }, .rparen, .lbrace, // let add = fn(x, y) {
        Token{ .ident = "x" }, .plus, Token{ .ident = "y" }, .semicolon, // x + y;
        .rbrace, .semicolon, // };
        .let, Token{ .ident = "result" }, .assign, Token{ .ident = "add" }, .lparen, Token{ .ident = "five" }, .comma, Token{ .ident = "ten" }, .rparen, .semicolon, // let result = add(five, ten);
        .eof
    };
    // zig fmt: on

    var lexer = Lexer.init(input);

    for (expected_tokens) |expected_token| {
        var token = lexer.nextToken();

        try std.testing.expectEqualDeep(expected_token, token);
    }
}

test "lexer test 4" {
    const input =
        \\!-/*5;
        \\5 < 10 > 5;
    ;

    // zig fmt: off
    const expected_tokens = [_]Token{ 
        .bang, .minus, .slash, .asterisk, Token{ .int = 5 }, .semicolon, // !-/*5;
        Token{ .int = 5 }, .less_than, Token{ .int = 10 }, .greater_than, Token{ .int = 5 }, .semicolon, // 5 < 10 > 5;
        .eof
    };
    // zig fmt: on

    var lexer = Lexer.init(input);

    for (expected_tokens) |expected_token| {
        var token = lexer.nextToken();

        try std.testing.expectEqualDeep(expected_token, token);
    }
}

test "lexer test 5" {
    const input =
        \\if (5 < 10) {
        \\  return true;
        \\} else {
        \\  return false;
        \\}
    ;

    // zig fmt: off
    const expected_tokens = [_]Token{ 
        .if_, .lparen, Token{ .int = 5 }, .less_than, Token{ .int = 10 }, .rparen, .lbrace, // if (5 < 10) {
        .return_, .true, .semicolon, // return true;
        .rbrace, .else_, .lbrace, // } else {
        .return_, .false, .semicolon, // return false;
        .rbrace, // }
        .eof
    };
    // zig fmt: on

    var lexer = Lexer.init(input);

    for (expected_tokens) |expected_token| {
        var token = lexer.nextToken();

        try std.testing.expectEqualDeep(expected_token, token);
    }
}

test "lexer test 6" {
    const input =
        \\10 == 10;
        \\10 != 9;
    ;

    // zig fmt: off
    const expected_tokens = [_]Token{ 
        Token{ .int = 10 }, .equal, Token{ .int = 10 }, .semicolon, // 10 == 10;
        Token{ .int = 10 }, .not_equal, Token{ .int = 9 }, .semicolon, // 10 != 9;
        .eof
    };
    // zig fmt: on

    var lexer = Lexer.init(input);

    for (expected_tokens) |expected_token| {
        var token = lexer.nextToken();

        try std.testing.expectEqualDeep(expected_token, token);
    }
}

// TODO: continue with page 26ff
