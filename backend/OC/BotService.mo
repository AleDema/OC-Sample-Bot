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

module {

  public func initModel() : BT.BotModel {
    {
      var botStatus = #NotInitialized;
      var botName = null;
      var botDisplayName = null;
      groups = Map.new<Text, ()>();
      var lastMessageId = 0;
    }
  };

  let USER_INDEX_CANISTER = "4bkt6-4aaaa-aaaaf-aaaiq-cai";
  let LOCAL_USER_INDEX_ID = "nq4qv-wqaaa-aaaaf-bhdgq-cai";
  let GROUP_INDEX_ID = "4ijyc-kiaaa-aaaaf-aaaja-cai";
  let NNS_PROPOSAL_GROUP_ID = "labxu-baaaa-aaaaf-anb4q-cai";
  let TEST_GROUP_ID = "evg6t-laaaa-aaaar-a4j5q-cai";
  let GOVERNANCE_ID = "rrkah-fqaaa-aaaaa-aaaaq-cai";
  let BOT_REGISTRATION_FEE: Nat = 10_000_000_000_000; // 10T

  public class BotService(botModel : BT.BotModel, ocService : OC.OCService, logService : LT.LogService) = {
    public func initBot<system>(name : Text, displayName : ?Text) : async Result.Result<Text, Text>{
      switch(botModel.botStatus){
        case(#NotInitialized){
          botModel.botStatus := #Initializing;
          Cycles.add<system>(BOT_REGISTRATION_FEE);
          let res = await* ocService.registerBot({username= name; display_name= displayName});
          switch(res){
            case(#ok(data)){
              switch(data){
                case (#Success or #AlreadyRegistered){
                  botModel.botStatus := #Initialized;
                  botModel.botName := ?name;
                  botModel.botDisplayName := displayName;
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


    func lookupLocalUserIndex(group: T.TextPrincipal) : async* Result.Result<Principal, Text> {
      let res = await* ocService.publicSummary(group, { invite_code = null});
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

    public func joinGroup(groupCanisterId : T.TextPrincipal, inviteCode : ?Nat64) : async* Result.Result<Text, Text>{
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


    public func sendGroupMessage(groupCanisterId : T.TextPrincipal, content : OCApi.MessageContentInitial, threadIndexId : ?Nat32) : async* Result.Result<T.SendMessageResponse, Text>{
      botModel.lastMessageId := botModel.lastMessageId + 1;
      let id = botModel.lastMessageId;
      let #ok(res) = await* ocService.sendGroupMessage(groupCanisterId, Option.get(botModel.botName, ""), botModel.botDisplayName, content, botModel.lastMessageId, threadIndexId)
      else{
        return #err("Trapped");
      };

      switch(res){
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

    func sendTextGroupMessage(groupCanisterId : T.TextPrincipal, content : Text, threadIndexId : ?Nat32) : async* Result.Result<T.SendMessageResponse, Text>{
      await* sendGroupMessage(groupCanisterId, #Text({text = content}), threadIndexId);
    };

    func editGroupMessage(groupCanisterId : T.TextPrincipal, messageId : OCApi.MessageId, newContent : OCApi.MessageContentInitial) : async* Result.Result<OCApi.MessagesResponse, Text>{
      let #ok(res) = await* ocService.editGroupMessage(groupCanisterId, messageId, newContent)
      else{
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

    func editTextGroupMessage(groupCanisterId : T.TextPrincipal, messageId : OCApi.MessageId, newContent : Text) : async* Result.Result<OCApi.MessagesResponse, Text>{
      await* editGroupMessage(groupCanisterId, messageId, #Text({text = newContent}));
    };


  };

  // func getGroupMessagesByIndex(groupCanisterId : T.TextPrincipal, indexes : [Nat32] ,latest_known_update : ?Nat64) : async* Result.Result<OC.MessagesResponse, Text> {
  //   let group_canister : OC.GroupIndexCanister = actor (groupCanisterId);
  //   let res = await group_canister.messages_by_message_index({
  //     thread_root_message_index = null;
  //     messages = indexes;
  //     latest_known_update = latest_known_update;
  //   });

  //   switch(res){
  //     case(#Success(val)){
  //       #ok(val);
  //     };
  //     case(_){
  //       return #err("Error")
  //     };
  //   }
  // };

  // func getNNSProposalMessageData(message : OC.MessageEventWrapper) : Result.Result<{proposalId : OC.ProposalId; messageIndex : OC.MessageIndex}, Text>{
  //   let event = message.event;
  //   switch(event.content){
  //     case(#GovernanceProposal(p)){
  //       switch(p.proposal){
  //         case(#NNS(proposal)){
  //           return #ok({
  //             proposalId = proposal.id;
  //             messageIndex = event.message_index;
  //           })
  //         };
  //         case(#SNS(_)){
  //           return #err("Not a NNS proposal");
  //         };
  //       }
  //     };
  //     case(_){
  //       return #err("Not a governance proposal");
  //     }
  //   }
  // };

  // func getLatestMessageIndex(groupCanisterId : T.TextPrincipal) : async* ?OC.MessageIndex{
  //   let group_canister : OC.GroupIndexCanister = actor (groupCanisterId);
  //   let res = await group_canister.public_summary({
  //     invite_code = null;
  //     correlation_id = 0;
  //   });

  //   switch(res){
  //     case(#Success(val)){
  //       return val.summary.latest_message_index;
  //     };
  //     case(_){
  //       return null;
  //     };
  //   };
  // };


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