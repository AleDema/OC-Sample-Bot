import Map "mo:map/Map";

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
        var lastMessageId : Nat;
    };


}