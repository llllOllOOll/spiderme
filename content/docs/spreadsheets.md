---
title: Spreadsheets (xlsx)
section: guide
order: 190
---

# Spreadsheets (xlsx)

`spider.xlsx` writes and reads Excel `.xlsx` files: an export people open in Excel, LibreOffice or Google Sheets, and an import of a file they filled in. It is written in Zig, with no other library and no temporary files.

The code on this page is from `examples/guide` ([source](https://github.com/llllOllOOll/spiderme/tree/main/examples/guide)): a small server kept as tests, for what the example apps do not use.

## Turning it on

It is one of the parts of Spider a project asks for by name, in `build.zig`, where the Spider dependency is declared:

```zig from=examples/guide/build.zig
```

Without `.xlsx = true`, code that uses `spider.xlsx` does not compile.

## An export

```zig from=examples/guide/src/server.zig decl=Order,orders,exportOrders
```

- A workbook has sheets; a sheet has cells, by row and column, both counted from zero. Cells can be set in any order.
- A value is `.{ .text = ... }`, `.int(n)`, `.{ .number = ... }`, `.{ .boolean = ... }`, `.{ .date = ... }`, `.{ .datetime = ... }`, `.{ .formula = "SUM(B2:B4)" }` or `.blank`.
- A style says how a cell looks: `bold`, `italic`, `font_color`, `fill`, `border`, `h_align`, `wrap`, and `number_format` (`.integer`, `.decimal`, `.thousands`, `.thousands_decimal`, `.percent`, `.date`, `.time` and others).
- `book.toOwnedSlice(allocator)` is the file, as bytes. [`c.download`](/docs/uploads) sends it with the name the browser saves it under.

The sheet also takes column widths and row heights, merged cells, links, frozen rows, filter buttons, and how it prints (paper, orientation, margins, a heading repeated on every page).

The test reads the file back, the way the next section does:

```zig from=examples/guide/src/files_test.zig decl="xlsx: the export is a file Excel opens, and reading it back gives the same rows"
```

## An import

A visitor uploads a file ([Uploads](/docs/uploads) shows the form), and the handler reads it one row at a time:

```zig from=examples/guide/src/server.zig decl=importOrders
```

```zig from=examples/guide/src/files_test.zig decl=upload,multipart decl="xlsx: an uploaded spreadsheet is read row by row"
```

What to know about a file someone else made:

- **Rows and cells have gaps.** A row or a cell that was never filled is not in the file. Go by `row.number` and `cell.column`, never by the position in the loop.
- **A cell is what it is, not what the column should be.** The same column often has numbers and numbers typed as text. A value is `.text`, `.number`, `.boolean`, `.date`, `.time`, `.err` or `.empty`: handle the ones the app accepts and say what is wrong with the rest.
- **Dates are numbers in the file.** A cell is a `.date` when its format shows a date.
- **Formulas are not calculated.** A formula cell gives the value the author's program last saved.
- **A row lasts until the next one.** The row, its cells and their text are valid until the next `rows.next()`: copy what is kept.

## A file from a stranger

An `.xlsx` is a zip, and a small one can expand into gigabytes. `Reader.open` takes limits, and `.{}` is the set meant for uploads: 16 MiB for the file, 100,000 rows a sheet, and a bound on how far the file may expand. Past a limit, or with a file that is not a spreadsheet, it fails instead of reading on:

```zig from=examples/guide/src/files_test.zig decl="xlsx: a file that is not a spreadsheet is refused, not read"
```

`xlsx.ReadLimits.large` is for big files from a source the app knows.
