
# See  - https://gist.github.com/1098762
#      > realtime markdown preview with Socket.IO

fs = require 'fs'
http = require 'http'
url = require 'url'
path = require 'path'
pandoc = require 'pdc'  # npm insall pdc,   Alse need instll pandoc on PATH.
markdown = require 'markdown' # npm markdown
socket = require 'socket.io' # npm install socket.io
spawn = require('child_process').spawn

last_version = null

emit_preview = (target, callback) ->
  # callback(result)
  result = ''
  fs.readFile target, "utf8", (err, text) ->
    console.error err  if err

    console.log "----------- emit_preview"
    if (processor == pandoc)
      pandoc text, 'markdown', 'html5', '-S --highlight-style=espresso', (err, result) ->
        console.error err  if err
        sio.sockets.emit 'change', result
        callback(result) if callback
    else if (processor == markdown)
      result = markdown.parse(text)
      sio.sockets.emit 'change', result
      callback(result) if callback

serve_preview = (res, target) ->
  # callback(result)
  res.writeHead 200,  'Content-Type': 'text/html'

  emit_preview target, (result) ->
    res.end PAGE_H + result + PAGE_T

# See https://gist.github.com/701407
serve_static = (res, filename) ->
  fs.exists filename, (exists) ->
    unless exists
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

start_watch = (target) ->
  fs.stat target, (err, stat) ->
    if err
      console.error err
      process.exit 1

    unless stat.isFile()
      console.error target + ' is not file'
      process.exit 1

    fs.watchFile target, {interval: 500}, (curr, prev) ->
      console.log "-------------- curr=#{curr}, prev=#{prev}"
      emit_preview target

#====================
target = process.argv[2]
port = 3000
port = parseInt(process.argv[3]) if process.argv.length > 3

processor = pandoc
if process.argv.length > 4
  processor = markdown if (process.argv[4] == 'markdown')
  processor = markdown if (process.argv[4] == 'pandoc')
  processor = 'github' if (process.argv[4] == 'github')


if processor == 'github'
  gfms = spawn('./node_modules/gfms/bin/gfms', ['-p', port])

  gfms.on 'exit', (code) ->
    console.log('child process exited with code ' + code)

  gfms.stdout.on 'data', (data) ->
    console.log('stdout: ' + data)

  gfms.stderr.on 'data', (data) ->
    console.log('stderr: ' + data)

unless target
  console.error 'usage: coffee preview-md.coffee <filename> [port] [pandoc|markdown|github]'
  console.error ''
  console.error 'sample:'
  console.error '    coffee preview-md.coffee readme.md 3000 pandoc'
  console.error '    coffee preview-md.coffee readme.md 3000 markdown'
  console.error '    coffee preview-md.coffee readme.md 3000 github'
  console.error ''
  process.exit 1

PAGE_H = '''
<!DOCTYPE html>
  <html>
  <head>
    <meta charset="utf-8"></meta>
    <meta http-equiv="Pragma" content="no-cache"></meta>
    <meta http-equiv="cache-control" content="no-cache"></meta>
    <meta http-equiv="expires" content="0"></meta>
    <link rel="shortcut icon" href="/favicon.ico" />
    <link rel="icon" type="image/png" href="/favicon.ico" />
    <script type="text/javascript" src="/socket.io/socket.io.js"></script>
    <script type="text/javascript">
      var socket = io.connect();
      socket.on("change", function (html) {
        document.getElementById("preview").innerHTML = html;
      });
    </script>
  </head>
  <body><div id="preview"></div>
'''

PAGE_T = '''</div></body>
  </html>
'''

server = http.createServer (req, res) ->
  uri = url.parse(req.url).pathname
  # console.log "------- uri=[#{uri}]"
  if (uri == '/')
    serve_preview res, target
  else
    serve_static res, path.join(path.dirname(target), uri)

sio = socket.listen(server)
sio.set 'log level', 1

server.listen port

console.log "start server: localhost:#{port}"

start_watch(target)
