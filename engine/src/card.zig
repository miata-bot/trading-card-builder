const std = @import("std");
const Allocator = std.mem.Allocator;

pub const CardSchema = enum { VersionMajor, VersionMinor, PrimaryTitle, SubTitle, Body, Background, Icon, Photo };

pub const Card = struct {
    allocator: Allocator,
    // These are floats cos that's what lua
    // returns and i'm too lazy to cast
    version_major: f64,
    version_minor: f64,
    id: []const u8,

    hash: ?[]const u8,

    primary_title: ?[]const u8,
    sub_title: ?[]const u8,
    body: ?[]const u8,

    pub fn init(allocator: Allocator, id: anytype) Card {
        return Card{
            .allocator = allocator,
            .id = id,
            .version_major = 0,
            .version_minor = 0,
            .hash = null,
            .primary_title = null,
            .sub_title = null,
            .body = null,
        };
    }

    pub fn deinit(self: *Card) void {
        self.allocator.free(self.id);
        if (self.hash) |hash| {
            self.allocator.free(hash);
        }

        if (self.primary_title) |primary_title| {
            self.allocator.free(primary_title);
        }

        if (self.sub_title) |sub_title| {
            self.allocator.free(sub_title);
        }

        if (self.body) |body| {
            self.allocator.free(body);
        }
    }
};
