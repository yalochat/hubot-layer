{Robot,Adapter,EnterMessage,TextMessage,User} = require 'hubot'
LayerAPI = require 'layer-api'

class Layer extends Adapter

  constructor: (robot) ->
    super robot

    @token = process.env.LAYER_TOKEN
    @appId = process.env.LAYER_APP_ID
    @botOperator = process.env.BOT_OPERATOR
    @logger = @robot.logger

    @logger.info 'Layer Bot: Adapter loaded :)'

  _createUser: (userId, conversationId, next) ->
    id = "#{userId}:#{conversationId}"

    user =
      id: id
      name: userId
      room: conversationId
      nickname: userId

    @logger.info 'Trying to create a new user with data:'
    @logger.info user

    next @robot.brain.userForId id, user

  _joinConversation: (conversation) ->
    return unless conversation.id?

    _conversationId = conversation.id

    message:
      room: _conversationId

    newConversation = new EnterMessage message, null, null

    if newConversation?
      @logger.info  "A new conversation has been created, ID: #{conversation.id}"
      @receive(newConversation) if newConversation?

  _processMessage: (message) ->
    return unless message.conversation?

    _conversationId = message.conversation.id
    _userId = message.sender.user_id

    # Ignore our own messages
    return if _userId == @botOperator

    @_createUser _userId, _conversationId, (user) =>
      @logger.info "A new user with the id: '#{user.id}' has been created"

      for part in message.parts
        if part.mime_type is 'text/plain'
          message = new TextMessage user, part.body.trim(), user.id
          @receive(message) if message?

  _sendMessage: (envelope, message) ->
    data =
      sender:
        user_id: @botOperator
      parts: [
        (body: message, mime_type: 'text/plain')
      ],
      notification:
        text: message,
        sound: 'chime.aiff'

    conversationId = envelope.room

    @logger.info "Trying to send a message to conversation: '#{conversationId}"

    @layer.messages.send conversationId, data, (error, response) =>
      return @logger.info error if error

      @logger.info "The message has been send to conversation: #{response.body.conversation.id}"

  send: (envelope, strings...) ->
    @_sendMessage envelope, strings.join '\n'

  reply: (envelope, strings...) ->
    message = strings.join '\n'
    user = envelope.user.nickname

    @_sendMessage envelope, "#{user}:#{message}"

  run: ->
    unless @token
      @emit 'error', new Error 'The environment variable "LAYER_TOKEN" is required.'

    unless @appId
      @emit 'error', new Error 'The environment variable "LAYER_APP_ID" is required.'

    unless @botOperator
      @emit 'error', new Error 'The environment variable "BOT_OPERATOR" is required'

    @layer = new LayerAPI token: @token, appId: @appId

    @robot.router.post '/', (req, res) =>
      return res.send 400 unless req.body.event?.type?

      data = req.body
      event = data.event.type

      @logger.info "A new event of type: '#{event}' has been received"

      switch event
        when 'message.sent'
          @_processMessage data.message
          break
        when 'conversation.created'
          break

      res.send 200

    # Tell Hubot we're connected so it can load scripts
    @emit 'connected'

    @logger.info 'Layer Bot is running'

exports.use = (robot) ->
  new Layer robot
