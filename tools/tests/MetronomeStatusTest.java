import org.opentune.tuner.MetronomeStatus;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Arrays;
public final class MetronomeStatusTest {
 private static void check(boolean ok){if(!ok)throw new AssertionError("production metro stream ABI");}
 public static void main(String[] args)throws Exception {
  String raw=Files.readString(Path.of(args[0])).trim();String[] fields=raw.substring(1,raw.length()-1).split(",");double[] p=Arrays.stream(fields).mapToDouble(Double::parseDouble).toArray();
  check(p.length==19&&p[0]==3&&p[17]==2&&p[18]>p[4]);check(MetronomeStatus.validRunning(p,17));
  double[] old=Arrays.copyOf(p,17);old[0]=2;check(MetronomeStatus.validRunning(old,17));
  double[] legacy=Arrays.copyOf(p,16);legacy[0]=1;check(MetronomeStatus.validRunning(legacy,17));
  check(!MetronomeStatus.validRunning(p,18));check(!MetronomeStatus.validRunning(null,17));
  for(int index:new int[]{0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18}){
   double[] bad=p.clone();bad[index]=Double.NaN;check(!MetronomeStatus.validRunning(bad,17));
   bad=p.clone();bad[index]=.5;check(!MetronomeStatus.validRunning(bad,17));
  }
  check(!MetronomeStatus.validRunning(Arrays.copyOf(p,18),17));
  System.out.println("Production C++ ABI3 pause snapshot -> production Java decoder, plus ABI1/2 and malformed inputs passed; not Android execution");
 }
}
