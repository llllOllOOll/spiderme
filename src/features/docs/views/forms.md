-- doc

# Form Data

Spider provides a powerful `spider.form` module for parsing form submissions with support for arrays, dot notation for nested fields, and automatic URL decoding.

## Basic Usage

Parse form data from a POST request using `c.parseForm()`:

```zig
const LoginInput = struct { username: []const u8, password: []const u8 };

pub fn login(c: *spider.Ctx) !spider.Response {
    const input = try c.parseForm(LoginInput);
    // input.username, input.password available
    return c.redirect("/dashboard");
}
```

## Nested Fields (Dot Notation)

Access nested struct fields using dot notation in form field names:

```html
<form method="POST" action="/users">
  <input name="user.name" value="Alice">
  <input name="user.email" value="alice@example.com">
  <input name="user.age" value="25">
</form>
```

```zig
const UserInput = struct { user: struct { name: []const u8, email: []const u8, age: i32 } };

pub fn createUser(c: *spider.Ctx) !spider.Response {
    const input = try c.parseForm(UserInput);
    // input.user.name, input.user.email, input.user.age
}
```

## Arrays

Parse multiple values for the same field name:

```html
<form method="POST" action="/tags">
  <input name="tags[]" value="zig">
  <input name="tags[]" value="web">
  <input name="tags[]" value="framework">
</form>
```

```zig
const TagInput = struct { tags: [][]const u8 };

pub fn createTags(c: *spider.Ctx) !spider.Response {
    const input = try c.parseForm(TagInput);
    // input.tags is a slice of []const u8
}
```

## Form Parser Features

- **URL decoding**: Automatically decodes `%20` to space, `%40` to `@`, etc.
- **Arrays**: Use `name="field[]"` for multiple values
- **Nested structs**: Use `user.name` notation for nested fields
- **Optional fields**: Fields not present in the form are left as their default values
- **Arena allocation**: All memory allocated in `c.arena` (freed after request)
