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
spdy = require 'spdy'
http = require 'http'
net = require 'net'
url = require 'url'
path = require "path"
encrypt = require './encrypt'
utils = require "./utils"
inet = require "./inet"

exports.main = ->
 
  console.log(utils.version)
  
  inetNtoa = (buf) ->
    buf[0] + "." + buf[1] + "." + buf[2] + "." + buf[3]
  
  config = utils.parseArgs true

  timeout = Math.floor(config.timeout * 1000) or 300000
  portPassword = config.port_password
  
  if not (config.server and (config.server_port or portPassword) and config.password)
    utils.warn 'config.json not found, you have to specify all config in commandline'
    process.exit 1
    
  connections = 0
  
  if portPassword 
    if config.server_port or config.password
      utils.warn 'warning: port_password should not be used with server_port and password. server_port and password will be ignored'
  else
    portPassword = {}
    portPassword[config.server_port.toString()] = config.password
      
    
  for _port, key of portPassword
    (->
      # let's use enclosures to seperate scopes of different servers
      port = _port
      utils.info "calculating ciphers for port #{port}"

      server = net.createServer((socket) ->
        socket = new encrypt.ShadowStream socket, config.method, key
        conn = new spdy.Connection(socket, {
          isServer: true,
          client: false
        }, server)
       
        conn._setVersion(3.1)
        
        conn.on 'error', (err) ->
          utils.error err
          
        conn.on 'stream', (stream) ->
          connections += 1
          stage = 0
          headerLength = 0
          remote = null
          cachedPieces = []
          addrLen = 0
          remoteAddr = null
          remotePort = null
          utils.debug "connections: #{connections}"
          
          clean = ->
            utils.debug "clean"
            connections -= 1
            remote = null
            stream = null
            utils.debug "connections: #{connections}"
    
          stream.on "data", (data) ->
            utils.log utils.EVERYTHING, "connection on data"
            if stage is 5
#              stream.pause()  unless remote.write(data)
              return
            if stage is 0
              try
                addrtype = data[0]
                if addrtype is undefined
                  return
                if addrtype is 3
                  addrLen = data[1]
                else unless addrtype in [1, 4]
                  utils.error "unsupported addrtype: " + addrtype + " maybe wrong password"
                  stream.destroy()
                  return
                # read address and port
                if addrtype is 1
                  remoteAddr = inetNtoa(data.slice(1, 5))
                  remotePort = data.readUInt16BE(5)
                  headerLength = 7
                else if addrtype is 4
                  remoteAddr = inet.inet_ntop(data.slice(1, 17))
                  remotePort = data.readUInt16BE(17)
                  headerLength = 19
                else
                  remoteAddr = data.slice(2, 2 + addrLen).toString("binary")
                  remotePort = data.readUInt16BE(2 + addrLen)
                  headerLength = 2 + addrLen + 2
                # connect remote server
                remote = net.connect(remotePort, remoteAddr, ->
                  utils.info "connecting #{remoteAddr}:#{remotePort}"
                  if not remote? or not stream?
                    return
                  i = 0
        
                  while i < cachedPieces.length
                    piece = cachedPieces[i]
                    remote.write piece
                    i++
                  cachedPieces = null # save memory
                           
                  remote.pipe stream
                  stream.pipe remote
        
                  stage = 5
                  utils.debug "stage = 5"
                )
       
                remote.on "error", (e)->
                  utils.debug "remote on error"
                  utils.error "remote #{remoteAddr}:#{remotePort} error: #{e}"
     
                remote.on "close", (had_error)->
                  utils.debug "remote on close:#{had_error}"
                  if had_error
                    stream.destroy() if stream
                  else
                    stream.end() if stream
       
                remote.setTimeout timeout, ->
                  utils.debug "remote on timeout"
                  remote.destroy() if remote
                  stream.destroy() if stream
        
                if data.length > headerLength
                  # make sure no data is lost
                  buf = new Buffer(data.length - headerLength)
                  data.copy buf, 0, headerLength
                  cachedPieces.push buf
                  buf = null
                  
                stage = 4
                utils.debug "stage = 4"
              catch e
                # may encouter index out of range
                utils.error e
                stream.destroy()
                remote.destroy()  if remote
            else cachedPieces.push data  if stage is 4
              # remote server not connected
              # cache received buffers
              # make sure no data is lost
         
          stream.on "error", (e)->
            utils.debug "connection on error"
            utils.error "local error: #{e}"
    
          stream.on "close", (had_error)->
            utils.debug "connection on close:#{had_error}"
            if had_error
              remote.destroy() if remote
            else
              remote.end() if remote
            clean()
        
          stream.setTimeout timeout, ->
            utils.debug "connection on timeout"
            remote.destroy()  if remote
            stream.destroy() if stream
        )
      servers = config.server
      unless servers instanceof Array
        servers = [servers]
      for server_ip in servers
        server.listen port, server_ip, ->
          utils.info "server listening at #{server_ip}:#{port} "
        
      server.on "error", (e) ->
        if e.code is "EADDRINUSE"
          utils.error "Address in use, aborting"
        else
          utils.error e
        process.stdout.on 'drain', ->
          process.exit 1
    )()

if require.main is module 
  exports.main()

