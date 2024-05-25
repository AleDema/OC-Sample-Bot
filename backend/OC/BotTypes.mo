import Result "mo:base/Result";
import Text "mo:base/Text";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Map "mo:map/Map";
import T "../Types";
import OCApi "./OCApi";

module {

    public type BotStatus = {
        #NotInitialized;
        #Initializing;
        #Initialized;
    };

    public type BotModel= {
        groups : Map.Map<Text, ()>;
        var botStatus : BotStatus;
        var botName : ?Text;
        var botDisplayName : ?Text;
        //var lastMessageId : Nat;
    };


    public type BotService = {
        initBot: (name : Text, _displayName : ?Text) -> async Result.Result<Text, Text>;
        joinGroup : (groupCanisterId : Text, inviteCode : ?Nat64) -> async* Result.Result<Text, Text>;
        sendGroupMessage : (groupCanisterId : Text, content : OCApi.MessageContentInitial, threadIndexId : ?Nat32) -> async* Result.Result<T.SendMessageResponse, Text>;
        sendTextGroupMessage : (groupCanisterId : Text, content : Text, threadIndexId : ?Nat32) -> async* Result.Result<T.SendMessageResponse, Text>;
        editGroupMessage : (groupCanisterId : Text, messageId : OCApi.MessageId, newContent : OCApi.MessageContentInitial) -> async* Result.Result<OCApi.EditMessageResponse, Text>;
        editTextGroupMessage : (groupCanisterId : Text, messageId : OCApi.MessageId, newContent : Text) -> async* Result.Result<OCApi.EditMessageResponse, Text>;
        getGroupMessagesByIndex : (groupCanisterId : Text, indexes : [Nat32] ,latest_known_update : ?Nat64) -> async* Result.Result<OCApi.MessagesResponse, Text>;
        getNNSProposalMessageData : (message : OCApi.MessageEventWrapper) -> Result.Result<{proposalId : OCApi.ProposalId; messageIndex : OCApi.MessageIndex}, Text>;
        getLatestGroupMessageIndex : (groupCanisterId : Text) -> async* ?OCApi.MessageIndex
    }


}