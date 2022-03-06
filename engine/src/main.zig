const std = @import("std");
const Allocator = std.mem.Allocator;

const e = @import("engine.zig");
const Engine = e.Engine;
const ByteCodeError = e.ByteCodeError;
const DatabaseError = e.DatabaseError;

const c = @import("card.zig");
const Card = c.Card;

test "initialize engine" {
    const state = try initEngine(std.testing.allocator, "./database.db");
    defer state.deinit();

    try std.testing.expect(std.mem.eql(u8, state.database_path, "./database.db"));
}

fn initEngine(allocator: Allocator, path: anytype) !Engine {
    const state = Engine.init(allocator, path) catch |err| {
        std.log.err("[{s}] Could not initialize engine.", .{@errorName(err)});
        return err;
    };
    return state;
}

test "load card" {
    const state = try initEngine(std.testing.allocator, "./database.db");
    defer state.deinit();

    var card = try loadCard(&state);
    defer card.deinit();

    try std.testing.expect(std.mem.eql(u8, card.id, "eeba7932-5b7f-4dc4-9470-e7d2bda8beb4"));
}

fn loadCard(state: *const Engine) !Card {
    var card = state.loadCard("eeba7932-5b7f-4dc4-9470-e7d2bda8beb4") catch |err| {
        std.log.err("[{s}] Could not load card.", .{@errorName(err)});
        return err;
    };
    return card;
}

test "load byte code" {
    const state = try initEngine(std.testing.allocator, "./database.db");
    defer state.deinit();

    var card = try loadCard(&state);
    defer card.deinit();

    try loadByteCode(&state, &card);
    try std.testing.expect(std.mem.eql(u8, card.hash.?, "9ABA6818E5925233B1A111DFB88BFF6397B3BEF3AF97F9D74ADF535BE30CE142"));
}

fn loadByteCode(state: *const Engine, card: *Card) !void {
    state.loadByteCode(card) catch |err| {
        switch (err) {
            ByteCodeError.Load, ByteCodeError.Execute, ByteCodeError.InvalidReturn => {
                const s = try state.getByteCodeError(err);
                defer state.freeByteCodeError(s);
                std.log.err("[{s}] Failed to load bytecode: {s}", .{ @errorName(err), s });
            },

            DatabaseError.Open, DatabaseError.Prepare, DatabaseError.Bind, DatabaseError.Query, DatabaseError.HashCheck => {
                std.log.err("[{s}] Failed to load bytecode due to a database error", .{@errorName(err)});
            },
            else => {
                std.log.err("[{s}] Failed to allocate memory", .{@errorName(err)});
            },
        }
        return err;
    };
}

test "exec byte code" {
    const state = try initEngine(std.testing.allocator, "./database.db");
    defer state.deinit();

    var card = try loadCard(&state);
    defer card.deinit();

    try loadByteCode(&state, &card);
    try execByteCode(&state, &card);

    try std.testing.expect(std.mem.eql(u8, card.primary_title.?, "cone"));
    try std.testing.expect(std.mem.eql(u8, card.sub_title.?, "@pressy4pie"));
    try std.testing.expect(card.version_major == 0);
    try std.testing.expect(card.version_minor == 1);
}

fn execByteCode(state: *const Engine, card: *Card) !void {
    state.executeByteCode(card) catch |err| {
        switch (err) {
            ByteCodeError.Load, ByteCodeError.Execute, ByteCodeError.InvalidReturn => {
                const s = try state.getByteCodeError(err);
                defer state.freeByteCodeError(s);
                std.log.err("[{s}] Failed to execute bytecode: {s}", .{ @errorName(err), s });
            },

            DatabaseError.Open, DatabaseError.Prepare, DatabaseError.Bind, DatabaseError.Query, DatabaseError.HashCheck => {
                std.log.err("[{s}] Failed to execute bytecode due to a database error", .{@errorName(err)});
            },
            else => {
                std.log.err("[{s}] Failed to allocate memory", .{@errorName(err)});
            },
        }
        return err;
    };
}

test "render card" {
    const state = try initEngine(std.testing.allocator, "./database.db");
    defer state.deinit();

    var card = try loadCard(&state);
    defer card.deinit();

    try loadByteCode(&state, &card);
    try execByteCode(&state, &card);
    try render(&state, &card);
}

fn render(state: *const Engine, card: *Card) !void {
    state.render(card) catch |err| {
        switch (err) {
            ByteCodeError.Load, ByteCodeError.Execute, ByteCodeError.InvalidReturn => {
                const s = try state.getByteCodeError(err);
                defer state.freeByteCodeError(s);
                std.log.err("[{s}] Bytecode error: {s}", .{ @errorName(err), s });
            },

            DatabaseError.Open, DatabaseError.Prepare, DatabaseError.Bind, DatabaseError.Query, DatabaseError.HashCheck => {
                std.log.err("[{s}] Database error", .{@errorName(err)});
            },
            else => {
                std.log.err("[{s}] Failed to allocate memory", .{@errorName(err)});
            },
        }
        return err;
    };
}

pub fn main() anyerror!u8 {
    const allocator = std.heap.page_allocator;

    const state = initEngine(allocator, "./database.db") catch return 1;
    defer state.deinit();
    std.log.info("initialized engine v{d}.{d}", .{ e.EngineMajor, e.EngineMinor });

    var card = loadCard(&state) catch return 1;
    defer card.deinit();
    std.log.info("loaded card {s}", .{card.id});

    loadByteCode(&state, &card) catch return 1;
    std.log.info("loaded bytecode {s}", .{card.hash});

    execByteCode(&state, &card) catch return 1;
    std.log.info("executed bytecode", .{});

    render(&state, &card) catch return 1;
    std.log.info("rendered {s}", .{"output.png"});

    return 0;
}
