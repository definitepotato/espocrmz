const std = @import("std");
const json = std.json;
const http = std.http;
const Allocator = std.mem.Allocator;

const api_path = "/api/v1";

/// Parses the json object `json_str` and returns the result packaged in a `std.json.Parsed`.
/// You must call `deinit()` of the returned object to clean up allocated resources.
pub fn Deserialize(allocator: Allocator, comptime T: type, json_str: []const u8) !json.Parsed(T) {
    const parsed = try json.parseFromSlice(T, allocator, json_str, .{ .ignore_unknown_fields = true });
    return parsed;
}

/// Takes any struct and returns a json object stringified.
/// You must call `allocator.free()` of the returned object to clean up allocated resources.
pub fn Serialize(allocator: Allocator, any: anytype) ![]u8 {
    const result = try json.stringifyAlloc(allocator, any, .{});
    return result;
}

/// Used to configure the espocrm `Client`.
const ClientConfig = struct {
    api_key: ?[]const u8 = undefined,
};

pub const Client = struct {
    const Self = @This();

    url: []const u8 = undefined,
    config: ClientConfig = undefined,

    pub fn init(url: []const u8, config: ClientConfig) Client {
        return Client{
            .url = url,
            .config = config,
        };
    }

    /// Fetches an `entity_type` record based on the `entity_id`.
    /// You must call `allocator.free()` of the returned object to clean up allocated resources.
    /// Documented at https://docs.espocrm.com/development/api/crud/#read
    pub fn readEntity(
        self: Self,
        allocator: Allocator,
        entity_type: []const u8,
        entity_id: []const u8,
    ) ![]u8 {
        const uri = try std.fmt.allocPrint(allocator, "{s}{s}/{s}/{s}", .{ self.url, api_path, entity_type, entity_id });
        defer allocator.free(uri);
        const endpoint = try std.Uri.parse(uri);

        const body = try self.sendRequest(allocator, http.Method.GET, endpoint, null);
        return body;
    }

    /// Lists all entities of an `entity_type` using `parameters` and `filter_params` (where).
    /// You must call `allocator.free()` of the returned object to clean up allocated resources.
    /// Documented at https://docs.espocrm.com/development/api/crud/#list
    pub fn listEntities(
        self: Self,
        allocator: Allocator,
        entity_type: []const u8,
        parameters: Parameters,
        filter_params: []const Where,
    ) ![]u8 {
        const params = try parameters.encode(allocator);
        defer allocator.free(params);

        const where = try Where.string(allocator, filter_params);
        defer allocator.free(where);

        const uri = try std.fmt.allocPrint(allocator, "{s}{s}/{s}{s}{s}", .{ self.url, api_path, entity_type, params, where });
        defer allocator.free(uri);
        const endpoint = try std.Uri.parse(uri);

        const body = try self.sendRequest(allocator, http.Method.GET, endpoint, null);
        return body;
    }

    /// Creates a new record of an `entity_type` using a json `payload` in the request body.
    /// `Payload` should contain a json string formatted as the `entity_type`, i.e.,
    /// - { "name": "Alice" }
    /// You must call `allocator.free()` of the returned object to clean up allocated resources.
    /// Documented at https://docs.espocrm.com/development/api/crud/#create
    pub fn createEntity(
        self: Self,
        allocator: Allocator,
        entity_type: []const u8,
        payload: []const u8,
    ) ![]u8 {
        const uri = try std.fmt.allocPrint(allocator, "{s}{s}/{s}", .{ self.url, api_path, entity_type });
        defer allocator.free(uri);
        const endpoint = try std.Uri.parse(uri);

        const body = try self.sendRequest(allocator, http.Method.POST, endpoint, payload);
        return body;
    }

    /// Deletes a record of an `entity_type` using the `entity_id`.
    /// You must call `allocator.free()` of the returned object to clean up allocated resources.
    /// Documented at https://docs.espocrm.com/development/api/crud/#delete
    pub fn deleteEntity(
        self: Self,
        allocator: Allocator,
        entity_type: []const u8,
        entity_id: []const u8,
    ) ![]u8 {
        const uri = try std.fmt.allocPrint(allocator, "{s}{s}/{s}/{s}", .{ self.url, api_path, entity_type, entity_id });
        defer allocator.free(uri);
        const endpoint = try std.Uri.parse(uri);

        const body = try self.sendRequest(allocator, http.Method.DELETE, endpoint, null);
        return body;
    }

    /// Updates a record of an `entity_type` using the `entity_id` and a json `payload` in the body of the request.
    /// `Payload` should contain a json string formatted as the `entity_type`, i.e.,
    /// - { "name" : "Alice" }
    /// You must call `allocator.free()` of the returned object to clean up allocated resources.
    /// Documented at https://docs.espocrm.com/development/api/crud/#update
    pub fn updateEntity(
        self: Self,
        allocator: Allocator,
        entity_type: []const u8,
        entity_id: []const u8,
        payload: []const u8,
    ) ![]u8 {
        const uri = try std.fmt.allocPrint(allocator, "{s}{s}/{s}/{s}", .{ self.url, api_path, entity_type, entity_id });
        defer allocator.free(uri);
        const endpoint = try std.Uri.parse(uri);

        const body = try self.sendRequest(allocator, http.Method.PUT, endpoint, payload);
        return body;
    }

    /// Lists all related entities of type `entity_type` of a record with `entity_id` for all related `related_type.
    /// You must call `allocator.free()` of the returned object to clean up allocated resources.
    /// Documented at https://docs.espocrm.com/development/api/relationships/#list-related-records
    pub fn listRelatedEntities(
        self: Self,
        allocator: Allocator,
        entity_type: []const u8,
        entity_id: []const u8,
        related_type: []const u8,
    ) ![]u8 {
        const uri = try std.fmt.allocPrint(allocator, "{s}{s}/{s}/{s}/{s}", .{ self.url, api_path, entity_type, entity_id, related_type });
        defer allocator.free(uri);
        const endpoint = try std.Uri.parse(uri);

        const body = try self.sendRequest(allocator, http.Method.GET, endpoint, null);
        return body;
    }

    /// Links the `entity_id` of type `entity_type` to a `related_entity_type` via the `payload`.
    /// `Payload` should contain the id/ids of the related entity, i.e.,
    /// - { "id": "6a183bcf77198a" }
    /// - { "ids": ["836bc38165a3", "2735b38a3a723"] }
    /// You must call `allocator.free()` of the returned object to clean up allocated resources.
    /// Documented at https://docs.espocrm.com/development/api/relationships/#link
    pub fn linkEntity(
        self: Self,
        allocator: Allocator,
        entity_type: []const u8,
        entity_id: []const u8,
        related_entity_type: []const u8,
        payload: []const u8,
    ) ![]u8 {
        const uri = try std.fmt.allocPrint(allocator, "{s}{s}/{s}/{s}/{s}", .{ self.url, api_path, entity_type, entity_id, related_entity_type });
        defer allocator.free(uri);
        const endpoint = try std.Uri.parse(uri);

        const body = try self.sendRequest(allocator, http.Method.POST, endpoint, payload);
        return body;
    }

    // BUG: Requires a payload but DELETE method usually doesn't contain a payload.
    // `unlinkEntity()` has a transfer_encoding issue due to unexpected message body
    // for the DELETE method.

    /// Unlinks the `entity_id` of type `entity_type` related to a `related_entity_type` via the `payload`.
    /// `Payload` should contain the id/ids of the related entity, i.e.,
    /// - { "id": "6a183bcf77198a" }
    /// - { "ids": ["836bc38165a3", "2735b38a3a723"] }
    /// You must call `allocator.free()` of the returned object to clean up allocated resources.
    /// Documented at https://docs.espocrm.com/development/api/relationships/#unlink
    pub fn unlinkEntity(
        self: Self,
        allocator: Allocator,
        entity_type: []const u8,
        entity_id: []const u8,
        related_entity_type: []const u8,
        payload: []const u8,
    ) ![]u8 {
        const uri = try std.fmt.allocPrint(allocator, "{s}{s}/{s}/{s}/{s}", .{ self.url, api_path, entity_type, entity_id, related_entity_type });
        defer allocator.free(uri);
        const endpoint = try std.Uri.parse(uri);

        const body = try self.sendRequest(allocator, http.Method.DELETE, endpoint, payload);
        return body;
    }

    fn sendRequest(
        self: Self,
        allocator: Allocator,
        method: http.Method,
        endpoint: std.Uri,
        payload: ?[]const u8,
    ) ![]u8 {
        const buf = try allocator.alloc(u8, 1024 * 1024 * 4);
        defer allocator.free(buf);

        var client = http.Client{ .allocator = allocator };
        defer client.deinit();

        var req = try client.open(method, endpoint, .{
            .server_header_buffer = buf,
            .extra_headers = &.{
                .{
                    .name = "content-type",
                    .value = "application/json",
                },
                .{
                    .name = "x-api-key",
                    .value = self.config.api_key.?,
                },
            },
        });
        defer req.deinit();

        switch (method) {
            .POST, .PUT => {
                req.transfer_encoding = .{ .content_length = payload.?.len };
                try req.send();
                var wtr = req.writer();
                try wtr.writeAll(payload.?);
                try req.finish();
                try req.wait();
            },
            else => {
                try req.send();
                try req.finish();
                try req.wait();
            },
        }

        try std.testing.expectEqual(req.response.status, .ok);

        var rdr = req.reader();
        const body = try rdr.readAllAlloc(allocator, 1024 * 1024 * 4);

        return body;
    }
};

pub const FilterOption = enum {
    Equals,
    NotEquals,
    GreaterThan,
    LessThan,
    GreaterThanOrEquals,
    LessThanOrEquals,
    IsNull,
    IsNotNull,
    IsTrue,
    IsFalse,
    LinkedWith,
    NotLinkedWith,
    IsLinked,
    IsNotLinked,
    In,
    NotIn,
    Contains,
    NotContains,
    StartsWith,
    EndsWith,
    Like,
    NotLike,
    Or,
    AndToday,
    Past,
    Future,
    LastSevenDays,
    CurrentMonth,
    LastMonth,
    NextMonth,
    CurrentQuarter,
    LastQuarter,
    CurrentYear,
    LastYear,
    CurrentFiscalYear,
    LastFiscalYear,
    CurrentFiscalQuarter,
    LastFiscalQuarter,
    LastXDays,
    NextXDays,
    OlderThanXDays,
    AfterXDays,
    Between,
    ArrayAnyOf,
    ArrayNoneOf,
    ArrayAllOf,
    ArrayIsEmpty,
    ArrayIsNotEmpty,

    /// Returns the url compatible string version of a `FilterOption` variant.
    pub fn string(self: FilterOption) []const u8 {
        return switch (self) {
            .Equals => "equals",
            .NotEquals => "notEquals",
            .GreaterThan => "greaterThan",
            .LessThan => "lessThan",
            .GreaterThanOrEquals => "greaterThanOrEquals",
            .LessThanOrEquals => "lessThanOrEquals",
            .IsNull => "isNull",
            .IsNotNull => "isNotNull",
            .IsTrue => "isTrue",
            .IsFalse => "isFalse",
            .LinkedWith => "linkedWith",
            .NotLinkedWith => "notLinkedWith",
            .IsLinked => "isLinked",
            .IsNotLinked => "isNotLinked",
            .In => "in",
            .NotIn => "notIn",
            .Contains => "contains",
            .NotContains => "notContains",
            .StartsWith => "startsWith",
            .EndsWith => "endsWith",
            .Like => "like",
            .NotLike => "notLike",
            .Or => "or",
            .AndToday => "andToday",
            .Past => "past",
            .Future => "future",
            .LastSevenDays => "lastSevenDays",
            .CurrentMonth => "currentMonth",
            .LastMonth => "lastMonth",
            .NextMonth => "nextMonth",
            .CurrentQuarter => "currentQuarter",
            .LastQuarter => "lastQuarter",
            .CurrentYear => "currentYear",
            .LastYear => "lastYear",
            .CurrentFiscalYear => "currentFiscalYear",
            .LastFiscalYear => "lastFiscalYear",
            .CurrentFiscalQuarter => "currentFiscalQuarter",
            .LastFiscalQuarter => "lastFiscalQuarter",
            .LastXDays => "lastXDays",
            .NextXDays => "nextXDays",
            .OlderThanXDays => "olderThanXDays",
            .AfterXDays => "afterXDays",
            .Between => "between",
            .ArrayAnyOf => "arrayAnyOf",
            .ArrayNoneOf => "arrayNoneOf",
            .ArrayAllOf => "arrayAllOf",
            .ArrayIsEmpty => "arrayIsEmpty",
            .ArrayIsNotEmpty => "arrayIsNotEmpty",
        };
    }
};

pub const Where = struct {
    filter_type: FilterOption,
    filter_attribute: []const u8,
    filter_value: []const u8,

    /// Returns a string encoded `Where` to embed into a url.
    /// You must call `allocator.free()` of the returned object to clean up allocated resources.
    pub fn string(
        allocator: Allocator,
        filter_params: []const Where,
    ) ![]u8 {
        var idx: usize = 0;
        var list = std.ArrayList(u8).init(allocator);

        for (filter_params) |filter| {
            const params = try std.fmt.allocPrint(
                allocator,
                "&where[{d}][type]={s}&where[{d}][attribute]={s}&where[{d}][value]={s}",
                .{ idx, filter.filter_type.string(), idx, filter.filter_attribute, idx, filter.filter_value },
            );
            defer allocator.free(params);

            try list.appendSlice(params);
            idx += 1;
        }

        return try list.toOwnedSlice();
    }
};

pub const Parameters = struct {
    max_size: usize = 200,
    offset: usize = 0,
    order_asc_desc: []const u8 = undefined,
    order_by: []const u8 = Order.Desc.string(),
    total: bool = false,
    // TODO: select

    pub fn init() Parameters {
        return Parameters{};
    }

    pub const Order = enum {
        Desc,
        Asc,

        pub fn string(self: Order) []const u8 {
            return switch (self) {
                .Desc => "desc",
                .Asc => "asc",
            };
        }
    };

    // TODO: orderBy()

    pub fn setMaxSize(self: *Parameters, value: usize) *Parameters {
        self.max_size = value;
        return self;
    }

    pub fn setOffset(self: *Parameters, value: usize) *Parameters {
        self.offset = value;
        return self;
    }

    pub fn setOrder(self: *Parameters, value: Order) *Parameters {
        self.order_asc_desc = value.string();
        return self;
    }

    pub fn setTotal(self: *Parameters, value: bool) *Parameters {
        self.total = value;
        return self;
    }

    /// Returns string encoded `Parameters` to embed into a url.
    /// You must call `allocator.free()` of the returned object to clean up allocated resources.
    pub fn encode(self: Parameters, allocator: Allocator) ![]u8 {
        const params = try std.fmt.allocPrint(
            allocator,
            "?maxSize={d}&offset={d}&total={any}&order={s}",
            .{ self.max_size, self.offset, self.total, self.order_by },
        );

        return params;
    }
};
