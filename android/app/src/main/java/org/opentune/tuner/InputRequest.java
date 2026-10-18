package org.opentune.tuner;

/** Immutable accepted request, shared with JVM admission tests. No Android API. */
public final class InputRequest {
    public final double referenceHz;
    public final boolean piano;
    public final int partialMidi;
    public final double associationHz;
    private InputRequest(double referenceHz, boolean piano, int partialMidi, double associationHz) {
        this.referenceHz = referenceHz;
        this.piano = piano;
        this.partialMidi = partialMidi;
        this.associationHz = associationHz;
    }
    public static InputRequest admit(boolean busy, double referenceHz, boolean piano) {
        if (busy) return null;
        if (!Double.isFinite(referenceHz) || referenceHz < 400 || referenceHz > 480) {
            throw new IllegalArgumentException("reference");
        }
        return new InputRequest(referenceHz, piano, -1, 0);
    }
    public static InputRequest admitPartial(boolean busy, double referenceHz, int midi) {
        return admitPartial(busy,referenceHz,midi,0);
    }
    public static InputRequest admitPartial(boolean busy, double referenceHz, int midi, double association) {
        if(busy)return null;
        if(midi<21 || midi>108)throw new IllegalArgumentException("partial target");
        InputRequest base=admit(false,referenceHz,true);
        double expected=referenceHz*Math.pow(2,(midi-69)/12.);
        if(!Double.isFinite(association)||association<0||association>0&&(association<20||association>5000||Math.abs(1200*Math.log(association/expected)/Math.log(2))>150.001))throw new IllegalArgumentException("association");
        return new InputRequest(base.referenceHz,true,midi,association);
    }
}
