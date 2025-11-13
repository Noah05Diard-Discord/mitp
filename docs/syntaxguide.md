# Full MCML Syntax Guide and how they work
Here is the full MCML Syntax Guide.

## `<head>`
```html
<head>
</head>
```
The `<head>` is a part where it tells information either to the browser with styling or crawlers what to do/how to render your website.
This tag is **REQUIRED**.
All tags in this tag **MUST BE IN THE CORRECT ORDER** (The order is basically the order i'm telling you each tags in head)

### `<title>`
```html
<head>
  <title>My Cool Website</title>
</head>
```
The `<title>` is always located inside the `<head>` for crawlers again, but it will probably be added in the next update to render it.
This tag is **REQUIRED**.

### `<description>`
```html
<head>
  <title>My Cool Website</title>
  <description>This Website is very cool and i like it!</description>
</head>
```
The `<description>` is always located inside the `<head>` for crawlers again, but it will probably be added in the next update to render it.
This tag is **REQUIRED**.

### `<style>`
```html
<head>
  <title>My Cool Website</title>
  <description>This Website is very cool and i like it!</description>
  <style for="body">textColor:white;bgColor:black</style>
</head>
```
Now this tag is very special, it's not necessarily required but, let me first explain it.
To style an element add an "id" parameter inside the tag.
Example:
```html
<rect id="myRectStyle" x="2" y="2" width="2" height="2" />
```
This draws a 2x2 rectangle at the pos X/Y : 2/2

This also works with the body which **must** be styled else, nothing will show up.
Example:
```html
<head>
  Other tags in here
  <style for="body">textColor:white;bgColor:black</style>
</head>
<body id="body">
  <text>This text is white and the background</text>
  <newLine>
  <text>And the background of the whole page is black</text>
</body>
```

## `<body>`
The body contains all of the code that'll get rendered by your web browser.

:warning: I'll continue this wiki later today.
