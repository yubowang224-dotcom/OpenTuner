package org.opentune.tuner;

/** Strict stream/ABI boundary used by MainActivity; no Android dependencies. */
public final class MetronomeStatus {
    private MetronomeStatus() {}
    public static boolean validRunning(double[] a, long owner) {
        if (a == null || owner <= 0) return false;
        if (!((a.length == 16 && a[0] == 1) || (a.length == 17 && a[0] == 2) || (a.length == 19 && a[0] == 3))) return false;
        for (double v : a) if (!Double.isFinite(v) || v != Math.rint(v) || Math.abs(v) > 9007199254740991d) return false;
        if (a[1] != owner || a[2] != 1 || a[3] < 8000 || a[3] > 192000 || a[4] < 0 || a[7] < 0 || a[13] != 0 || a[15] < 0 || a[15] > a[4]) return false;
        if (a[8] < 20 || a[8] > 300 || a[9] < 1 || a[9] > 12 || (a[10] != 4 && a[10] != 8) || a[11] < 1 || a[11] > 4) return false;
        if ((a[12] != 0 && a[12] != 1) || (a[14] != 0 && a[14] != 1) || a[5] < -1 || a[5] >= a[9] || a[6] < -1 || a[6] >= a[11] || (a[5] < 0) != (a[6] < 0)) return false;
        if (a.length >= 17 && (a[16] < 0 || a[16] > 100)) return false;
        return a.length < 19 || (a[17] >= 0 && a[17] <= 3 && a[18] >= a[4]);
    }
}
