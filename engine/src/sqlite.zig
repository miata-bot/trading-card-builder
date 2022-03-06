pub const sqlite = @cImport({
    @cInclude("sqlite3.h");
    @cInclude("sqlite3ext.h");
});
