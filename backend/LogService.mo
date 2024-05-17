
import Debug "mo:base/Debug";
import List "mo:base/List";

module {
    public type LogLevel = {
        #Error;
        #Warn;
        #Info;
        #Debug;
    };

    public type LogService = {
        log : (level : LogLevel, message : Text) -> ();
        // logError : (message : Text) -> ();
        // logWarn : (message : Text) -> ();
        // logInfo : (message : Text) -> ();
        // logDebug : (message : Text) -> ();
        getLogs(height : ?Nat) : [(LogLevel,Text)];
    };

    public type LogModel = {
        var logs : List.List<(LogLevel,Text)>;
    };

    public func initLogModel() : LogModel {
        {
           var logs = List.nil<(LogLevel,Text)>()
        }
    };

    public class LogServiceImpl(logModel : LogModel, maxLogSize : Nat, isDebug : Bool) {
        public func log(level : LogLevel, message : Text) : () {
            if(isDebug){
                Debug.print(message);
            };
            
            logModel.logs := List.push((level, message), logModel.logs);
            if (List.size(logModel.logs) > maxLogSize){
                let (_, tmp) = List.pop(logModel.logs);
                logModel.logs := tmp;
            };
        };

        public func getLogs(height : ?Nat) : [(LogLevel,Text)] {
            switch(height){
                case(?h){
                    if (List.size(logModel.logs) < h) {
                        return List.toArray(logModel.logs);
                    };
                    List.toArray(List.drop( logModel.logs, List.size(logModel.logs) - h));
                };
                case(_){
                    return List.toArray(logModel.logs);
                };
            }
        };
    };
}