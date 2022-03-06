const std = @import("std");
const Allocator = std.mem.Allocator;

const c = @import("card.zig");
const Card = c.Card;
const CardSchema = c.CardSchema;

const i = @import("image.zig");
const Image = i.Image;

const lua = @import("lua.zig").lua;
const util = @import("util.zig");
const sqlite = @import("sqlite.zig").sqlite;
const magick_wand = @import("magick_wand.zig").magick_wand;
const base16 = @import("base16.zig").standard_base16;

pub const DatabaseError = error{ Open, Prepare, Bind, Query, HashCheck };
pub const ByteCodeError = error{ Load, Execute, InvalidReturn };
pub const EngineError = DatabaseError || ByteCodeError || Allocator.Error;

pub const EngineMajor = 0;
pub const EngineMinor = 1;

pub const Engine = struct {
    allocator: Allocator,
    db: ?*sqlite.sqlite3,
    database_path: []const u8,
    L: ?*lua.lua_State,

    pub fn init(allocator: Allocator, database_path: anytype) EngineError!Engine {
        var db: ?*sqlite.sqlite3 = undefined;
        errdefer _ = sqlite.sqlite3_close(db);

        const result = try allocator.dupeZ(u8, database_path[0..database_path.len]);
        errdefer allocator.free(result);

        var rc = sqlite.sqlite3_open(result.ptr, &db);

        if (rc != sqlite.SQLITE_OK) {
            _ = sqlite.sqlite3_close(db);
            std.log.err("rc={d} {s}", .{ rc, sqlite.sqlite3_errstr(rc) });
            return DatabaseError.Open;
        }

        var L = lua.luaL_newstate();
        errdefer lua.lua_close(L);

        util.init(L, db);
        return Engine{ .allocator = allocator, .db = db, .database_path = result, .L = L };
    }

    pub fn deinit(self: *const Engine) void {
        _ = sqlite.sqlite3_close(self.db);
        _ = lua.lua_close(self.L);
        self.allocator.free(self.database_path);
    }

    pub fn getByteCodeError(self: *const Engine, _: EngineError) ![]u8 {
        const string = try std.fmt.allocPrint(self.allocator, "{s}", .{lua.lua_tolstring(self.L, -1, null)});
        errdefer self.allocator.free(string);
        return string;
    }

    pub fn freeByteCodeError(self: *const Engine, s: anytype) void {
        self.allocator.free(s);
    }

    pub fn loadCard(self: *const Engine, id: anytype) EngineError!Card {
        var res: ?*sqlite.sqlite3_stmt = undefined;
        defer _ = sqlite.sqlite3_finalize(res);

        var rc = sqlite.sqlite3_prepare_v2(self.db, "SELECT id,hash FROM 'cards' WHERE id=$1", -1, &res, 0);
        if (rc != sqlite.SQLITE_OK)
            return DatabaseError.Prepare;

        rc = sqlite.sqlite3_bind_text(res, 1, id, @intCast(c_int, id.len), null);
        if (rc != sqlite.SQLITE_OK)
            return DatabaseError.Query;

        rc = sqlite.sqlite3_step(res);
        if (rc == sqlite.SQLITE_ROW) {
            const got_id_length = sqlite.sqlite3_column_bytes(res, 0);
            const got_id = sqlite.sqlite3_column_text(res, 0);

            const hash_length = sqlite.sqlite3_column_bytes(res, 1);
            const hash = sqlite.sqlite3_column_text(res, 1);
            try util.validateHash(self, got_id[0..@intCast(usize, got_id_length)], hash[0..@intCast(usize, hash_length)]);

            const result = try self.allocator.dupe(u8, got_id[0..@intCast(usize, got_id_length)]);
            errdefer self.allocator.free(result);

            return Card.init(self.allocator, result);
        } else return DatabaseError.Query;
    }

    pub fn loadByteCode(self: *const Engine, card: *Card) EngineError!void {
        var res: ?*sqlite.sqlite3_stmt = undefined;
        defer _ = sqlite.sqlite3_finalize(res);

        var rc = sqlite.sqlite3_prepare_v2(self.db, "SELECT data FROM 'card_blocks' WHERE card_id=$1 AND name='card.lua'", -1, &res, 0);
        if (rc != sqlite.SQLITE_OK)
            return DatabaseError.Prepare;

        rc = sqlite.sqlite3_bind_text(res, 1, card.id.ptr, @intCast(c_int, card.id.len), null);
        if (rc != sqlite.SQLITE_OK)
            return DatabaseError.Bind;

        rc = sqlite.sqlite3_step(res);
        if (rc == sqlite.SQLITE_ROW) {
            const block = sqlite.sqlite3_column_text(res, 0);
            const length = sqlite.sqlite3_column_bytes(res, 0);
            const load_status = lua.luaL_loadbufferx(self.L, block, @intCast(usize, length), "card.lua", "bt");
            if (load_status != lua.LUA_OK)
                return ByteCodeError.Load;

            var binary_hash: [32]u8 = undefined;
            var encoded_hash: [64]u8 = undefined;
            std.crypto.hash.sha2.Sha256.hash(block[0..@intCast(usize, length)], &binary_hash, .{});
            base16.encode(&encoded_hash, &binary_hash);
            const result = try self.allocator.dupe(u8, &encoded_hash);
            errdefer self.allocator.free(result);
            card.hash = result;
        } else return DatabaseError.Query;
    }

    pub fn executeByteCode(self: *const Engine, card: *Card) EngineError!void {
        const call_status = lua.lua_pcallk(self.L, 0, lua.LUA_MULTRET, 0, 0, null);
        if (call_status != lua.LUA_OK)
            return ByteCodeError.Execute;

        try util.checkReturn(self);

        card.version_major = try util.checkVersionMajor(self);
        card.version_minor = try util.checkversionMinor(self);
        card.body = try util.getString(self, CardSchema.Body);
        card.primary_title = try util.getString(self, CardSchema.PrimaryTitle);
        card.sub_title = try util.getString(self, CardSchema.SubTitle);
    }

    pub fn render(self: *const Engine, card: *Card) EngineError!void {
        magick_wand.MagickWandGenesis();
        defer magick_wand.MagickWandTerminus();

        var wand = magick_wand.NewMagickWand();
        defer _ = magick_wand.DestroyMagickWand(wand);

        _ = magick_wand.MagickSetImageAlphaChannel(wand, magick_wand.ActivateAlphaChannel);

        var pixel_wand = magick_wand.NewPixelWand();
        defer _ = magick_wand.DestroyPixelWand(pixel_wand);

        _ = magick_wand.PixelSetColor(pixel_wand, "rgb(255,255,255)");
        _ = magick_wand.PixelSetAlpha(pixel_wand, 0.0);
        _ = magick_wand.MagickSetImageBackgroundColor(wand, pixel_wand);
        _ = magick_wand.MagickNewImage(wand, 750, 1050, pixel_wand);
        _ = magick_wand.MagickTransparentPaintImage(wand, pixel_wand, 0.0, 10, magick_wand.MagickFalse);

        var draw_wand = magick_wand.NewDrawingWand();
        defer _ = magick_wand.DestroyDrawingWand(draw_wand);

        _ = magick_wand.PixelSetAlpha(pixel_wand, 1.0);
        _ = magick_wand.PixelSetColor(pixel_wand, "rgb(66, 66, 84)");
        _ = magick_wand.DrawSetFillColor(draw_wand, pixel_wand);
        _ = magick_wand.DrawRoundRectangle(
            draw_wand,
            0,
            0,
            750,
            1050,
            40,
            40,
        );
        _ = magick_wand.MagickDrawImage(wand, draw_wand);

        // write title text
        if (card.primary_title) |primary_title| {
            _ = magick_wand.PixelSetColor(pixel_wand, "white");
            _ = magick_wand.DrawSetFillColor(draw_wand, pixel_wand);
            _ = magick_wand.DrawSetFont(draw_wand, "Verdana-Bold-Italic");
            _ = magick_wand.DrawSetFontSize(draw_wand, 72);
            _ = magick_wand.DrawSetTextAntialias(draw_wand, magick_wand.MagickTrue);
            _ = magick_wand.DrawAnnotation(draw_wand, 25, 65, primary_title.ptr);
            _ = magick_wand.MagickDrawImage(wand, draw_wand);
        }

        // write subtitle text
        if (card.sub_title) |sub_title| {
            _ = magick_wand.PixelSetColor(pixel_wand, "white");
            _ = magick_wand.DrawSetFillColor(draw_wand, pixel_wand);
            _ = magick_wand.DrawSetFont(draw_wand, "Verdana-Bold-Italic");
            _ = magick_wand.DrawSetFontSize(draw_wand, 30);
            _ = magick_wand.DrawSetTextAntialias(draw_wand, magick_wand.MagickTrue);
            _ = magick_wand.DrawAnnotation(draw_wand, 470, 635, sub_title.ptr);
            _ = magick_wand.MagickDrawImage(wand, draw_wand);
        }

        // write body text
        if (card.body) |body| {
            _ = magick_wand.PixelSetColor(pixel_wand, "white");
            _ = magick_wand.DrawSetFillColor(draw_wand, pixel_wand);
            _ = magick_wand.DrawSetFont(draw_wand, "Verdana-Bold-Italic");
            _ = magick_wand.DrawSetFontSize(draw_wand, 35);
            _ = magick_wand.DrawSetTextAntialias(draw_wand, magick_wand.MagickTrue);
            _ = magick_wand.DrawAnnotation(draw_wand, 220, 700, body.ptr);
            _ = magick_wand.MagickDrawImage(wand, draw_wand);
        }

        // write serial number
        _ = magick_wand.PixelSetColor(pixel_wand, "white");
        _ = magick_wand.PixelSetAlpha(pixel_wand, 0.3);
        _ = magick_wand.DrawSetFillColor(draw_wand, pixel_wand);
        _ = magick_wand.DrawSetFont(draw_wand, "Verdana-Bold-Italic");
        _ = magick_wand.DrawSetFontSize(draw_wand, 12);
        _ = magick_wand.DrawSetTextAntialias(draw_wand, magick_wand.MagickTrue);
        _ = magick_wand.DrawAnnotation(draw_wand, 430, 1045, card.id.ptr);
        _ = magick_wand.MagickDrawImage(wand, draw_wand);

        // overlay photo
        const photo = try util.getImage(self, CardSchema.Photo);
        defer photo.deinit();

        _ = magick_wand.MagickResizeImage(photo.wand, 660, 500, magick_wand.BesselFilter);
        _ = magick_wand.MagickCompositeImage(wand, photo.wand, magick_wand.OverCompositeOp, magick_wand.MagickTrue, 40, 100);

        // overlay icon
        const icon = try util.getImage(self, CardSchema.Icon);
        defer icon.deinit();

        _ = magick_wand.MagickCompositeImage(wand, icon.wand, magick_wand.OverCompositeOp, magick_wand.MagickTrue, 40, 540);

        // end
        _ = magick_wand.MagickWriteImages(wand, "output.png", magick_wand.MagickTrue);
    }
};
