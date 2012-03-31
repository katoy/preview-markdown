
# See  - https://gist.github.com/1098762
#      > realtime markdown preview with Socket.IO

fs = require 'fs'
http = require 'http'
url = require 'url'
path = require 'path'
pandoc = require 'pdc'  # npm insall pdc,   Alse need instll pandoc on PATH.
socket = require 'socket.io' # npm install socket.io

target = process.argv[2]
port = 3000
port = parseInt(process.argv[3]) if process.argv.length > 3

unless target
  console.error 'usage: ' + process.argv[0] + ' ' + process.argv[1] + ' <filename> [port]'
  process.exit 1

_res = null

PAGE = "<!DOCTYPE html><html><head>" + "<meta charset=\"utf-8\"></meta>" +
'<meta http-equiv="Pragma" content="no-cache"></meta><meta http-equiv="cache-control" content="no-cache"></meta><meta http-equiv="expires" content="0"></meta>' +
"<script type=\"text/javascript\" src=\"/socket.io/socket.io.js\"></script>" + "<script type=\"text/javascript\">var socket = io.connect();socket.on(\"change\", function (html) { document.getElementById(\"preview\").innerHTML = html; });</script>" +
"</head>" + "<body><div id=\"preview\"></div></body></html>"

server = http.createServer (req, res) ->
  uri = url.parse(req.url).pathname

  if (uri == '/')
    serve_preview res, target
  else
    serve_static res, path.join(path.dirname(target), uri)

server.listen port
console.log "start server: localhost:#{port}"

sio = socket.listen(server)

fs.stat target, (err, stat) ->
  if err
    console.error err
    process.exit 1

  unless stat.isFile()
    console.error target + ' is not file'
    process.exit 1

  fs.watchFile target, interval: 500, (curr, prev) -> emit_preview(target)

emit_preview = (target) ->
  fs.readFile target, "utf8", (err, text) ->
    console.error err  if err

    pandoc text, 'markdown', 'html5', '-S --highlight-style=espresso', (err, result) ->
      console.error err  if err
      sio.sockets.emit 'change', result

serve_preview = (res, target) ->
  res.writeHead 200,  'Content-Type': 'text/html'
  res.end PAGE
  emit_preview target

# See https://gist.github.com/701407
serve_static = (res, filename) ->
  path.exists filename, (exists) ->
    if !exists
      res.writeHead 404, {"Content-Type": "text/plain"}
      res.write "404 Not Found: #{filename}\n"
      res.end()
      return

    filename += '/index.html' if fs.statSync(filename).isDirectory()
    fs.readFile filename, "binary", (err, file) ->
      if err
        res.writeHead 500, {"Content-Type": "text/plain"}
        res.write err + "\n"
        res.end()
      else
        res.writeHead 200
        res.write file, "binary"
        res.end()
