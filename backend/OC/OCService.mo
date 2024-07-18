import OCApi "./OCApi";
import Result "mo:base/Result";
import Principal "mo:base/Principal";
import OCTypes "./OCTypes";
import Error "mo:base/Error";

module {
public class OCServiceImpl() {

    public func registerBot(userIndexCanister : Text, {username : Text; displayName : ?Text}) : async* Result.Result<OCApi.InitializeBotResponse, Text>{
      let user_index : OCApi.UserIndexCanister = actor (userIndexCanister);
      try{
        let res = await user_index.c2c_register_bot({username= username; display_name= displayName});
        return #ok(res)
        } catch(e){
          return #err(Error.message(e))
        };  
    };

    public func userSummary(userIndexCanister : Text, {userId : ?OCApi.UserId; username : ?Text}) : async* Result.Result<OCApi.UserSummaryResponse, Text>{
      let user_index : OCApi.UserIndexCanister = actor (userIndexCanister);
      try{
        let res = await user_index.user({username= username; user_id= userId});
        return #ok(res)
        } catch(e){
          return #err(Error.message(e))
        };  
    };

    public func publicGroupSummary(groupCanisterId : Text, args : {invite_code : ?Nat64;}) : async* Result.Result<OCTypes.PublicSummaryResponse, Text>{
      let group_index : OCApi.GroupIndexCanister = actor (groupCanisterId);
      try{
        let res = await group_index.public_summary(args);
        return #ok(res)
        } catch(e){
          return #err(Error.message(e))
        };  
    };

    public func publicCommunitySummary(communityCanisterId : Text, args : {invite_code : ?Nat64;}) : async* Result.Result<OCApi.CommunitySummaryResponse, Text>{
      let community_index : OCApi.CommunityIndexCanister = actor (communityCanisterId);
      try{
        let res = await community_index.summary(args);
        return #ok(res)
        } catch(e){
          return #err(Error.message(e))
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
          new_achievement = false;
        });
        return #ok(res)
      }  catch(e){
        return #err(Error.message(e))
      };  
    };
    
    public func sendChannelMessage(communityCanisterId : Text, channelId : Nat, sender : Text, senderDisplayName : ?Text, content : OCApi.MessageContent, messageId : Nat,  threadIndexId : ?Nat32) : async* Result.Result<OCApi.SendMessageResponse, Text> {
      let channel_canister : OCApi.CommunityIndexCanister = actor (communityCanisterId);
      try{
        let res = await channel_canister.send_message({
          channel_id = channelId;
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
          community_rules_accepted= null;
          channel_rules_accepted = null;
          new_achievement = false;
        });
        return #ok(res)
      }  catch(e){
        return #err(Error.message(e))
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
          new_achievement = false;
        });

        #ok(res);
      }catch(e){
        return #err(Error.message(e))
      }
    };

    public func joinGroup(groupCanisterId : Text, args : OCApi.JoinGroupArgs) : async* Result.Result<OCApi.JoinGroupResponse, Text> {
      try{
        let localIndexCanister : OCApi.LocalUserIndexCanister = actor (groupCanisterId);
        let res = await localIndexCanister.join_group(args);
        #ok(res);
      } catch(e){
        return #err(Error.message(e))
      }
    };


    public func joinCommunity(communityCanisterId : Text, args : OCApi.JoinCommunityArgs) : async* Result.Result<OCApi.JoinCommunityResponse, Text> {
      try{
        let communityIndexCanister : OCApi.CommunityIndexCanister = actor (communityCanisterId);
        let res = await communityIndexCanister.join_community(args);
        #ok(res);
      } catch(e){
        return #err(Error.message(e))
      }
    };

    public func joinChannel(communityCanisterId : Text, args : OCApi.JoinChannelArgs) : async* Result.Result<OCApi.JoinChannelResponse, Text> {
      try{
        let communityIndexCanister : OCApi.CommunityIndexCanister = actor (communityCanisterId);
        let res = await communityIndexCanister.join_channel(args);
        #ok(res);
      } catch(e){
        return #err(Error.message(e))
      }
    };

    public func messagesByMessageIndex(groupCanisterId : Text, args : OCApi.MessagesByMessageIndexArgs) : async* Result.Result<OCApi.MessagesByMessageIndexResponse, Text>{
      try{
        let group_canister : OCApi.GroupIndexCanister = actor (groupCanisterId);
        let res = await group_canister.messages_by_message_index(args);
        #ok(res)
      }catch(e){
        return #err(Error.message(e))
      };
    }
  };
    
}