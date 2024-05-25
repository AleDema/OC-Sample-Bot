import OCApi "./OCApi";
import Result "mo:base/Result";
import Principal "mo:base/Principal";

module { 

  public type PublicSummaryResponse = {
      #Success: OCApi.PublicSummarySuccessResult;
      #NotAuthorized
  };

  public type OCService = {
    registerBot : (userIndexCanister : Text, {username : Text; displayName : ?Text}) -> async* Result.Result<OCApi.InitializeBotResponse, Text>;
    userSummary(userIndexCanister : Text, {userId : ?OCApi.UserId; username : ?Text}) : async* Result.Result<OCApi.UserSummaryResponse, Text>;
    publicGroupSummary : (groupCanisterId : Text, args : {invite_code : ?Nat64; }) -> async* Result.Result<PublicSummaryResponse, Text>;
    publicCommunitySummary : (groupCanisterId : Text, args : {invite_code : ?Nat64; }) -> async* Result.Result<OCApi.CommunitySummaryResponse, Text>;
    joinGroup : (groupCanisterId : Text, OCApi.JoinGroupArgs) -> async* Result.Result<OCApi.JoinGroupResponse, Text>;
    sendGroupMessage : (groupCanisterId : Text, sender : Text, senderDisplayName : ?Text, content : OCApi.MessageContentInitial, messageId : Nat,  threadIndexId : ?Nat32) -> async* Result.Result<OCApi.SendMessageResponse, Text>;
    editGroupMessage : (groupCanisterId :Text, messageId : OCApi.MessageId, newContent : OCApi.MessageContentInitial) -> async* Result.Result<OCApi.EditMessageResponse, Text>;
    messagesByMessageIndex : (Text, OCApi.MessagesByMessageIndexArgs) -> async* Result.Result<OCApi.MessagesByMessageIndexResponse, Text>;
    sendChannelMessage : (communityCanisterId : Text, channelId : Nat, sender : Text, senderDisplayName : ?Text, content : OCApi.MessageContent, messageId : Nat,  threadIndexId : ?Nat32) -> async* Result.Result<OCApi.SendMessageResponse, Text>;
    joinCommunity : (communityCanisterId : Text, args : OCApi.JoinCommunityArgs) -> async* Result.Result<OCApi.JoinCommunityResponse, Text> 
  };

}

