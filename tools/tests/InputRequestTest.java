import org.opentune.tuner.InputRequest;

public final class InputRequestTest {
    private static void require(boolean ok) { if (!ok) throw new AssertionError("input request"); }
    public static void main(String[] args) {
        InputRequest first = InputRequest.admit(false, 442, true);
        require(first != null && first.referenceHz == 442 && first.piano);
        // The first request is waiting for permission. A second busy request
        // cannot supply replacement parameters for its eventual open.
        require(InputRequest.admit(true, 400, false) == null);
        require(first.referenceHz == 442 && first.piano);
        InputRequest next = InputRequest.admit(false, 400, false);
        require(next.referenceHz == 400 && !next.piano);
        require(InputRequest.admit(false, 480, true).referenceHz == 480);
        double target=442*Math.pow(2,-90./1200);
        InputRequest partial=InputRequest.admitPartial(false,442,69,target);
        require(partial.partialMidi==69 && partial.associationHz==target && partial.referenceHz==442);
        require(InputRequest.admitPartial(true,400,21,100)==null);
        require(partial.partialMidi==69 && partial.associationHz==target);
        for(double hz:new double[]{-1,1,5001,442*Math.pow(2,151./1200),Double.NaN}){
            boolean rejected=false;try{InputRequest.admitPartial(false,442,69,hz);}catch(IllegalArgumentException expected){rejected=true;}
            require(rejected);
        }
        for (double invalid : new double[]{399, 481, Double.NaN}) {
            boolean rejected = false;
            try { InputRequest.admit(false, invalid, false); }
            catch (IllegalArgumentException expected) { rejected = true; }
            require(rejected);
        }
        System.out.println("Production InputRequest admission/immutable parameters/range passed; Android permission UI not executed");
    }
}
