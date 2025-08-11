const std = @import("std");
const csvData = @embedFile("test.csv");
const print = std.debug.print;

const CSV = struct {
    Ncolumns: u16,
    Nrows: u16,
    header: [][]const u8,
    data: [][][]const u8,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *CSV) void {
        // Free each row
        for (self.data) |row| {
            self.allocator.free(row);
        }
        // Free the data array
        self.allocator.free(self.data);
        // Free the header array
        self.allocator.free(self.header);
    }
};

fn parseCsv(rawdata: []const u8, allocator: std.mem.Allocator) !CSV {
    var header_list = std.ArrayList([]const u8).init(allocator);
    defer header_list.deinit(); // Clean up the ArrayList itself

    var rows = std.ArrayList([][]const u8).init(allocator);
    defer rows.deinit(); // Clean up the ArrayList itself

    var iter_all_line = std.mem.splitScalar(u8, rawdata, '\n');
    var number_of_column: u16 = 0;
    var number_of_rows: u16 = 0;

    // Parse header
    if (iter_all_line.next()) |header_line| {
        var iter_header_line = std.mem.splitScalar(u8, header_line, ',');
        while (iter_header_line.next()) |column| : (number_of_column += 1) {
            try header_list.append(column);
        }
    }

    // Parse data rows
    while (iter_all_line.next()) |line| {
        // Skip empty lines
        if (line.len == 0) continue;

        var row = std.ArrayList([]const u8).init(allocator);
        defer row.deinit(); // Clean up the ArrayList itself

        var iter_line = std.mem.splitScalar(u8, line, ',');
        while (iter_line.next()) |value_of_column| {
            try row.append(value_of_column);
        }

        const rowslice = try row.toOwnedSlice();
        try rows.append(rowslice);
        number_of_rows += 1; // Fixed: increment per row, not per column
    }

    const rows_result = try rows.toOwnedSlice();
    const header_result = try header_list.toOwnedSlice();

    const result: CSV = CSV{
        .Ncolumns = number_of_column,
        .Nrows = number_of_rows,
        .header = header_result,
        .data = rows_result,
        .allocator = allocator, // Store allocator for cleanup
    };

    return result;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var result = try parseCsv(csvData, allocator);
    defer result.deinit(); // Clean up all allocated memory

    print("Columns: {}, Rows: {}\n", .{ result.Ncolumns, result.Nrows });

    // Print headers
    print("Headers: ", .{});
    for (result.header, 0..) |header, i| {
        print("{s}", .{header});
        if (i < result.header.len - 1) print(", ", .{});
    }
    print("\n", .{});

    // Print first 5 rows
    for (result.data, 0..) |row, i| {
        if (i >= 5) break;
        print("Row {}: ", .{i});
        for (row, 0..) |cell, j| {
            print("{s}", .{cell});
            if (j < row.len - 1) print(", ", .{});
        }
        print("\n", .{});
    }
}
