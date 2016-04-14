{Robot, Adapter, EnterMessage, TextMessage} = require 'hubot'
LayerAPI = require 'layer-api'

class Layer extends Adapter

  constructor: (@robot) ->
    super @robot

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
      conversation: conversationId

    next @robot.brain.userForId id user

  _joinConversation: (conversation) ->
    return unless conversation.id?

    @logger.info  "A new conversation has been created, ID: #{conversation.id}"
    @receive new EnterMessage conversation

  _processMessage = (message) ->
    return unless message.conversation?

    _conversationId = message.conversation.id
    _userId = message.conversation.sender.user_id

    @_createUser _userId, _conversationId, (user) ->
      for part of message.parts
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

    @layer.messages.send envelope.user.conversationId, data, (error, response) ->
      return @logger.info error if error

      @logger.info response.statusCode

  send: (envelope, strings...) ->
    @_sendMsg envelope, strings.join '\n'

  reply: (envelope, strings...) ->
    message = strings.join '\n'
    user = envelope.user.name

    @_sendMsg envelope, "#{user}:#{message}"

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

      switch event
        when 'message.sent'
          @_processMessage data.message
          break
        when 'conversation.created'
          @_joinConversation data.conversation

      res.send 200

    # Tell Hubot we're connected so it can load scripts
    @emit 'connected'

    @logger.info 'Layer Bot is running'

exports.use = (robot) ->
  new Layer robot
