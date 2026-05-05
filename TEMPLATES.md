# Spider Template Modes

## Runtime Mode

Templates são lidos do disco em cada requisição. Nenhuma configuração necessária — é o comportamento padrão.

```zig
// main.zig — não declara spider_templates
pub fn main(init: std.process.Init) !void { ... }
```

Spider monta o caminho físico e lê o arquivo:

```
c.view("docs/index", ...) → {views_dir}/docs/index.html
```

Útil em desenvolvimento (com `watchexec` o servidor reinicia e pega as mudanças).

## Embed Mode

Templates são compilados dentro do binário em tempo de compilação. O binário funciona sem nenhum arquivo `.html` presente no servidor.

Para ativar, declare em `main.zig`:

```zig
pub const spider_templates = @import("embedded_templates.zig").EmbeddedTemplates;
```

O Spider detecta via `@hasDecl(@import("root"), "spider_templates")` — o mesmo padrão do `std_options` da stdlib do Zig.

## Como o Spider decide qual modo usar

Em `context.zig`, na compilação:

```zig
const root = @import("root");
const has_embed = @hasDecl(root, "spider_templates"); // comptime
```

Em `c.view()`:

```zig
if (has_embed) {
    // busca no struct EmbeddedTemplates
} else {
    // lê do disco
}
```

## Scan e geração do embedded_templates.zig

O `generate_templates.zig` (ferramenta do Spider) varre `src/` recursivamente procurando `.html` e `.md`, e gera um struct com cada arquivo embutido:

```zig
pub const EmbeddedTemplates = struct {
    docs_index:      []const u8 = @embedFile("features/docs/views/index.html"),
    docs_quickstart: []const u8 = @embedFile("features/docs/views/quickstart.md"),
    layout:          []const u8 = @embedFile("shared/templates/layout.html"),
    // ...
};
```

Invocado automaticamente pelo `build.zig`:

```zig
const gen = b.addRunArtifact(spider_dep.artifact("generate-templates"));
gen.addArg("src/");
gen.addArg("src/embedded_templates.zig");
exe.step.dependOn(&gen.step);
```

## Normalização de nomes

O gerador transforma o caminho do arquivo em nome de campo:

| Arquivo | Campo gerado |
|---|---|
| `features/docs/views/index.html` | `docs_index` |
| `features/docs/views/http_client.md` | `docs_http_client` |
| `shared/templates/layout.html` | `layout` |
| `shared/templates/layout_docs.html` | `layout_docs` |
| `shared/templates/site-nav.html` | `site_nav` |

Regras: pega o segmento após `views/` ou `templates/`, troca `/` e `-` por `_`, remove a extensão.

Em `c.view()`, o nome passado pelo handler sofre a mesma normalização antes de buscar no struct:

```zig
// "docs/index" → "docs_index"
buf[j] = if (c == '/' or c == '-') '_' else c;
```

## O bug

`main.zig` tinha:

```zig
const templates = @import("embedded_templates.zig").EmbeddedTemplates;
```

Dois problemas:

1. **Nome errado** — Spider procura especificamente `spider_templates`, não `templates`
2. **Sem `pub`** — sem `pub`, `@hasDecl` não enxerga a declaração

Resultado: `has_embed` era sempre `false`. Com `src/` presente funcionava (runtime lê o disco). Sem `src/`, o runtime não achava os arquivos e retornava `TemplateNotFound`.

Correção:

```zig
pub const spider_templates = @import("embedded_templates.zig").EmbeddedTemplates;
```
