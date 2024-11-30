import Result "mo:base/Result";
import Text "mo:base/Text";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Principal "mo:base/Principal";
import Cycles "mo:base/ExperimentalCycles";
import Time "mo:base/Time";
import Random "mo:base/Random";
import List "mo:base/List";
import Nat32 "mo:base/Nat32";
import Debug "mo:base/Debug";
import Iter "mo:base/Iter";
import Option "mo:base/Option";
import Int "mo:base/Int";
import Array "mo:base/Array";
import Timer "mo:base/Timer";
import Int32 "mo:base/Int32";
import Int64 "mo:base/Int64";
import Map "mo:map/Map";
import T "../Types";
import TU "../TextUtils";
import G "../Guards";
import MT "../MetricTypes";
import F "../Fixtures";
import TT "../TrackerTypes";
import LS "../Log/LogService";
import LT "../Log/LogTypes";
import { nhash; n64hash; n32hash; thash } "mo:map/Map";
import BT "../Bot/BotTypes";
import BS "../Bot/BotService";
import OCS "../OC/OCService";
import OCApi "../OC/OCApi";
import GS "../Governance/GovernanceService";
import GT "../Governance/GovernanceTypes";
import PS "../Proposal/ProposalService";
import PB "../ProposalBot/ProposalBot";
import DateTime "mo:datetime/DateTime";
import Prng "mo:prng";
import TallyTypes "./TallyTypes";
import TallyBot "./TallyBot";
shared ({ caller }) actor class OCBot() = Self {

  let NNS_PROPOSAL_GROUP_ID = "labxu-baaaa-aaaaf-anb4q-cai";
  //let TEST_GROUP_ID = "evg6t-laaaa-aaaar-a4j5q-cai";

  stable var custodians = List.make<Principal>(caller);
  stable var allowedNotifiers = List.nil<Principal>();
  stable let logs = LS.initLogModel();
  let logService = LS.LogServiceImpl(logs, 100, true);

  stable let botData = BS.initModel();
  let ocService = OCS.OCServiceImpl();
  let botService = BS.BotServiceImpl(botData, ocService, logService);
  stable let tallyModel = TallyBot.initTallyModel();

  stable var avatar : ?OCApi.Document = null;

  let tallyBot = TallyBot.TallyBot(tallyModel, botService, logService);

      public type HttpRequest = {
        body: Blob;
        headers: [HeaderField];
        method: Text;
        url: Text;
    };

    public type HeaderField = (Text, Text);

    public type HttpResponse = {
        body: Blob;
        headers: [HeaderField];
        status_code: Nat16;
    };

    private func removeQuery(str: Text): Text {
        return Option.unwrap(Text.split(str, #char '?').next());
    };

    let CACHE_HEADER_VALUE = "public, max-age=604800, immutable";

    public query func http_request(req: HttpRequest): async (HttpResponse) {
        let path = removeQuery(req.url);
        if(path == "/avatar") {
          switch(avatar) {
            case (?avatar) {
              return {
                status_code = 200;
                headers = [
                    ("Content-Type", avatar.mime_type),
                    ("Cache-Control", CACHE_HEADER_VALUE)
                ];
                body = avatar.data;
                streaming_strategy = null;
                upgrade = null;
              }

            };
            case(_){
              return {
                  body = Text.encodeUtf8("No avatar:" # path);
                  headers = [];
                  status_code = 404;
              };
            };
          };
            return {
                body = Text.encodeUtf8("root page :" # path);
                headers = [];
                status_code = 200;
            };
        };

        return {
            body = Text.encodeUtf8("404 Not found :" # path);
            headers = [];
            status_code = 404;
        };
    };

    public func testUserSummary(userId : ?Principal, username : ?Text) : async Result.Result<OCApi.UserSummaryResponse, Text>{
    await* ocService.userSummary("4bkt6-4aaaa-aaaaf-aaaiq-cai", {userId = userId; username= username});
  };

  //////////////////////////
  ////////////////// TALLY BOT
  //////////////////////////

  public shared({caller}) func initBot<system>(name : Text, _displayName : ?Text) : async Result.Result<(), Text> {
    if (not G.isCustodian(caller, custodians)) {
      return #err("Not authorized: " # Principal.toText(caller));
    };
    await botService.initBot(name : Text, _displayName : ?Text);
  };

  public shared ({ caller }) func setAvatar(_avatar : BT.SetAvatarArgs) :  async Result.Result<BT.SetAvatarResponse, Text> {
    // if (not G.isCustodian(caller, custodians)) {
    //   return #err("Not authorized");
    // };
    avatar := _avatar.avatar;
    logService.logInfo("setAvatar", null);
    switch(await* botService.setAvatar(_avatar)){
      case(#ok(res)){
        #ok(res);
      };
      case(#err(err)){
        #err(err);
      };
    };
  };

  public shared ({ caller }) func tallyUpdate(feed : [TallyTypes.TallyFeed]) :  async Result.Result<(), Text> {
    if (not G.isCustodian(caller, allowedNotifiers)) {
      logService.logWarn("Not authorized call by:  " # Principal.toText(caller),  ?"[tallyUpdate]");
      return #err("Not authorized");
    };
    
    logService.logInfo("Tally update", null);
    await tallyBot.tallyUpdate(feed);
    #ok();
  };

  public shared ({ caller }) func toggleNNSGroup() : async Result.Result<Bool, Text> {
    if (not G.isCustodian(caller, custodians)) {
      return #err("Not authorized");
    };

    #ok(tallyBot.toggleNNSGroup());
  };

  public shared ({ caller }) func deleteAllMessageIds() : async Result.Result<(), Text> {
    if (not G.isCustodian(caller, custodians)) {
      return #err("Not authorized");
    };

    botService.deleteAllMessageIds();
    #ok();
  };


  public shared ({ caller }) func addSubscriber(tallyId : TallyTypes.TallyId, subscriber : TallyTypes.Sub) : async Result.Result<(), Text>{
    if (not G.isCustodian(caller, custodians)) {
      return #err("Not authorized");
    };
    tallyBot.addSubscriber(tallyId, subscriber)
  };

  public shared ({ caller }) func deleteSubscription(tallyId : TallyTypes.TallyId, subscriber : TallyTypes.Sub) : async Result.Result<(), Text> {
    if (not G.isCustodian(caller, custodians)) {
      return #err("Not authorized");
    };
    tallyBot.deleteSubscription(tallyId, subscriber);
  };

  public shared ({ caller }) func getSubscribers(tallyId : ?TallyTypes.TallyId) : async [(TallyTypes.TallyId, [TallyTypes.Sub])] {
    tallyBot.getSubscribers(tallyId)
  };

  //join group/channel

  public shared ({ caller }) func tryJoinGroup(groupCanisterId : Text, inviteCode : ?Nat64) : async Result.Result<Text, Text> {
    if (not G.isCustodian(caller, custodians)) {
      return #err("Not authorized");
    };

    await* botService.joinGroup(groupCanisterId : Text, inviteCode : ?Nat64);
  };


  public shared ({ caller }) func tryJoinCommunity(communityCanisterId : Text, inviteCode : ?Nat64) : async Result.Result<Text, Text> {
    if (not G.isCustodian(caller, custodians)) {
      return #err("Not authorized");
    };

    await* botService.joinCommunity(communityCanisterId : Text, inviteCode : ?Nat64, Principal.fromActor(Self));
  };

  public shared ({ caller }) func tryJoinChannel(communityCanisterId : Text, channelId : Nat, inviteCode : ?Nat64) : async Result.Result<Text, Text> {
    if (not G.isCustodian(caller, custodians)) {
      return #err("Not authorized");
    };

    await* botService.joinChannel(communityCanisterId : Text, channelId, inviteCode : ?Nat64);
  };

  public func testMatchProposalsWithMessages(proposals : [Nat64], maxEmptyRounds : ?Nat) : async Result.Result<[(Nat64, OCApi.MessageIndex)], Text> {
    let proposalSet = Map.new<Nat64, ()>();
    for (proposal in proposals.vals()) {
      Map.set(proposalSet, n64hash, proposal, ());
    };

    let #ok(res) = await* tallyBot.matchProposalsWithMessages(NNS_PROPOSAL_GROUP_ID, proposalSet, maxEmptyRounds) else {
      return #err("Error matching proposals with messages");
    };

    #ok(List.toArray(res));
  };


  public shared ({ caller }) func testSendMessageToGroup(groupCanisterId : Text, message : Text, threadIndexId : ?Nat32) : async Result.Result<T.SendMessageResponse, Text> {
    if (not G.isCustodian(caller, custodians)) {
      return #err("Not authorized");
    };
    await* botService.sendTextGroupMessage(groupCanisterId, message, threadIndexId ) 
  };

  public shared ({ caller }) func testSendMessageToChannel(communityCanisterId : Text, channelId: Nat, content : OCApi.MessageContent, threadIndexId : ?Nat32) : async Result.Result<T.SendMessageResponse, Text> {
    if (not G.isCustodian(caller, custodians)) {
      return #err("Not authorized");
    };
    await* botService.sendChannelMessage(communityCanisterId : Text, channelId: Nat, content : OCApi.MessageContent, threadIndexId : ?Nat32)
  };
  
  public shared ({ caller }) func testEditGroupMessage(groupCanisterId : Text, messageId : OCApi.MessageId, threadRootIndex : ?OCApi.MessageIndex, newContent : OCApi.MessageContentInitial) : async Result.Result<OCApi.EditMessageResponse, Text> {
    if (not G.isCustodian(caller, custodians)) {
      return #err("Not authorized");
    };
    await* botService.editGroupMessage(groupCanisterId : Text, messageId : OCApi.MessageId, threadRootIndex : ?OCApi.MessageIndex, newContent : OCApi.MessageContentInitial)
  };

  public shared ({ caller }) func testFormatBallot(groupCanisterId : Text, threadIndexId : ?Nat32, ballot : TallyTypes.Ballot) : async Result.Result<T.SendMessageResponse, Text> {
    if (not G.isCustodian(caller, custodians)) {
      return #err("Not authorized");
    };

    let message = tallyBot.formatBallot("1", ?"Test", ballot);

    await* botService.sendTextGroupMessage(groupCanisterId, message, threadIndexId ) 
  };


  //////////////////////////
  ////////////////// ADMIN
  //////////////////////////

  public shared ({ caller }) func addNotifier(new_notifier : Principal) : async Result.Result<Text, Text> {
    if (not G.isCustodian(caller, custodians)) {
      return #err("Not authorized");
    };

    allowedNotifiers := List.push(new_notifier, allowedNotifiers);

    return #ok("Notifier Added");
  };

  public shared ({ caller }) func getNotifiers() : async List.List<Principal> {
    allowedNotifiers;
  };

  public shared ({ caller }) func addCustodian(new_custodian : Principal) : async Result.Result<Text, Text> {
    if (not G.isCustodian(caller, custodians)) {
      return #err("Not authorized");
    };

    custodians := List.push(new_custodian, custodians);

    return #ok("Custodian Added");
  };

  public shared ({ caller }) func getCustodians() : async List.List<Principal> {
    custodians;
  };

  //////////////////////////
  ////////////////// METRICS
  //////////////////////////
  public shared ({ caller }) func getCanisterStatus() : async Result.Result<MT.CanisterStatus, Text> {
    if (not G.isCustodian(caller, custodians)) {
      return #err("Not authorized");
    };
    let management_canister_actor : MT.ManagementCanisterActor = actor ("aaaaa-aa");
    let res = await management_canister_actor.canister_status({
      canister_id = Principal.fromActor(Self);
    });
    Debug.print(debug_show (res.settings.controllers));
    let canister_status = {
      cycle_balance = res.cycles;
      memory_used = res.memory_size;
      daily_burn = res.idle_cycles_burned_per_day;
      controllers = res.settings.controllers;
    };
    #ok(canister_status);
  };

  //////////////////////////
  ////////////////// LOGS
  //////////////////////////
  public func getLogs(filter : ?LT.LogFilter) : async [LT.Log] {
    logService.getLogs(filter);
  };

  public shared ({ caller }) func clearLogs() : async Result.Result<(), Text> {
    if (not G.isCustodian(caller, custodians)) {
      return #err("Not authorized");
    };

    logService.clearLogs();
    #ok();
  };

};
