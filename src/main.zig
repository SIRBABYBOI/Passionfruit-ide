const std = @import("std");
const dvui = @import("dvui");

pub const dvui_app: dvui.App = .{
    .config = .{ .options = .{
        .size = .{ .w = 1080, .h = 720 },
        .min_size = .{ .w = 640, .h = 440 },
        .title = "Passionfruit IDE",
        .app = "Passionfruit IDE",
        .org = "com.passionfruit.ide",
        .window_init_options = .{ .keybinds_zoom = true },
    } },
    .frameFn = appFrame,
};

pub const main = dvui.App.main;
pub const panic = dvui.App.panic;
pub const std_options: std.Options = .{ .logFn = dvui.App.logFn };

var current_file: []const u8 = "main.zig";

const files = [_][]const u8{ "main.zig", "root.zig", "build.zig", "README.md" };

const file_contents = [_][]const u8{
    \\const std = @import("std");
    \\
    \\pub fn main() !void {
    \\    const stdout = std.io.getStdOut().writer();
    \\    try stdout.print("Hello, Passionfruit IDE!\n", .{});
    \\}
    ,
    \\const std = @import("std");
    \\
    \\pub fn coreInit() void {
    \\    // Initialize application context
    \\}
    ,
    \\const std = @import("std");
    \\
    \\pub fn build(b: *std.Build) void {
    \\    const target = b.standardTargetOptions(.{});
    \\    const optimize = b.standardOptimizeOption(.{});
    \\    _ = b.addModule("passionfruit", .{ .root_source_file = b.path("src/root.zig") });
    \\}
    ,
    \\# Passionfruit IDE
    \\
    \\A minimal, performant Zig development environment.
    ,
};

fn spacer(src: std.builtin.SourceLocation) void {
    var box = dvui.box(src, .{}, .{ .expand = .horizontal });
    box.deinit();
}

pub fn appFrame() !dvui.App.Result {
    var root = dvui.box(@src(), .{ .dir = .vertical }, .{ .expand = .both });
    defer root.deinit();

    // 1. TOP MENU / TITLEBAR
    {
        var topbar = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .horizontal, .background = true, .padding = .{ .x = 8, .y = 4, .w = 8, .h = 4 } });
        defer topbar.deinit();

        {
            var menu = dvui.menu(@src(), .horizontal, .{});
            defer menu.deinit();

            if (dvui.menuItemLabel(@src(), "File", .{ .submenu = true }, .{})) |rect| {
                var popup = dvui.floatingMenu(@src(), .{ .from = rect }, .{});
                defer popup.deinit();
                if (dvui.backend.kind != .web and dvui.menuItemLabel(@src(), "Exit", .{}, .{ .expand = .horizontal }) != null) return .close;
            }
            _ = dvui.menuItemLabel(@src(), "Edit", .{}, .{});
            _ = dvui.menuItemLabel(@src(), "View", .{}, .{});
            _ = dvui.menuItemLabel(@src(), "Run", .{}, .{});
            _ = dvui.menuItemLabel(@src(), "Help", .{}, .{});
        }

        spacer(@src());
        if (dvui.buttonIcon(@src(), "Settings", dvui.entypo.cog, .{}, .{}, .{
            .min_size_content = .{ .w = 16, .h = 16 },
        })) {
            dvui.dialog(@src(), .{}, .{ .title = "Settings", .message = "Settings are not available yet." });
        }
    }

    // 2. MAIN WORKSPACE
    {
        var workbench = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .both });
        defer workbench.deinit();

        // SIDEBAR / FILE EXPLORER
        {
            var sidebar = dvui.box(@src(), .{ .dir = .vertical }, .{ .min_size_content = .{ .w = 220, .h = 0 }, .expand = .vertical, .background = true, .padding = .{ .x = 0, .y = 8, .w = 0, .h = 0 } });
            defer sidebar.deinit();

            dvui.label(@src(), "EXPLORER", .{}, .{
                .font = dvui.Font.theme(.mono).withSize(10),
                .padding = .{ .x = 12, .y = 4, .w = 12, .h = 8 },
                .color_text = .{ .color = .{ .r = 130, .g = 130, .b = 130, .a = 255 } },
            });

            // Project Root Folder Header
            {
                var folder = dvui.box(@src(), .{ .dir = .horizontal }, .{ .padding = .{ .x = 12, .y = 2, .w = 12, .h = 4 } });
                defer folder.deinit();
                dvui.icon(@src(), "Project folder", dvui.entypo.folder, .{}, .{ .min_size_content = .{ .w = 14, .h = 14 } });
                dvui.label(@src(), "  passionfruit-ide", .{}, .{ .font = dvui.Font.theme(.body).withSize(12) });
            }

            // Folder Tree
            {
                var folder = dvui.box(@src(), .{ .dir = .horizontal }, .{ .padding = .{ .x = 24, .y = 2, .w = 12, .h = 2 } });
                defer folder.deinit();
                dvui.icon(@src(), "Source folder", dvui.entypo.folder, .{}, .{ .min_size_content = .{ .w = 14, .h = 14 } });
                dvui.label(@src(), "  src", .{}, .{ .font = dvui.Font.theme(.body).withSize(12) });
            }

            for (files, 0..) |file, i| {
                const selected = std.mem.eql(u8, file, current_file);
                if (dvui.buttonLabelAndIcon(@src(), .{ .label = file, .tvg_bytes = dvui.entypo.text_document, .icon_first = true }, .{
                    .id_extra = i,
                    .expand = .horizontal,
                    .background = selected,
                    .padding = .{ .x = 36, .y = 4, .w = 4, .h = 4 },
                    .corners = .all(0),
                })) {
                    current_file = file;
                }
            }
        }

        // EDITOR AREA
        {
            var editor = dvui.box(@src(), .{ .dir = .vertical }, .{ .expand = .both });
            defer editor.deinit();

            // TAB BAR
            {
                var tabs = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .horizontal, .background = true });
                defer tabs.deinit();

                for (files, 0..) |file, i| {
                    const is_active = std.mem.eql(u8, file, current_file);
                    if (dvui.buttonLabelAndIcon(@src(), .{ .label = file, .tvg_bytes = dvui.entypo.text_document, .icon_first = true }, .{
                        .id_extra = i,
                        .background = is_active,
                        .padding = .{ .x = 12, .y = 6, .w = 12, .h = 6 },
                        .corners = .all(0),
                        .font = dvui.Font.theme(.body).withSize(12),
                    })) {
                        current_file = file;
                    }
                }
            }

            // CODE EDITOR CONTAINER
            {
                var scroll = dvui.scrollArea(@src(), .{}, .{ .expand = .both, .background = true });
                defer scroll.deinit();

                var content = dvui.box(@src(), .{ .dir = .vertical }, .{ .expand = .both, .padding = .{ .x = 0, .y = 8, .w = 12, .h = 8 } });
                defer content.deinit();

                // Get active content index
                var active_idx: usize = 0;
                for (files, 0..) |f, idx| {
                    if (std.mem.eql(u8, f, current_file)) {
                        active_idx = idx;
                        break;
                    }
                }

                var it = std.mem.splitScalar(u8, file_contents[active_idx], '\n');
                var line_num: usize = 1;

                while (it.next()) |line| : (line_num += 1) {
                    var row = dvui.box(@src(), .{ .dir = .horizontal }, .{ .id_extra = line_num, .expand = .horizontal });
                    defer row.deinit();

                    // Line numbers
                    dvui.label(@src(), "{d: >3}  ", .{line_num}, .{
                        .font = dvui.Font.theme(.mono).withSize(12),
                        .padding = .{ .x = 12, .y = 1, .w = 8, .h = 1 },
                        .color_text = .{ .color = .{ .r = 100, .g = 100, .b = 100, .a = 255 } },
                    });

                    // Line code
                    dvui.label(@src(), "{s}", .{line}, .{
                        .font = dvui.Font.theme(.mono).withSize(12),
                        .padding = .{ .x = 0, .y = 1, .w = 0, .h = 1 },
                    });
                }
            }
        }
    }

    // 3. STATUS BAR
    {
        var status = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .horizontal, .background = true, .padding = .{ .x = 10, .y = 3, .w = 10, .h = 3 } });
        defer status.deinit();

        dvui.label(@src(), "Ready", .{}, .{ .font = dvui.Font.theme(.mono).withSize(11) });

        spacer(@src());

        dvui.label(@src(), "{s}   |   UTF-8   |   Zig", .{current_file}, .{ .font = dvui.Font.theme(.mono).withSize(11) });
    }

    return .ok;
}
