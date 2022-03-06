const std = @import("std");
const lua = @import("lua.zig").lua;
const sqlite = @import("sqlite.zig").sqlite;
const base16 = @import("base16.zig").standard_base16;

const c = @import("card.zig");
const Card = c.Card;
const CardSchema = c.CardSchema;

const e = @import("engine.zig");
const Engine = e.Engine;
const EngineError = e.EngineError;
const ByteCodeError = e.ByteCodeError;
const DatabaseError = e.DatabaseError;

const i = @import("image.zig");
const Image = i.Image;

pub fn init(L: ?*lua.lua_State, db: ?*sqlite.sqlite3) void {
    lua.luaL_openlibs(L);
    lua.lua_register(L, "loadImg", loadImg);

    lua.lua_pushlightuserdata(L, db);
    lua.lua_setglobal(L, "__db__");
}

pub fn getString(engine: *const Engine, field: CardSchema) EngineError![]const u8 {
    _ = lua.lua_getfield(engine.L, 1, @tagName(field));
    if (lua.lua_isstring(engine.L, -1) != 1) {
        lua.lua_pop(engine.L, 1);
        const string = "invalid field expected string";
        _ = lua.lua_pushlstring(engine.L, string, string.len);
        return ByteCodeError.InvalidReturn;
    }
    var field_length: usize = 0;
    const field_value = lua.lua_tolstring(engine.L, -1, &field_length);
    lua.lua_pop(engine.L, 1);

    const result = try engine.allocator.dupe(u8, field_value[0..@intCast(usize, field_length)]);
    errdefer engine.allocator.free(result);

    return result;
}

pub fn checkVersionMajor(engine: *const Engine) EngineError!f64 {
    const field_type = lua.lua_getfield(engine.L, 1, @tagName(CardSchema.VersionMajor));
    if (field_type != lua.LUA_INT_TYPE) {
        lua.lua_pop(engine.L, 1);
        const string = "Card.VersionMajor is required to be an integer";
        _ = lua.lua_pushlstring(engine.L, string, string.len);
        return ByteCodeError.InvalidReturn;
    }
    const majorVersion = lua.lua_tonumberx(engine.L, -1, null);
    lua.lua_pop(engine.L, 1);
    if (majorVersion > e.EngineMajor) {
        const string = "Card.VersionMajor is greater this engine supports";
        _ = lua.lua_pushlstring(engine.L, string, string.len);
        return ByteCodeError.InvalidReturn;
    }
    return majorVersion;
}

pub fn checkversionMinor(engine: *const Engine) EngineError!f64 {
    const field_type = lua.lua_getfield(engine.L, 1, @tagName(CardSchema.VersionMinor));
    if (field_type != lua.LUA_INT_TYPE) {
        lua.lua_pop(engine.L, 1);
        const string = "Card.VersionMinor is required to be an integer";
        _ = lua.lua_pushlstring(engine.L, string, string.len);
        return ByteCodeError.InvalidReturn;
    }
    const versionMinor = lua.lua_tonumberx(engine.L, -1, null);
    lua.lua_pop(engine.L, 1);
    if (versionMinor > e.EngineMinor) {
        const string = "Card.VersionMinor is greater than engine supports";
        _ = lua.lua_pushlstring(engine.L, string, string.len);
        return ByteCodeError.InvalidReturn;
    }
    return versionMinor;
}

pub fn checkReturn(engine: *const Engine) EngineError!void {
    // checks that the return was a table
    if (!lua.lua_istable(engine.L, 1)) {
        lua.lua_pop(engine.L, 1);
        const string = "return value must be a Card table";
        _ = lua.lua_pushlstring(engine.L, string, string.len);
        return ByteCodeError.InvalidReturn;
    }
}

pub fn validateHash(engine: *const Engine, card_id: anytype, provided_hash: anytype) EngineError!void {
    var res: ?*sqlite.sqlite3_stmt = undefined;
    defer _ = sqlite.sqlite3_finalize(res);

    var rc = sqlite.sqlite3_prepare_v2(engine.db, "SELECT data FROM 'card_blocks' WHERE card_id=$1", -1, &res, 0);
    if (rc != sqlite.SQLITE_OK)
        return DatabaseError.Prepare;

    rc = sqlite.sqlite3_bind_text(res, 1, card_id.ptr, @intCast(c_int, card_id.len), null);
    if (rc != sqlite.SQLITE_OK)
        return DatabaseError.Bind;

    var binary_hash: [32]u8 = undefined;
    var encoded_hash: [64]u8 = undefined;
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    while (sqlite.sqlite3_step(res) == sqlite.SQLITE_ROW) {
        const block_length = sqlite.sqlite3_column_bytes(res, 0);
        const block_data = sqlite.sqlite3_column_text(res, 0);
        hash.update(block_data[0..@intCast(usize, block_length)]);
    }
    hash.final(&binary_hash);
    base16.encode(&encoded_hash, &binary_hash);
    if (!std.mem.eql(u8, encoded_hash[0..encoded_hash.len], provided_hash))
        return DatabaseError.HashCheck;
}

pub fn getImage(engine: *const Engine, field: CardSchema) EngineError!Image {
    _ = lua.lua_getfield(engine.L, 1, @tagName(field));
    if (lua.lua_isstring(engine.L, -1) != 1) {
        lua.lua_pop(engine.L, 1);
        const string = "invalid field expected binary blob";
        _ = lua.lua_pushlstring(engine.L, string, string.len);
        return ByteCodeError.InvalidReturn;
    }
    var img_size: usize = 0;
    const img_value = lua.lua_tolstring(engine.L, -1, &img_size);

    const result = try engine.allocator.dupe(u8, img_value[0..@intCast(usize, img_size)]);
    errdefer engine.allocator.free(result);

    lua.lua_pop(engine.L, 1);

    return Image.init(engine.allocator, result) catch {
        _ = lua.lua_pushfstring(engine.L, "could not load image");
        return ByteCodeError.InvalidReturn;
    };
}

export fn loadImg(L: ?*lua.lua_State) c_int {
    var name_length: usize = 0;
    const name = lua.luaL_checklstring(L, 1, &name_length);
    _ = lua.lua_pop(L, 1);

    const db = getDB(L);

    var res: ?*sqlite.sqlite3_stmt = undefined;
    defer _ = sqlite.sqlite3_finalize(res);

    var rc = sqlite.sqlite3_prepare_v2(db, "SELECT id,data FROM 'card_blocks' WHERE name=$1;", -1, &res, 0);

    if (rc != sqlite.SQLITE_OK)
        return lua.luaL_error(L, "could not prepare statement %s %s", sqlite.sqlite3_errstr(rc), sqlite.sqlite3_errmsg(db));

    rc = sqlite.sqlite3_bind_text(res, 1, name, @intCast(c_int, name_length), null);
    if (rc != sqlite.SQLITE_OK)
        return lua.luaL_error(L, "could not bind statement %s", sqlite.sqlite3_errstr(rc));

    rc = sqlite.sqlite3_step(res);
    if (rc == sqlite.SQLITE_ROW) {
        // const id = sqlite.sqlite3_column_text(res, 0);
        const block = sqlite.sqlite3_column_text(res, 1);
        const block_length = sqlite.sqlite3_column_bytes(res, 1);
        _ = lua.lua_pushlstring(L, block, @intCast(usize, block_length));
        return 1;
    } else {
        return lua.luaL_error(L, "Could not load image: %s %s", name, sqlite.sqlite3_errstr(rc));
    }
}

fn getDB(L: ?*lua.lua_State) ?*sqlite.sqlite3 {
    _ = lua.lua_getglobal(L, "__db__");
    if (lua.lua_isuserdata(L, 1) != 1) {
        _ = lua.lua_pop(L, 1);
        // this never returns
        _ = lua.luaL_error(L, "could not read database");
        unreachable;
    }

    var voidp = lua.lua_touserdata(L, 1);
    _ = lua.lua_pop(L, 1);
    return @ptrCast(?*sqlite.sqlite3, @alignCast(@alignOf(?*sqlite.sqlite3), voidp));
}
