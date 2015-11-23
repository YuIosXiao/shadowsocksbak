###
  Copyright (c) 2014 clowwindy
 
  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to deal
  in the Software without restriction, including without limitation the rights
  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:
 
  The above copyright notice and this permission notice shall be included in
  all copies or substantial portions of the Software.
 
  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
  SOFTWARE.
###
 
fs = require 'fs'
net = require 'net'
spdy = require 'spdy'
encrypt = require './encrypt'
utils = require './utils'
inet = require './inet'
strategy = require './strategy'

inetNtoa = (buf) ->
  buf[0] + "." + buf[1] + "." + buf[2] + "." + buf[3]
inetAton = (ipStr) ->
  parts = ipStr.split(".")
  unless parts.length is 4
    null
  else
    buf = new Buffer(4)
    i = 0

    while i < 4
      buf[i] = +parts[i]
      i++
    buf

currentConnections = 0
connectionIdCount = 1
streamIdCount = 1

createServer = (serverAddr, serverPort, port, key, method, timeout, local_address='127.0.0.1', connections=1) ->
  _connections = {}
  new strategy.WindowSizeStrategy _connections, {}
  
  getConnection = (callback) ->
    # get a connection by random
    if Object.keys(_connections).length + 1 > connections
      utils.debug 'return an existing connection'
      keys = Object.keys(_connections)
      index = Math.floor(Math.random() * keys.length)
      connection = _connections[keys[index]]
      if connection.writable
        process.nextTick ->
          callback(_connections[keys[index]])
        return _connections[keys[index]]
      else
        delete _connections[connection.connectionId]
    # return a new connection
    utils.debug 'return a new connection'
    connection = null
    _socket = net.connect {port: serverPort, host: serverAddr}, ->
      connection = new spdy.Connection(_socket, {
        isServer: false
#        windowSize: 10 * 1024 * 1024  # 10M window size
      })
      connection._setVersion(3.1)
      connection._connectionId = connectionIdCount
      connectionIdCount += 1
      _connections[connection._connectionId] = connection
      callback(connection)
      _socket.on 'end', (err) ->
        utils.error 'connection ended:'
  #        connection.destroy()
        delete _connections[connection._connectionId]
      _socket.on 'close', (err) ->
        delete _connections[connection._connectionId]
      connection.on 'error', (err) ->
        utils.error err
    _socket = new encrypt.ShadowStream _socket, method, key
    _socket.on 'error', (err) ->
      utils.error 'connection error:'
      utils.error err
      _socket.destroy()
      if connection
        delete _connections[connection._connectionId]
      else
        process.nextTick ->
          callback(null)
    return null
   
  createStream = (connection, callback) ->
    stream = new spdy.Stream(connection, {
      id: streamIdCount,
      priority: 7
    })
    streamIdCount += 2
  
    # a silly patch to send SYN_STREAM frame
    headers = {}
    state = stream._spdyState
    connection._lock ->
      state.framer.streamFrame state.id, 0, {
        priority: 7
      }, headers, (err, frame) ->
        if (err) 
          connection._unlock()
          return self.emit('error', err)
        connection.write(frame)
        connection._unlock()
        connection._addStream(stream)
    
        stream.emit('_spdyRequest')
        state.initialized = true
    if callback?
      process.nextTick ->
        callback(stream)
    stream
  

#  udpServer = udpRelay.createServer(local_address, port, serverAddr, serverPort, key, method, timeout, true)

  server = net.createServer((connection) ->
    currentConnections += 1
    stage = 0
    headerLength = 0
    remote = null
    cachedPieces = []
    addrLen = 0
    remoteAddr = null
    remotePort = null
    addrToSend = ""
    utils.debug "connections: #{currentConnections}"
    clean = ->
      utils.debug "clean"
      currentConnections -= 1
      remote = null
      connection = null
      utils.debug "connections: #{currentConnections}"

    connection.on "data", (data) ->
      utils.log utils.EVERYTHING, "connection on data"
      if stage is 5
        return
      if stage is 0
        tempBuf = new Buffer(2)
        tempBuf.write "\u0005\u0000", 0
        connection.write tempBuf
        stage = 1
        utils.debug "stage = 1"
        return
      if stage is 1
        try
        # +----+-----+-------+------+----------+----------+
        # |VER | CMD |  RSV  | ATYP | DST.ADDR | DST.PORT |
        # +----+-----+-------+------+----------+----------+
        # | 1  |  1  | X'00' |  1   | Variable |    2     |
        # +----+-----+-------+------+----------+----------+

        #cmd and addrtype
          cmd = data[1]
          addrtype = data[3]
          if cmd is 1
            # TCP
#          else if cmd is 3
#            # UDP
#            utils.info "UDP assc request from #{connection.localAddress}:#{connection.localPort}"
#            reply = new Buffer(10)
#            reply.write "\u0005\u0000\u0000\u0001", 0, 4, "binary"
#            utils.debug connection.localAddress
#            inetAton(connection.localAddress).copy reply, 4
#            reply.writeUInt16BE connection.localPort, 8
#            connection.write reply
#            stage = 10
          else
            utils.error "unsupported cmd: " + cmd
            reply = new Buffer("\u0005\u0007\u0000\u0001", "binary")
            connection.end reply
            return
          if addrtype is 3
            addrLen = data[4]
          else unless addrtype in [1, 4]
            utils.error "unsupported addrtype: " + addrtype
            connection.destroy()
            return
          addrToSend = data.slice(3, 4).toString("binary")
          # read address and port
          if addrtype is 1
            remoteAddr = inetNtoa(data.slice(4, 8))
            addrToSend += data.slice(4, 10).toString("binary")
            remotePort = data.readUInt16BE(8)
            headerLength = 10
          else if addrtype is 4
            remoteAddr = inet.inet_ntop(data.slice(4, 20))
            addrToSend += data.slice(4, 22).toString("binary")
            remotePort = data.readUInt16BE(20)
            headerLength = 22
          else
            remoteAddr = data.slice(5, 5 + addrLen).toString("binary")
            addrToSend += data.slice(4, 5 + addrLen + 2).toString("binary")
            remotePort = data.readUInt16BE(5 + addrLen)
            headerLength = 5 + addrLen + 2
#          if cmd is 3
#            utils.info "UDP assc: #{remoteAddr}:#{remotePort}"
#            return
          buf = new Buffer(10)
          buf.write "\u0005\u0000\u0000\u0001", 0, 4, "binary"
          buf.write "\u0000\u0000\u0000\u0000", 4, 4, "binary"
          # 2222 can be any number between 1 and 65535
          buf.writeInt16BE 2222, 8
          connection.write buf
          # connect remote server
          utils.info "connecting #{remoteAddr}:#{remotePort}"
          getConnection (aConnection) ->
            if not aConnection?
              connection.destroy() if connection
              return
            remote = createStream(aConnection, ->
              if not remote? or not connection?
                return
              addrToSendBuf = new Buffer(addrToSend, "binary")
              remote.write addrToSendBuf
              i = 0
  
              while i < cachedPieces.length
                piece = cachedPieces[i]
                remote.write piece
                i++
              cachedPieces = null # save memory
               
              remote.pipe connection
              connection.pipe remote
            
              stage = 5
              utils.debug "stage = 5"
            )
          
            remote.on "error", (e)->
              utils.debug "remote on error"
              utils.error "remote #{remoteAddr}:#{remotePort} error: #{e}"
  
            remote.on "close", (had_error)->
              utils.debug "remote on close:#{had_error}"
              if had_error
                connection.destroy() if connection
              else
                connection.end() if connection
  
            remote.setTimeout timeout, ->
              utils.debug "remote on timeout"
              remote.destroy() if remote
              connection.destroy() if connection

          if data.length > headerLength
            buf = new Buffer(data.length - headerLength)
            data.copy buf, 0, headerLength
            cachedPieces.push buf
            buf = null
          stage = 4
          utils.debug "stage = 4"
        catch e
        # may encounter index out of range
          throw e
          utils.error e
          connection.destroy() if connection
          remote.destroy() if remote
      else cachedPieces.push data  if stage is 4
    # remote server not connected
    # cache received buffers
    # make sure no data is lost

    connection.on "error", (e)->
      utils.debug "connection on error"
      utils.error "local error: #{e}"
    
    connection.on "close", (had_error)->
      utils.debug "connection on close:#{had_error}"
      if had_error
        remote.destroy() if remote
      else
        remote.end() if remote
      clean()

    connection.setTimeout timeout, ->
      utils.debug "connection on timeout"
      remote.destroy() if remote
      connection.destroy() if connection
  )
  if local_address?
    server.listen port, local_address, ->
      utils.info "local listening at #{server.address().address}:#{port}"
  else
    server.listen port, ->
      utils.info "local listening at 0.0.0.0:" + port

  server.on "error", (e) ->
    if e.code is "EADDRINUSE"
      utils.error "Address in use, aborting"
    else
      utils.error e

  server.on "close", ->
    udpServer.close()

  return server

exports.createServer = createServer
exports.main = ->
  console.log(utils.version)

  config = utils.parseArgs false
  timeout = Math.floor(config.timeout * 1000) or 300000
  s = createServer config.server, config.server_port, config.local_port, 
    config.password, config.method, timeout, config.local_address, 
    config.connections
  s.on "error", (e) ->
    process.stdout.on 'drain', ->
      process.exit 1
if require.main is module
  exports.main()
