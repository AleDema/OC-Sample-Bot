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
import Map "mo:map/Map";
import T "./Types";
import TU "./TextUtils";
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
  let LOCAL_USER_INDEX_ID = "nq4qv-wqaaa-aaaaf-bhdgq-cai";
  let GROUP_INDEX_ID = Principal.fromText("4ijyc-kiaaa-aaaaf-aaaja-cai");
  let NNS_PROPOSAL_GROUP_ID = Principal.fromText("labxu-baaaa-aaaaf-anb4q-cai");
  let TEST_GROUP_ID = "evg6t-laaaa-aaaar-a4j5q-cai";
  let BOT_REGISTRATION_FEE: Nat = 10_000_000_000_000; // 10T

  let { nhash } = Map;

  stable var custodians = List.make<Principal>(caller);
  stable var groups = List.nil<Principal>();
  stable var activeProposals = Map.new<Nat, Nat>();
  stable var botStatus : T.BotStatus = #NotInitialized;
  stable var botName : Text = "";
  stable var botDisplayName : ?Text = null;
  stable var lastMessageID : Nat = 0;

  stable var latestMessageIndex = 0;
  stable var latestProposalID = 0;

  public shared({caller}) func initBot(name : Text, displayName : ?Text) : async Result.Result<Text, Text>{
    if (not G.isCustodian(caller, custodians)) {
      return #err("Not authorized");
    };

    switch(botStatus){
      case(#NotInitialized){
        botStatus := #Initializing;

        Cycles.add(BOT_REGISTRATION_FEE);
        let user_index : OC.UserIndexCanister = actor (USER_INDEX_CANISTER);
        try{
          let res = await user_index.c2c_register_bot({username= name; display_name= displayName});

          switch (res){
            case (#Success or #AlreadyRegistered){

              botStatus := #Initialized;
              botName := name;
              botDisplayName := displayName;
              return #ok("Initialized");
            };
            case (#InsufficientCyclesProvided(n)) {
              botStatus := #NotInitialized;
              return #err("Not enough cycles. Required: " # Nat.toText(n));
            };
            case(_){
              botStatus := #NotInitialized;
              return #err("Error")
            };
          };
          botStatus := #Initialized;
          return #ok("Initialized")
          } catch(e){
            botStatus := #NotInitialized;
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

  func getGroupMessagesByIndex(groupCanisterId : Principal, indexes : [Nat32] ,latest_known_update : ?Nat64) : async* Result.Result<OC.MessagesResponse, Text> {
    let group_canister : OC.GroupIndexCanister = actor (Principal.toText(groupCanisterId));
    let res = await group_canister.messages_by_message_index({
      thread_root_message_index = null;
      messages = indexes;
      latest_known_update = latest_known_update;
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

  func getNNSProposalMessageData(message : OC.MessageEventWrapper) : Result.Result<{proposalId : Nat64; messageIndex : OC.MessageIndex}, Text>{
      let event = message.event;
      switch(event.content){
        case(#GovernanceProposal(p)){
          switch(p.proposal){
            case(#NNS(proposal)){
              return #ok({
                proposalId = proposal.id;
                messageIndex = event.message_index;
              })
            };
            case(#SNS(_)){
              return #err("Not a NNS proposal");
            };
          }
        };
        case(_){
          return #err("Not a governance proposal");
        }
      }
  };

  func getLatestMessageIndex(groupCanisterId : Principal) : async ?OC.MessageIndex{
    let group_canister : OC.GroupIndexCanister = actor (Principal.toText(groupCanisterId));
    let res = await group_canister.public_summary({
      invite_code = null;
      correlation_id = 0;
    });

    switch(res){
      case(#Success(val)){
        return val.summary.latest_message_index;
        };
        case(_){
          return null;
        };
      };
  };

  let messageRange : Nat32 = 10;
  // Attempt to send messages for new proposals and register the corresponding message ID in the associative map.
  // To keep payload size at a minimum it retrieves 10 messages at a time for a max of maxRetries.
  func trySendMessages( tallies : [ T.TallyData]) : async Result.Result<Text, Text> {

    var index = switch(await getLatestMessageIndex(NNS_PROPOSAL_GROUP_ID)){
      case(?index){index};
      case(_){return #err("Error")};
    };

    var _tallies = tallies;

    //TODO: compromise IC calls with increased payload size?
    var maxRetries = 3;
    label attempts while (maxRetries > 0){
      maxRetries := maxRetries - 1;

      //generate ranges for message indexes to fetch
      let indexVec = Iter.range(Nat32.toNat(index) - Nat32.toNat(messageRange) , Nat32.toNat(index)) |> 
                        Iter.map(_, func (n : Nat) : Nat32 {Nat32.fromNat(n)}) |> 
                          Iter.toArray(_);
    

      let #ok(res) = await* getGroupMessagesByIndex(NNS_PROPOSAL_GROUP_ID, indexVec, null)
      else {
        //Error retrieving messages
        continue attempts;
      };

      label messages for (message in res.messages.vals()){ 
        let #ok(proposalData) = getNNSProposalMessageData(message)
        else {
           //This shouldn't happen, TODO: log
           continue messages;
        };
        let exists = Array.find<T.TallyData>(_tallies, func (t : T.TallyData) : Bool {
          return Nat64.toNat(proposalData.proposalId) == t.proposalId;
        });


        let tally = switch(exists){
          case(?t){t};
          case(_){
            continue messages;
          };
        };

        //send message
        let msg = await* sendTextMessageToGroup(NNS_PROPOSAL_GROUP_ID, TU.formatMessage(tally), ?proposalData.messageIndex);

        switch (msg){
          case(#Success(msgData)){
            //remove from tallies
            _tallies := Array.filter(_tallies, func(n : T.TallyData) : Bool {
              return n.proposalId != tally.proposalId;
            });

            //handle edge case where a proposal is settled on the first send, it won;t be updated so there is no need to add to the map
            switch(tally.proposalStatus){
              case(#Pending){
                Map.set(activeProposals, nhash, Nat64.toNat(proposalData.proposalId), Nat32.toNat(msgData.message_index));
              };
              case(_){};
            }
          };
          case(_){ //TODO: log error
          };
        };
      };

      index := index - messageRange;
      //return early if all tallies are matched
      if ((Array.size(_tallies) == 0)){
        return #ok("Tallies updated");
      };
    };

    //TODO: log unmatched proposal ids
     return #err("Max retries reached");
  };

  public shared({caller}) func updateTallies(tallies : [T.TallyData]) : async Result.Result<Text, Text>{
    if (not G.isCustodian(caller, custodians)) {
      return #err("Not authorized");
    };

    var _tallies = tallies;
    label it for (tally in tallies.vals()){
      let p = switch(Map.get(activeProposals, nhash, tally.proposalId)){
        case(?p){p};
        case(_){ continue it; };
      };
      // edit message
      let res = await* editTextGroupMessage(NNS_PROPOSAL_GROUP_ID, p, TU.formatMessage(tally));

      // if proposal is over, remove from map
      switch (tally.tallyStatus, tally.proposalStatus){
        case((#Approved or #Rejected), #Executed(verdict)){
          Map.delete(activeProposals, nhash, tally.proposalId);
        };
        case(_){};
      };

      // Remove updated tallies
      _tallies := Array.filter(_tallies, func(n : T.TallyData) : Bool {
        return n.proposalId != tally.proposalId;
      });
    };

    //at least one proposal is new
    if (not (Array.size(_tallies) > 0)){
      return await trySendMessages(_tallies);
    };
    return #ok("Tallies updated");
  };

  //TEST ENDPOINTS

  public shared({caller}) func joinTestGroup() : async Result.Result<Text, Text>{
    if (not G.isCustodian(caller, custodians)) {
      return #err("Not authorized: " # Principal.toText(caller));
    };

    await joinGroup(Principal.fromText(TEST_GROUP_ID), null);
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

    let res = await* sendTextMessageToGroup(Principal.fromText(TEST_GROUP_ID), content, null);
    #ok(res)
  };

  public shared({caller}) func testSendMessageThread(content : Text, threadIndexId : Nat32) : async Result.Result<OC.SendMessageResponse, Text>{
    if (not G.isCustodian(caller, custodians)) {
      return #err("Not authorized: " # Principal.toText(caller));
    };

    let res = await* sendTextMessageToGroup(Principal.fromText(TEST_GROUP_ID), content, ?threadIndexId);
    #ok(res)
  };

  public shared({caller}) func testEditMessage(messageId : Nat, newContent : Text) : async Result.Result<OC.EditMessageResponse, Text>{
    if (not G.isCustodian(caller, custodians)) {
      return #err("Not authorized: " # Principal.toText(caller));
    };

    let res = await* editTextGroupMessage(Principal.fromText(TEST_GROUP_ID), 3453453, newContent);
    #ok(res)
  };

  public shared({caller}) func testGetMessages(indexes : [Nat32]) : async Result.Result<OC.MessagesResponse, Text>{
    if (not G.isCustodian(caller, custodians)) {
      return #err("Not authorized: " # Principal.toText(caller));
    };

    await* getGroupMessagesByIndex(Principal.fromText(TEST_GROUP_ID), indexes, ?0);
  };

  public shared({caller}) func testGetNNSProposals(indexes : [Nat32]) : async Result.Result<OC.MessagesResponse, Text>{
    if (not G.isCustodian(caller, custodians)) {
      return #err("Not authorized: " # Principal.toText(caller));
    };

    await* getGroupMessagesByIndex(NNS_PROPOSAL_GROUP_ID, indexes, ?0);
  };

  public shared({caller}) func testGetProposalsGroupLastId() : async Result.Result<OC.MessageIndex, Text>{
    if (not G.isCustodian(caller, custodians)) {
      return #err("Not authorized: " # Principal.toText(caller));
    };
    var index = switch(await getLatestMessageIndex(NNS_PROPOSAL_GROUP_ID)){
      case(?index){index};
      case(_){return #err("Error")};
    };

    return #ok(index)
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
  public shared({caller}) func getCanisterStatus() : async Result.Result<MT.CanisterStatus, Text> {
    if (not G.isCustodian(caller, custodians)) {
      return #err("Not authorized");
    };
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
    #ok(canister_status)
  };

  //Waiting for OC support
  // public shared({caller}) func handle_direct_message_msgpack(data : HandleMessageArgs) : async Result.Result<Text, Text>{
  //   //TODO: validate caller

  //   let group_canister : T.GroupIndexCanister = actor (TEST_GROUP_ID);
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
  //     let group_canister : T.GroupIndexCanister = actor (TEST_GROUP_ID);
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
