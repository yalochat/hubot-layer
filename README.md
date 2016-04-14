# hubot-layer

This is [Hubot](https://hubot.github.com/) adapter to use with [Layer](https://layer.com/)

## Getting Started

#### Creating a new bot

- `npm install -g hubot coffee-script yo generator-hubot`
- `mkdir -p /path/to/myhubot`
- `cd /path/to/myhubot`
- `yo hubot`
- `npm install hubot-layer --save`
- Initialize git and make your initial commit.
- Check out the [hubot docs](https://github.com/github/hubot/tree/master/docs) for further guidance on how to build your bot.

#### Testing your bot locally

- `LAYER_TOKEN=<STAGING_LAYER_TOKEN> LAYER_APP_ID=<STAGING_LAYER_APP_ID> BOT_OPERATOR=bot.operator ./bin/hubot -a layer`

#### Deploying to Heroku

This is a modified set of instructions based on the [instructions on the Hubot wiki](https://github.com/github/hubot/blob/master/docs/deploying/heroku.md).

- Follow the instructions above to create a hubot locally

- Install [heroku toolbelt](https://toolbelt.heroku.com/) if you haven't already.
- `heroku create my-company-layerbot`
- `heroku addons:create rediscloud:30`
- Add the [config variables](#configuration). For example:

        % heroku config:add LAYER_TOKEN=<PRODUCTION_LAYER_TOKEN>
        % heroku config:add LAYER_APP_ID=<PRODUCTION_LAYER_APP_ID>
        % heroku config:add BOT_OPERATOR=<NAME_BOT_OPERATOR>

- Deploy the bot:

        % git push heroku master

- :sunglasses:

*Note*:

> Free dynos on Heroku will [sleep after 30 minutes of inactivity](https://devcenter.heroku.com/articles/dyno-sleeping). That means your hubot would leave the chat room and only rejoin when it does get traffic. This is extremely inconvenient since most interaction is done through chat, and hubot has to be online and in the room to respond to messages. To get around this, you can use the [hubot-heroku-keepalive](https://github.com/hubot-scripts/hubot-heroku-keepalive) script, which will keep your free dyno alive for up to 18 hours/day. If you never want Hubot to sleep, you will need to [upgrade to Heroku's hobby plan](https://www.heroku.com/pricing)

## Configuration

This adapter uses the following environment variables:

 - `LAYER_TOKEN` - this is the Token given by Layer that allows use Platform API.
 - `LAYER_APP_ID` - this is the App ID given by Layer.
 - `BOT_OPERATOR` - this is the name of operator that will send messages to users.

## Copyright

Copyright &copy; Yalo MIT License; see LICENSE for further details.

----

Created with :heart: by [Yalo](http://yalochat.com)
