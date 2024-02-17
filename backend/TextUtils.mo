import T "./Types";
import Nat "mo:base/Nat";
import Array "mo:base/Array";
import Principal "mo:base/Principal";
import Option "mo:base/Option";

module {
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

    var res = "Status: " # "\n";
    res := res # "Proposal ID: " # Nat.toText(tally.proposalId) # "\n";
    res := res # "Proposal Topic: " # Nat.toText(tally.proposalTopic) # "\n";
    res := res # "Proposal Status: " # proposalStatusToText(tally.proposalStatus) # "\n";
    res := res # "Tally Status: " # voteToText(tally.tallyStatus) # "Approves: " # "Rejects: " # "Total: " # total #  "\n";

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
      tmp := tmp # "Neuron ID: " # Principal.toText(voteRecord.principal) # "Display Name: " # Option.get(voteRecord.displayName, "()") # "Vote: " # voteToText(voteRecord.vote) # "\n";
    };

    res := res # tmp;
    res
  };
};