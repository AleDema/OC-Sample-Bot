import T "./Types";
import TT "./TrackerTypes";
import Nat "mo:base/Nat";
import Array "mo:base/Array";
import Principal "mo:base/Principal";
import Option "mo:base/Option";
import Nat64 "mo:base/Nat64";
import Text "mo:base/Text";
import Nat32 "mo:base/Nat32";
import Int64 "mo:base/Int64";
import Iter "mo:base/Iter";
import Map "mo:map/Map";
import DateTime "mo:datetime/DateTime";
import Utils "Utils";

module {
  let { nhash; n64hash; n32hash } = Map;
  type Proposal = {proposalData : TT.ProposalAPI; messageIndex : ?Nat32; attempts : Nat};


  public func formatProposal(proposal : TT.ProposalAPI) : Text {
    var text = "Proposal " # Nat.toText(proposal.id) # "\n";
    text := text # "Title: " # proposal.title # "\n";
    text := text # "Topic: " # proposalTopicToText(T.topicIdToVariant(proposal.topicId)) # "\n";
    //add type
    let fmt = "YYYY-MM-DD HH:mm";
    let date = DateTime.DateTime(Int64.toInt(Int64.fromNat64(proposal.proposalTimestampSeconds * 1_000_000_000))); //secs to nano
    text := text # "Date Created: " # DateTime.toTextAdvanced(date, #custom({format = fmt; locale = null})) # "\n";
    text := text # "Proposer: " # Nat64.toText(proposal.proposer) # "\n";
    text
  };

  public func formatProposals(proposals : [Proposal]) : Text {
    var text = "";
    for (proposal in Array.vals(proposals)) {
      text := text # formatProposal(proposal.proposalData) # "\n\n";
    };
    text
  };

  public func formatProposalThreadMsg(ocGroupId : Text, proposalId : Nat, ocGroupMessageId : ?Nat32) : Text {
    var text = "Proposal " # Nat.toText(proposalId) # ":\n";
    text :=  text # "[Dashboard Link](https://dashboard.internetcomputer.org/proposal/" # Nat.toText(proposalId) # ")\n";
    if (Option.isSome(ocGroupMessageId)) {
      text := text # "[OpenChat Link to vote](https://oc.app/group/" # ocGroupId # "/" # Nat32.toText(Option.get(ocGroupMessageId, Nat32.fromNat(0))) # ")" # "\n";
    };
    text
  };

  public func formatBatchProposalThreadMsg(ocGroupId : Text, proposals : [Proposal]) : Text {
    var text = "";
    for (proposal in Array.vals(proposals)) {
      let _ = do ?{
        text := text # formatProposalThreadMsg(ocGroupId, proposal.proposalData.id, proposal.messageIndex) # "\n\n";
      };
    };
    text
  };

  public func isSeparateBuildProcess(title : Text) : Bool {
    if (Text.contains(title, #text "qoctq-giaaa-aaaaa-aaaea-cai") or Text.contains(title, #text "rdmx6-jaaaa-aaaaa-aaadq-cai")) {
      return true;
    };
    return false
  };


  public func extractGitHash(title : Text, description : ?Text) : ?Text {
    let #ok(descr) = Utils.optToRes(description)
    else{
      return null
    };

   if(Text.contains(title, #text "with hash")) {
      let lines = Iter.toArray(Text.split(descr, #char '\n'));

      for (line in Array.vals(lines)) {
          if (Text.startsWith(line, #text "Git hash: ")) {
              var hash = Text.trimStart(line, #text "Git Hash: ");
              return ?Text.trim(hash, #char ' ');
          } else if(Text.startsWith(line, #text "### Git Hash: ")){
              var hash = Text.trimStart(line, #text "### Git Hash: ");
              return ?Text.trim(hash, #char ' ');
          };
      };

   };
    return null;

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