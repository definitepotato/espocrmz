# Getting Started

This Zig `espocrm` library provides an API client for EspoCRM. To get started you'll have to provide the URL where EspoCRM is located and your method of authentication. Read more from the [official documentation](https://docs.espocrm.com/development/api/#authentication).

## Installation

Add this to your build.zig.zon

```zig
.dependencies = .{
    .espocrmz = .{
        .url = "https://github.com/definitepotato/espocrmz/archive/refs/heads/master.tar.gz",
        //the correct hash will be suggested by zig
    }
}
```

Add this to your build.zig

```zig
const espocrmz = b.dependency("espocrmz", .{
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("espocrmz", espocrmz.module("espocrmz"));
```

You can then import the library into your code like this

```zig
const espocrm = @import("espocrmz").Client;
```

## Basic Usage

### Using API Key Authentication:

```go
  var gpa = std.heap.GeneralPurposeAllocator(.{}){};
  defer _ = gpa.deinit();
  const allocator = gpa.allocator();

  const client = Client.init("https://espocrm.example.com", .{ .api_key = "Your API Key here" });
```

### Making a Read request:

```zig
  const result = try client.readEntity("Contact", "78abc123def456", allocator);
  defer allocator.free(result);
```
