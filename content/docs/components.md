---
title: Components
section: guide
order: 130
---

# Components

A component is a template used as a tag. A page of any size ends up made of them: a card repeated in a list, a panel around a group of things, a badge that knows its own colors. And because a component is a piece of the page with a name, it is also what the server sends when only that piece changes.

The small ones on this page are from the example apps, [Posts](https://posts.spiderme.org) and [Bookings](https://bookings.spiderme.org). The shop that puts them together is from `examples/guide` ([source](https://github.com/llllOllOOll/spiderme/tree/main/examples/guide)): a small server kept as tests.

## A file is a tag

The name of the file is the name of the tag, in PascalCase: `StateBadge.html` is `<StateBadge>`, and so is `state-badge.html`. This is the one of Bookings:

```html from=examples/bookings/src/shared/templates/StateBadge.html
```

```html
<StateBadge state="{ booking.state }" />
```

A component is a template like any other: it has `if`, `for` and other components. What it does not have is a handler. It shows what it is given.

Where the file goes: next to the views of the feature that uses it (`src/features/shop/views`), or in `src/shared/templates` when several features do. A tag finds its file in either place.

## What a component sees

Two things: its attributes, and everything the page was given.

```html from=examples/guide/src/features/shop/views/ProductList.html
```

`<ProductList />` in the page has no attribute. It reads `products` and `q` because the handler gave them to the page. That is the usual way to cut a long page into parts: each part is a file, and none of them needs its values passed down.

`<ProductCard>` is different: it is used once per product, so each use says which one, in attributes.

```html from=examples/guide/src/features/shop/views/ProductCard.html
```

## Attributes

An attribute is written in one of two ways, and they are not the same thing:

- `name="{ product.name }"` gives the component a **value**. Whatever it is (text, a number, true or false), the component gets it as it is: `on_sale` arrives as a boolean and `if (on_sale)` works. The value is escaped where it is finally printed, once, however many components it went through.
- `heading="Products"` gives it **text**, as written.

Do not mix the two in one attribute inside a loop. `href="/shop/{ product.id }"` reaches the component as that very text, braces included, because the loop's `product` does not exist inside the component. Pass the value and build the text where it is used, as `ProductCard` does with `id`: `href="/shop/{ id }"`.

## What goes inside the tag

A component prints what was written inside its tag where it says `{ slot }`:

```html from=examples/guide/src/shared/templates/Panel.html
```

```html from=examples/guide/src/features/shop/views/index.html
```

What is inside the tag belongs to the page, not to the panel: it sees the page's values, and may use other components. A layout works the same way, with the whole page as what goes inside ([Templates](/docs/templates)).

## Components made of components

`ProductCard` uses `PriceTag`, which decides how a price looks:

```html from=examples/guide/src/shared/templates/PriceTag.html
```

There is a limit to how deep components may go inside each other, there to stop one that includes itself: such a page fails with an error instead of never finishing.

The whole page, with every piece in place:

```zig from=examples/guide/src/components_test.zig decl="components: a page is its layout, a panel, and a card for each product"
```

## Sending one component to htmx

When a visitor types in the search box, only the list changes. `c.viewFragment(template, component, data, .{})` renders one component, without the layout and without the rest of the page:

```zig from=examples/guide/src/server.zig decl=Product,catalogue,shop
```

The page and the part come from the same files and the same data, so they cannot drift apart. The first argument is the page the component belongs to; the second, the component.

A request often changes two places of the page: here the list, and a count above it. The answer carries both. The first goes where the request pointed, and the second says where it goes itself:

```html from=examples/guide/src/features/shop/views/ResultCount.html
```

```zig from=examples/guide/src/components_test.zig decl="components: htmx gets the parts that change, each one a component"
```

This is how a large app keeps its pages fast: the frame (a side menu, a top bar) is sent once, and every click after that asks for the component of the content, plus the few places of the frame that change with it, such as a title.

## A component for one page

A component only one page uses can be written in that page, above where it is used. A tag with a capital letter that has other lines inside it, at the top of the file, is a definition:

```html from=examples/guide/src/features/shop/views/receipt.html
```

```zig from=examples/guide/src/components_test.zig decl="components: one defined in the page that uses it"
```

`c.viewFragment` finds these too, by the name of the page and of the component.

## A name that is wrong

A tag that no file answers to prints nothing, and nothing says so. When a part of a page is missing, check the spelling of the tag first:

```html from=examples/guide/src/features/shop/views/typo.html
```

```zig from=examples/guide/src/components_test.zig decl="components: a tag no file answers to prints nothing, and says nothing"
```
