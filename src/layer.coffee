{Robot,Adapter,EnterMessage,TextMessage,User} = require 'hubot'
LayerAPI = require 'layer-api'

class Layer extends Adapter

  constructor: (robot) ->
    super robot

    # Set instance variables
    @token = process.env.LAYER_TOKEN
    @appId = process.env.LAYER_APP_ID
    @botOperator = process.env.BOT_OPERATOR
    @logger = @robot.logger

    @logger.info 'Layer Bot: Adapter loaded :)'

  _createUser: (userId, conversationId, next) ->
    # Generate ID for User in the brain
    id = "#{userId}:#{conversationId}"

    # Object that will be stored in the brain of robot
    user =
      id: id
      name: userId
      room: conversationId
      nickname: userId

    @logger.info 'Trying to create a new user with data:'
    @logger.info user

    next @robot.brain.userForId id, user

  _joinConversation: (conversation) ->
    # If the id conversation is not set, return function
    return unless conversation.id?

    _conversationId = conversation.id

    message:
      room: _conversationId

    newConversation = new EnterMessage message, null, null

    if newConversation?
      @logger.info  "A new conversation has been created, ID: #{conversation.id}"

      # Send message of type EnterMessage
      @receive(newConversation) if newConversation?

  _processMessage: (message) ->
    return unless message.conversation?

    _conversationId = message.conversation.id
    _userId = message.sender.user_id

    # Ignore our own messages
    return if _userId == @botOperator

    # Create a new user if not exists for message
    @_createUser _userId, _conversationId, (user) =>
      @logger.info "A new user with the id: '#{user.id}' has been created"

      for part in message.parts
        if part.mime_type is 'text/plain'
          message = new TextMessage user, part.body.trim(), user.id
          @receive(message) if message?

  _sendMessage: (envelope, message) ->
    # Data used to send a message to Layer
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

    # Send message to conversation of Layer
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

    # Initialize client of Layer Platform
    @layer = new LayerAPI token: @token, appId: @appId

    # Webhook used to listen income requests
    @robot.router.post '/', (req, res) =>
      # Return bad request if event object or event.type value is not set
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
