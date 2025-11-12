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
 <textbox <id>="idForStyling" <x>="1" <y>="1" width="5" />
</body>
```
You **MUST** give styling to body.
# MCJS Syntax Guide
```lua
Read the environment:
-- Create safe environment
    local env = {
        elements = pageEnv.elements,
        setCookie = pageEnv.setCookie,
        getCookie = pageEnv.getCookie,
        cookieExist = pageEnv.cookieExist,
        redirect = pageEnv.redirect,
        wait = pageEnv.wait,
        print = print,
        sleep = sleep
    }
    
    setmetatable(env, {__index = _G})
    
    local func, err = load(script, "page_script", "t", env)
    if func then
        local success, result = pcall(func)
        if not success then
            print("Script error: " .. tostring(result))
        end
    else
        print("Script load error: " .. tostring(err))
    end
```
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
