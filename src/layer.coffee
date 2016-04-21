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

  _makeId: (userId, conversationId) ->
    # Make id for user to add a brain of robot
    "#{userId}:#{conversationId}"

  _getUser: (id) ->
    # Get user for the brain of robot
    @robot.brain.userForId id

  _createUser: (userId, conversationId, metadata, next) ->

    # Generate ID for User in the brain
    id = @_makeId userId, conversationId

    # Set default metadata if is null
    metadata = metadata or {}

    # Object that will be stored in the brain of robot
    user =
      name: userId
      room: conversationId
      metadata: metadata

    @logger.info 'Trying to create a new user with data:'
    @logger.info user

    # Create a new user in robot brain and call callback
    next @robot.brain.userForId id, user

  _processConversation: (conversation) ->
    # If id conversation is not set, return function
    return unless conversation.id?

    # If metadata, user or chat profile are not set, return function
    return unless conversation.metadata?.user?.chatProfile?

    # Get data used to build a new user
    _conversationId = conversation.id
    _userId = conversation.metadata.user.chatProfile
    _metadata = conversation.metadata
    _id = @_makeId _userId, _conversationId

    # Get user from the robot brain
    user = @_getUser _id

    if user
      @logger.info "Conversation #{_conversationId} already receive"

      # Create a instance of EnterMessage for conversation
      message = new EnterMessage user, null, null

      @_sendConversation message
    else
      @logger.info "New conversation has been received"

      # Create the new user
      @_createUser _userId, _conversationId, _metadata, (user) =>
        message = new EnterMessage user, null, null

        @_sendConversation message

  _sendConversation: (message) ->
    # Send only if message is not null
    if message?
      @logger.info "A conversation has been received"

      @receive message

  _processMessage: (message) ->
    return unless message.conversation?

    # Get data used to build a new user
    _conversationId = message.conversation.id
    _userId = message.sender.user_id
    _id = @_makeId _userId, _conversationId

    # Ignore our own messages
    return if _userId == @botOperator

    # Get user from the robot brain
    user = @_getUser _id

    if user
      @logger.info "The user already exists"

      # Iterate parts of message
      @_sendMessages user, message
    else
      # Make request to get metadata of conversation
      @layer.conversations.get _conversationId, (err, res) =>
        return @logger.info err if err

        # Get metadata of conversation
        _metadata = res.body.metadata or {}

        @logger.info "Conversation #{_conversationId} has been obtained, metada:"
        @logger.info _metadata

        # Create the new user
        @_createUser _userId, _conversationId, _metadata, (user) =>
          @logger.info "A new user with the id: #{_id} has been created"

          @_sendMessages user, message

  _sendMessages: (user, message) ->
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
    # Validate if token has been setted
    unless @token
      @emit 'error', new Error 'The environment variable "LAYER_TOKEN" is required.'

    # Validate if appId has been setted
    unless @appId
      @emit 'error', new Error 'The environment variable "LAYER_APP_ID" is required.'

    # Validate if botOperator has been setted
    unless @botOperator
      @emit 'error', new Error 'The environment variable "BOT_OPERATOR" is required'

    # Initialize client of Layer Platform
    @layer = new LayerAPI token: @token, appId: @appId

    # Webhook used to listen income requests
    @robot.router.post '/', (req, res) =>
      # Return bad request if event object or event.type value is not set
      return res.send 400 unless req.body.event?.type?

      # Get body of request
      data = req.body

      # Get event type
      event = data.event.type

      @logger.info "A new event of type: '#{event}' has been received"

      # Process event
      switch event
        when 'message.sent'
          @_processMessage data.message
          break
        when 'conversation.created'
          @_processConversation data.conversation
          break

      # Send status code 'success'
      res.send 200

    # Tell Hubot we're connected so it can load scripts
    @emit 'connected'

    @logger.info 'Layer Bot is running'

exports.use = (robot) ->
  new Layer robot
