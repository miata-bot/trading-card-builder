const magick_wand = @import("magick_wand.zig").magick_wand;

const qr = @cImport({
    @cInclude("qrcodegen.h");
});

// pub fn scaleArray() void {
//   for (int i = 0; i < 8; ++i) {
//     for (int j = 0; j < 8; ++j) {
//         scaledArray[(i*2)][(j*2)] = array[i][j];
//         scaledArray[(i*2) + 1][(j*2)] = array[i][j];
//         scaledArray[(i*2)][(j*2) + 1] = array[i][j];
//         scaledArray[(i*2) + 1][(j*2) + 1] = array[i][j];
//     }
// }
// }

pub fn generate(text: anytype) *magick_wand.MagickWand {
    const errCorLvl = qr.qrcodegen_Ecc_LOW;
    var qrcode: [qr.qrcodegen_BUFFER_LEN_MAX]u8 = undefined;
    var tempBuffer: [qr.qrcodegen_BUFFER_LEN_MAX]u8 = undefined;
    var ok = qr.qrcodegen_encodeText(text, &tempBuffer, &qrcode, errCorLvl, qr.qrcodegen_VERSION_MIN, qr.qrcodegen_VERSION_MAX, qr.qrcodegen_Mask_AUTO, true);
    _ = ok;

    var size: c_int = qr.qrcodegen_getSize(&qrcode);
    size*=4;

    var qrwand = magick_wand.NewMagickWand();
    errdefer _ = magick_wand.DestroyMagickWand(qrwand);

    var qrpwand = magick_wand.NewPixelWand();
    defer _ = magick_wand.DestroyPixelWand(qrpwand);
    _ = magick_wand.PixelSetColor(qrpwand, "red");

    _ = magick_wand.MagickNewImage(qrwand, @intCast(usize, size), @intCast(usize, size), qrpwand);

    var iter = magick_wand.NewPixelIterator(qrwand);
    defer _ = magick_wand.DestroyPixelIterator(iter);

    var pixel: magick_wand.PixelInfo = undefined;
    var scaledArray[size*4][size*4]u1 = undefined;
    var i:usize = 0;
    while(i < size/2) {
      i+=1;
      var j:usize=0;
      while(j<size/2) {
        j+=1;
                    const module = qr.qrcodegen_getModule(&qrcode, 
              @intCast(c_int, i), 
              @intCast(c_int, j)
            );
            if(module) {
        scaledArray[(i*2)][(j*2)] = 1;
        scaledArray[(i*2) + 1][(j*2)] = 1;
        scaledArray[(i*2)][(j*2) + 1] = 1;
        scaledArray[(i*2) + 1][(j*2) + 1] = 1;

            } else {
        scaledArray[(i*2)][(j*2)] = 0;
        scaledArray[(i*2) + 1][(j*2)] = 0;
        scaledArray[(i*2)][(j*2) + 1] = 0;
        scaledArray[(i*2) + 1][(j*2) + 1] = 0;
            }
      }
    }

    var y: isize = 0;
    while (y < size) {
        var num_wands: usize = 0;
        _ = magick_wand.PixelSetIteratorRow(iter, y);
        var row = magick_wand.PixelGetCurrentIteratorRow(iter, &num_wands);
        
        var x: isize = 0;
        while (x < size) {
            const module = qr.qrcodegen_getModule(&qrcode, 
              @intCast(c_int, x), 
              @intCast(c_int, y)
            );
            pixel = magick_wand.PixelGetPixel(row[@intCast(usize, x)]);
            if (module) {
                pixel.red = 0;
                pixel.green = 0;
                pixel.blue = 0;
            } else {
                pixel.red = 0;
                pixel.green = 0xffff;
                pixel.blue = 0;
            }
            _ = magick_wand.PixelSetPixelColor(row[@intCast(usize, x)], &pixel);
            x += 1;
        }
        _ = magick_wand.PixelSyncIterator(iter);
        y += 1;
    }
    return qrwand.?;
}
