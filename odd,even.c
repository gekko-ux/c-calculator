#include<stdio.h>
int main()
{
    int n;
    printf("Enter the number to check even or odd:");
    scanf("%d",&n);

    if(n % 2 == 0) {
        printf("The number is Even\n");
    } else {
        printf("The number is Odd\n");
    }

    return 0;
}