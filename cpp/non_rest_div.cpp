#include <cmath>
#include <cstdint>
#include <iostream>

int main()
{
    const int32_t A = 0x78;
    const int32_t B = 0xA;
    const bool signed_division = false;
    // Registers    
    uint64_t P_A_reg;
    uint32_t B_reg;

    // 1a. Check for special cases of the ISA
    //     - Check whether the divisor is 0.
    //     - Check overflow: Dividend=−2^(WIDTH−1)−1 and Divisor=-1
    bool zero_divisor = B==0;
    bool overflow = A==(-2^31 -1) & B==-1;
    // 1b. At the same time, pre-process the inputs based on their signs.
    //     - Initialize the registers.
    //     - Initialize the sign of "partial remainder" to 0
    bool sign_dividend = A>>31;
    bool sign_divisor = B>>31;
    if(signed_division==true){
        if(sign_dividend==true)
            P_A_reg = (uint64_t)(-A);
        else
            P_A_reg = (uint64_t)A;
        if(sign_divisor==true)
            B_reg = -B;
        else
            B_reg = B;
    }
    else{
        P_A_reg = (uint64_t)A;
        B_reg = B;
    }
    bool sign_p = P_A_reg>>63;

    // Perform n divide steps.
    uint32_t P = (P_A_reg>>32); 
    for(int i=0; i<32; i++){
        if (sign_p == true){
            // (i-a) Shift the register pair (P,A) one bit left.
            P_A_reg = P_A_reg<<1;
            // (ii-a) Add the contents of register B to P.
            P = (P_A_reg>>32); 
            P += B_reg;
            P_A_reg = (P_A_reg & 0x00000000FFFFFFFF) | ((uint64_t)P<<32);
        }
        else{
            // (i-b) Shift the register pair (P,A) one bit left.
            P_A_reg = P_A_reg<<1;
            // (ii-b) Subtract the contents of register B from P.
            P = (P_A_reg>>32);
            P -= B_reg;
            P_A_reg = (P_A_reg & 0x00000000FFFFFFFF) | ((uint64_t)P<<32);
        }
        // Get the sign of P.
        sign_p = P_A_reg>>63;
        // (iii) If P is negative, set the low-order bit of A to 0, otherwise set it to 1.
        P_A_reg = P_A_reg | !sign_p;
    }

    // After repeating this n times, the quotient is in A.
    int32_t Q = (uint32_t)P_A_reg;
    // 3. Final restoring step: If sign of "partial remainder" is negative -> add the divisor.
    int32_t R;
    // If P is nonnegative, it is the remainder.
    if (sign_p==false){
        R = P_A_reg>>32;
    // Otherwise, it needs to be restored (i.e., add b), and then it will be the remainder.
    }else{
        // (ii-a) Add the contents of register B to P.
        P = (P_A_reg>>32); 
        P += B_reg;
        P_A_reg = (P_A_reg & 0x00000000FFFFFFFF) | ((uint64_t)P<<32);
        R = P_A_reg>>32;
    }

    // 4. Post-process the results
    // - If signs of the dividend and divisor do not match -> perform 2's complement on the Quotient
    // - According to the sign of the dividend -> perform 2's complement on the Remainder to match.
    if(sign_dividend!=sign_divisor){
        Q = (~Q)+1;
    }
    if(sign_dividend==true){
        R = (~R)+1;
    }

    return 0;
}
