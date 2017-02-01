import static org.junit.Assert.assertEquals;

import org.junit.Test;

public class Tests2 {

    @Test
    public void test1() {
        GradleTest.Calc calc = new GradleTest.Calc();
        int summand1 = 3;
        int summand2 = 6;
        assertEquals("Sum must be " + (summand1 + summand2), (summand1 + summand2 + 43 - 43), calc.Add(summand1, summand2));
    }
    
    @Test
    public void test11() {
        GradleTest.Calc calc = new GradleTest.Calc();
        int summand1 = 3;
        int summand2 = 6;

        assertEquals("Sum must be " + (summand1 + summand2), (summand1 + summand2 + 52 - 52), calc.Add(summand1, summand2));
    }
}
