# Open Chat Bot Motoko Sample
This repo contains a basic service to interact with the Open Chat API using Motoko. It allows to register a canister as an Open Chat bot. Samples for a basic proposal bot and tally bot are also included.

## 📦 Create a New Project

Make sure that [Node.js](https://nodejs.org/en/) `>= 16` and [`dfx`](https://internetcomputer.org/docs/current/developer-docs/build/install-upgrade-remove) `>= 0.14` are installed on your system.

Run the following commands in a new, empty project directory:

```sh
git clone
dfx start --clean --background # Run dfx in the background
npm run setup # Install packages, deploy canisters, and generate type bindings

npm start # Start the development server
```

When ready, run `dfx deploy --network ic` to deploy your application to the Internet Computer.
It is advised to top up the canister with at least 12 XDR in cycles upon creation, a 0.5XDR fee is charged for instantiating a canister and 10XDR fee is charged by Open Chat in order to register a bot. The remaining cycles can be used to pay for the bot's operation. To do so this command can be used:

```
dfx canister --network ic create OCBot --with-cycles 12_000_000_000_000
```

## 🛠️ Technology Stack
- [Motoko](https://github.com/dfinity/motoko#readme): a safe and simple programming language for the Internet Computer
- [Mops](https://mops.one): an on-chain community package manager for Motoko
- [mo-dev](https://github.com/dfinity/motoko-dev-server#readme): a live reload development server for Motoko

## 📚 Documentation

- [Internet Computer docs](https://internetcomputer.org/docs/current/developer-docs/ic-overview)
- [Best practices](https://internetcomputer.org/docs/current/developer-docs/smart-contracts/best-practices/general)
- [`dfx.json` reference schema](https://internetcomputer.org/docs/current/references/dfx-json-reference/)
- [Motoko developer docs](https://internetcomputer.org/docs/current/developer-docs/build/cdks/motoko-dfinity/motoko/)
- [Mops usage instructions](https://j4mwm-bqaaa-aaaam-qajbq-cai.ic0.app/#/docs/install)
- [OC design overview](https://github.com/open-chat-labs/open-chat/blob/master/architecture/doc.md)
- [Rust bot reference](https://github.com/open-chat-labs/open-chat/tree/master/backend/bots)


## Tally Bot

### Usage

Once the canister has been deployed on mainnet, it can be interacted with either by using DFX or [Candid UI](https://a4gq6-oaaaa-aaaab-qaa4q-cai.raw.ic0.app/), if you wish to use the latter, it is first required that the principal is added to the admin list, otherwise management endpoints will not be available.
To do so, use the following command:

  ```bash
  dfx canister call OCBot addCustodian '(principal "${your-principal}")' --ic
  ```

#### Initiating the bot
In order to send messages, the canister has to be first registered as an Open Chat bot, this procedure requires the canister having at least 10XDR in cycles in its balance, otherwise it will fail. To do so, use the following command:
  ```bash
    # With both name and displayName
    dfx canister call OCBot initBot '("bot_name", opt "Display Name")'

    # With name but no displayName (null case)
    dfx canister call OCBot initBot '("bot_name", null)'
```

After the bot has been initiated, it has to be added to a channel/group in order to send messages. If the community is set to private, the bot should first be invited by an admin by using the dedicated UI.

#### Joining a group
The bot can be added to a group by using the following command:
```bash
# With an invite code
dfx canister call OCBot tryJoinGroup '("abc123", opt 123456789)'

# Without an invite code (null case)
dfx canister call OCBot tryJoinGroup '("abc123", null)'
```

#### Joining a community
The bot can be added to a community by using the following command:
```bash
# With an invite code
dfx canister call OCBot tryJoinCommunity '("abc123", opt 123456789)'

# Without an invite code (null case)
dfx canister call OCBot tryJoinCommunity '("abc123", null)'
```

#### Joining a channel
The bot can be added to a channel by using the following command:
```bash
# With an invite code
dfx canister call OCBot tryJoinChannel '("${community_id}", ${channel_id}, opt 123456789)'

# Without an invite code (null case)
dfx canister call OCBot tryJoinChannel '("${community_id}", ${channel_id}, null)'
```
Once the tally bot has been added to a community, it can be used to send tally updates to them, but in order to do so, it is first required that the community is subscribed to the list of tally IDs.

#### Subscribing to tally IDs
The tally bot can be subscribed to a list of tally IDs by using the following command:
```bash
# For Channel subscriber
dfx canister call OCBot addSubscriber '("your_tally_id", 
  variant { 
    Channel = record { 
      communityCanisterId = "${community_id}"; 
      channelId = ${channel_id 
    } 
  }
)'

# For Group subscriber
dfx canister call OCBot addSubscriber '("your_tally_id", 
  variant { 
    Group = "group_canister_id" 
  }
)'
```

#### Fetching tally subscriptions
It is possible to fetch the list of subscriptions for each tally id by using the following command:
```bash
dfx canister call OCBot getSubscribers '(opt "tally_123")'
```
The argument is optional, if not provided, all the subscriptions will be returned.

#### Deleting a tally subscription
```bash
# For Channel subscriber
dfx canister call OCBot deleteSubscription '("your_tally_id", 
  variant { 
    Channel = record { 
      communityCanisterId = "${community_id}"; 
      channelId = ${channel_id 
    } 
  }
)'

# For Group subscriber
dfx canister call OCBot deleteSubscription '("your_tally_id", 
  variant { 
    Group = "group_canister_id" 
  }
)'
```


