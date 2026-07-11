#include<stdio.h>
#include<math.h>
int main()
{
    int x,y;
    char op;

    printf("Enter the Arithmetic problem:");
    scanf("%d %c %d", &x, &op, &y);

    if(op == '+') {
        printf("The addition is:%d\n",x+y);
    } else if(op == '-') {
        printf("The substraction is:%d\n",x-y);
    } else if(op == '*') {
        printf("The multiplication is:%d\n",x*y);
    } else if(op == '/') {
        printf("The division is:%d\n",x/y);
    } else if(op == '^') {
        printf("The power is:%.0f\n",pow(x,y));
    } else if(op == '%') {
        printf("%d is %.2f%% percentage of %d\n",x,((x*100.0)/y),y);
    } else {
        printf("ERROR \n");
    }

    return 0;
}