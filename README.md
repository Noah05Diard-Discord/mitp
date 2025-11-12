# mitp
Minecraft InTernet Projekt
# MCML Syntax Guide
```html
<head>
 <title>Website Title</title>
 <description>The description for internet crawlers if someone makes Google heh</description>
 <style for="body">textColor:black;bgColor:white</style>
 <script>
  // Your MCJS Code
 </script>
</head>
<body id="body">
 ; Comments aren’t a thing in MCML but here listen, the syntax must be in **THIS ORDER**
 ; for the parameters in elements, if the name of the parameter is encased in a <> that means optional
 <text <id>="idForStyling">Text!</text>
 <newLine>
 <button <id>="idForStyling" web="example.com" page="index" <x>="1" <y>="1">Yeah a button</button>
 <newLine>
 <rect <id>="idForStyling" <x>="1" <y>="1" width="5" height="5" />
 <newLine>
 <textbox <id>="idForMCJSAndStyling" <x>="1" <y>="1" width="5"  height="3" />
</body>
```
You **MUST** give styling to body.
# MCJS Syntax Guide

```js
var elem = get("elementId")

// Here are the different methods for that object
elem.bgColor = "red"      // Sets the BG Color to red
elem.textColor = "white"  // Sets the TEXT Color to white
elem.width = "5"          // Sets the width to 5 pixels (ONLY WORKS WITH RECT AND TEXTBOX)
elem.height = "5"         // Sets the height to 5 pixels (ONLY WORKS WITH RECT AND TEXTBOX)
elem.x = "1"              // Sets the X pos to 1
elem.y = "1"              // Sets the Y pos to 1
elem.text = "Hello, world!" // Sets the text to that, works with buttons and text elements only
elem.web = "example.com"  // Sets the dest website, only works with buttons
elem.page = "index"       // Sets the dest page, only works with buttons
var(elem.content) // Returns the element content, ONLY WORKS WITH TEXTBOX
elem.setContent("Content goes here, you can use var() too")
// Now events!
// You can hook into button clicks — set the web tag to "#" and page to "#" to use MCJS on it!
// Here is the ONLY VALID SYNTAX!

codeblock buttonClicked() {
  // Here put your code
}
hook("click", "buttonId", "buttonClicked")

// Now you can do other stuff like waits
wait(5) // Waits 5 seconds

// Or other things
redirect("example.com", "index") // Redirects

// You can define variables to use them everywhere
var test = "Hey"
elem.text = var("test")

// And almost forgot, MATH
var calc = "5 + 5"
var calced = eval(var("calc"))
elem.text = var("calced")

// Also! COOKIES
var cookie = getCookie("cookieName")
setCookie("cookieName", var(calced))
var cexist = cookieExist("iDontExist")

// If statements
if (cexist == true) {
  // do stuff
} elseif (cexist == var(calc)) {
  // do other stuff
} else {
  // do stuff
}

// For loops
for (k = 1; 5) {
  // Counts from 1 to 5
  // Do stuff — you have the var k here only
  elem.text = var("k")
}

// THAS ALL FOR NOW!

```
---

# 🧩 How to Integrate

Add this inside your MCML <head>:
```html
<script>
// Your code here
</script>
```

# Code Editor supports
Most code editor will highlight and support my cursed syntax, if anyone makes a NPP or VSCode extension to support it feel free to contact me on discord @noah05diard and i'll add it here
Supported Extensions:
- None :(

**For more information about other elements, like router, dns server, webserver, client find their own pages in the folder : docs**
When im on PC and upload them...