import static org.junit.Assert.assertEquals;

import org.junit.Test;

public class Tests2 {

        @Test
        public void test1() {
            GradleTest.Calc calc = new GradleTest.Calc();
            int summand1 = 3;
            int summand2 = 5;
            assertEquals("Sum must be " + (summand1 + summand2), (summand1 + summand2 +4-4), calc.Add(summand1, summand2));
        }
}