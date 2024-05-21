import Time "mo:base/Time";

module{
    public type TimeService = {
        now : () -> Int;
    };

    public class TimeServiceImpl() {
        public func now() : Int {
            return Time.now();
        };
    };

    public class TimeServiceMock() {
        var init = true;
        var time : Time.Time = 0;
        public func now() : Int {
            if(init){
                init := false;
                time := Time.now();
                return time;
            };
            return time;
        };

        public func advance(by : Int) : () {
            time += by;
        };

        public func reset() : () {
            time := Time.now();
        };
    };
}