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
import T "./Types";
import G "./Guards";
import OC "./OCTypes";
import MT "./MetricTypes";

shared ({ caller }) actor class OCBot() = Self {

  //TODO: find proposal id
  // receive ds
  // store in progress proposals and their message id
  // set avatar
  // send message and save messageIDs for edits

  let USER_INDEX_CANISTER = "4bkt6-4aaaa-aaaaf-aaaiq-cai";
  let LOCAL_USER_INDEX_CANISTER = "nq4qv-wqaaa-aaaaf-bhdgq-cai";
  let GROUP_INDEX_CANISTER = "4ijyc-kiaaa-aaaaf-aaaja-cai";
  let TEST_GROUP_CANISTER_ID = "evg6t-laaaa-aaaar-a4j5q-cai";
  let BOT_REGISTRATION_FEE: Nat = 10_000_000_000_000; // 10T

  stable var custodians = List.make<Principal>(caller);
  stable var groups = List.nil<Principal>();
  stable var status : T.BotStatus = #NotInitialized;
  stable var botName : Text = "";
  stable var botDisplayName : ?Text = null;
  stable var lastMessageID : Nat = 0;

  public shared({caller}) func initBot(name : Text, displayName : ?Text) : async Result.Result<Text, Text>{
    if (not G.isCustodian(caller, custodians)) {
      return #err("Not authorized");
    };

    switch(status){
      case(#NotInitialized){
        status := #Initializing;

        Cycles.add(BOT_REGISTRATION_FEE);
        let user_index : OC.UserIndexCanister = actor (USER_INDEX_CANISTER);
        try{
          let res = await user_index.c2c_register_bot({username= name; display_name= displayName});

          switch (res){
            case (#Success or #AlreadyRegistered){

              status := #Initialized;
              botName := name;
              botDisplayName := displayName;
              return #ok("Initialized");
            };
            case (#InsufficientCyclesProvided(n)) {
              status := #NotInitialized;
              return #err("Not enough cycles. Required: " # Nat.toText(n));
            };
            case(_){
              status := #NotInitialized;
              return #err("Error")
            };
          };
          status := #Initialized;
          return #ok("Initialized")
          } catch(e){
            status := #NotInitialized;
            return #err("Trapped")
          }
      };
      case(#Initializing){
        return #err("Initializing")
      };
      case(#Initialized){
        return #err("Initialized")
      }
    }
  };

  func joinGroup(groupCanisterId : Principal, inviteCode : ?Nat64) : async Result.Result<Text, Text>{

    let indexCanister = await* lookupLocalUserIndex(groupCanisterId);

    switch(indexCanister){
      case(#ok(id)){
        let localIndexCanister : OC.LocalUserIndexCanister = actor (Principal.toText(id));
        let res = await localIndexCanister.join_group({ chat_id= groupCanisterId; invite_code= inviteCode; correlation_id =  0});
        switch(res){
          case(#Success(_)){
            groups := List.push(groupCanisterId, groups);
            #ok("OK")
          };
          case(#AlreadyInGroup or #AlreadyInGroupV2(_)){
            #err("Already in group")
          };
          case(_){
            #err("Error")
          }
        }
      };
       case (#err(response)){
        return #err("Lookup error");
      }
    }
  };

  func lookupLocalUserIndex(group: Principal) : async* Result.Result<Principal, OC.GroupLookupResponse> {
    let group_canister : OC.GroupIndexCanister = actor (Principal.toText(group));
    let res = await group_canister.public_summary({ invite_code = null});

    switch(res){
      case (#Success(response)){
        #ok(response.summary.local_user_index_canister_id)
      };
      case (#NotAuthorized(_)){
        #err(#GroupNotFound)
      };
    }
  };

  func sendMessageToGroup(groupCanisterId : Principal, content : OC.MessageContentInitial, threadIndexId : ?Nat32) : async* OC.SendMessageResponse{
      let group_canister : OC.GroupIndexCanister = actor (Principal.toText(groupCanisterId));
      let res = await group_canister.send_message_v2({
        message_id = lastMessageID;
        thread_root_message_index = threadIndexId;
        content = content;
        sender_name = botName;
        sender_display_name = botDisplayName;
        replies_to =  null;
        mentioned = [];
        forwarding = false;
        rules_accepted=  null;
        message_filter_failed = null;
        correlation_id= 0;
      });
      lastMessageID := lastMessageID + 1;
     res
  };

  func sendTextMessageToGroup(groupCanisterId : Principal, content : Text, threadIndexId : ?Nat32) : async* OC.SendMessageResponse{
    await* sendMessageToGroup(groupCanisterId, #Text({text = content}), threadIndexId);
  };

  func editGroupMessage(groupCanisterId : Principal, messageId : Nat, newContent : OC.MessageContentInitial) : async* OC.EditMessageResponse{
      let group_canister : OC.GroupIndexCanister = actor (Principal.toText(groupCanisterId));
      let res = await group_canister.edit_message_v2({
        message_id = messageId;
        thread_root_message_index = null;
        content = newContent;
        correlation_id= 0;
      });

     res
  };

  func editTextGroupMessage(groupCanisterId : Principal, messageId : Nat, newContent : Text) : async* OC.EditMessageResponse{
    await* editGroupMessage(groupCanisterId, messageId, #Text({text = newContent}));
  };

  func getGroupMessagesByIndex(groupCanisterId : Principal, indexes : [Nat32] ,latest_known_update : Nat64) : async* Result.Result<OC.MessagesResponse, Text> {
    let group_canister : OC.GroupIndexCanister = actor (Principal.toText(groupCanisterId));
    let res = await group_canister.messages_by_message_index({
      thread_root_message_index = null;
      messages = indexes;
      latest_known_update = ?latest_known_update;
    });

    switch(res){
      case(#Success(val)){
        #ok(val);
      };
      case(_){
        return #err("Error")
      };
    }
  };

  // public shared({caller}) func updateTallies(tallies : [OC.Tally]) : async Result.Result<Text, Text>{
  //   if (not G.isCustodian(caller, custodians)) {
  //     return #err("Not authorized");
  //   };
  // };

  //TEST ENDPOINTS

  public shared({caller}) func joinTestGroup() : async Result.Result<Text, Text>{
    if (not G.isCustodian(caller, custodians)) {
      return #err("Not authorized: " # Principal.toText(caller));
    };

    await joinGroup(Principal.fromText(TEST_GROUP_CANISTER_ID), null);
  };

  public shared({caller}) func testJoinGroup(groupCanisterId : Principal) : async Result.Result<Text, Text>{
    if (not G.isCustodian(caller, custodians)) {
      return #err("Not authorized: " # Principal.toText(caller));
    };
    await joinGroup(groupCanisterId, null);
  };

  public shared({caller}) func testSendMessage(content : Text) : async Result.Result<OC.SendMessageResponse, Text>{
    if (not G.isCustodian(caller, custodians)) {
      return #err("Not authorized: " # Principal.toText(caller));
    };

    let res = await* sendTextMessageToGroup(Principal.fromText(TEST_GROUP_CANISTER_ID), content, null);
    #ok(res)
  };

  public shared({caller}) func testSendMessageThread(content : Text, threadIndexId : Nat32) : async Result.Result<OC.SendMessageResponse, Text>{
    if (not G.isCustodian(caller, custodians)) {
      return #err("Not authorized: " # Principal.toText(caller));
    };

    let res = await* sendTextMessageToGroup(Principal.fromText(TEST_GROUP_CANISTER_ID), content, ?threadIndexId);
    #ok(res)
  };

  public shared({caller}) func testEditMessage(messageId : Nat, newContent : Text) : async Result.Result<OC.EditMessageResponse, Text>{
    if (not G.isCustodian(caller, custodians)) {
      return #err("Not authorized: " # Principal.toText(caller));
    };

    let res = await* editTextGroupMessage(Principal.fromText(TEST_GROUP_CANISTER_ID), 3453453, newContent);
    #ok(res)
  };

  public shared({caller}) func testGetMessages(indexes : [Nat32]) : async Result.Result<OC.MessagesResponse, Text>{
    if (not G.isCustodian(caller, custodians)) {
      return #err("Not authorized: " # Principal.toText(caller));
    };

    await* getGroupMessagesByIndex(Principal.fromText(TEST_GROUP_CANISTER_ID), indexes, 0);
  };

  // ADMIN //
  public shared ({ caller }) func addCustodian(new_custodian : Principal) : async Result.Result<Text, Text> {
    if (not G.isCustodian(caller, custodians)) {
      return #err("Not authorized");
    };

    custodians := List.push(new_custodian, custodians);

    return #ok("Custodian Added");
  };

  //METRICS
  func getCanisterStatus() : async MT.CanisterStatus {
    let management_canister_actor : MT.ManagementCanisterActor = actor("aaaaa-aa");
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
    canister_status
  };

  //Waiting for OC support
  // public shared({caller}) func handle_direct_message_msgpack(data : HandleMessageArgs) : async Result.Result<Text, Text>{
  //   //TODO: validate caller

  //   let group_canister : T.GroupIndexCanister = actor (TEST_GROUP_CANISTER_ID);
  //   let res = await group_canister.messages_by_message_index(null, [], null);

  //   switch(res){
  //     case(#Success(val)){
  //       #ok(val.latest_event_index);
  //     };
  //     case(_){
  //       return #err("Error")
  //     };
  //   }
  // };

  // Not supported 
  // public func sendTestGovernanceMessage() : async T.SendMessageResponse{
  //     let group_canister : T.GroupIndexCanister = actor (TEST_GROUP_CANISTER_ID);
  //     let res = await group_canister.send_message_v2({
  //       message_id = lastMessageID; //TODO: save messageIDs for edits, 3453453
  //       thread_root_message_index = null;
  //       content = #GovernanceProposal({    
  //           my_vote = null;
  //           governance_canister_id =  Principal.fromText("rrkah-fqaaa-aaaaa-aaaaq-cai");
  //           proposal =
  //             #NNS({
  //                 id = 73327;
  //                 url =  "Text";
  //                 status =  #Open;
  //                 payload_text_rendering =  ?"Test";
  //                 tally =  {
  //                     no =  12;
  //                     yes =  12;
  //                     total =  24;
  //                     timestamp =  2222;
  //                   };
  //                 title =  "Test title";
  //                 created =  22;
  //                 topic =  5;
  //                 last_updated =  22;
  //                 deadline =  22;
  //                 reward_status =  #Settled;
  //                 summary =  "Text";
  //                 proposer =  222;
  //             });
  //         });
  //         sender_name = "test_bot";
  //       sender_display_name = null;
  //       replies_to =  null;
  //       mentioned = [];
  //       forwarding = false;
  //       rules_accepted=  null;
  //       message_filter_failed = null;
  //       correlation_id= 0;
  //     });
  //     lastMessageID := lastMessageID + 1;
  //     res
  // };
};
