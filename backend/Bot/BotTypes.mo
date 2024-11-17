import Result "mo:base/Result";
import Text "mo:base/Text";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Map "mo:map/Map";
import T "../Types";
import OCApi "../OC/OCApi";

module {

    public type BotStatus = {
        #NotInitialized;
        #Initializing;
        #Initialized;
    };

    public type BotModel= {
        groups : Map.Map<Text, ()>;
        savedMessages : Map.Map<Text, OCApi.MessageId>;
        var botStatus : BotStatus;
        var botName : ?Text;
        var botDisplayName : ?Text;
        //var lastMessageId : Nat;
    };

    public type BotService = {
        initBot: (name : Text, _displayName : ?Text) -> async Result.Result<(), Text>;
        joinGroup : (groupCanisterId : Text, inviteCode : ?Nat64) -> async* Result.Result<Text, Text>;
        sendGroupMessage : (groupCanisterId : Text, content : OCApi.MessageContentInitial, threadIndexId : ?Nat32) -> async* Result.Result<T.SendMessageResponse, Text>;
        sendTextGroupMessage : (groupCanisterId : Text, content : Text, threadIndexId : ?Nat32) -> async* Result.Result<T.SendMessageResponse, Text>;
        editGroupMessage : (groupCanisterId : Text, messageId : OCApi.MessageId, threadRootIndex : ?OCApi.MessageIndex,  newContent : OCApi.MessageContentInitial) -> async* Result.Result<OCApi.EditMessageResponse, Text>;
        editTextGroupMessage : (groupCanisterId : Text, messageId : OCApi.MessageId, threadRootIndex : ?OCApi.MessageIndex, newContent : Text) -> async* Result.Result<OCApi.EditMessageResponse, Text>;
        getGroupMessagesByIndex : (groupCanisterId : Text, indexes : [Nat32] ,latest_known_update : ?Nat64) -> async* Result.Result<OCApi.MessagesResponse, Text>;
        getNNSProposalMessageData : (message : OCApi.MessageEventWrapper) -> Result.Result<{proposalId : OCApi.ProposalId; messageIndex : OCApi.MessageIndex}, Text>;
        getLatestGroupMessageIndex : (groupCanisterId : Text) -> async* ?OCApi.MessageIndex;

        joinCommunity : (communityCanisterId : Text, inviteCode : ?Nat64) -> async* Result.Result<Text, Text>;
        joinChannel : (communityCanisterId : Text, channelId: Nat, inviteCode : ?Nat64) -> async* Result.Result<Text, Text>;
        sendChannelMessage : (communityCanisterId : Text, channelId: Nat, content : OCApi.MessageContent, threadIndexId : ?Nat32) -> async* Result.Result<T.SendMessageResponse, Text>;

        saveMessageId : (key : Text, messageid : OCApi.MessageId) -> ();
        getMessageId  : (key : Text) -> ?OCApi.MessageId;
        deleteMessageId : (key : Text) -> ();
    }


}