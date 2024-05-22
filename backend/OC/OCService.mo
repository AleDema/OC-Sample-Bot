import OCApi "./OCApi";
import Result "mo:base/Result";
import Principal "mo:base/Principal";
import OCTypes "./OCTypes";
module {
public class OCServiceImpl() {

    public func registerBot(userIndexCanister : Text, {username : Text; displayName : ?Text}) : async* Result.Result<OCApi.InitializeBotResponse, Text>{
      let user_index : OCApi.UserIndexCanister = actor (userIndexCanister);
      try{
        let res = await user_index.c2c_register_bot({username= username; display_name= displayName});
        return #ok(res)
        } catch(e){
          return #err("Trapped")
        };  
    };

    public func publicSummary(groupCanisterId : Text, args : {invite_code : ?Nat64;}) : async* Result.Result<OCTypes.PublicSummaryResponse, Text>{
      let group_index : OCApi.GroupIndexCanister = actor (groupCanisterId);
      try{
        let res = await group_index.public_summary(args);
        return #ok(res)
        } catch(e){
          return #err("Trapped")
        };  
    };

    public func sendGroupMessage(groupCanisterId : Text, sender : Text, senderDisplayName : ?Text, content : OCApi.MessageContentInitial, messageId : Nat,  threadIndexId : ?Nat32) : async* Result.Result<OCApi.SendMessageResponse, Text> {
      let group_canister : OCApi.GroupIndexCanister = actor (groupCanisterId);
      try{
        let res = await group_canister.send_message_v2({
          message_id = messageId;
          thread_root_message_index = threadIndexId;
          content = content;
          sender_name = sender;
          sender_display_name = senderDisplayName;
          replies_to =  null;
          mentioned = [];
          forwarding = false;
          rules_accepted=  null;
          message_filter_failed = null;
          correlation_id= 0;
          block_level_markdown = false;
        });
        return #ok(res)
      }  catch(e){
        return #err("Trapped")
      };  
    };

    public func editGroupMessage(groupCanisterId :Text, messageId : OCApi.MessageId, newContent : OCApi.MessageContentInitial) : async* Result.Result<OCApi.EditMessageResponse, Text> {
      try{
        let group_canister : OCApi.GroupIndexCanister = actor (groupCanisterId);
        let res = await group_canister.edit_message_v2({
          message_id = messageId;
          thread_root_message_index = null;
          content = newContent;
          correlation_id= 0;
        });

        #ok(res);
      }catch(e){
        return #err("Trapped")
      }
    };

    public func joinGroup(groupCanisterId : Text, args : OCApi.JoinGroupArgs) : async* Result.Result<OCApi.JoinGroupResponse, Text> {
      try{
        let localIndexCanister : OCApi.LocalUserIndexCanister = actor (groupCanisterId);
        let res = await localIndexCanister.join_group(args);
        #ok(res);
      } catch(e){
        return #err("Trapped")
      }
    };

    public func messagesByMessageIndex(groupCanisterId : Text, args : OCApi.MessagesByMessageIndexArgs) : async* Result.Result<OCApi.MessagesByMessageIndexResponse, Text>{
      try{
        let group_canister : OCApi.GroupIndexCanister = actor (groupCanisterId);
        let res = await group_canister.messages_by_message_index(args);
        #ok(res)
      }catch(e){
        return #err("Trapped")
      };
    }
  };
    
}