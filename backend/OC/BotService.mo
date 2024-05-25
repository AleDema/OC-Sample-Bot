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
import Map "mo:map/Map";
import T "../Types";
import TU "../TextUtils";
import G "../Guards";
import OC "./OCTypes";
import OCApi "./OCApi";
import MT "../MetricTypes";
import F "../Fixtures";
import TT "../TrackerTypes";
import LS "../Log/LogService";
import LT "../Log/LogTypes";
import BT "./BotTypes";
import {  nhash; n64hash; n32hash; thash } "mo:map/Map";
import Prng "mo:prng";

  //TODOs:
  // set avatar
  // check init status
  // check group membership
module {

  public func initModel() : BT.BotModel {
    {
      var botStatus = #NotInitialized;
      var botName = null;
      var botDisplayName = null;
      groups = Map.new<Text, ()>();
      //var lastMessageId = 0;
    }
  };

  let USER_INDEX_CANISTER = "4bkt6-4aaaa-aaaaf-aaaiq-cai";
  //let LOCAL_USER_INDEX_ID = "nq4qv-wqaaa-aaaaf-bhdgq-cai";
  //let GROUP_INDEX_ID = "4ijyc-kiaaa-aaaaf-aaaja-cai";
  //let NNS_PROPOSAL_GROUP_ID = "labxu-baaaa-aaaaf-anb4q-cai";
  let TEST_GROUP_ID = "evg6t-laaaa-aaaar-a4j5q-cai";
  //let GOVERNANCE_ID = "rrkah-fqaaa-aaaaa-aaaaq-cai";
  let BOT_REGISTRATION_FEE: Nat = 10_000_000_000_000; // 10T

  public class BotServiceImpl(botModel : BT.BotModel, ocService : OC.OCService, logService : LT.LogService) = {
    public func initBot<system>(name : Text, _displayName : ?Text) : async Result.Result<Text, Text>{
      switch(botModel.botStatus){
        case(#NotInitialized){
          botModel.botStatus := #Initializing;
          Cycles.add<system>(BOT_REGISTRATION_FEE);
          let res = await* ocService.registerBot(USER_INDEX_CANISTER, {username= name; displayName= _displayName});
          switch(res){
            case(#ok(data)){
              switch(data){
                case (#Success or #AlreadyRegistered){
                  botModel.botStatus := #Initialized;
                  botModel.botName := ?name;
                  botModel.botDisplayName := _displayName;
                  return #ok("Initialized");
                };
                case (#InsufficientCyclesProvided(n)) {
                  botModel.botStatus := #NotInitialized;
                  return #err("Not enough cycles. Required: " # Nat.toText(n));
                };
                case(_){
                  botModel.botStatus := #NotInitialized;
                  return #err("Error")
                };
              }
            };
            case(#err(msg)){
              botModel.botStatus := #NotInitialized;
              return #err("Error: " # msg);
            };
            };
            botModel.botStatus := #Initialized;
            return #ok("Initialized")
        };
        case(#Initializing){
          return #err("Initializing")
        };
        case(#Initialized){
          return #err("Initialized")
        }
      }
    };


    public func getBotStatus() : BT.BotStatus {
      botModel.botStatus
    };

    public func setBotStatus() {
      botModel.botStatus := #Initialized;
    };

    public func joinGroup(groupCanisterId : Text, inviteCode : ?Nat64) : async* Result.Result<Text, Text>{
      let indexCanister = await* lookupLocalUserIndex(groupCanisterId);
      switch(indexCanister){
        case(#ok(id)){
          let #ok(res) = await* ocService.joinGroup(Principal.toText(id), { chat_id= Principal.fromText(groupCanisterId); invite_code= inviteCode; correlation_id =  0})
          else{
            return #err("Trapped");
          };

          switch(res){
            case(#Success(_)){
              Map.set(botModel.groups, thash, groupCanisterId, ());
              #ok("OK")
            };
            case(#AlreadyInGroup or #AlreadyInGroupV2(_)){
              #err("Already in group")
            };
            case(_){
              #err("Error")
            }
          };
        };
        case(#err(msg)){
           #err(msg)
        }
      };
    };

    func localCommunityIndex(communityCanisterId : Text) : async* Result.Result<Principal, Text>{
      let res = await* ocService.publicCommunitySummary(communityCanisterId, { invite_code = null});
      switch(res){
        case(#ok(data)){
        switch(data){
          case (#Success(response)){
            #ok(response.local_user_index_canister_id)
          };
          case (#PrivateCommunity(_)){
            #err("PrivateCommunity")
          };
        }
        };
        case(#err(msg)){
          #err(msg)
        };
      }
    };

    public func joinCommunity(communityCanisterId : Text, inviteCode : ?Nat64) : async* Result.Result<Text, Text>{
      let indexCanister = await* localCommunityIndex(communityCanisterId);
      switch(indexCanister){
        case(#ok(id)){
          let res = await* ocService.joinCommunity(Principal.toText(id), { 
            community_id = Principal.fromText(communityCanisterId);
            user_id = Principal.fromText("7g2oq-raaaa-aaaap-qb7sq-cai");
            principal= Principal.fromText("7g2oq-raaaa-aaaap-qb7sq-cai");
            invite_code= inviteCode;
            is_platform_moderator = false;
            is_bot= true;
            diamond_membership_expires_at= null;
            verified_credential_args=null;
          });
          switch(res){
            case(#ok(data)){
                switch(data){
                  case(#Success(_)){
                    //TODO: Add to communities
                    //Map.set(botModel.groups, thash, communityCanisterId, ());
                    #ok("OK")
                  };
                  case(#AlreadyInCommunity(_)){
                    #err("Already in community")
                  };
                  case(#GateCheckFailed(_)){
                    #err("GateCheckFailed")
                  };
                  case(#NotInvited){
                    #err("NotInvited")
                  };
                  case(#UserBlocked){
                    #err("UserBlocked")
                  };

                  case(#MemberLimitReached(limit)){
                    #err("MemberLimitReached")
                  };
                  case(#CommunityFrozen){
                    #err("CommunityFrozen")
                  };
                  case(#InternalError(e)){
                    #err("InternalError: " # e)
                  };
                };
            };
            case(#err(e)){
              #err(e)
            }
          };
        };
        case(#err(msg)){
           #err(msg)
        }
      };
    };

    public func sendGroupMessage(groupCanisterId : Text, content : OCApi.MessageContentInitial, threadIndexId : ?Nat32) : async* Result.Result<T.SendMessageResponse, Text>{
      let seed : Nat64 = Nat64.fromIntWrap(Time.now());
      let rng = Prng.Seiran128();
      rng.init(seed);
      let id = Nat64.toNat(rng.next());
      let res = await* ocService.sendGroupMessage(groupCanisterId, Option.get(botModel.botName, ""), botModel.botDisplayName, content, id, threadIndexId);
      switch(res){
        case(#ok(data)){
          switch(data){
            case(#Success(response)){
              #ok(#Success({ response with message_id = id;}))
            };
            case(#ChannelNotFound){
              #ok(#ChannelNotFound)
            };
            case(#ThreadMessageNotFound){
              #ok(#ThreadMessageNotFound)
            };
            case(#MessageEmpty){
              #ok(#MessageEmpty)
            };
            case(#TextTooLong(n)){
              #ok(#TextTooLong(n))
            };
            case(#InvalidPoll(reason)){
              #ok(#InvalidPoll(reason) )
            };
            case(#NotAuthorized){
              #ok(#NotAuthorized)
            };
            case(#UserNotInCommunity){
              #ok(#UserNotInCommunity)
            };
            case(#UserNotInChannel){
              #ok(#UserNotInChannel)
            };
            case(#UserSuspended){
              #ok(#UserSuspended)
            };
            case(#InvalidRequest(reason)){
              #ok(#InvalidRequest(reason))
            };
            case(#CommunityFrozen){
              #ok(#CommunityFrozen)
            };
            case(#RulesNotAccepted){
              #ok(#RulesNotAccepted)
            };
            case(#CommunityRulesNotAccepted){
              #ok(#CommunityRulesNotAccepted)
            };
          }
        };
        case(#err(msg)){
          #err(msg)
        }
      }
    };

    public func sendTextGroupMessage(groupCanisterId : Text, content : Text, threadIndexId : ?Nat32) : async* Result.Result<T.SendMessageResponse, Text>{
      await* sendGroupMessage(groupCanisterId, #Text({text = content}), threadIndexId);
    };

    public func editGroupMessage(groupCanisterId : Text, messageId : OCApi.MessageId, newContent : OCApi.MessageContentInitial) : async* Result.Result<OCApi.EditMessageResponse, Text>{
      let #ok(res) = await* ocService.editGroupMessage(groupCanisterId, messageId, newContent)
      else{
        return #err("Trapped");
      };

      #ok(res);
    };

    public func editTextGroupMessage(groupCanisterId : Text, messageId : OCApi.MessageId, newContent : Text) : async* Result.Result<OCApi.EditMessageResponse, Text>{
      await* editGroupMessage(groupCanisterId, messageId, #Text({text = newContent}));
    };


    public func getGroupMessagesByIndex(groupCanisterId : Text, indexes : [Nat32] ,latest_known_update : ?Nat64) : async* Result.Result<OCApi.MessagesResponse, Text> {
      let #ok(res) = await* ocService.messagesByMessageIndex(groupCanisterId, {
        thread_root_message_index = null;
        messages = indexes;
        latest_known_update = latest_known_update;
      }) else {
        return #err("Trapped");
      };

      switch(res){
        case(#Success(val)){
          #ok(val);
        };
        case(_){
          return #err("Error")
        };
      }
    };

    func lookupLocalUserIndex(group: Text) : async* Result.Result<Principal, Text> {
      let res = await* ocService.publicGroupSummary(group, { invite_code = null});
      switch(res){
        case(#ok(data)){
        switch(data){
          case (#Success(response)){
            #ok(response.summary.local_user_index_canister_id)
          };
          case (#NotAuthorized(_)){
            #err("GroupNotFound")
          };
        }
        };
        case(#err(msg)){
          #err(msg)
        };
      }
    };

    public func getNNSProposalMessageData(message : OCApi.MessageEventWrapper) : Result.Result<{proposalId : OCApi.ProposalId; messageIndex : OCApi.MessageIndex}, Text>{
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

    public func getLatestGroupMessageIndex(groupCanisterId : Text) : async* ?OCApi.MessageIndex{
     let #ok(res) = await* ocService.publicGroupSummary(groupCanisterId, { invite_code = null})
     else {
      return null;
     };

      switch(res){
        case(#Success(val)){
          return val.summary.latest_message_index;
        };
        case(_){
          return null;
        };
      };
    };


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




  // let messageRange : Nat32 = 10;
  // // Attempt to send messages for new proposals and register the corresponding message ID in the associative map.
  // // To keep payload size at a minimum it retrieves 10 messages at a time for a max of maxRetries.
  // func trySendMessages( tallies : [T.TallyData]) : async* Result.Result<Text, Text> {

  //   var index = switch(await* getLatestMessageIndex(NNS_PROPOSAL_GROUP_ID)){
  //     case(?index){index};
  //     case(_){return #err("Error")};
  //   };

  //   var _tallies = tallies;

  //   //TODO: consider compromising cross canister calls with increased payload size
  //   var maxRetries = 3;
  //   label attempts while (maxRetries > 0){
  //     maxRetries := maxRetries - 1;

  //     //generate ranges for message indexes to fetch
  //     let indexVec = Iter.range(Nat32.toNat(index) - Nat32.toNat(messageRange) , Nat32.toNat(index)) |> 
  //                       Iter.map(_, func (n : Nat) : Nat32 {Nat32.fromNat(n)}) |> 
  //                         Iter.toArray(_);
    

  //     let #ok(res) = await* getGroupMessagesByIndex(NNS_PROPOSAL_GROUP_ID, indexVec, null)
  //     else {
  //       //Error retrieving messages
  //       continue attempts;
  //     };

  //     label messages for (message in res.messages.vals()){ 
  //       let #ok(proposalData) = getNNSProposalMessageData(message)
  //       else {
  //          //This shouldn't happen unless OC changes something
  //          //TODO: log
  //          continue messages;
  //       };
  //       let exists = Array.find<T.TallyData>(_tallies, func (t : T.TallyData) : Bool {
  //         return proposalData.proposalId == t.proposalId;
  //       });


  //       let tally = switch(exists){
  //         case(?t){t};
  //         case(_){
  //           continue messages;
  //         };
  //       };

  //       var group_id = NNS_PROPOSAL_GROUP_ID;
  //       if (TEST_MODE){group_id := TEST_GROUP_ID};

  //       var messageIndex = ?proposalData.messageIndex;

  //       if(TEST_MODE){messageIndex := null};

  //       let res = await* sendTextMessageToGroup(group_id, TU.formatMessage(tally), messageIndex);

  //       switch (res){
  //         case(#Success(msgData)){
  //           //remove from tallies
  //           _tallies := Array.filter(_tallies, func(n : T.TallyData) : Bool {
  //             return n.proposalId != tally.proposalId;
  //           });

  //           //handle edge case where a proposal is settled on the first send, it won;t be updated so there is no need to add to the map
  //           switch(tally.proposalStatus){
  //             case(#Pending){
  //               //Dont save to hashmap in testmode for now
  //               if(not TEST_MODE){
  //                 Map.set(activeProposals, n64hash, proposalData.proposalId, msgData.message_id);
  //               }
  //             };
  //             case(_){};
  //           }
  //         };
  //         case(_){ //TODO: log error
  //         };
  //       };
  //     };

  //     index := index - messageRange;
  //     //return early if all tallies are matched
  //     if ((Array.size(_tallies) == 0)){
  //       return #ok("Tallies updated 2");
  //     };
  //   };

  //   var notFound = "";
  //   for(i in _tallies.vals()){
  //     notFound := notFound # Nat64.toText(i.proposalId) # " ";
  //   };

  //   //TODO: log unmatched proposal ids
  //    return #err("Max retries reached: Proposals not found: " # notFound);
  // };


  //TODO: remove
  //////////////////////////
  ////////////////// TALLIES
  //////////////////////////

  // public shared({caller}) func updateTallies(tallies : [T.TallyData]) : async Result.Result<Text, Text>{
  //   if (not G.isCustodian(caller, custodians)) {
  //     return #err("Not authorized: " # Principal.toText(caller));
  //   };

  //   var _tallies = tallies;
  //   label it for (tally in tallies.vals()){
  //     let p = switch(Map.get(activeProposals, n64hash, tally.proposalId)){
  //       case(?p){p};
  //       case(_){ continue it; };
  //     };
  //     // edit message
  //     let res = await* editTextGroupMessage(NNS_PROPOSAL_GROUP_ID, p, TU.formatMessage(tally));
  //     //TODO: log edit errors
  //     // if proposal is over, remove from map
  //     switch (tally.tallyStatus, tally.proposalStatus){
  //       //TODO: reconsider after polling canister design
  //       case((#Approved or #Rejected), #Executed(verdict)){
  //         Map.delete(activeProposals, n64hash, tally.proposalId);
  //       };
  //       case(_){};
  //     };

  //     // Remove updated tallies
  //     _tallies := Array.filter(_tallies, func(n : T.TallyData) : Bool {
  //       return n.proposalId != tally.proposalId;
  //     });
  //   };

  //   //at least one proposal is new
  //   if (Array.size(_tallies) > 0){
  //     return await* trySendMessages(_tallies);
  //   };
  //   return #ok("Tallies updated 1");
  // };


  // public shared({caller}) func test() : async Result.Result<Text, Text>{
  //   let mock = F.basicMockData();
  //   return await updateTallies(mock);
  // };

  // public shared({caller}) func test2() : async Result.Result<Text, Text>{
  //   let mock = F.wrongMockData();
  //   return await updateTallies(mock);
  // };

  // public shared({caller}) func testGetNeuron(id : Nat64) : async GT.ListNeuronsResponse{
  //   let gs = GS.GovernanceService(GOVERNANCE_ID);
  //   return await* gs.listNeurons({
  //               neuron_ids = [id];
  //               include_neurons_readable_by_caller = false;
  //           });
  // };

  // public shared({caller}) func testGetNeuronVote(id : Nat64, proposalId : OC.ProposalId) : async ({#Approved; #Rejected; #Unspecified}, Nat64, Nat64){
  //   let gs = GS.GovernanceService(GOVERNANCE_ID);
  //   return await* gs.getVoteStatus(id, proposalId);
  // };