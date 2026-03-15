# Changes Required for New Spider Version

## Update Status
- ✅ **Build works** after fixes
- ✅ **Server runs** without PostgreSQL
- ❌ **PostgreSQL shows error** in new version
- ✅ **Web documentation works** normally

## Identified Changes

### 1. PostgreSQL API (`spg.init()`)
**Before:**
```zig
try spg.init(allocator, .{});
```

**After:**
```zig
try spg.init(allocator, io, .{});
```

**Note:** The function now requires `io` as the second parameter.

### 2. Error in New PostgreSQL Version
The current code shows an error in line 189 of Spider's `pg.zig` file:
```
index out of bounds: index 75, len 74
```

This suggests a change in how connection configurations are processed.

### 3. Recommended Configuration
To use the new version without PostgreSQL for now:
```zig
// Comment out PostgreSQL initialization
try spider.loadEnv(allocator, ".env");
// try spg.init(allocator, io, .{});
// defer spg.deinit();
// try db_migrate.run();
```

## Documentation That Needs Updating

### Web Documentation Sections:
1. **PostgreSQL** (`/docs/postgres`) - Update code examples
2. **Pooling** (`/docs/pooling`) - Check for API changes
3. **Quick Start** (`/docs/quickstart`) - Update initial examples

### Affected Code Examples:
- All functions using `spg.init()`
- Database configuration examples
- Connection pool examples

## Next Steps
1. Investigate the specific cause of PostgreSQL error
2. Update HTML documentation templates
3. Test specific functionalities
4. Update code examples