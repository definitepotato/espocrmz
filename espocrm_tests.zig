const std = @import("std");
const print = std.debug.print;
const assert = std.debug.assert;
const espocrm = @import("espocrm.zig");

test "deserialize json string" {
    const allocator = std.testing.allocator;

    const Account = struct { accountNumber: []u8, name: []u8 };
    const json_string = "{\"name\":\"Alice\",\"registration\":\"Alice\",\"batchID\":\"111\",\"accountNumber\":\"12345\"}";

    const parsed = try espocrm.Deserialize(allocator, Account, json_string);
    defer parsed.deinit();

    try std.testing.expect(std.mem.eql(u8, parsed.value.accountNumber, "12345"));

    try std.testing.expect(std.mem.eql(u8, parsed.value.name, "Alice"));
}

test "serialize struct" {
    const allocator = std.testing.allocator;

    const Acc = struct { name: []const u8, registration: []const u8, batchID: []const u8, accountNumber: []const u8 };
    const list = Acc{ .name = "Alice", .registration = "Alice", .batchID = "111", .accountNumber = "12345" };

    const stringified = try espocrm.Serialize(allocator, list);
    defer allocator.free(stringified);

    try std.testing.expect(std.mem.eql(
        u8,
        stringified,
        "{\"name\":\"Alice\",\"registration\":\"Alice\",\"batchID\":\"111\",\"accountNumber\":\"12345\"}",
    ));
}

test "where filter encoding" {
    const allocator = std.testing.allocator;

    const where = try espocrm.Where.string(allocator, &[_]espocrm.Where{
        .{ .filter_type = espocrm.FilterOption.Equals, .filter_attribute = "a", .filter_value = "c" },
        .{ .filter_type = espocrm.FilterOption.NotEquals, .filter_attribute = "b", .filter_value = "d" },
    });
    defer allocator.free(where);

    try std.testing.expect(std.mem.eql(
        u8,
        where,
        "&where[0][type]=equals&where[0][attribute]=a&where[0][value]=c&where[1][type]=notEquals&where[1][attribute]=b&where[1][value]=d",
    ));
}

test "parameter encoding" {
    const allocator = std.testing.allocator;

    var params = espocrm.Parameters.init();

    _ = params.setMaxSize(10).setOrder(espocrm.Parameters.Order.Asc);
    const res = try params.encode(allocator);
    defer allocator.free(res);

    try std.testing.expect(std.mem.eql(u8, res, "?maxSize=10&offset=0&total=false&order=desc"));
}
