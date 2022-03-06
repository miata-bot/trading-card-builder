const std = @import("std");
const Allocator = std.mem.Allocator;
const magick_wand = @import("magick_wand.zig").magick_wand;

pub const ImageError = error{Magick};

pub const Image = struct {
    allocator: Allocator,
    data: ?[]const u8,
    wand: ?*magick_wand.MagickWand,

    pub fn init(allocator: Allocator, data: anytype) ImageError!Image {
        var wand = magick_wand.NewMagickWand();
        errdefer _ = magick_wand.DestroyMagickWand(wand);

        const magick_status = magick_wand.MagickReadImageBlob(wand, data.ptr, data.len);
        if (magick_status == magick_wand.MagickFalse)
            return ImageError.Magick;

        return Image{ .allocator = allocator, .data = data, .wand = wand };
    }

    pub fn deinit(self: *const Image) void {
        if (self.data) |data| {
            self.allocator.free(data);
        }

        if (self.wand) |wand| {
            _ = magick_wand.DestroyMagickWand(wand);
        }
    }
};
