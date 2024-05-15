import OC "./OCTypes";
import Principal "mo:base/Principal";
module{

  public type TextPrincipal = Text;
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

  public type VoteRecord = {
    neuronId : OC.NnsNeuronId;
    displayName : ?Text;
    vote : Vote;
  };

  type Subscriber = {
    #NNSGROUP;
    #SNSGROUP : Principal;
    #CustomGroup : Principal;
    #DirectChat : Principal;
  };


  type ProposalType = {
    #NNS;
    #SNS : Principal;
  };

 public type TallyData = {
    name : ?Text;
    //subscribers : [Subscriber];
    votes : [VoteRecord];
    proposalId : OC.ProposalId;
    proposalStatus : ProposalStatus;
    //proposalType : ProposalType;
    //proposalTopic : Nat;
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
