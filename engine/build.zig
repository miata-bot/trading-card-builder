const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const c_flags = [_][]const u8{
        "-std=c99",
        "-O2",
    };

    const sqlite = b.addStaticLibrary("sqlite", null);
    sqlite.addIncludeDir("sqlite");
    sqlite.addCSourceFile("sqlite/sqlite3.c", &c_flags);
    sqlite.linkLibC();

    const lua = b.addStaticLibrary("lua", null);
    lua.addIncludeDir("lua-5.3.4/src");
    lua.linkLibC();

    const lua_c_files = [_][]const u8{
        "lapi.c",
        "lauxlib.c",
        "lbaselib.c",
        "lbitlib.c",
        "lcode.c",
        "lcorolib.c",
        "lctype.c",
        "ldblib.c",
        "ldebug.c",
        "ldo.c",
        "ldump.c",
        "lfunc.c",
        "lgc.c",
        "linit.c",
        "liolib.c",
        "llex.c",
        "lmathlib.c",
        "lmem.c",
        "loadlib.c",
        "lobject.c",
        "lopcodes.c",
        "loslib.c",
        "lparser.c",
        "lstate.c",
        "lstring.c",
        "lstrlib.c",
        "ltable.c",
        "ltablib.c",
        "ltm.c",
        "lundump.c",
        "lutf8lib.c",
        "lvm.c",
        "lzio.c",
    };

    inline for (lua_c_files) |c_file| {
        lua.addCSourceFile("lua/src/" ++ c_file, &c_flags);
    }

    const qr_code_generator = b.addStaticLibrary("qr_code_generator", null);
    qr_code_generator.addIncludeDir("QR-Code-generator.git/c/");
    qr_code_generator.addCSourceFile("QR-Code-generator.git/c/qrcodegen.c",  &c_flags);
    qr_code_generator.addCSourceFile("QR-Code-generator.git/c/qrcodegen-demo.c",  &c_flags);

    const exe = b.addExecutable("engine", "src/main.zig");
    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.linkLibC();
    exe.addIncludeDir("sqlite");
    exe.linkLibrary(sqlite);

    exe.addIncludeDir("lua/src");
    exe.linkLibrary(lua);

    exe.addLibPath("/usr/lib/");
    exe.addIncludeDir("/usr/include/ImageMagick-7");
    exe.linkSystemLibrary("MagickWand-7.Q16HDRI");
    exe.linkSystemLibrary("MagickCore-7.Q16HDRI");

    exe.linkLibrary(qr_code_generator);
    exe.addIncludeDir("QR-Code-generator.git/c/");
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_tests = b.addTest("src/main.zig");
    const coverage = b.option(bool, "test-coverage", "Generate test coverage") orelse false;
    exe_tests.setTarget(target);
    exe_tests.setBuildMode(mode);
    exe_tests.linkLibC();
    exe_tests.addIncludeDir("sqlite");
    exe_tests.linkLibrary(sqlite);

    exe_tests.addIncludeDir("lua/src");
    exe_tests.linkLibrary(lua);

    exe_tests.addLibPath("/usr/lib/");
    exe_tests.addIncludeDir("/usr/include/ImageMagick-7");
    exe_tests.linkSystemLibrary("MagickWand-7.Q16HDRI");
    exe_tests.linkSystemLibrary("MagickCore-7.Q16HDRI");

    if (coverage) {
        // with kcov
        exe_tests.setExecCmd(&[_]?[]const u8{
            "kcov",
            //"--path-strip-level=3", // any kcov flags can be specified here
            "kcov-output", // output dir for kcov
            null, // to get zig to use the --test-cmd-bin flag
        });
    }

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&exe_tests.step);
}
