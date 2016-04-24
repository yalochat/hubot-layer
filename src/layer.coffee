{Robot,Adapter,EnterMessage,TextMessage,User} = require 'hubot'
LayerAPI = require 'layer-api'

class Layer extends Adapter
  # Events processed by the adapter
  @EVENTS: ['message.sent', 'conversation.created']

  # Typo bots allowed by the adapter
  @TYPEBOTS: ['store', 'category', 'general']

  constructor: (robot) ->
    super robot

    # Set instance variables
    @token = process.env.LAYER_TOKEN
    @appId = process.env.LAYER_APP_ID
    @operatorBot = process.env.OPERATOR_BOT
    @typeBot = process.env.TYPE_BOT or 'general'
    @logger = @robot.logger

    @logger.info 'Layer Bot: Adapter loaded :)'

  _getUser: (id) ->
    # Get user for the brain of robot
    @logger.info "Trying to get information of user in the brain of robot with ID: #{id}"
    @robot.brain.userForId id

  _createUser: (userId, conversationId, conversation, next) ->

    # Generate ID for User in the brain
    id = conversationId

    # Set default metadata if is null
    metadata = metadata or {}

    # Object that will be stored in the brain of robot
    user =
      room: conversationId
      conversation: conversation

    @logger.info 'Trying to create a new user with data:'
    @logger.info user

    # Create a new user in robot brain and call callback
    next @robot.brain.userForId id, user

  _validateConversation: (conversation) ->
    @logger.info 'Validating conversation...'

    switch @typeBot
      when 'store'
        return @operatorBot in conversation.participants
        break
      when 'category'
        return false
        break
      when 'general'
        return true
        break

  _validateMessage: (message) ->
    @logger.info 'Validating message...'

    switch @typeBot
      when 'store'
        return @operatorBot of message.recipient_status
        break
      when 'category'
        return false
        break
      when 'general'
        return true
        break

  _validateUser: (conversation, user) ->
    @logger.info 'Validating user...'

    # Get user info
    userInfo = conversation.metadata.user
    userConversation = userInfo.id or userInfo.nickname

    # If user is in the metada of conversation, is a final user
    isFinalUser = user is userConversation

    if isFinalUser then @logger.info 'Is a final user' else @logger.info 'Not is a final user'

    isFinalUser

  _processConversation: (conversation) ->
    # If id conversation is not set, return function
    return unless conversation.id?

    # Validate conversation with type of bot
    return unless @_validateConversation conversation

    # Get data used to build a new user
    _conversationId = conversation.id

    # Get user from the robot brain
    user = @_getUser _conversationId

    if user.conversation?.metadata?.user?
      @logger.info "Conversation #{_conversationId} already receive"

      # Create a instance of EnterMessage for conversation
      message = new EnterMessage user, null, null

      # Send the message to robot, in the listener 'enter'
      @_sendConversation message
    else
      @logger.info 'New conversation has been received'

      # Make request to get metadata of conversation
      @layer.conversations.get _conversationId, (err, res) =>
        return @logger.info err if err

        # Get metadata of conversation
        conversation = res.body

        # Return if does not an object as a conversation
        return unless conversation.id?

        @logger.info "Conversation #{_conversationId} has been obtained, metadata:"
        @logger.info conversation.metadata

        _userId = conversation.metadata.user.id

        # Create the new user
        @_createUser _userId, _conversationId, conversation, (user) =>
          # Create a instance of EnterMessage for conversation
          message = new EnterMessage user, null, null

          # Send the message to robot, in the listener 'enter'
          @_sendConversation message

  _sendConversation: (message) ->
    # Send only if message is not null
    if message?
      @logger.info "A conversation has been received"

      @receive message

  _processMessage: (message) ->
    # Not proccess if message has not the conversation key
    return unless message.conversation?

    # Validate message with type of bot
    return unless @_validateMessage message

    # Get data used to build a new user
    _conversationId = message.conversation.id
    _userId = message.sender.user_id

    # Ignore our own messages
    return @logger.info 'Ignore own message' if _userId is @operatorBot

    # Get user from the robot brain
    user = @_getUser _conversationId

    if user.conversation?.metadata?.user?
      @logger.info "The user already exists"

      # Validate if sender message is a final user
      return unless @_validateUser user.conversation, _userId

      # Iterate parts of message
      @_sendMessages user, message
    else
      # Make request to get metadata of conversation
      @layer.conversations.get _conversationId, (err, res) =>
        return @logger.info err if err

        # Get metadata of conversation
        conversation = res.body

        # Return if does not an object as a conversation
        return unless conversation.id?

        @logger.info "Conversation #{_conversationId} has been obtained, metadata:"
        @logger.info conversation.metadata

        # Create the new user
        @_createUser _userId, _conversationId, res.body, (user) =>
          @logger.info "A new user with the id: #{_conversationId} has been created"

          # Validate if sender message is a final user
          return unless @_validateUser user.conversation, _userId

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
        user_id: @operatorBot
      parts: [
        (body: message, mime_type: 'text/plain')
      ],
      notification:
        text: message,
        sound: 'chime.aiff'

    # Get the conversation id from the user
    conversationId = envelope.room

    @logger.info "Trying to send a message to conversation: '#{conversationId}"

    # Send message to conversation of Layer
    @layer.messages.send conversationId, data, (error, response) =>
      return @logger.info error if error

      @logger.info "The message has been sent to conversation: #{response.body.conversation.id}"

  send: (envelope, strings...) ->
    # Send a message to user
    @_sendMessage envelope, strings.join '\n'

  reply: (envelope, strings...) ->
    message = strings.join '\n'

    # Get user info from the metadata
    userInfo = envelope.user.conversation.metadata.user
    user = userInfo.nickname or userInfo.id

    # Reply a message to user
    @_sendMessage envelope, "#{user}: #{message}"

  run: ->
    # Validate if token has been setted
    unless @token
      @emit 'error', new Error 'The environment variable "LAYER_TOKEN" is required.'

    # Validate if appId has been setted
    unless @appId
      @emit 'error', new Error 'The environment variable "LAYER_APP_ID" is required.'

    # Validate if operatorBot has been setted
    unless @operatorBot
      @emit 'error', new Error 'The environment variable "OPERATOR_BOT" is required'

    # Validate type of bot
    if @typeBot not in Layer.TYPEBOTS
      @emit 'error', new Error 'The type bot is not valid'

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

      # Validate if the event received is in EVENTS
      return res.send 400 if event not in Layer.EVENTS

      @logger.info "A new event of type: '#{event}' has been received"

      # Process event
      switch event
        when 'message.sent'
          @_processMessage data.message
          break
        when 'conversation.created'
          @logger.info data.conversation
          @_processConversation data.conversation
          break

      # Send status code 'success'
      res.send 200

    # Tell Hubot we're connected so it can load scripts
    @emit 'connected'

    @logger.info 'Layer Bot is running'

exports.use = (robot) ->
  new Layer robot
