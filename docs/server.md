# Making work the Server
Simple, you first open it once to let it initialize then navigate into the new folder "web_pages/"
Then execute these commands :
```bash
set edit.default_extension ""
edit index
```
Now that you are editing the main page of your server you can begin coding it
Here is the required structure:
```html
<head>
  <title>Website Title Goes Here</title>
  <description>Set this to "NI" if you want to make crawlers not index this page (if someone makes some) or type your page description</description>
  <style for="body">textColor:white;bgColor:black</style>
</head>
<body id="body">
  Now you can put your website code here
</body>
```
Now that you know how to make the base of your website let me give you an example:
Testing All Features:
```html
<head>
  <title>Website Title Goes Here</title>
  <description>Set this to "NI" if you want to make crawlers not index this page (if someone makes some) or type your page description</description>
  <style for="body">textColor:white;bgColor:black</style>
  <style for="text1">textColor:red;bgColor:white</style>
  <style for="rect">bgColor:orange;textColor:white</style>
  <style for="textbox">bgColor:white;textColor:black</style>
</head>
<body id="body">
  <text x="1" y="2">Not styled text</text>
  <newLine>
  <text>New lines are a thing too!
  <text id="text1" x="1" y="4">Styled text</text>
  <button web="example.com" page="index" x="26" y="2">Not styled button</button>
  <button id="button" web="example.com" page="index?styledButton" x="26" y="3">Styled Button</button>
  <rect id="rect" x="25" y="2" width="1" height="20" />
  <textbox id="textbox" x="1" y="5" width="10" />
</body>
```
Here you go!

Now make your own website! Have fun!
