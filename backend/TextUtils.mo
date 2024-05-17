import T "./Types";
import TT "./TrackerTypes";
import Nat "mo:base/Nat";
import Array "mo:base/Array";
import Principal "mo:base/Principal";
import Option "mo:base/Option";
import Nat64 "mo:base/Nat64";
import Text "mo:base/Text";

module {

  func topicIdToVariant(topic : Int32) : {#RVM; #SCM; #OTHER}{
    switch(topic){
      case(8){
        return #SCM;
      };
      case(13){
        return #RVM;
      };
      case(_){
        return #OTHER;
      }
    }
  };

  public func formatProposal(proposal : TT.ProposalAPI) : Text {
    var text = "Proposal " # Nat.toText(proposal.id) # ":\n";
    text := text # "Title: " # proposal.title # "\n";
    text := text # "Topic: " # proposalTopicToText(topicIdToVariant(proposal.topicId)) # "\n";
    //add type
    //add date created
    text := text # "Proposer: " # Nat64.toText(proposal.proposer) # "\n";
    text
  };

  public func formatProposals(proposals : [TT.ProposalAPI]) : Text {
    var text = "";
    for (proposal in Array.vals(proposals)) {
      text := text # formatProposal(proposal) # "\n\n";
    };
    text
  };

  public func formatProposalThreadMsg(ocGroupId : Text, proposalId : Nat, ocGroupMessageId : ?Nat) : Text {
    var text = "Proposal " # Nat.toText(proposalId) # ":\n";
    text :=  text # "[Dashboard Link](https://dashboard.internetcomputer.org/proposal/" # Nat.toText(proposalId) # ")\n";
    if (Option.isSome(ocGroupMessageId)) {
      text := text # "[OpenChat Link to vote](https://oc.app/group" # ocGroupId # "/" # Nat.toText(Option.get(ocGroupMessageId, 0)) # "\n";
    };
    text
  };

  public func formatBatchProposalThreadMsg(ocGroupId : Text, proposals : [TT.ProposalAPI]) : Text {
    var text = "";
    for (proposal in Array.vals(proposals)) {
      text := text # formatProposalThreadMsg(ocGroupId, proposal.id, null) # "\n\n";
    };
    text
  };

  public func isSeparateBuildProcess(title : Text) : Bool {
    if (Text.contains(title, #text "qoctq-giaaa-aaaaa-aaaea-cai") or Text.contains(title, #text "rdmx6-jaaaa-aaaaa-aaadq-cai")) {
      return true;
    };
    return false
  };

  func proposalTopicToText(topic : {#SCM; #RVM; #OTHER}) : Text {
    switch(topic){
      case(#SCM){
        return "System Canister Management";
      };
      case(#RVM){
        return "IC OS Version Election";
      };
      case(#OTHER){
        return "Other";
      };
    };
  };

  public func voteToText(vote : T.Vote) : Text {
    switch(vote){
      case(#Abstained){
        return "Abstained";
        };
        case(#Approved){
          return "Accepted";
        };
        case(#Rejected){
          return "Rejected";
        };
        case(#Pending){
          return "Pending";
        };
    };
  };

  public func proposalStatusToText(status : T.ProposalStatus) : Text {
    switch(status){
      case(#Pending){
        return "Pending"; 
      };
      case(#Executed(verdict)){
        switch(verdict){
          case(#Approved){
            return "Approved";
          };
          case(#Rejected){
            return "Rejected";
          };
        };
      };
    };
  };

  public func formatMessage(tally : T.TallyData) : Text {
    var approves = 0;
    var rejects = 0;
    let total = Nat.toText(Array.size(tally.votes));

    var tmp : Text = "";
    for(voteRecord in tally.votes.vals()){
      switch(voteRecord.vote){
        case(#Approved){
          approves := approves + 1;
        };
        case(#Rejected){
          rejects := rejects + 1;
        };
        case(_){};
      };
      tmp := tmp # "Neuron ID: " # Nat64.toText(voteRecord.neuronId) # " | Alias: " # Option.get(voteRecord.displayName, "()") # " | Vote: " # voteToText(voteRecord.vote) # "\n";
    };

    var res =  "Tally Status: " # voteToText(tally.tallyStatus) # "\n Approves: " # Nat.toText(approves) # "Rejects: " #  Nat.toText(rejects) # "Total: " # total #  "\n";
    res := res # tmp;
    res
  };
};