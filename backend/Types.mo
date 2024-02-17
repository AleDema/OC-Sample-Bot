import OC "./OCTypes";
module{

  public type BotStatus = {
    #NotInitialized;
    #Initializing;
    #Initialized;
  };

  public type RustResult<S, E> = {
    #Ok : S;
    #Err : E;
  };

  public type ProposalStatus = {
    #Executed : {#Approved; #Rejected;};
    #Pending;
  };

  public type Vote = {
    #Approved;
    #Rejected;
    #Abstained;
    #Pending;
  };

  type VoteRecords = {
    principal : Principal;
    displayName : ?Text;
    vote : Vote;
  };

 public type TallyData = {
    votes : [VoteRecords];
    proposalId : OC.ProposalId;
    proposalStatus : ProposalStatus;
    proposalTopic : Nat;
    tallyStatus : Vote;
    timestamp : Nat;
  };

  //needed cause the relative OC type doesn't return message id 
  public type SendMessageResponse = {
      #Success : {
          event_index : Nat32;
          message_index : Nat32;
          message_id : OC.MessageId;
      };
      #ChannelNotFound;
      #ThreadMessageNotFound;
      #MessageEmpty;
      #TextTooLong : Nat32;
      #InvalidPoll : OC.InvalidPollReason;
      #NotAuthorized;
      #UserNotInCommunity;
      #UserNotInChannel;
      #UserSuspended;
      #InvalidRequest : Text;
      #CommunityFrozen;
      #RulesNotAccepted;
      #CommunityRulesNotAccepted;
  };

}
